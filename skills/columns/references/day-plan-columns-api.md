# Day Plan Columns — Endpoint Reference (rkit:columns)

**Source**: https://api.resultmaps.com/api-docs/v2 — refresh from here when endpoints change or docs seem stale.

Base URL: `https://api.resultmaps.com/api/v2`
Web App: `https://resultkit.ai` — Web URL column values are paths relative to this base. NEVER link users to the legacy `app.resultmaps.com` UI.
Auth: Bearer token in `Authorization` header (handled by `scripts/api.sh`). Find your token at https://resultkit.ai/customize.

This reference covers only the three reads `rkit:columns` uses. The skill is **read-only** — it issues GETs and nothing else. Verified live against production on 2026-08-03 (all three endpoints returned 200).

---

## Call order (binding)

The Custom tab of the Prioritizer issues exactly two GETs, in this order, and `rkit:columns` must issue the same two in the same order:

1. `GET /api/v2/day-plans/today`
2. `GET /api/v2/day-plan-columns`

**Why the order is load-bearing.** `/day-plans/today` **auto-creates and populates** the caller's plan for today when one does not exist yet — an idempotent `populateDayPlan` that pulls the person's recurring items, carried-over items and priority-tagged work onto today's plan. The `items[]` embedded in `/day-plan-columns` are scoped to *today's plan*. So on a fresh day, before today's plan has been materialized, `/day-plan-columns` returns **every column with `items: []`** — a 200, no error, and a completely empty board that is not actually empty. Calling `/day-plans/today` first is what prevents it.

That failure was observed live on 2026-08-03 at 11:07 UTC: the skill called `/day-plan-columns` alone on a fresh day and reported every column empty while the Custom tab showed 20 items.

The done flows add a third read, `GET /day-plan-completions`, after those two.

---

## Day Plan Today (materializes the plan; source of the Not categorized bucket)

| Method | Path | Description | Web URL |
|--------|------|-------------|---------|
| GET | `/day-plans/today` | The caller's day plan for today, **auto-created and populated if absent** (idempotent). Returns `{ data: DayPlan }` — an object, not an array. | `/prioritizer` |

### Response envelope

```json
{ "status": 200, "body": { "data": { "id": 0, "date": "YYYY-MM-DD", "creator": { }, "items": [ /* Item[] */ ] } } }
```

Note the shape difference from the other two reads: `body.data` here is an **object**, and the items live at `body.data.items`. On `/day-plan-columns` and `/day-plan-completions`, `body.data` is an array.

### Fields this skill uses

| Field | Type | Notes |
|-------|------|-------|
| `data.date` | `YYYY-MM-DD` | Today, in the caller's timezone. |
| `data.items` | Item[] | Every item on today's plan — **including items that sit in no column**. |
| `data.items[].id` | integer | Joins to `DayPlanColumn.items[].id`. This is the key the set difference is computed on. |
| `data.items[].name` | string | What the reply templates render for an uncategorized item. |
| `data.items[].completed` | boolean | Open/done discriminator, same meaning as on column items. |
| `data.items[].position` | integer | Order on today's plan. Render uncategorized items in the order returned. |

The item objects here are the full day-plan item shape (description, status, tags, assignees, `day_plan_action_id`, …). This skill reads `id`, `name`, `completed` and nothing else.

### The "Not categorized" set difference

**No endpoint returns this bucket.** The Custom tab computes it client-side, and so does this skill:

```
notCategorized = today.items
                   .filter(i => i.completed == false)
                   .filter(i => i.id ∉ ⋃ columns[].items[].id)
```

It renders as the **first (leftmost) lane** on the Custom tab, above every column, and the skill renders it first for the same reason. Counting is **open-only** in the skill — the UI's lane badge counts completed items too, and the skill deliberately does not copy that, because the locked BDD excludes completed items from every count.

Live check, 2026-08-03: today's plan held 20 open items; the five columns held 12 of them (Mender 3, Curantis 4, ResultKit Platform 3, GTM 0, For the universe 2); the set difference was 8. 8 + 12 = 20, every item accounted for.

**Ruled by Scott 2026-08-03 (UI parity).** Not part of the 8 locked scenarios at https://resultkit.ai/pages/55 — those fixtures contain no uncategorized items, so this rule adds a group that never appears in them and contradicts nothing.

---

## Day Plan Columns (Custom Columns / Personal Planner Buckets)

Personal Planner custom column lanes — the **Custom tab** of the Prioritizer (`/prioritizer`, Personal context). All endpoints require auth. Items embedded in column responses are automatically scoped to the caller's **today** DayPlan — no filter param needed.

`rkit:columns` uses **only the GET**, and only **after** `GET /day-plans/today` — see "Call order (binding)" above. The other verbs on this resource (POST, PATCH, DELETE, reposition, drop-action) exist but are out of scope for this skill — see the sibling [`api-reference.md`](api-reference.md) if you need them. That sibling is this skill's copy of the repo-root master; `/day-plan-completions` is **not** in the master yet, so it is documented here and only here until the master gains it.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/day-plan-columns` | List all active (non-archived) columns owned by the caller, with embedded items scoped to today's plan — **empty for every column unless `/day-plans/today` has been called first**. Priority-tag filter applied to embedded items (same rule as `/day-plans/today`): non-active priority-tagged items are excluded. Returns `{ data: DayPlanColumn[] }`. | "show me my columns", "what's in my columns", "list my columns", "show custom columns", "what are my planner buckets", "show planner columns" | `/prioritizer/custom-columns` |

### Response envelope

```json
{ "status": 200, "body": { "data": [ /* DayPlanColumn */ ] } }
```

`api.sh` wraps the HTTP response — read the columns from `body.data`. No pagination meta on this endpoint.

### DayPlanColumn fields

| Field | Type | Notes |
|-------|------|-------|
| `id` | integer | Column id. Use as `column_id` on `/day-plan-completions`. |
| `name` | string | Column name as the user typed it on the Custom tab. Render verbatim. |
| `position` | integer | 0-indexed board order. **The array comes back already sorted by `position`** — render columns in the order returned. |
| `is_archived` | boolean | Always `false` in this response; archived columns are excluded server-side. |
| `color` | string \| null | 6-digit hex (e.g. `#2563EB`) or `null`. Not rendered by this skill. |
| `created_at` | ISO 8601 string | |
| `updated_at` | ISO 8601 string | |
| `items` | DayPlanColumnItem[] | Items in this column that are on **today's** plan. Empty array when the column holds nothing today — **and also when today's plan has not been materialized yet**, which is why `/day-plans/today` must be called first. The union of these `id`s across all columns is the right-hand side of the Not categorized set difference. |

### DayPlanColumnItem fields (verified live 2026-08-02)

| Field | Type | Notes |
|-------|------|-------|
| `id` | integer | Item id. |
| `name` | string | **This is what the reply templates render.** |
| `completed` | boolean | **The open/done discriminator.** `false` = open, `true` = completed. Open counts and all listing come from `completed == false` only. |
| `position` | integer | 0-indexed within the column. **The array comes back already sorted by `position`** — render items in the order returned; that is the order the user sees on the Custom tab. |
| `due` | `YYYY-MM-DD` \| null | Not rendered by this skill. |
| `recur_daily` | boolean | Not rendered by this skill. |
| `is_top` | boolean | Not rendered by this skill. |
| `assignees` | array | Not rendered by this skill. |

**No `description` field is returned on embedded column items.** The locked summary offer says "the 3 from each column (names/descriptions)", but every locked drill-in template renders **names only**. Render names only — do not invent, fetch, or synthesize descriptions.

### Sample (shape only, live 2026-08-02)

```json
{
  "id": 183,
  "name": "Mender",
  "position": 0,
  "is_archived": false,
  "color": null,
  "created_at": "2025-01-01T00:00:00.000Z",
  "updated_at": "2026-08-02T00:00:00.000Z",
  "items": [
    { "id": 206568, "name": "Performance review write up process", "completed": false, "position": 3, "due": null, "recur_daily": false, "is_top": false, "assignees": [] }
  ]
}
```

A user with no custom columns gets `200` with `{ "data": [] }` — **not** a 404. That empty array is the trigger for the no-columns fallback reply.

---

## Day Plan Completions (Historical "what's done")

Historical completions from the signed-in person's **own** day plans, most recent first. Added 2026-08-02 (w3mg/resultmaps-api2#478, PR #479) specifically to serve this skill's "what's done in my columns" scenarios; the current day-plan reads only ever surface today's plan and cannot answer them.

Binding spec: `docs/design-intent/day-plan-completions/day-plan-completions-spec.md` in `w3mg/resultmaps-api2`.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/day-plan-completions` | Historical day-plan completions for the caller, most recent first. Params (all optional): `months`, `column`, `column_id`. Default window is the last 30 days. Returns `{ data: DayPlanCompletion[] }`. | "what's done in my columns", "what have I completed", "what did I finish", "3 months", "6 months" | — |

### Query parameters

| Param | Type | Description |
|-------|------|-------------|
| `months` | positive integer | Window length in **calendar months**. **Omit for the last 30 days** (the default window). A non-positive or non-numeric value is treated as not supplied. |
| `column` | string | Only completions whose item **currently sits** in this column, matched by name, case-insensitive. Optional. |
| `column_id` | positive integer | The same filter by column id. **Wins over `column` when both are sent.** Optional. |

**Scenario → parameter mapping (this is the whole mapping — do not invent others):**

| The user's window | Request |
|---|---|
| "the last 30 days" (default, first done reply) | `GET /day-plan-completions` — **no `months` param** |
| "3 months" | `GET /day-plan-completions?months=3` |
| "6 months" | `GET /day-plan-completions?months=6` |

**No fan-out — but two GETs, in a fixed order.** The whole skill is `/day-plans/today` then `/day-plan-columns`, plus, on a done ask, **one** `/day-plan-completions`. (An earlier version of this reference claimed "one GET" — that was wrong, and it is what produced the empty-columns defect.) That single completions request serves the entire window at every window size. Never issue one call per date, per column, or per month to assemble an answer. The column filter is optional and this skill does not use it — one unfiltered request returns every column's completions, already carrying the column each item sits in.

### Response envelope

```json
{ "status": 200, "body": { "data": [ /* DayPlanCompletion */ ] } }
```

### DayPlanCompletion fields (verified live 2026-08-02)

| Field | Type | Notes |
|-------|------|-------|
| `item_id` | integer | The completed item's id. Note the name — it is `item_id`, **not** `id`. |
| `name` | string | **This is what the reply templates render.** |
| `completed_on` | `YYYY-MM-DD` | Date-only, in the person's own timezone. Not rendered by this skill's templates — used only for ordering, which the API already applies. |
| `column` | `{ id, name }` \| **null** | The day-plan column the item **currently** sits in, or `null` if it sits in none (never placed, or its only placement was in a column the user has since archived). `null` → the **`Not categorized`** group, rendered first and counted. |

Ordering: **most recent first** by `completed_on`. The array is already sorted — within a column group, keep the order returned.

A completion is per-day: the same item finished on two different days is two entries.

`column: null` is common in live data — 3 of the 5 completions in the default 30-day window on a real account on 2026-08-03 carried it. They render under a **`Not categorized`** group, first, above every column, and they are counted in the total. **Ruled by Scott 2026-08-03 (UI parity), not page-55-locked** — see case 8 under "Cases the locked spec does not cover".

### Sample (shape only, live 2026-08-02)

```json
[
  { "item_id": 222747, "name": "Write Mender annual reviews (Gus)", "completed_on": "2026-07-30", "column": null },
  { "item_id": 222571, "name": "Updated Billing Milestones to John", "completed_on": "2026-07-19", "column": { "id": 155, "name": "GTM" } }
]
```

---

## Error handling

`api.sh` returns `{ "status": <int>, "body": <object> }`, or `{ "status": 0, "error": "<CODE>" }`.

| Status | Response |
|---|---|
| `error: NO_CONFIG` | "Config not found. Run `/rkit:setup` first." |
| `error: NO_TOKEN` | "No API token. Run `/rkit:setup` to configure." |
| `error: CURL_FAILED` | "Network error. Check your connection." |
| `status: 401` | "Unauthorized. Run `/rkit:setup` to update your token." |
| `status: 404` | "Not found." |
| Other non-200 | Show status code and error message from the response body. |

`200` with `{ "data": [] }` is **not** an error on either endpoint — it is the normal answer for "nothing there".

---

## Cases the locked spec does not cover

The 8 locked scenarios at https://resultkit.ai/pages/55 are law. These situations fall outside them. They are recorded here, not silently absorbed into the templates — if one comes up in real use, it is a spec question, not a rendering decision.

1. **Singular counts in the header lines.** The locked headers read "— 6 open items total" and "— 2 completed items in the last 30 days". No scenario shows a total of 1. Substitute the number and change nothing else; do not re-word to "item".
2. **More than one column truncated in the "3 from each" reply.** ~~Open question.~~ **RULED by Scott 2026-08-03 — no longer an uncovered case.** Scenario 2b locks the closing line for **exactly one** truncated group only — "Want the rest of Deep Work, or the complete list from every column?" — and that single-group form stays exactly as locked. When two or more groups are truncated in the same reply (Not categorized counts as a group here, same as everywhere else), the closing line names every truncated group in display (board) order, joined with "and": `Want the rest of {A} and {B}, or the complete list from every column?` for exactly two; `Want the rest of {A}, {B}, and {C}, or the complete list from every column?` for three or more. Not page-55-locked — no locked fixture truncates two groups at once, so no locked template is affected by this ruling.
3. **"the rest of &lt;column&gt;".** Scenario 2b offers it; no scenario locks the reply. Nearest locked behavior is the complete-list reply (Scenario 3/3b template).
4. **The done ask when the user has no custom columns at all.** Scenario 5 locks the fallback for "show me my columns and what's in each". Reuse that same locked sentence — there are no columns to report on either way. No new wording.
5. **A done window that returns nothing.** No scenario shows an empty done reply. Whatever is shown, Scenario 4's invariant still binds: never state or imply that completed history is gone, cleared, or deleted.
6. **Every column empty of open items.** No scenario shows a summary where no column has an open item. The templates still substitute mechanically — a `0` total, an empty top list, every column under "These columns have no open items:", and the locked drill-in offer that now has nothing to drill into.
7. **The 6-month header.** Scenario 4b locks "in the last 3 months" for `months=3`. `months=6` substitutes the number into that same phrase — "in the last 6 months" — and closes with nothing, since no further extension is offered. Substitution only, no new wording.
8. **A completion whose `column` is `null`.** ~~Open question.~~ **RULED by Scott 2026-08-03 — no longer an uncovered case.** The live endpoint returns them, and often — 3 of 5 in the real 30-day window on 2026-08-03. They render under a **`Not categorized`** group, placed **first**, above every column, and they **are counted in the total**. Nothing is dropped. This is the same UI-parity ruling that put the Not categorized lane at the front of the open-item flows; it mirrors the Custom tab, where the uncategorized lane is leftmost. It replaces the previous interim "drop it" rule, which made the reply understate what the user had finished. Not page-55-locked — the locked fixtures carry no `column: null` completion, so no locked template is affected, and with none in the window the reply is byte-identical to the locked one.
9. **The user takes up the "create" offer after Scenario 5.** The locked no-columns sentence ends by offering to create columns, but nothing is specced past that point and **no rkit skill owns `POST /day-plan-columns`** — `rkit:columns` is read-only, and the create/rename/archive/reposition verbs documented in the sibling [`api-reference.md`](api-reference.md) have no skill behind them. Which skill should own them, and what that reply reads like, is a spec question for Scott. **Interim behavior:** the request is uncovered — do not write, and do not improvise a create flow inside this skill.
10. **An ambiguous follow-up to the summary.** The summary offers two paths ("the 3 from each" / "the complete list"); no scenario covers a reply that clearly answers the offer but picks neither cleanly. This skill never uses AskUserQuestion and no locked template supplies a clarifying question, so asking is not available. **Interim behavior:** route to the closest matching flow. A follow-up that stays genuinely unresolvable is an uncovered case, and what should happen then is a spec question for Scott.
