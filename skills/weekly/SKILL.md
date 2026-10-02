---
name: rkit:weekly
description: View and manage the team weekly board (Level 10 for EOS teams). Shows items grouped by status column using framework-specific terminology. Uses L10-specific API routes for EOS teams. Use this skill when users mention their weekly board, team board, Level 10 board, L10, weekly items, team priorities, team issues, or want to manage items on the team's weekly meeting board.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Read, Glob, Grep, AskUserQuestion
---

# rkit:weekly

The team weekly board (Level 10 for EOS teams). It drives the ResultKit connector's MCP tools, named below by base name: the full tool name is `mcp__<server>__<tool>` and the server alias varies by install, so match on the base name. `scripts/api.sh` is used only for the jobs under **Fallback**.

## Current State

- Config status: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING"; fi`
- api.sh (Fallback only): !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/weekly/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/weekly/scripts/api.sh "$HOME/.claude/skills/rkit:weekly/scripts/api.sh" "$HOME/.agents/skills/weekly/scripts/api.sh" "$HOME/.gemini/skills/weekly/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes**: Before any write, summarize all planned changes in a single prompt and ask for confirmation. If the command implies multiple related mutations, batch them under one confirmation. Reads execute immediately.
- **Show IDs**: Always include item IDs in output so users can reference them.
- **Concise output**: Tables and short summaries. No verbose prose.
- **Direct execution**: Call the connector tools directly (`scripts/api.sh` only for the Fallback jobs). Never use Task agents or subagents, never curl or hand-build a URL, and skip the connector's `guide` tool: the flows below are complete for this skill.

## Framework Terminology

`get_team` answers a `**Framework**:` line (the team's `framework`; no line = default/null). Map the board name and column headers:

| | Default / null | EOS | OKR | 4DX | V2MOM | SRT | SVEP |
|-------------|----------------|-----|-----|-----|-------|-----|------|
| **Board name** | Weekly | Level 10 | Weekly | Weekly | Weekly | Weekly | Weekly |
| next | Next | To-Do | Priorities | WIG Actions | Next | Next | Next |
| done | Done | Done | Done | Done | Done | Done | Done |
| blocked | Issues | Issues | Issues + Challenges | Blockers | Obstacles | Issues | Issues |
| parked | Parked | Parked | Park for Later | Parked | Parked | Parked | Parked |

**Always use the framework-mapped board name in all user-facing output and messages.** For EOS teams, say "Level 10" — never "weekly board" or "team weekly."

## Argument Parsing

| Input | Flow |
|-------|------|
| *(no args)* | View Weekly |
| `next` / `done` / `blocked` / `parked` | View Single Column |
| `move {item_id} {column}` | Move Item |
| `add {item_id}` or `add {item_id} {column}` | Add Item to Weekly |
| `remove {item_id}` | Remove Item from Weekly |
| `comment {item_id} "text"` *(+ "leave a note on {id}", "comment on {id}")* | Add a Comment to an Item |
| `comments {item_id}` *(+ "show comments on {id}", "what did people say on {id}")* | List Comments on an Item |
| `edit comment {comment_id} "text"` | Edit My Comment |
| `delete comment {comment_id}` | Delete My Comment |
| `--team {id}` (anywhere in args) | Override team ID for any flow |

If the input doesn't match any pattern, show this usage summary and ask what they'd like to do.

**Team ID.** `--team {id}` if given, else `default_team_id` from the config above, else "No default team configured. Run `/rkit:setup` first."

## Tools

| Job | Tool and arguments |
|---|---|
| Team name and framework | `get_team`: `team_id`. Answers `# {name}` and `**Framework**: {value}`. |
| Whole board, EOS team | `L10_todos_issues`: `team_id`. Answers JSON `{team_id, sections: {next, done, blocked, parked}}`; each section is `{items, page, per_page, total}`. |
| One column, EOS team | `list_L10_section`: `team_id`, `section` (`next`, `done`, `blocked` or `parked`). Answers `{section, items, page, per_page, total}`. |
| Read one item | `get_item`: `todo_or_issue`. Answers `# {name}` and `**Status**: {status}`; the board columns are the statuses `next`, `done`, `blocked`, `parked`. |
| Move | `move_on_L10`: `team_id`, `todo_or_issue`, `section` (the column). Moves only an item already on this team's board. |
| Remove | `remove_from_L10`: `team_id`, `todo_or_issue`. The item is not deleted. |
| Comments | `add_item_comment`: `todo_or_issue`, `body`. `list_item_comments`: `todo_or_issue`. |

Each item in a column has `id`, `name`, `creator`, `due`.

## Fallback — still `scripts/api.sh`

The connector has no tool for these jobs, so they run as before: `RESPONSE=$("<api.sh path>" METHOD PATH [BODY])` returns `{status, body}`. Confirm writes first, as above.

| Job | Call |
|---|---|
| Board reads for a non-EOS team (the connector's board tools read the Level 10 service, a different read from the generic board these teams used) | `GET /teams/TEAM_ID/items/COLUMN?per_page=50` for `next`, `done`, `blocked`, `parked`; items in `body.data`, count in `body.meta.total` |
| Add an existing item to the board in a column (`place_on_L10` is not this job: it cannot reach Done or Parked and does not tag the name `#next`) | `GET /items/ITEM_ID` (`on_weekly`, name, status), then `PUT /teams/TEAM_ID/items/COLUMN/ITEM_ID` |
| Edit comment | `PATCH /comments/COMMENT_ID` `{"body": "NEW_TEXT"}`; 403 "You can only edit your own comments." |
| Delete comment | `DELETE /comments/COMMENT_ID`; 403 "You can only delete your own comments (a team admin can also delete any comment on this item)." |

api.sh errors: `NO_CONFIG` or `NO_TOKEN` "Config not found. Run `/rkit:setup` first."; `CURL_FAILED` "Network error. Check your connection."; 401 "Unauthorized (401). Run `/rkit:setup` to update your token."; 404 "Not found (404)."; 422 show the validation error from the body; other non-200 show the status code and the error from the body; path `NOT_FOUND` "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`".

---

## Flow: View Weekly

**Trigger**: No args (or only `--team {id}`). Resolve the team ID. Call `get_team` for the framework and team name. EOS team: `L10_todos_issues`. Any other framework: the four Fallback board reads. Look up column headers in the Framework Terminology table.

```
{board_name}: {team_name} (ID: {team_id})

## {Next Header} ({next_total} items)

| ID | Name | Creator | Due |
|----|------|---------|-----|
| 42 | Fix login bug | Scott Levy | 2026-02-20 |
| 88 | Write API tests | Patrick Angodung | — |

Showing 50 of {total} — more items exist

## {Done Header} ({done_total} items)

(empty)

## {Blocked Header} ({blocked_total} items)

...

## {Parked Header} ({parked_total} items)

...
```

**Display rules**:
- Column header shows the framework-mapped name and the section's `total` (`meta.total` on the Fallback read).
- Each item shows: ID, name, creator (`first_name last_name` from `creator`; show login if names are empty), due date (or "—" if null).
- Empty columns show "(empty)".
- If a column has more than 50 items (`total` over 50), show the first 50 and "Showing 50 of {total} — more items exist" after the table.
- Column order: next, done, blocked, parked (always this order).

## Flow: View Single Column

**Trigger**: `next`, `done`, `blocked`, or `parked`. Resolve the team ID; `get_team` for the framework. EOS team: `list_L10_section` with that section. Any other framework: the Fallback read for that column. Display as a single section from View Weekly — framework-mapped header, item table, overflow indicator.

## Flow: Move Item

**Trigger**: `move {item_id} {column}`. Column must be one of `next`, `done`, `blocked`, `parked` ("Invalid column '{input}'. Use: next, done, blocked, or parked.").

1. `get_item`. Not found → "Item {item_id} not found." Map its `**Status**` to a column; already the target → "Item {item_id} is already in {column}." and stop.
2. Resolve the team ID. Confirm: > Move item **{item_name}** (ID: {item_id}) from **{current_column}** to **{target_column}**? Wait for confirmation, then `move_on_L10` (`team_id`, `todo_or_issue`, `section` = the target column).
3. Success: "Moved **{item_name}** (ID: {item_id}) to **{target_column}**." Refused because the item is not on this team's Level 10 (the answer says to place it there first; nothing is written) → "Item {item_id} is not on the {board_name}. Use `add` to put it on first."

## Flow: Add Item to Weekly

**Trigger**: `add {item_id}` or `add {item_id} {column}`. All calls are Fallback.

1. `GET /items/ITEM_ID`. 404 → "Item {item_id} not found." `on_weekly` true → "Item **{item_name}** (ID: {item_id}) is already on the {board_name} in **{current_column}** (map `status` to a column as in the Move flow). Move it instead?" — yes switches to the Move flow.
2. Column: from args (must be next/done/blocked/parked), else ask with framework-mapped names:
   > Which column for **{item_name}** (ID: {item_id})?
   > 1. Next
   > 2. Done
   > 3. Blocked
   > 4. Parked
3. Resolve the team ID. Confirm: > Add **{item_name}** (ID: {item_id}) to the {board_name} in **{column}**? Wait for confirmation, then `PUT /teams/TEAM_ID/items/COLUMN/ITEM_ID`. This single call adds the item to the team board (`on_weekly=true`) and sets its status in one step.
4. 200 → "Added **{item_name}** (ID: {item_id}) to **{column}**."

## Flow: Remove Item from Weekly

**Trigger**: `remove {item_id}`.

1. `get_item`. Not found → "Item {item_id} not found."
2. Resolve the team ID. Confirm: > Remove **{item_name}** (ID: {item_id}) from the {board_name}? (Item will still exist — only removed from the {board_name}.) Wait for confirmation, then `remove_from_L10` (`team_id`, `todo_or_issue`).
3. Success: "Removed **{item_name}** (ID: {item_id}) from the {board_name}." Refused with "To-do or issue not found or you don't have access to it." (the item just read fine, so it is not on this team's board) → "Item {item_id} is not on the {board_name}."

## Flow: Add Comment to an Item

**Trigger**: `comment {item_id} "text"`. Empty text → "Comment text cannot be empty." `get_item` for the name (not found → "Item {item_id} not found."). Confirm: > Add comment to **{item_name}** (ID: {item_id}): > "{text}" > > Proceed? Wait for confirmation, then `add_item_comment` (`todo_or_issue`, `body` = the text). The answer names the new comment's id: `Comment added (ID: {id}) to **{item_name}**: "{body}"`, with the text you sent. "A comment cannot be blank." → "Comment text cannot be empty."

## Flow: List Comments on an Item

**Trigger**: `comments {item_id}`. `list_item_comments` (`todo_or_issue`); it answers JSON `{total, comments: [{id, body, author, created_at, updated_at}]}`. None → "No comments on item {item_id}." Else display (strip HTML from `body`; append `(edited)` after the time when `updated_at` is later than `created_at`):

```
| ID | Author | Comment | Time |
|----|--------|---------|------|
| 9001 | Sarah Lee | Talked to the vendor. | 2026-03-07 14:02 |
```

"To-do or issue not found or you don't have access to it." → "Item {item_id} not found."

## Flow: Edit / Delete My Comment

**Trigger**: `edit comment {comment_id} "text"` or `delete comment {comment_id}`. Both are Fallback.

**Edit** — confirm `Edit comment **{comment_id}** to: "{text}"? Proceed?`, then `PATCH /comments/COMMENT_ID`. 200 → "Comment **{comment_id}** updated." · 403 → "You can only edit your own comments." · 404 → "Comment {comment_id} not found." · 422 → "Comment text cannot be empty."

**Delete** — confirm `Delete comment **{comment_id}**? This cannot be undone.`, then `DELETE /comments/COMMENT_ID`. 200 → "Comment **{comment_id}** deleted." · 403 → "You can only delete your own comments (a team admin can also delete any comment on this item)." · 404 → "Comment {comment_id} not found."

---

## Errors

| The tool answers | Say |
|---|---|
| tools missing, or an authorization error | "The ResultKit connector isn't connected. Connect it (https://mcp.resultkit.ai) and try again." |
| `get_team`: "Team not found." or "You don't have access to this team." | "Team {id} not found (404)." |
| any other `Error: …` | Show it as returned. |

## Edge Cases

- **No config** (and no `--team`) → "Config not found. Run `/rkit:setup` first."
- **All columns empty** → show all four column headers with "(empty)"
- **Invalid column name** (move, add) → "Invalid column '{input}'. Use: next, done, blocked, or parked."

## References

- [ResultMaps V2 API Reference](references/api-reference.md) — payloads for the Fallback calls.
