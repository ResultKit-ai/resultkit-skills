---
name: rkit:columns
description: Day Plan Columns — read the custom columns on the Custom tab of your personal Prioritizer — which columns you have, what's open in each, and what you've completed in them. Use this skill whenever someone asks about their day plan columns, custom columns, planner columns, or planner buckets — "show me my columns", "show me my columns and what's in each", "what's in my columns", "what's in each column", "list my columns", "show custom columns", "show planner columns", "what are my planner buckets", "my day plan columns", "what's done in my columns", "what have I completed in my columns". Follow-ups inside an already-open columns conversation ("the 3 from each", "the complete list", "the rest of {column}", "3 months", "6 months") are routed by this skill's Tool Routing Table once it is loaded — they are deliberately not listed here, because on their own they say nothing about columns. Read-only — it never adds, completes, moves, renames, or deletes anything.
# NOTE: this skill must stay model-invocable — the locked BDD (https://resultkit.ai/pages/55) has the user invoke it by typing a plain sentence. Never add `disable-model-invocation` here.
user-invocable: true
allowed-tools: Bash(*/skills/columns/scripts/api.sh GET *), Bash(jq *), Read, Glob, Grep
# NOTE: the api.sh pattern is deliberately unlike the siblings' `Bash(scripts/api.sh *)`. That
# relative pattern does not match this skill's invocations, which use the resolved absolute path;
# verified 2026-08-03 that it is denied. `*/skills/columns/scripts/api.sh GET *` matches every
# install location (plugin cache, $CLAUDE_PLUGIN_ROOT, ./skills/..., ./.claude/skills/...), matches
# both the bare and the relative form, and denies both another script's path and any verb other than
# GET — so the read-only invariant is enforced at the permission layer, not just by prose.
---

# rkit:columns

Reads the personal planner's day-plan custom columns. **Read-only.**

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh: !`CACHE=$(ls -1d "$HOME"/.claude/plugins/cache/*/rkit/*/skills/columns/scripts/api.sh 2>/dev/null | sort -rV | head -1); for p in "${CLAUDE_PLUGIN_ROOT}/skills/columns/scripts/api.sh" "$CACHE" "./skills/columns/scripts/api.sh" "./.claude/skills/columns/scripts/api.sh" "$HOME/.claude/skills/rkit:columns/scripts/api.sh" "$HOME/.agents/skills/columns/scripts/api.sh" "$HOME/.gemini/skills/columns/scripts/api.sh"; do [ -f "$p" ] && { echo "$p"; exit 0; }; done; echo "NOT_FOUND"`

## Rules

- **The templates are law.** Every reply below is locked wording — https://resultkit.ai/pages/55, 8 scenarios locked 2026-08-02. Reproduce the wording, punctuation, blank lines, and ordering exactly. Substitute counts and names; change nothing else. No preamble, no sign-off, no extra commentary, no headings, no bold, no item IDs, no dates, no emoji.
- **Emit as plain lines**, not inside a code fence and not as a table. The fences below mark where each template starts and stops.
- **Read-only skill.** GETs only. Never POST, PATCH, PUT, or DELETE. (`GET /day-plans/today` materializes today's plan server-side as part of serving it — idempotent, and exactly what the Custom tab triggers. That is the server populating a plan, not this skill writing.) The closing offers ("check anything off", "add anything new", "create") are conversational — if the user takes one up, hand off to the skill that owns that action (`rkit:today` for day-plan writes). No rkit skill owns column creation (`POST /day-plan-columns`), so the "create" offer has no handoff target — that is an uncovered case, listed in `references/day-plan-columns-api.md`. This skill never writes.
- **Never ask before reading.** GETs execute immediately. Never use AskUserQuestion — the offers are literal reply lines, not prompts.
- **No fan-out.** Two GETs in a fixed order — `GET /day-plans/today`, then `GET /day-plan-columns` — and, for done flows, one more `GET /day-plan-completions`. Never one call per date, per column, or per month.
- **Board order everywhere.** `/day-plan-columns` returns columns already sorted by `position` — that is the Custom-tab order the user sees. Render columns in the order returned, in every reply. Within a column, render items in the order returned. The **Not categorized** group always renders *before* the first column, because that is where the Custom tab puts it.

---

## Tool Routing Table

Match the user's message against the **Triggers** column. Pick the first matching row.

| Triggers | Intent | Flow |
|---|---|---|
| "show me my columns", "show me my columns and what's in each", "what's in my columns", "what's in each column", "list my columns", "show custom columns", "show planner columns", "what are my planner buckets", "my day plan columns" | Summary of columns with open counts | `summary` |
| "the 3 from each", "the 3 from each column", "3 from each", "show me the 3" — **only** as a reply to the summary offer in this session | Drill in — first 3 open per column | `three_from_each` |
| "the complete list", "the complete list from each", "the full list", "everything", "all of them", "the complete list from every column" — **only** as a reply to the summary offer in this session | Drill in — every open item per column | `complete_list` |
| "what's done in my columns", "what's done in my columns?", "what have I completed", "what did I finish", "show me what's done", "completed in my columns" | Completions, last 30 days | `whats_done` |
| "3 months", "the last 3 months", "6 months", "the past 6 months", "extend it", "go back further" — **only** as a reply to a done offer | Completions, extended window | `extend_done` |
| "the rest of {column}" — **only** as a reply to a truncated `three_from_each` | Not locked by any scenario | `rest_of_column` |

**Cold entry.** Only two rows can fire with no prior columns reply in this session — `summary` (Scenarios 1 and 5) and `whats_done` (Scenario 4). Those are the locked cold entries. Any other columns-related ask arriving cold, including one shaped like a drill-in follow-up, runs `summary` first — it is the only locked cold entry into the open-item ladder. The four session-guarded rows never fire on their own: with no reply for them to answer, a bare "the 3 from each", "the complete list", "everything", "all of them", "the rest of X", "3 months", or "6 months" is not a trigger for this skill at all.

**Never ask which option the user meant.** This skill never uses AskUserQuestion, and no locked scenario supplies a clarifying-question template. Route an ambiguous follow-up to the closest matching flow. If it is genuinely unresolvable, it is an uncovered case — see "Cases the locked spec does not cover" in `references/day-plan-columns-api.md`.

---

## Conversation ladder

```
summary ──┬─→ three_from_each ──(only if a column was truncated, which
          │                       offers both branches below)──┬─→ rest_of_column ──→ (renders the
          │                                                    │                       complete_list reply)
          │                                                    └─→ complete_list
          └─→ complete_list ──→ (ends the ladder — offers actions, never more listing)

whats_done ──→ extend_done (3 months) ──→ extend_done (6 months)
```

The done flows are a **separate branch**. They are entered by an explicit done ask only — never offered from the summary or drill-in replies, and never mixed into them.

---

## Flows

### Shared step — fetch today's plan, then the columns

Every flow starts here. **Two GETs, in this exact order.** This is the order the Custom tab itself issues, and the order is load-bearing.

**1. Today's plan — always first.**

```bash
"<api.sh path>" GET "/day-plans/today"
```

**2. The columns — second.**

```bash
"<api.sh path>" GET "/day-plan-columns"
```

**Why the order matters.** `/day-plans/today` auto-creates and populates today's plan when it does not exist yet (idempotent `populateDayPlan` server-side). The items embedded in `/day-plan-columns` are scoped to today's plan, so on a fresh day — before anything has materialized that plan — calling `/day-plan-columns` first returns **every column with `items: []`**, and the skill reports an empty board that is not empty. Fetching today first is what prevents that. Never reverse them, and never skip step 1.

**Issue them as two separate Bash calls, each a bare invocation** — exactly as written above. Do not chain them with `&&`, `;`, or a pipe; do not assign the path to a shell variable; do not wrap the call in `$( )`; do not append `echo`. The skill's `allowed-tools` permits only the bare `GET` form, and anything else is denied.

Read today's items from `body.data.items` (step 1) and the columns from `body.data` (step 2). Then compute, once:

- **Open items in a column** = that column's `items` where `completed == false`. Completed items are dropped here, once, and are invisible to every open-item flow below.
- **Not categorized** = today's items where `completed == false` **and** whose `id` does not appear in any column's `items[]`. It is a **set difference the caller computes** — no endpoint returns this bucket, and the Custom tab builds it the same way.
- `TOTAL` = the Not categorized open count **plus** the open counts of all columns.

Then:

- `body.data` from `/day-plan-columns` is **empty** → run `no_columns`. Stop. Nothing else renders — not the columns, not the Not categorized group, not a single day-plan item.

---

### The "Not categorized" group

**Ruled by Scott 2026-08-03 (UI parity) — not page-55-locked.** The eight locked templates below are unchanged and stay byte-frozen. Their fixtures hold zero uncategorized items, so a Not categorized group never appears in any of them; nothing here contradicts them.

- **Position: first.** It renders above every column in `summary`, `three_from_each`, and `complete_list` — the leftmost lane on the Custom tab.
- **Label:** exactly `Not categorized`. In `summary` the line reads `- Not categorized — N open`. In the drill-in flows the header reads `Not categorized — N open`, or `Not categorized — N open (showing 3)` when truncated.
- **Open-only counting, like every column.** The Custom tab's own badge counts completed items too — **do not copy that.** The locked invariants exclude completed items from every count in every reply.
- **It participates in `TOTAL`.**
- **Zero open uncategorized items → it does not render at all.** No `— 0 open` line, and it is never named under "These columns have no open items:" — it is not a column. With nothing uncategorized, every reply is byte-identical to the locked templates.
- **Truncation and the closing offer treat it exactly like a column.** 4+ open in `three_from_each` → first 3 only, header `Not categorized — N open (showing 3)`. If it is the only truncated group, the locked Scenario 2b closing line substitutes its name: `Want the rest of Not categorized, or the complete list from every column?` — substitution into locked wording, nothing new.

---

### summary

Run the shared step. `TOTAL` = Not categorized open + the sum of open items across all columns.

Split the columns, keeping board order in both groups:
- **With open items** — one line each in the top list, under the Not categorized line.
- **With no open items** — named in the "no open items" chunk. This covers a column holding nothing *and* a column holding only completed items. They read identically.

```
Your day plan columns — TOTAL open items total

- Not categorized — N open
- COLUMN — N open
- COLUMN — N open

These columns have no open items:
- COLUMN
- COLUMN

Want the 3 from each column (names/descriptions), or the complete list from each?
```

The `- Not categorized — N open` line is present only when there is at least one uncategorized open item, and is always the **first** line of the top list. Omit the "These columns have no open items:" chunk and its preceding blank line when every column has at least one open item. **Inferred, not locked** — every locked scenario has at least one column with no open items, so no scenario shows what the reply looks like without that chunk. Keep this behavior until a scenario locks it.

**Locked example** (Scenario 1 — Deep Work 3 open + 1 completed, Code Review 2, Quick Hits 1, Waiting On 1 completed only, Someday empty):

```
Your day plan columns — 6 open items total

- Deep Work — 3 open
- Code Review — 2 open
- Quick Hits — 1 open

These columns have no open items:
- Waiting On
- Someday

Want the 3 from each column (names/descriptions), or the complete list from each?
```

The total reads 6, not 7 — the completed "Review Alya's ops intake spec" is neither shown nor counted. Evan has nothing uncategorized in this fixture, so no Not categorized line renders and the reply is exactly the locked one.

---

### three_from_each

Run the shared step. Same `TOTAL` and same split as `summary`.

For the Not categorized group first (when it has open items), then each column with open items in board order: a header line, then **at most the first 3** open items in the order returned.

- 3 or fewer open → header `COLUMN — N open`, list all of them.
- More than 3 open → header `COLUMN — N open (showing 3)`, list the first 3 only. `N` is the full open count, not 3.

```
Your day plan columns — TOTAL open items total

Not categorized — N open
- ITEM
- ITEM

COLUMN — N open
- ITEM
- ITEM

COLUMN — N open (showing 3)
- ITEM
- ITEM
- ITEM

These columns have no open items:
- COLUMN
- COLUMN

Want the rest of COLUMN, or the complete list from every column?
```

The closing offer appears **only when at least one group was truncated** — the Not categorized group counts as a group for this purpose. With nothing truncated the reply ends after the "no open items" chunk — no closing line at all.

Scenario 2b locks that closing line for **exactly one** truncated group ("Want the rest of Deep Work, or the complete list from every column?") — that single-truncated form is unchanged. **Ruled by Scott 2026-08-03, not page-55-locked:** when two or more groups are truncated in the same reply — Not categorized counts as a group here too — the closing line names every truncated group in display (board) order, joined with "and": exactly two groups reads `Want the rest of {A} and {B}, or the complete list from every column?`; three or more reads `Want the rest of {A}, {B}, and {C}, or the complete list from every column?`. Substitution into the same locked frame — nothing invented beyond the join. See "Cases the locked spec does not cover" in `references/day-plan-columns-api.md` — that entry is now marked RULED.

**Locked example, nothing truncated** (Scenario 2):

```
Your day plan columns — 6 open items total

Deep Work — 3 open
- Finish sprint API contract
- Draft Q1 dev process rock plan
- Refactor auth middleware

Code Review — 2 open
- Review Gregor's delivery checklist PR
- Review onboarding SOP draft

Quick Hits — 1 open
- Reply to Sue re: defect report

These columns have no open items:
- Waiting On
- Someday
```

**Locked example, one column truncated** (Scenario 2b — Deep Work holds 7 open):

```
Your day plan columns — 10 open items total

Deep Work — 7 open (showing 3)
- Finish sprint API contract
- Draft Q1 dev process rock plan
- Refactor auth middleware

Code Review — 2 open
- Review Gregor's delivery checklist PR
- Review onboarding SOP draft

Quick Hits — 1 open
- Reply to Sue re: defect report

These columns have no open items:
- Waiting On
- Someday

Want the rest of Deep Work, or the complete list from every column?
```

Deep Work's other four open items are not listed, though the count reads "7 open (showing 3)".

---

### complete_list

Run the shared step. Same `TOTAL` and same split as `summary`.

For the Not categorized group first (when it has open items), then each column with open items in board order: header `COLUMN — N open`, then **every** open item in the order returned. Nothing is truncated and nothing ever reads "(showing 3)".

```
Your day plan columns — TOTAL open items total

Not categorized — N open
- ITEM
- ITEM

COLUMN — N open
- ITEM
- ITEM

COLUMN — N open
- ITEM

These columns have no open items:
- COLUMN
- COLUMN

Want to check anything off or add anything new?
```

**Locked example** (Scenario 3):

```
Your day plan columns — 6 open items total

Deep Work — 3 open
- Finish sprint API contract
- Draft Q1 dev process rock plan
- Refactor auth middleware

Code Review — 2 open
- Review Gregor's delivery checklist PR
- Review onboarding SOP draft

Quick Hits — 1 open
- Reply to Sue re: defect report

These columns have no open items:
- Waiting On
- Someday

Want to check anything off or add anything new?
```

**Locked example, a column holding 7** (Scenario 3b) — all seven listed, header reads `Deep Work — 7 open`, no "(showing 3)", same closing line:

```
Your day plan columns — 10 open items total

Deep Work — 7 open
- Finish sprint API contract
- Draft Q1 dev process rock plan
- Refactor auth middleware
- Spec retry logic for sync jobs
- Pair with Gregor on delivery handoff
- Update dev process playbook
- Write migration rollback notes

Code Review — 2 open
- Review Gregor's delivery checklist PR
- Review onboarding SOP draft

Quick Hits — 1 open
- Reply to Sue re: defect report

These columns have no open items:
- Waiting On
- Someday

Want to check anything off or add anything new?
```

The closing line offers **actions**, never more listing. A complete-list reply never ends with a drill-in offer.

---

### whats_done

Run the shared step (the columns response supplies board order and the empty-columns check), then fetch the completions for the default window — **no `months` param**. A third bare Bash call:

```bash
"<api.sh path>" GET "/day-plan-completions"
```

Read completions from `body.data`. Then:

- **A completion whose `column` is `null` goes into the `Not categorized` group** — *ruled by Scott 2026-08-03 (UI parity), not page-55-locked. This replaces the old interim "drop it" rule.* It renders as the **first** group, above every column, headed `Not categorized — N completed`, and it **is counted in `TOTAL`**. Nothing is dropped.
- Group the rest by `column.name`. Order the groups by **board order** from `/day-plan-columns`, after the Not categorized group. Within a group keep the order returned (most recent first).
- `TOTAL` = every completion returned in the window, Not categorized included.
- With no `column: null` completions in the window the Not categorized group does not render at all — no `— 0 completed` header — and the reply is byte-identical to the locked template.

```
Done in your day plan columns — TOTAL completed items in the last 30 days

Not categorized — N completed
- ITEM

COLUMN — N completed
- ITEM

COLUMN — N completed
- ITEM

Would you like me to extend my search to the last 3 or 6 months?
```

**Locked example** (Scenario 4):

```
Done in your day plan columns — 2 completed items in the last 30 days

Deep Work — 1 completed
- Review Alya's ops intake spec

Waiting On — 1 completed
- Confirm staging access with Alya

Would you like me to extend my search to the last 3 or 6 months?
```

Only groups with completions appear. There is **no** "These columns have no completed items" chunk. No open item is named or counted. No "Want to check anything off or add anything new?" offer. Fixture C carries no `column: null` completion, so no Not categorized group renders and the reply is exactly the locked one.

---

### extend_done

Only from a done offer. Re-fetch with the window the user named:

| The user says | Request | Window words in the header | Closing line |
|---|---|---|---|
| "3 months" | `GET /day-plan-completions?months=3` | `in the last 3 months` | `Would you like me to extend my search to the past 6 months?` |
| "6 months" † | `GET /day-plan-completions?months=6` | `in the last 6 months` | *(none — the ladder ends)* |

† The 6-month row is a **number-substitution inference, not locked**. Scenario 4b locks `months=3` only — the header "in the last 3 months" and the closing "…the past 6 months?". The 6-month reply substitutes `6` into that same locked header phrase and closes with nothing, since no further extension is offered. Substitution only, never new wording.

Same grouping, same `Not categorized` handling for `column: null`, same board order as `whats_done`.

```
Done in your day plan columns — TOTAL completed items in the last 3 months

COLUMN — N completed
- ITEM
- ITEM

COLUMN — N completed
- ITEM

Would you like me to extend my search to the past 6 months?
```

**Locked example** (Scenario 4b — an item completed 40 days ago now falls inside the window):

```
Done in your day plan columns — 3 completed items in the last 3 months

Deep Work — 2 completed
- Review Alya's ops intake spec
- Close out Q2 sprint retro actions

Waiting On — 1 completed
- Confirm staging access with Alya

Would you like me to extend my search to the past 6 months?
```

Note the wording shift the spec locks: the 30-day reply offers "**the last** 3 or 6 months"; the 3-month reply offers "**the past** 6 months". Reproduce both exactly.

---

### no_columns

`GET /day-plan-columns` returned `200` with an empty `data` array. One sentence, and nothing else — no summary, no total, no list of the user's day-plan items, and nothing that reads as an error:

```
I don't see that you've created any custom columns for organizing your day plan items yet. Would you like to learn how that can help you, or do you have some you'd like to create?
```

**Locked example** (Scenario 5 — Sue has never created a column; her two open day-plan items are not listed).

This same sentence is the answer whichever way the user asked, including a done ask — there are no columns to report on either way. **Inferred, not locked** — Scenario 5 locks this sentence only for "show me my columns and what's in each"; no scenario shows a done ask from an account with no columns. Reuse the locked sentence, never new wording.

If the user takes up the "create" half of that offer, that is an **uncovered case** — no rkit skill owns `POST /day-plan-columns`, and this skill never writes. See "Cases the locked spec does not cover" in `references/day-plan-columns-api.md`.

---

### rest_of_column

Offered by a truncated `three_from_each`, but **no scenario locks a reply for it**. The nearest locked behavior is `complete_list` (Scenario 3/3b) — render that. Do not invent a partial "just the remaining four" variant.

---

## Invariants

These hold in every reply. A reply that breaks one is wrong even if it looks right.

1. **Open counts exclude completed items.** Filter `completed == false` once at fetch, then count and list from that. A column's count, the Not categorized count, and the running total are all open-only. The Custom tab's badge counts completed items as well — that is the one place this skill deliberately does **not** match the UI.
2. **No group ever renders "— 0 open".** A column with no open items is named only under "These columns have no open items:" — never as a zero-count line, never with an empty item list. The Not categorized group with no open items renders **nowhere at all**: not as a zero line and not in that chunk, because it is not a column.
3. **Completed items are invisible to the open-item flows.** `summary`, `three_from_each`, and `complete_list` never name a completed item, never count one, and never mark one as done.
4. **Truncation is exactly 3.** More than 3 open in `three_from_each` → first 3 only, header `— N open (showing 3)` with the full `N`. Exactly 3 or fewer → no "(showing 3)" on that group. The closing line is a property of the whole reply, not of one group: `Want the rest of COLUMN, or the complete list from every column?` appears when **at least one** group in the reply was truncated — Not categorized counts as a group — and when **nothing** was truncated the reply carries no closing line at all.
5. **`complete_list` never truncates and never offers more listing.** It closes `Want to check anything off or add anything new?` — an action offer, never a drill-in.
6. **The summary always closes** `Want the 3 from each column (names/descriptions), or the complete list from each?`
7. **Done replies show only completed items.** No open item is named or counted. No "no completed items" chunk exists. No check-off/add offer.
8. **Done replies never say history is gone.** Never state or imply that completed history is cleared, deleted, expired, or unavailable. An empty or short window means the search window, not the record.
9. **Months language is exact.** Default window: "in the last 30 days", closing "Would you like me to extend my search to the last 3 or 6 months?". After extending: "in the last 3 months", closing "Would you like me to extend my search to the past 6 months?".
10. **The no-columns fallback lists nothing.** One sentence, verbatim, and no day-plan items.
11. **Names render verbatim.** Column names and item names exactly as the API returns them — no trimming, re-casing, re-wrapping, truncating, or tidying.
12. **Nothing is written.** The only calls this skill ever makes are `GET /day-plans/today`, `GET /day-plan-columns`, and `GET /day-plan-completions`. No other endpoint and no other verb, ever.
13. **`/day-plans/today` is fetched first, always.** Open-item flows read it for the Not categorized set difference; every flow relies on it having materialized today's plan before `/day-plan-columns` is read. Reversing the order, or skipping it, produces empty columns on a fresh day — the exact defect this ordering exists to prevent.
14. **Every open item on today's plan is accounted for.** `TOTAL` equals the count of open items on today's plan. An item that is in no column appears under Not categorized; nothing is silently dropped.
15. **Not categorized renders first.** Above every column, in the open-item flows and in the done flows alike. *(Invariants 14 and 15, and the Not categorized half of 1, 2 and 12–13: ruled by Scott 2026-08-03 for UI parity — not page-55-locked.)*

---

## Error Handling

| Status | Response |
|---|---|
| `error: NO_CONFIG` | "Config not found. Run `/rkit:setup` first." |
| `error: NO_TOKEN` | "No API token. Run `/rkit:setup` to configure." |
| `error: CURL_FAILED` | "Network error. Check your connection." |
| `status: 401` | "Unauthorized. Run `/rkit:setup` to update your token." |
| `status: 404` | "Not found." |
| Other non-200 | Show status code and error message from the response body. |

`200` with an empty `data` array is not an error. On `/day-plan-columns` it means `no_columns`.

**api.sh not found**: "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"

---

## Out of scope

- **Writes of any kind** — creating, renaming, archiving, or repositioning columns; adding, completing, moving, or removing items. Those live in other skills.
- **The `column` / `column_id` filter** on `/day-plan-completions`. One unfiltered request already returns every column's completions carrying its column.
- **"Help me organize my todos" routing** (Scenario Family 2 on page 55) — deferred, not specced, build nothing for it.

## References

- [Day Plan Columns — Endpoint Reference](references/day-plan-columns-api.md) — all three reads, the fixed call order, the Not categorized set-difference rule, live-verified field names, the window→param mapping, and the cases the locked spec does not cover.
- [ResultMaps V2 API Reference](references/api-reference.md) — the whole V2 surface, including the write verbs on `/day-plan-columns` that this skill never calls. `/day-plan-completions` is **not** in the master yet; it is documented only in `references/day-plan-columns-api.md`.
- Binding BDD: https://resultkit.ai/pages/55 — 8 scenarios, locked 2026-08-02. Never edit it.
