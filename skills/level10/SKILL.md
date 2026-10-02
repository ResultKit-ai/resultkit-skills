---
name: rkit:level10
description: View and manage EOS Level 10 meeting artifacts — to-dos, done, issues, parked, and headlines. Full L10 workflow with native EOS terminology. Use this skill when users mention "level 10", "L10", "EOS meeting", "EOS to-dos", "EOS issues", "parked items", "done items", or want to work with a team's Level 10 board.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Read, Glob, Grep, AskUserQuestion
---

# rkit:level10

Drives the ResultKit connector's MCP tools; `scripts/api.sh` is used only for the jobs under **Fallback (api.sh)**. Tools are named by base name below; the callable name is `mcp__<server>__<tool>` and the `<server>` alias varies by install, so match on the base name.

## Current State

- Config status: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING"; fi`
- api.sh (Fallback only): !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/level10/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/level10/scripts/api.sh "$HOME/.claude/skills/rkit:level10/scripts/api.sh" "$HOME/.agents/skills/level10/scripts/api.sh" "$HOME/.gemini/skills/level10/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes**: Before any create, done, move, remove, update or comment, summarize all planned changes in a single prompt and ask for confirmation. If the command implies multiple related mutations, batch them under one confirmation. Reads execute immediately.
- **Show IDs**: Always include entity IDs in output so users can reference them (this overrides the connector's general "never print ids" note). `list_headlines` carries no headline IDs, so the Headlines table has no ID column; the Fallback read supplies them on request.
- **Concise output**: Tables and short summaries. No verbose prose.
- **Direct execution**: Call the connector tools directly. Never use Task agents or subagents, never curl or hand-build a URL, and skip the connector's `guide` tool — the flows below are complete for this skill.
- **EOS only**: This skill is exclusively for teams using the EOS framework. Non-EOS teams get a clear error.

## Argument Parsing

Parse the user input to determine which flow to follow:

| Input | Flow |
|-------|------|
| *(no args)* | View L10 Board |
| `todos` | View To-Dos Only |
| `done` | View Done Only |
| `issues` | View Issues Only |
| `parked` | View Parked Only |
| `headlines` | View Headlines Only |
| `add todo "text"` *(+ optional description in natural language)* | Create To-Do |
| `add issue "text"` *(+ optional description in natural language)* | Create Issue |
| `add headline "text"` | Create Headline |
| `done {item_id}` | Mark Item Done |
| `move {item_id} todos` | Move Item to To-Dos |
| `move {item_id} issues` | Move Item to Issues |
| `move {item_id} parked` | Move Item to Parked |
| `remove {item_id}` | Remove from L10 Board |
| `remove headline {id}` | Archive Headline |
| `update headline {id} "text"` | Update Headline Text |
| `comment {item_id} "text"` *(+ "leave a note on {id}", "comment on {id}")* | Add a Comment to an Item |
| `comments {item_id}` *(+ "show comments on {id}", "what did people say on {id}")* | List Comments on an Item |
| `edit comment {comment_id} "text"` | Edit My Comment |
| `delete comment {comment_id}` | Delete My Comment |
| `--team {id}` *(anywhere)* | Override team ID for any flow |

If the input doesn't match any pattern, show this usage summary and ask what they'd like to do.

## Team ID Resolution

1. **`--team {id}` flag** in args → use that team ID
2. **`default_team_id` in config** → use that
3. **Neither** → "No default team configured. Run `/rkit:setup` first."

## Pre-Flight: EOS Framework Gate

Before any operation, after resolving the team ID, call `get_team` (`team_id`). It answers text: line 1 is `# {team_name}` and a `**Framework**: …` line gives the framework (no such line when the team has none).

1. If the framework is not `eos` (any case) → stop and show: "Level 10 is only available for teams using the EOS framework. Use `/rkit:weekly` instead."
2. If EOS, keep `team_name` and `team_id` for output headers.

## Reads

| Job | Tool and arguments | Answers |
|---|---|---|
| All four sections | `L10_todos_issues`: `team_id` | JSON `{sections: {next, done, blocked, parked}}`, each `{items, page, per_page, total}` |
| One section | `list_L10_section`: `team_id`, `section` (`todos`, `done`, `issues`, `parked`) | JSON `{section, items, page, per_page, total}` |
| Headlines | `list_headlines`: `team_id` | prose: a header, then `- "text" — Creator (created date) [expires: …]` per headline; no IDs |
| One item | `get_item`: `todo_or_issue` | text: `# {name}`, `**Status**` (`next`, `blocked`, `parked`, `done`, …), `**ID**` |

In `L10_todos_issues`, `next` is To-Dos and `blocked` is Issues. Each item row carries `id`, `name`, `status`, `due`, `assignees` and `creator` (a person: `first_name`, `last_name`, `login`). Leave `all` out: each section keeps its 7-day window, as before.

## Flow: View L10 Board

**Trigger**: No args (or only `--team {id}`)

Resolve the team ID and run the gate. Then call `L10_todos_issues` and `list_headlines` together and display:

```
Level 10: {team_name} (ID: {team_id})

## To-Dos ({count} items)

| ID | Name | Assignee | Creator | Due |
|----|------|----------|---------|-----|
| 42 | Fix login bug | Jane Doe | Scott Levy | 2026-03-07 |

## Done ({count} items)

| ID | Name | Assignee | Creator | Due |
|----|------|----------|---------|-----|
| 55 | Deploy staging fix | — | Jane Doe | 2026-02-28 |

## Issues ({count} items)

| ID | Name | Assignee | Creator | Due |
|----|------|----------|---------|-----|
| 88 | Cash flow concern | Patrick A. | Scott Levy | — |

## Parked ({count} items)

| ID | Name | Assignee | Creator | Due |
|----|------|----------|---------|-----|
| 73 | Office relocation plan | — | Scott Levy | — |

## Headlines ({count} headlines)

| Text | Creator | Expires |
|------|---------|---------|
| New client signed | John Smith | 2026-03-07 |
```

**Display rules**:
- Section headers show the count from `total`
- To-Dos, Done, Issues, and Parked: show ID, name, assignee (first entry from `assignees` — `first_name last_name`, fall back to `login` if names are empty, or "—" if the array is empty), creator (`first_name last_name` from `creator`; fall back to `login` if names are empty), due date (or "—" if null)
- Headlines: text, creator and `expires:` date (or "—" if absent), from the `list_headlines` lines. No ID column; if the user asks for headline IDs, use the Fallback read
- Empty sections show "(empty)"
- If any section has more items than returned (`total` > returned count), show "Showing {returned} of {total} — more items exist"

## Flow: View Single Section

**Trigger**: `todos`, `done`, `issues`, `parked`, or `headlines`

Resolve the team ID and run the gate. Call `list_L10_section` (`team_id`, `section`), or `list_headlines` for `headlines`. Display with the same format as that section of View L10 Board — header with count, table, empty/overflow handling.

## Writes

Resolve the team ID and run the gate (not for comments, which work on the item alone), then confirm, then call the tool. Names, ids and dates in the success lines come from the tool's answer (an item as JSON) or from what the user gave.

| Flow | Tool and arguments | Confirm | On success |
|---|---|---|---|
| Create To-Do | `add_L10_todo`: `team_id`, `name`, `description?`, `due?` | Create to-do "**{name}**" for **{team_name}**{due info}? (+ `Description: {description}`) | `Created to-do **{id}**: "{name}" (due {date})` |
| Create Issue | `add_L10_issue`: `team_id`, `name`, `description?` | Create issue "**{name}**" for **{team_name}**{due info}? (+ `Description: {description}`) | `Created issue **{id}**: "{name}"` |
| Create Headline | `create_headline`: `team_id`, `text`, `expires_at` | Create headline "**{text}**" for **{team_name}** (expires {date})? | `Created headline **{id}**: "{text}" (expires {date})` |
| Mark Done | `mark_done`: `todo_or_issue` | Mark {L10_term} **{item_name}** (ID: {item_id}) as done? | Moved **{item_name}** (ID: {item_id}) to **Done**. |
| Move Item | `move_on_L10`: `team_id`, `todo_or_issue`, `section` | Move **{item_name}** (ID: {item_id}) from **{current_section}** to **{target_section}**? | Moved **{item_name}** (ID: {item_id}) to **{target_section}**. |
| Remove from Board | `remove_from_L10`: `team_id`, `todo_or_issue` | Remove **{item_name}** (ID: {item_id}) from the Level 10 board? Item will still exist. | Removed **{item_name}** (ID: {item_id}) from the Level 10 board. |
| Archive Headline | `archive_headline`: `team_id`, `headline_id` | Archive headline **{headline_id}** from **{team_name}**? | Archived headline **{headline_id}**. |
| Update Headline | `update_headline`: `team_id`, `headline_id`, `text?`, `expires_at?` | Update headline **{headline_id}** on **{team_name}**: {changes}? | Updated headline **{id}**: "{text}" (expires {date}) |
| Add Comment | `add_item_comment`: `todo_or_issue`, `body` | Add comment to **{item_name}** (ID: {item_id}): "{text}" Proceed? | Comment added (ID: {comment_id}) to **{item_name}**: "{text}" (the answer carries the comment id) |

- **Create To-Do / Issue** (`add todo "text"`, `add issue "text"`, optionally `--due YYYY-MM-DD`): the tool takes `name` (required), `description` (optional) and, for a to-do, `due` (optional). Users often provide a title and additional context in natural language — extract the title as `name` and any extra detail as `description`. When the user explicitly separates a title from a description (or provides context beyond the title), always pass `description`. Empty text → "To-do name cannot be empty." / "Issue name cannot be empty." `add_L10_issue` takes no `due`: with `--due`, call `update_item` (`todo_or_issue` = the new id, `due`) once it is created.
- **Headlines**: `add headline "text"` takes `--expires YYYY-MM-DD` (else 7 days from today); empty text → "Headline text cannot be empty." `update headline {id} "new text"` and/or `--expires`; with neither → "Provide text or --expires to update." Pass only the fields provided. `remove headline {id}` archives. A headline named by its text → find its ID with the Fallback read.
- **Mark Done** (`done {item_id}`): `get_item` first — not found → "Item {item_id} not found."; `**Status**` already `done` → "Item **{name}** (ID: {item_id}) is already done." and stop. L10_term from the status: `next` → "To-Do", `blocked` → "Issue", `parked` → "Parked".
- **Move Item** (`move {item_id} todos|issues|parked`): `get_item` first — not found → "Item {item_id} not found." Target status: `todos` → `next`, `issues` → `blocked`, `parked` → `parked`; if the item already has it → "Item **{name}** (ID: {item_id}) is already in {target_section}." and stop. Current section from the status: `next` → "To-Dos", `blocked` → "Issues", `done` → "Done", `parked` → "Parked". If `move_on_L10` answers that the item is not on this team's Level 10, put it there first with `place_on_L10` (`todo_or_issue`, `team_id`, `section` = `issues` for an issue target, else `todos`) and repeat `move_on_L10` — the old route put it on the board too.
- **Remove from Board** (`remove {item_id}`): read the item with the Fallback item read (`get_item` has no `on_weekly`) — 404 → "Item {item_id} not found."; `on_weekly` false → "Item {item_id} is not on the Level 10 board." Then confirm and `remove_from_L10`.
- **Add Comment** (`comment {item_id} "text"`): to-dos, issues, done, and parked items all support comments (they're the same underlying object, just different statuses). Headlines do not — a headline can't carry a comment. Empty text → "Comment text cannot be empty." `get_item` first — not found → "Item {item_id} not found."

## Flow: List Comments on an Item

**Trigger**: `comments {item_id}`

Call `get_item` and `list_item_comments` (`todo_or_issue`) together; the comments answer JSON `{total, comments: [{id, body, author, created_at, updated_at}]}`. Not found → "Item {item_id} not found." None → "No comments on item {item_id}." Otherwise display (strip HTML from `body`; author is `first_name last_name`, else `login`; Time from `created_at`):

```
## Comments — {item_name} (ID: {item_id})

| ID | Author | Comment | Time |
|----|--------|---------|------|
| 9001 | Sarah Lee | Talked to the vendor — quote is in the shared drive. | 2026-03-07 14:02 |
```

Append `(edited)` after the time when `updated_at` is later than `created_at`.

## Fallback (api.sh)

The connector has no tool for these jobs, so they run as before: `RESPONSE=$("<api.sh path>" METHOD PATH [BODY])` returns `{status, body}`; escape double quotes in JSON bodies. Confirm writes first, as above.

| Job | Call |
|---|---|
| Item read with `on_weekly` (Remove from Board) | `GET /items/ITEM_ID` |
| Headlines with IDs (to show IDs, or to find the ID of a headline the user named by its text) | `GET /teams/TEAM_ID/l10/headlines`; headlines in `body.data` with `id`, `text`, `creator`, `expires_at`; table columns `ID`, `Text`, `Creator`, `Expires` |
| Edit my comment (`edit comment {comment_id} "text"`; confirm `Edit comment **{comment_id}** to: "{text}"? Proceed?`) | `PATCH /comments/COMMENT_ID` `{"body":"NEW_TEXT"}`. 200 "Comment **{comment_id}** updated."; 403 "You can only edit your own comments."; 404 "Comment {comment_id} not found."; 422 "Comment text cannot be empty." |
| Delete my comment (`delete comment {comment_id}`; confirm `Delete comment **{comment_id}**? This cannot be undone.`) | `DELETE /comments/COMMENT_ID`. 200 "Comment **{comment_id}** deleted."; 403 "You can only delete your own comments (a team admin can also delete any comment on this item)."; 404 "Comment {comment_id} not found." |

api.sh errors: `NO_CONFIG` or `NO_TOKEN` "Config not found. Run `/rkit:setup` first."; `CURL_FAILED` "Network error. Check your connection."; 401 "Unauthorized (401). Run `/rkit:setup` to update your token."; 404 "Not found (404)."; 422 show the validation error from the body; other non-200 show the status code and error from the body; path `NOT_FOUND` "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"

## Errors

| The tool answers | Say |
|---|---|
| tools missing, or an authorization error | "The ResultKit connector isn't connected. Connect it (https://mcp.resultkit.ai) and try again." |
| "Team not found or you don't have access to it." / "You don't have access to this team." | "Team {id} not found, or you don't have access to it." |
| "To-do or issue not found or you don't have access to it." | "Item {id} not found." |
| "Headline not found or you don't have access to it." | "Headline {id} not found, or you can't change it (only its creator or a team admin can)." |
| "Validation failed: expires_at …" | "Expiration date must be in YYYY-MM-DD format." |
| "A comment cannot be blank." | "Comment text cannot be empty." |
| any other `Error: …` | Show it as returned. |

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
