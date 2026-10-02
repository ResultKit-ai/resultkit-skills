---
name: rkit:board
description: View any item's children as a kanban-style board. Children become columns, grandchildren become items. Supports viewing, filtering by column, moving items between columns, adding items, and removing items. Use this skill when users want to see a board view, manage columns, move items between columns, or work with a hierarchical item structure.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Read, Glob, Grep, AskUserQuestion
---

# rkit:board

Drives the ResultKit connector's MCP tools; `scripts/api.sh` is used only for the jobs under **Fallback (api.sh)**. Tools are named by base name below; the callable name is `mcp__<server>__<tool>` and the `<server>` alias varies by install, so match on the base name.

## Current State

- Config status: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base, default_board_id}' "$HOME/.config/resultkit/config.json"; else echo "MISSING"; fi`
- api.sh (Fallback only): !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/board/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/board/scripts/api.sh "$HOME/.claude/skills/rkit:board/scripts/api.sh" "$HOME/.agents/skills/board/scripts/api.sh" "$HOME/.gemini/skills/board/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes**: Before any create, move, remove or comment, summarize all planned changes in a single prompt and ask for confirmation. If the command implies multiple related mutations, batch them under one confirmation. Reads execute immediately.
- **Show IDs**: Always include item IDs in output so users can reference them (this overrides the connector's general "never print ids" note).
- **Concise output**: Tables and short summaries. No verbose prose.
- **Direct execution**: Call the connector tools directly. Never use Task agents or subagents, never curl or hand-build a URL, and skip the connector's `guide` tool — the flows below are complete for this skill.

## Argument Parsing

Parse the user input to determine which flow to follow:

| Input | Flow |
|-------|------|
| *(no args)* | View Board |
| `{id}` | View Board (with explicit board ID) |
| `{id} {column}` | View Single Column |
| `move {item_id} {target_id}` | Move Item |
| `add {board_id} ...` | Add Item |
| `remove {item_id}` | Remove Item |
| `bulk-move {item_ids} {parent_id}` | Bulk Move Items |
| `comment {item_id} "text"` *(+ "leave a note on {id}", "comment on {id}")* | Add a Comment to an Item |
| `comments {item_id}` *(+ "show comments on {id}", "what did people say on {id}")* | List Comments on an Item |
| `edit comment {comment_id} "text"` | Edit My Comment |
| `delete comment {comment_id}` | Delete My Comment |

If the input doesn't match any pattern, show this usage summary and ask what they'd like to do.

## Board ID Resolution

Used by View Board, Add Item, and Remove Item flows to determine which item to treat as the board root.

**Resolution order**:

1. **Explicit ID in args** → use directly
2. **`default_board_id` in config is an integer** → use that ID
3. **`default_board_id` in config is `"ask"`** → show the default and ask user to confirm or provide a different ID
4. **`default_board_id` absent from config** → prompt user: "No default board configured. Enter an item ID to use as the board:"

## Tools

| Job | Tool and arguments |
|---|---|
| Board: its columns and the items in each | `project_columns`: `project_id` = the board ID (any item can be a board root) |
| One item (name, status, parent) | `get_item`: `todo_or_issue` |
| Create an item in a column | `create_item`: `name`, `parent_id` = the column ID |
| Put an item on today's plan | `attach_to_work_plan`: `todo` |
| Comments | `add_item_comment`: `todo_or_issue`, `body`; `list_item_comments`: `todo_or_issue` |

`project_columns` answers JSON `{items, page, perPage, total}`: `items` are the board's columns (`total` = how many), and each column carries ALL its items in `children`, in board order. Each item has `id`, `name`, `status`, `due`. `get_item` answers text: `# {name}`, `**Status**`, `**Due**`, `**Parent item ID**`, `**ID**`.

## Flow: View Board

**Trigger**: No args, or a single numeric ID

Resolve the board ID (Board ID Resolution), then call `project_columns`. No `items` → "No children found for item {id}." Take the first 10 columns (if `total` > 10, note the overflow count) and the first 50 items of each. Display the board title using the board ID, then each column:

```
Board: {board_id}

## {Column Name} (ID: {column_id})

| ID | Name | Status | Due |
|----|------|--------|-----|
| 42 | Fix login bug | next | 2026-02-20 |
| 88 | Write API tests | not_started | — |

{N} items shown

## {Next Column Name} (ID: {column_id})

(empty)

...
```

**Display rules**:
- Each column header shows name and ID (FR-002)
- Each item shows ID, name, status, due date (FR-003). If due is null, show "—"
- Empty columns show "(empty)"
- If a column has more than 50 items, show "({total} total, showing first 50)" after the table, `total` being its item count (FR-006)
- If more than 10 columns exist (`total` > 10), show "({overflow_count} more columns not shown)" at the end (FR-008)

## Flow: View Single Column

**Trigger**: `{board_id} {column_name_or_id}`

Call `project_columns` for the board and match the second argument against its columns: numeric → exact match on `id`; a string → case-insensitive substring on `name`.
- **No match** → "No column matching '{input}' on board {board_id}." Then list available columns with IDs.
- **One match** → display that column in the View Board format (header with name/ID, item table, empty/overflow handling).
- **Multiple matches** → list matching columns with their IDs and ask user to pick. Suggest renaming one to avoid future ambiguity.

## Writes

Confirm first, then run the steps. Names and ids in the success lines come from `get_item` or the tool's answer.

| Flow | Steps | Confirm | On success |
|---|---|---|---|
| Move Item (`move {item_id} {target_column_id}`) | `get_item` for the item and for the target, together: either not found → "Item {id} not found." and stop; the item's `**Parent item ID**` already the target → "Item {item_id} is already under {target_name} (ID: {target_id})." and stop. Then the Fallback move | Move item **{item_name}** (ID: {item_id}) to **{target_name}** (ID: {target_id})? | Moved **{item_name}** (ID: {item_id}) to **{target_name}** (ID: {target_id}). |
| Add Item (`add {board_id} {column_id} "name"` or `add {board_id} "name"`) | A numeric second arg with a third arg as the name is the column ID (`get_item` for its name); with no column ID, call `project_columns` for the board, list the columns with IDs and ask user to choose. Then `create_item`: `name`, `parent_id` = the column ID (answers `Created "{name}" (id: {id}, type: Task).`) | Create item "**{name}**" under **{column_name}** (ID: {column_id})? | Created item **{id}**: "{name}" under **{column_name}** (ID: {column_id}). |
| Add Comment (`comment {item_id} "text"`) | Empty text → "Comment text cannot be empty." `get_item` (not found → "Item {item_id} not found."), then `add_item_comment`: `todo_or_issue`, `body` | Add comment to **{item_name}** (ID: {item_id}): "{text}" Proceed? | Comment added (ID: {id}) to **{item_name}**: "{body}" (the answer carries the comment id) |

## Flow: Remove Item

**Trigger**: `remove {item_id}`

1. Resolve the board ID. Call `get_item` (the item) and `project_columns` (the board) together. Item not found → "Item {item_id} not found." The item's `**Parent item ID**` must be one of the board's column IDs; if not → "Item {item_id} is not on this board."
2. Display the item name and current column, then present options:

   > Removing **{item_name}** (ID: {item_id}) from **{column_name}**. Where should it go?
   >
   > 1. Remove from all projects
   > 2. Move to another project
   > 3. Move to a one-on-one or other source

   Ask user to choose (1, 2, or 3).
3. **Option 1** — Confirm: "Remove **{item_name}** from all projects and add to your day plan?" If the user declines, abort — do not remove or move the item. If confirmed, run the Fallback move with `{"parent_id": null}`; when it succeeds, call `attach_to_work_plan` (`todo` = the item ID). Show: "**{item_name}** removed from all projects and added to today's plan."
   **Options 2 and 3** — Ask "Enter the target project/parent item ID:" (option 3: "Enter the target parent item ID:"), confirm "Move **{item_name}** to item {target_id}?", then run the Fallback move. Show: "Moved **{item_name}** (ID: {item_id}) to item {target_id}."

## Flow: Bulk Move Items

**Trigger**: `bulk-move {item_ids} {parent_id}`

1. Parse `item_ids` as a comma-separated list of integers (strip spaces) and `parent_id` as a single integer. No arguments or missing parent ID → show usage:
   > Usage: `/rkit:board bulk-move {item_ids} {parent_id}`
   > Example: `/rkit:board bulk-move 1,2,3 100`
2. Describe the action, warn about side effects, and wait for confirmation (declines → abort):
   > Move {count} items under #{parent_id}? (Items will be removed from all weekly boards.)
3. Run the Fallback bulk move. Success: `body.data.moved`, `.failed`, `.errors`. Always show "Moved {moved} items under #{parent_id}. {failed} failed." If `failed > 0`, add an error table (reasons such as `forbidden`, `not_found`, `self_reference`; all failed → "Moved 0 items under #{id}. {N} failed." with the full table):

   ```
   | Item ID | Reason |
   |---------|--------|
   | 42 | forbidden |
   | 99 | not_found |
   ```

## Flow: List Comments on an Item

**Trigger**: `comments {item_id}`

Call `list_item_comments` (`todo_or_issue`). It answers JSON `{total, comments: [{id, body, author, created_at, updated_at}]}`. Not found → "Item {item_id} not found." None → "No comments on item {item_id}." Otherwise display (strip HTML from `body`; author is `first_name last_name`, else `login`; Time from `created_at`):

```
| ID | Author | Comment | Time |
|----|--------|---------|------|
| 9001 | Sarah Lee | Talked to the vendor — quote is in the shared drive. | 2026-03-07 14:02 |
```

Append `(edited)` after the time when `updated_at` is later than `created_at`.

## Fallback (api.sh)

The connector has no tool for these jobs, so they run as before: `RESPONSE=$("<api.sh path>" METHOD PATH [BODY])` returns `{status, body}`; escape double quotes in JSON bodies. Confirm writes first, as above.

| Job | Call |
|---|---|
| Move an item under another parent (Move Item; Remove Item options 1–3) | `PUT /items/ITEM_ID/move` `{"parent_id": TARGET_ID}` (`null` takes it out of all projects). 404 "Item not found (404)."; 422 show the validation error |
| Bulk move | `PATCH /items/bulk-move` `{"item_ids": [ITEM_IDS], "parent_id": PARENT_ID}`. 403 "Access denied to parent item (403)."; 404 "Parent item not found (404)."; 422 show the validation error |
| Edit my comment (`edit comment {comment_id} "text"`; confirm `Edit comment **{comment_id}** to: "{text}"? Proceed?`) | `PATCH /comments/COMMENT_ID` `{"body": "NEW_TEXT"}`. 200 "Comment **{comment_id}** updated."; 403 "You can only edit your own comments."; 404 "Comment {comment_id} not found."; 422 "Comment text cannot be empty." |
| Delete my comment (`delete comment {comment_id}`; confirm `Delete comment **{comment_id}**? This cannot be undone.`) | `DELETE /comments/COMMENT_ID`. 200 "Comment **{comment_id}** deleted."; 403 "You can only delete your own comments (a team admin can also delete any comment on this item)."; 404 "Comment {comment_id} not found." |

api.sh errors: `NO_CONFIG` or `NO_TOKEN` "Config not found. Run `/rkit:setup` first."; `CURL_FAILED` "Network error. Check your connection."; 401 "Unauthorized (401). Run `/rkit:setup` to update your token."; other non-200 show the status code and error from the body; path `NOT_FOUND` "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"

## Errors

| The tool answers | Say |
|---|---|
| tools missing, or an authorization error | "The ResultKit connector isn't connected. Connect it (https://mcp.resultkit.ai) and try again." |
| "Item not found or you don't have access to it." (`project_columns`) | "Item {id} not found (404)." |
| "To-do or issue not found or you don't have access to it." (`get_item`, comments) | "Item {id} not found." |
| "Parent item not found." (`create_item`) | "Item {id} not found (404)." |
| "A comment cannot be blank." | "Comment text cannot be empty." |
| any other `Error: …` | Show it as returned (validation errors included). |

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
