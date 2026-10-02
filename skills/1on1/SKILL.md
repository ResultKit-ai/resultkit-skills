---
name: rkit:1on1
description: View and manage one-on-one meetings. Shows meetings with items grouped by column (next, done, blocked). Use this skill when users mention 1:1s, one-on-ones, 1-on-1 meetings, want to see their one-on-one agenda, add items to a 1:1, or manage items in a one-on-one meeting.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Read, Glob, Grep, AskUserQuestion
---

# rkit:1on1

Drives the ResultKit connector's MCP tools; `scripts/api.sh` is used only for the jobs under **Fallback (api.sh)**. Tools are named by base name below; the callable name is `mcp__<server>__<tool>` and the `<server>` alias varies by install, so match on the base name.

## Current State

- Config status: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING"; fi`
- api.sh (Fallback only): !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/1on1/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/1on1/scripts/api.sh "$HOME/.claude/skills/rkit:1on1/scripts/api.sh" "$HOME/.agents/skills/1on1/scripts/api.sh" "$HOME/.gemini/skills/1on1/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes**: Before any create, move, remove, save or comment, summarize all planned changes in a single prompt and ask for confirmation. If the command implies multiple related mutations, batch them under one confirmation. Reads execute immediately.
- **Show IDs**: Always include item and meeting IDs in output so users can reference them (this overrides the connector's general "never print ids" note).
- **Concise output**: Tables and short summaries. No verbose prose.
- **Direct execution**: Call the connector tools directly. Never use Task agents or subagents, never curl or hand-build a URL, and skip the connector's `guide` tool — the flows below are complete for this skill.

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
| `{meeting_id} comment {item_id} "text"` *(+ "leave a note on {id}", "comment on {id}")* | Add a Comment to an Item |
| `{meeting_id} comments {item_id}` *(+ "show comments on {id}", "what did people say on {id}")* | List Comments on an Item |
| `{meeting_id} edit comment {comment_id} "text"` | Edit My Comment |
| `{meeting_id} delete comment {comment_id}` | Delete My Comment |
| `--team {id}` *(anywhere in args)* | Override team ID for any flow |

If the input doesn't match any pattern, show this usage summary and ask what they'd like to do.

## Team ID Resolution

1. **`--team {id}` flag** in args → use that team ID
2. **`default_team_id` in config** → use that
3. **Neither** → no team filter applied (show all one-on-ones)

## Reads

| Job | Tool and arguments |
|---|---|
| Team name | `get_team`: `team_id` (text; line 1 is `# {team_name}`) |
| List one-on-ones | `list_1on1s`: `team_id?`, `per_page` (100) |
| Open one (people, items by column) | `get_1on1`: `meeting_id` |
| One item (name, status) | `get_item`: `todo_or_issue` |
| Comments on an item | `list_item_comments`: `todo_or_issue` |

`list_1on1s` answers JSON `{one_on_ones, page, per_page, total}`; each row has `id`, `date`, `human_name`, `persons` (`person1`, `person2`: `first_name`, `last_name`, `login`) and `assisted`. `get_1on1` answers JSON with `human_name`, `persons` and `items: {next, done, issues}`; each item has `id`, `name`, `status`, `due`, `creator`. Read columns from `get_1on1`: the connector's `list_1on1_section` and `list_1on1_todos_issues` return raw rows with only the creator's `user_id`, no name.

## Flow: List One-on-Ones

**Trigger**: No args (or only `--team {id}`)

Resolve the team ID (Team ID Resolution). With a team ID, call `get_team` and `list_1on1s` (`team_id`, `per_page` 100) together; without one, call `list_1on1s` (`per_page` 100) alone. Every row is a one-on-one (project meetings are never listed). Display as a table:

```
## One-on-Ones — {team_name} (ID: {team_id})

| ID | With | Date |
|----|------|------|
| 15 | Patrick Angodung | 2026-02-20 |
| 22 | Mary Mejia | 2026-02-18 |

{count} one-on-ones
```

Without a team filter the heading is `## One-on-Ones`, and after the count add: `Tip: Set a default team with `/rkit:setup` to filter by team.`

**Display rules**:
- `With` column: show the other participant (`persons.person1` or `persons.person2` — whichever is not the current user). There is no who-am-I tool: the current user is the person who appears in every row; a row with `assisted: true` shows both names. Use `human_name` as the meeting display name if needed. Show `first_name last_name` for the person; fall back to `login` if names are empty.
- `Date` column: show date if present, "—" if null

**Empty result (with team)**: "No one-on-ones found for {team_name}."
**Empty result (no team)**: "No one-on-ones found."

## Flow: View One-on-One Detail

**Trigger**: `{meeting_id}` or `show {meeting_id}`

Call `get_1on1` (`meeting_id`) and display:

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

## Flow: View Single Column / Done Items

**Trigger**: `{meeting_id} next`, `{meeting_id} blocked`, `{meeting_id} issues` (alias for `blocked`), `{meeting_id} done`, or `{meeting_id} done --since YYYY-MM-DD`

Call `get_1on1` and show only the requested column — `next` → `items.next`, `blocked` or `issues` → `items.issues`, `done` → `items.done` (the default Done window: completed in the last 10 days, shown newest first by `complete`) — with archived items excluded as in View One-on-One Detail. Use the same display format as a single section from View Detail — column header, item table (ID, Name, Creator, Due); with more than 50 items show the first 50 and "({total} total, showing first 50)". Done header: `### Done ({count} items)`.

`done --since DATE` runs the Fallback done read instead, with `start_date` = DATE and `end_date` = today. Header: `### Done since {date} ({count} items)`.

## Writes

Confirm first, then call the tool. Names and ids in the success lines come from the tool's answer, or from `get_item`.

| Flow | Tool and arguments | Confirm | On success |
|---|---|---|---|
| Move Item (`{meeting_id} move {item_id} {column}`) | `move_on_1on1`: `meeting_id`, `todo_or_issue`, `section` (`next` → `todos`, `blocked` → `issues`, `done` → `done`) | Move item **{item_name}** (ID: {item_id}) from **{current_column}** to **{target_column}**? | Moved **{item_name}** (ID: {item_id}) to **{target_column}**. |
| Add new item (`{meeting_id} add "text"`) | `add_1on1_todo` (default column `next`) or `add_1on1_issue` (blocked): `meeting_id`, `name`, `description?` | Add **"{text}"** to one-on-one {meeting_id}? | Added **{item_name}** (ID: {item_id}) to one-on-one {meeting_id}. |
| Add existing item (`{meeting_id} add {item_id}`) | `place_on_1on1`: `meeting_id`, `todo_or_issue` | Add **{item_name}** (ID: {item_id}) to one-on-one {meeting_id}? | Added **{item_name}** (ID: {item_id}) to one-on-one {meeting_id}. |
| Remove Item (`{meeting_id} remove {item_id}`) | `remove_from_1on1`: `meeting_id`, `todo_or_issue` | Remove item {item_id} from one-on-one {meeting_id}? (Item will still exist — only detached from this meeting.) | Removed item {item_id} from one-on-one {meeting_id}. |
| Save Notes (`{meeting_id} notes "text"`) | `save_1on1_notes`: `meeting_id`, `text` | Save notes to one-on-one {meeting_id}? (This will overwrite any existing notes.) | Notes saved to one-on-one {meeting_id}. |
| Add Comment (`{meeting_id} comment {item_id} "text"`) | `add_item_comment`: `todo_or_issue`, `body` | Add comment to item **{item_id}** in one-on-one {meeting_id}: "{text}" Proceed? | Comment added (ID: {id}) to item **{item_id}**: "{body}" (the answer carries the comment id) |

- **Move**: column must be one of `next`, `done`, `blocked`. Call `get_item` first for the name and `**Status**` (not found → "Item {item_id} not found."). Map the status to a column (`next` → next, `done` → done, `blocked` → blocked); if it already matches the target → "Item {item_id} is already in {column}." and stop. The item must already be on this meeting.
- **Add**: a quoted string creates a new item, a number adds an existing one. For a new item pass `description` (HTML body) when the user provides one; a new item straight into the done column is a Fallback job. For an existing item call `get_item` first (not found → "Item {item_id} not found.").
- **Notes**: empty or missing text → "Please provide note content. Example: `/rkit:1on1 {id} notes \"Discussion about Q2 goals\"`" and stop.
- **Comment**: empty text → "Comment text cannot be empty." Comments target the item directly, not the meeting — the `meeting_id` prefix is only this skill's own addressing convention, kept consistent with `move`/`add`/`remove`. A participant of this 1-on-1 can comment on an item shared to it even without ordinary view access to the item — the connector grants that fallback specifically for 1:1 participants.

## Flow: List Comments on an Item

**Trigger**: `{meeting_id} comments {item_id}`

Call `list_item_comments` (`todo_or_issue`). It answers JSON `{total, comments: [{id, body, author, created_at, updated_at}]}`. None → "No comments on item {item_id}." Otherwise display (strip HTML from `body`; author is `first_name last_name`, else `login`; Time from `created_at`):

```
| ID | Author | Comment | Time |
|----|--------|---------|------|
| 9001 | Sarah Lee | Talked to the vendor. | 2026-03-07 14:02 |
```

Append `(edited)` after the time when `updated_at` is later than `created_at`.

## Fallback (api.sh)

The connector has no tool for these jobs, so they run as before: `RESPONSE=$("<api.sh path>" METHOD PATH [BODY])` returns `{status, body}`; escape double quotes in JSON bodies. Confirm writes first, as above.

| Job | Call |
|---|---|
| Done items since a date (`done --since`; the connector's Done read returns raw rows with no creator name) | `GET /1-on-1/MEETING_ID/done?start_date=DATE&end_date=TODAY&per_page=50` (the window needs both dates); items in `body.data`, each with `creator`; `body.meta.total` |
| New item straight into the done column | `POST /1-on-1/MEETING_ID/items` `{"name":"TEXT","column":"done"}` (+ `description`); 201 → "Added **{item_name}** (ID: {item_id}) to one-on-one {meeting_id}." |
| Edit my comment (`{meeting_id} edit comment {comment_id} "text"`; confirm `Edit comment **{comment_id}** to: "{text}"? Proceed?`) | `PATCH /comments/COMMENT_ID` `{"body": "NEW_TEXT"}`. 200 "Comment **{comment_id}** updated."; 403 "You can only edit your own comments."; 404 "Comment {comment_id} not found."; 422 "Comment text cannot be empty." |
| Delete my comment (`{meeting_id} delete comment {comment_id}`; confirm `Delete comment **{comment_id}**? This cannot be undone.`) | `DELETE /comments/COMMENT_ID`. 200 "Comment **{comment_id}** deleted."; 403 "You can only delete your own comments (a team admin can also delete any comment on this item)."; 404 "Comment {comment_id} not found." |

api.sh errors: `NO_CONFIG` or `NO_TOKEN` "Config not found. Run `/rkit:setup` first."; `CURL_FAILED` "Network error. Check your connection."; 401 "Unauthorized (401). Run `/rkit:setup` to update your token."; 404 "Not found (404)."; 422 show the validation error from the body; other non-200 show the status code and error from the body; path `NOT_FOUND` "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"

## Errors

| The tool answers | Say |
|---|---|
| tools missing, or an authorization error | "The ResultKit connector isn't connected. Connect it (https://mcp.resultkit.ai) and try again." |
| "1-on-1 not found or you don't have access to it." | "Meeting {id} not found." |
| "To-do or issue not found or you don't have access to it." | "Item {id} not found." (one sentence now covers the old 403 "Not authorized to comment on this item.") |
| "Team not found or you don't have access to it." / "You don't have access to this team." | "Team {id} not found, or you don't have access to it." |
| "A comment cannot be blank." | "Comment text cannot be empty." |
| any other `Error: …` | Show it as returned. |

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
