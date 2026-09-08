---
name: rkit:1on1
description: View and manage one-on-one meetings. Shows meetings with items grouped by column (next, done, blocked). Use this skill when users mention 1:1s, one-on-ones, 1-on-1 meetings, want to see their one-on-one agenda, add items to a 1:1, or manage items in a one-on-one meeting.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Read, Glob, Grep, AskUserQuestion
---

# rkit:1on1

## Current State

- Config status: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING"; fi`
- api.sh: !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/1on1/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/1on1/scripts/api.sh "$HOME/.claude/skills/rkit:1on1/scripts/api.sh" "$HOME/.agents/skills/1on1/scripts/api.sh" "$HOME/.gemini/skills/1on1/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes**: Before any POST/PUT/PATCH/DELETE, summarize all planned changes in a single prompt and ask for confirmation. If the command implies multiple related mutations, batch them under one confirmation. GET requests execute immediately.
- **Show IDs**: Always include item and meeting IDs in output so users can reference them.
- **Concise output**: Tables and short summaries. No verbose prose.
- **Direct execution**: Use Bash for all API calls via api.sh. Never use Task agents or subagents.

## Argument Parsing

Parse the user input to determine which flow to follow:

| Input | Flow |
|-------|------|
| *(no args)* | List One-on-Ones |
| `{meeting_id}` or `show {meeting_id}` | View One-on-One Detail |
| `{meeting_id} next` / `blocked` | View Single Column (next or blocked) |
| `{meeting_id} issues` | View Single Column (blocked — alias for `blocked`) |
| `{meeting_id} done` | View Done Items (dedicated endpoint) |
| `{meeting_id} done --since YYYY-MM-DD` | View Done Items with Date Filter |
| `{meeting_id} move {item_id} {column}` | Move Item |
| `{meeting_id} add "text"` | Add New Item |
| `{meeting_id} add {item_id}` | Add Existing Item |
| `{meeting_id} remove {item_id}` | Remove Item |
| `{meeting_id} notes "text"` | Save Notes (Enhancement) |
| `--team {id}` *(anywhere in args)* | Override team ID for any flow |

If the input doesn't match any pattern, show this usage summary and ask what they'd like to do.

---

## Error Handling

Parse the JSON response from api.sh. Handle these cases:

- `"error": "NO_CONFIG"` or `"error": "NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 404` → "Not found (404)."
- `status: 422` → Show validation error from response body.
- Other non-200 → Show status code and error from response body.

---

## Team ID Resolution

1. **`--team {id}` flag** in args → use that team ID
2. **`default_team_id` in config** → use that
3. **Neither** → no team filter applied (show all one-on-ones)

---

## Flow: List One-on-Ones

**Trigger**: No args (or only `--team {id}`)

### Step 1: Resolve team and fetch meetings

Resolve team ID using Team ID Resolution.

**If team ID is resolved** — fetch team detail for the team name, then fetch meetings filtered by team:

```bash
API_SH="<api.sh path from Current State>"
TEAM=$("$API_SH" GET "/teams/TEAM_ID")
echo "$TEAM"
RESPONSE=$("$API_SH" GET "/1-on-1?group_id=TEAM_ID&per_page=100")
echo "$RESPONSE"
```

**If no team ID** — fetch all one-on-ones (no filter):

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/1-on-1?per_page=100")
echo "$RESPONSE"
```

### Step 2: Filter and display

Filter the response client-side:
- `type` must be `one_on_one` (always — exclude project meetings)

Display as a table:

**With team filter:**

```
## One-on-Ones — {team_name} (ID: {team_id})

| ID | With | Date |
|----|------|------|
| 15 | Patrick Angodung | 2026-02-20 |
| 22 | Mary Mejia | 2026-02-18 |

{count} one-on-ones
```

**Without team filter:**

```
## One-on-Ones

| ID | With | Date |
|----|------|------|
| 15 | Patrick Angodung | 2026-02-20 |
| 22 | Mary Mejia | 2026-02-18 |

{count} one-on-ones

Tip: Set a default team with `/rkit:setup` to filter by team.
```

**Display rules**:
- `With` column: show the other participant (`persons.person1` or `persons.person2` — whichever is not the current user). Use `human_name` as the meeting display name if needed. Show `first_name last_name` for the person; fall back to `login` if names are empty.
- `Date` column: show date if present, "—" if null

**Empty result (with team)**: "No one-on-ones found for {team_name}."
**Empty result (no team)**: "No one-on-ones found."

---

## Flow: View One-on-One Detail

**Trigger**: `{meeting_id}` or `show {meeting_id}`

### Step 1: Fetch meeting detail

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/1-on-1/MEETING_ID")
echo "$RESPONSE"
```

### Step 2: Display meeting

The response nests sections under an `items` key: `items.next`, `items.done`, `items.issues`. The `items.issues` array is the **Blocked** column.

Persons are nested under `persons`: `persons.person1`, `persons.person2`.

Before rendering, filter each array: **exclude any item where `status == "archived"`**. Items with null or missing `status` are treated as active and kept.

Display format:

```
## One-on-One: {persons.person1 name} & {persons.person2 name} (ID: {meeting_id})

### Next ({count} items)

| ID | Name | Creator | Due |
|----|------|---------|-----|
| 42 | Discuss hiring plan | Scott Levy | 2026-02-25 |

### Done ({count} items)

| ID | Name | Creator | Due |
|----|------|---------|-----|
| 38 | Review Q4 results | Patrick Angodung | — |

### Blocked ({count} items)

(empty)
```

**Display rules**:
- **Response shape**: Read `items.next`, `items.done`, `items.issues` — NOT top-level `next`/`done`/`blocked`. The `items.issues` array IS the Blocked column; display it under the "### Blocked" header.
- **Persons**: Read from `persons.person1` and `persons.person2` (not top-level fields). Use `human_name` for the meeting title if available.
- **Archived items**: Exclude any item with `status: "archived"` from all three columns before rendering. Items with null/missing `status` are treated as active.
- `{count}` in each column header reflects the filtered count (non-archived items only), not the raw API count.
- Each item shows: ID, name, creator (`first_name last_name` from `creator` field; fall back to `login` if names empty), due date (or "—" if null)
- Empty columns show "(empty)"
- Column order: next, done, blocked (always this order)

---

## Flow: View Single Column

**Trigger**: `{meeting_id} next`, `{meeting_id} blocked`, or `{meeting_id} issues`

> **Note**: `{meeting_id} done` is handled by the dedicated Done Items flow (see below). `issues` is an alias for `blocked`.

### Step 1: Fetch the requested column

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/1-on-1/MEETING_ID/items/COLUMN?per_page=50")
echo "$RESPONSE"
```

Replace `COLUMN` with:
- `next` for next items
- `blocked` for blocked/issues items (`issues` trigger also maps here)

### Step 2: Display column

Use same display format as a single section from View Detail — column header, item table, overflow indicator if more than 50 items.

> **Note**: `GET /1-on-1/{id}/items/{section}` excludes archived items by API default (`include_archived` defaults to `false`). No client-side filtering is needed for this flow.

---

## Flow: Done Items

**Trigger**: `{meeting_id} done` or `{meeting_id} done --since YYYY-MM-DD`

### Step 1: Fetch done items

```bash
API_SH="<api.sh path from Current State>"
# Without date filter:
RESPONSE=$("$API_SH" GET "/1-on-1/MEETING_ID/done?per_page=50")
# With --since DATE filter:
RESPONSE=$("$API_SH" GET "/1-on-1/MEETING_ID/done?since=DATE&per_page=50")
echo "$RESPONSE"
```

### Step 2: Display done items

Use same table format as single column view (ID, Name, Creator, Due).

Header: `### Done ({count} items)` — or `### Done since {date} ({count} items)` if `--since` was provided.

Archived items are excluded by the API by default. No client-side filtering needed.

---

## Flow: Move Item

**Trigger**: `{meeting_id} move {item_id} {column}`

Column must be one of: `next`, `done`, `blocked`.

### Step 1: Check current status

Fetch the item to check its current status:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/items/ITEM_ID")
echo "$RESPONSE"
```

Map the item's `status` to a column:
- `next` → next
- `done` → done
- `blocked` → blocked

If the item's current column matches the target → "Item {item_id} is already in {column}." and stop.

### Step 2: Confirm and execute

Map target column to API status:
- `next` → `next`
- `done` → `done`
- `blocked` → `blocked`

Describe the move:
> Move item **{item_name}** (ID: {item_id}) from **{current_column}** to **{target_column}**?

Wait for confirmation. Then:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" PATCH "/items/ITEM_ID" '{"status":"TARGET_STATUS"}')
echo "$RESPONSE"
```

### Step 3: Handle response

- **Status 200**: "Moved **{item_name}** (ID: {item_id}) to **{target_column}**."
- **Error** → use Error Handling above

---

## Flow: Add Item to One-on-One

**Trigger**: `{meeting_id} add "text"` or `{meeting_id} add {item_id}`

### Step 1: Determine if new or existing

- If arg is a quoted string → create new item
- If arg is a number → add existing item

### Step 2 (new item): Confirm and execute

Describe:
> Add **"{text}"** to one-on-one {meeting_id}?

Wait for confirmation. Then:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" POST "/1-on-1/MEETING_ID/items" '{"name":"TEXT"}')
echo "$RESPONSE"
```

Optional body fields: `column` (`next`/`blocked`/`done`, default `next`) and `description` (HTML body) — include them in the JSON when the user provides them.

- **Status 201**: "Added **{item_name}** (ID: {item_id}) to one-on-one {meeting_id}."
- **Error** → use Error Handling above

### Step 2 (existing item): Fetch, confirm, and execute

Fetch the item to confirm it exists:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/items/ITEM_ID")
echo "$RESPONSE"
```

- If 404 → "Item {item_id} not found."

Describe:
> Add **{item_name}** (ID: {item_id}) to one-on-one {meeting_id}?

Wait for confirmation. Then:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" POST "/1-on-1/MEETING_ID/align" '{"alignable_type":"Item","alignable_id":ITEM_ID}')
echo "$RESPONSE"
```

- **Status 200**: "Added **{item_name}** (ID: {item_id}) to one-on-one {meeting_id}."
- **Error** → use Error Handling above

---

## Flow: Remove Item

**Trigger**: `{meeting_id} remove {item_id}`

### Step 1: Confirm and execute

Describe:
> Remove item {item_id} from one-on-one {meeting_id}? (Item will still exist — only detached from this meeting.)

Wait for confirmation. Then:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" DELETE "/1-on-1/MEETING_ID/items/ITEM_ID")
echo "$RESPONSE"
```

### Step 2: Handle response

- **Status 200/204**: "Removed item {item_id} from one-on-one {meeting_id}."
- **Error** → use Error Handling above

---

## Flow: Save Notes (Enhancement)

**Trigger**: `{meeting_id} notes "text"`

### Step 1: Validate input

If notes text is empty or missing → "Please provide note content. Example: `/rkit:1on1 {id} notes \"Discussion about Q2 goals\"`" and stop.

### Step 2: Confirm and execute

Describe:
> Save notes to one-on-one {meeting_id}? (This will overwrite any existing notes.)

Wait for confirmation. Then:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" PUT "/1-on-1/MEETING_ID/notes" '{"notes":"TEXT"}')
echo "$RESPONSE"
```

### Step 3: Handle response

- **Status 200**: "Notes saved to one-on-one {meeting_id}."
- **Error** → use Error Handling above

---

## Edge Cases

- **No config** → "Config not found. Run `/rkit:setup` first."
- **api.sh not found** → "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"
- **No one-on-ones** → "No one-on-ones found."
- **Meeting not found (404)** → "Meeting {id} not found."
- **All columns empty** → show all three column headers with "(empty)"
- **All items in a column are archived** → that column shows "(empty)" after filtering; apply to all three columns independently
- **Item already in target column (move)** → warn and skip
- **Item not found (add existing)** → "Item {id} not found."
- **Creator names empty** → fall back to `login` field
- **Empty notes text** → warn and do not submit

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
