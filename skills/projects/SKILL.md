---
name: rkit:projects
description: List active projects for a team and manage project items. View project columns with item counts, add items to specific columns, batch-add multiple items, and move things on a project — a to-do to another column or another project, a column to a new place in its project or to another project. Use this skill whenever users want to move a to-do or a column on a project — "move Draft launch email to Doing", "put X at the top of Doing", "move X to Ideas on Content Workflow", "move this to another project", "move the Backlog column", "move the Shipped column to the front" — or ask about projects, project boards, project columns, want to list team projects, add items to a project, or view project status. It finds a project by name on your default team, so no team ID or project ID is needed first.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Read, Glob, Grep, AskUserQuestion
---

# rkit:projects

List active projects for a team. Drill into a project to see its columns, add items, and move a to-do or a column. It drives the ResultKit connector's MCP tools, named below by base name (the full name is `mcp__<server>__<tool>`; the server alias varies by install). `scripts/api.sh` is used only for the jobs under **Fallback (api.sh)**.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh (Fallback only): !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/projects/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/projects/scripts/api.sh "$HOME/.claude/skills/rkit:projects/scripts/api.sh" "$HOME/.agents/skills/projects/scripts/api.sh" "$HOME/.gemini/skills/projects/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes.** Reads execute immediately. Before any write, summarize all planned changes in a single prompt and ask for confirmation. If the command implies multiple related mutations, batch them under one confirmation.
- **Show IDs.** Always include project and item IDs in output (this overrides the connector's general "never print raw ids" note).
- **Concise output.** Tables and short summaries. No filler.
- **Direct execution.** Call the connector tools directly. Fallback jobs use Bash with api.sh (a move is never one of them). Never use Task agents, never curl or hand-build a URL, and skip the connector's `guide` tool — the routing below is complete for this skill.
- **Two-level shape.** A project's direct children are usually **columns / section names**, not to-dos. The actual to-dos are **grandchildren** under those columns. A minority of projects are flat checklists (items as direct children, no columns). Never present direct children as to-dos without first checking. `project_columns` returns the top-level rows with their children nested; for a flat checklist those top-level rows are the to-dos. See the **Project Hierarchy** section in `references/api-reference.md` for detection (its calls are REST calls: run them through api.sh).

## Argument Parsing

| Input | Behavior | Tool / flow |
|-------|----------|-------------|
| *(no args)* | List **active** projects for default team (the server's default: done, archived, parked, blocked and draft are left out) | `projects` |
| `{team_id}` | List active projects for specified team | `projects` |
| `done` / `completed` | List done projects (`status: "done"`) | `projects` |
| `q "search term"` | Filter projects by name (the tool ignores a term under 2 characters) | `projects` |
| `{project_id} columns` | Show columns (direct children) of a project | `project_columns` |
| `{project_id} add "item name"` | Add an item to a project column (prompts for column if not specified) | `project_columns`, then `create_item` |
| `{project_id} add {column_id} "item name"` | Add an item directly to a specific column | `create_item` |
| "move X to Doing", "put X at the top/bottom of Doing", "put X after Y in Doing" *(any verb, to-do or item)* | Move a to-do to another column of its project, or to a place in a column | `projects`, `project_columns`, then `move_project_item` |
| "move X to Ideas on Content Workflow", "move X to another project" *(+ onto a project, naming no column)* | Move a to-do to a column of another project, or onto that project in no column | `projects`, `project_columns`, then `move_project_item` |
| "move the Shipped column to the front", "put the Backlog column after Doing" | Move a column to a new place in its own project | `projects`, `project_columns`, then `move_project_column` |
| "move the Backlog column to Content Workflow" | Move a whole column, with its to-dos, to another project | `projects`, `project_columns`, then `move_project_column` |
| `{project_id} comment "text"` *(+ "leave a note on project {id}", "comment on project {id}")* | Add a comment to the project | `add_item_comment` |
| `{project_id} comments` *(+ "show comments on project {id}", "project discussion")* | List comments on the project | `list_item_comments` |
| `edit comment {comment_id} "text"` | Edit my comment | Fallback |
| `delete comment {comment_id}` | Delete my comment | Fallback |

**Ambiguous project_id vs team_id:** if the first arg is a number followed by `columns`, `add`, `comment` or `comments`, treat it as a project ID. Otherwise treat it as a team ID.

## Flow: List Projects

1. **Team ID.** Use the one in args; otherwise `default_team_id` from Current State config. Neither → "No team specified and no default configured. Run `/rkit:setup`."
2. **Fetch.** Call `projects` with `team_id`, plus `status: "done"` for `done` / `completed` and `q` for a search. It answers JSON `{items, page, perPage, total}`; each item is a project with `id`, `name`, `status`, `due`, `creator`.
3. **Show.** No items → "No active projects for team {team_id}." Otherwise:

   ```
   ## Active Projects — Team {team_id}

   | ID | Name | Status | Due | Creator |
   |----|------|--------|-----|---------|
   | 201 | Q1 Product Launch | not_started | 2026-03-31 | Jane D. |
   | 205 | API Migration | next | — | John S. |

   {count} active projects ({total} total)
   ```

   - `Due`: the date, or "—" when null. `Creator`: `creator.first_name` + last initial (e.g., "Jane D.").
   - `count` = rows shown; `total` = the answer's `total`. If `total` is more than the rows returned, show "Page {page} of {ceil(total / perPage)}" with a note that more projects exist (the tool has no paging input; later pages are under Fallback).
   - **Footer hint**, always:
     ```
     Tip: `/rkit:projects {id} columns` to view columns · `/rkit:projects {id} add "item"` to add items · `/rkit:board {id}` for full board view
     ```

## Flow: View Project Columns

**Trigger**: `{project_id} columns`. Call `project_columns` with `project_id`. It answers JSON `{items, page, perPage, total}`: `items` are the project's columns, each carrying its to-dos in `children`, so one call gives every count. No items → "No columns found for project {project_id}." Otherwise:

```
## Columns — {project_name} ({project_id})

| ID | Column | Items |
|----|--------|-------|
| 207441 | Backlog | 12 |
| 207442 | Do next | 3 |
| 207443 | Working | 5 |
| 207444 | Done | 8 |

Tip: `/rkit:projects {project_id} add "item name"` to add an item · `/rkit:board {project_id}` for full board view
```

`Items` = the number of entries in that column's `children`. Use `{project_name}` only when you already have it from a project list; otherwise head the table `Columns — Project {project_id}`.

## Flow: Add Item to Project Column

**Trigger**: `{project_id} add "item name"` or `{project_id} add {column_id} "item name"`.

1. **Resolve column.** With a column ID (three args after project_id: column_id + item name), use it directly. Otherwise call `project_columns`, list the columns with IDs and ask the user to pick:
   ```
   Which column?
   1. Backlog (207441)
   2. Do next (207442)
   3. Working (207443)
   4. Done (207444)
   ```
2. **Confirm.** Describe the action and wait for confirmation:
   > Create item "**{name}**" under **{column_name}** (ID: {column_id})?
3. **Create.** Call `create_item` with `name` and `parent_id` = the column ID (leave `team_id` and `type` out). It answers `Created "{name}" (id: N, type: Task).`
4. **Report.** "Created item **{id}**: \"{name}\" under **{column_name}** (ID: {column_id})."

**Batch add.** If the user gives several item names (comma-separated, or several quoted strings), create each one under the same column with its own `create_item` call. Confirm the full list before executing. Show the results as a table:

```
Added to {column_name} ({column_id}):

| ID | Name |
|----|------|
| 211296 | CDW quote tool |
| 211297 | Research Pipedrive workflow |
```

## Flow: Move a To-Do or Column

**Trigger**: any ask to move a to-do (or item) to another column or another project, to put it at the top or bottom of a column or right after another one, or to move a column (reorder it in its project, or move it to another project), whatever the verb ("move", "put", "send", "file"). One move call per move, after a yes: `move_project_item` for a to-do or item, `move_project_column` for a column. The move goes through the connector only: ids come from `projects` and `project_columns` (never `get_item`), and there is no api.sh or curl step.

Both tools take `into` (the id of the column or project it goes into) and, only when the user named a place, `to` (`top` or `bottom`) or `after` (the id of another one already in `into`), never both. With no place it lands last. To reorder within where it already sits, `into` is its current column (for a column: its project). Which tool follows from what `project_columns` shows: a top-level row is a column, a row in a column's `children` is an item. A tool given the other kind refuses it in words, naming the other tool.

| The user asks to move | Tool | Id to move | `into` | Place |
|---|---|---|---|---|
| a to-do or item to a column (this project or another) | `move_project_item` | `item` = its id | the column's id | `to` for top or bottom, `after` for "after Y" (Y = another item in that column) |
| a to-do or item onto a project, naming no column | `move_project_item` | `item` = its id | the project's id | none: it lands at the project's top level, in no column |
| a column to a new place in its project | `move_project_column` | `column` = its id | the project's id | `to` for front/first/top or end/last/bottom, `after` for "after the Doing column" (another column of that project) |
| a column to another project | `move_project_column` | `column` = its id | the other project's id | none: it lands last, and its to-dos go with it |

1. **Connector first.** If `projects`, `project_columns` or the move tool needed (`move_project_item`, or `move_project_column` for a column) is missing, or answers an authorization error, give the Errors sentence and stop, before any other call.
2. **What and where.** Take from the message what moves, where it goes and any place. Something missing ("move a to-do to another column") → ask for it in one line (`Which to-do or column, and where should it go?`) and stop. Team: the one in args, else `default_team_id` from Current State (neither → "No team specified and no default configured. Run `/rkit:setup`.").
3. **Read.** Call `projects` for the team (add `q` when one project is named; leave it out when two are, so one answer holds both), then `project_columns` for each project named. No project named: read every active project's columns. Columns are the top-level rows and each column's to-dos are its `children`; every row carries its `id` and `name`. Match names ignoring case, exact first, then contains; several matches → list them with IDs and ask which. A destination name that is a column of the project the thing sits in goes into that column; one that is a project goes into the project; one that is both → ask which.
4. **Say what is wrong, in words, and stop. No write:**
   - no column of that name → `There is no column "{typed}" on {project_name}. Its columns: {A}, {B}, {C}.` (names verbatim, board order). Never create one.
   - the to-do, column or project is not on what the user named → `I don't see "{name}" on {project_name}.`
   - it already sits in that column or project and the user named no place → `{name} is already in {destination}.` Nothing changed, and it is not an error.
   - a project as the thing to move → `Only a to-do or a column can be moved here, not a project.` A column into a column → `A column goes into a project, not into another column.`
   - the user named both a top/bottom and an "after" → `Pick one place: the top or bottom, or right after another one, not both.`
5. **Confirm.** One plain question in the reply (not AskUserQuestion), naming what moves, where it goes and its place, with IDs as above; for a column going to another project also how many to-dos go with it. Then wait.
   > Move **Draft launch email** (ID: 9101) from **Backlog** to **Doing** (ID: 9012) on Go To Market?
   > Put **Price the starter plan** (ID: 9103) first in **Doing** (ID: 9012)?
   > Move the **Backlog** column (ID: 9011) from Go To Market to **Content Workflow** (ID: 9002)? Its 3 to-dos go with it.

   On **no**: `Okay, nothing was moved.` and make no call. On **yes**: call `move_project_item` (`item`) or `move_project_column` (`column`) once, with `into`, and `to` or `after` only if a place was named.
6. **Answer, then show the columns.** The tool answers one sentence with links (`[{name}](…) is now last in "Doing" on …`). Reply with it, a blank line, then call `project_columns` for the project it went into (the project itself when `into` is a project) and show every column with its to-dos, in the order returned:

   ```
   ## Columns — {project_name} ({project_id})

   ### {column_name} ({column_id}) — {n} to-dos
   - {to-do name} ({to-do_id})
   ```
   A column with none shows its heading and `— 0 to-dos`. An `Error: …` is said as the Errors table says, and nothing is shown after it.

## Flow: Comments on a Project

The connector has no project-specific comment tool. A project is an Item of type TodoList, so its comments are item comments: pass the project's ID as `todo_or_issue`. Unlike the project route, these tools do not check that the ID is a project, so use the project ID that `projects` lists. For a comment on one of the project's individual to-dos rather than the project itself, use `/rkit:board` or `/rkit:level10`/`/rkit:weekly` against that to-do's own ID.

**Add** — `{project_id} comment "text"`. Empty text → "Comment text cannot be empty." Confirm, wait, then call `add_item_comment` with `todo_or_issue` = the project ID and `body` = the text:

> Add comment to project **{project_name}** (ID: {project_id}):
> "{text}"
>
> Proceed?

It answers `Comment N added to …`. Report: `Comment added (ID: {id}) to **{project_name}**: "{body}"`.

**List** — `{project_id} comments`. Call `list_item_comments` with `todo_or_issue` = the project ID. It answers JSON `{todo_or_issue, page, per_page, total, comments: [{id, body, author, created_at, updated_at}]}`. None → "No comments on project {project_id}." Otherwise strip HTML from `body` and show:

```
## Comments — {project_name} ({project_id})

| ID | Author | Comment | Time |
|----|--------|---------|------|
| 9001 | Sarah Lee | Vendor confirmed the timeline. | 2026-03-07 14:02 |
```

Append `(edited)` after the time when `updated_at` is later than `created_at`.

## Fallback (api.sh)

The connector has no live tool for these jobs, so they run as before: `RESPONSE=$("<api.sh path>" METHOD PATH [BODY])` returns `{status, body}`. Confirm writes first, as above; escape double quotes in the comment text.

| Job | Call |
|---|---|
| Edit my comment — confirm `Edit comment **{comment_id}** to: "{text}"? Proceed?` | `PATCH /comments/COMMENT_ID` `{"body": "NEW_TEXT"}`. 200 "Comment **{comment_id}** updated." · 403 "You can only edit your own comments." · 404 "Comment {comment_id} not found." · 422 "Comment text cannot be empty." |
| Delete my comment — confirm `Delete comment **{comment_id}**? This cannot be undone.` | `DELETE /comments/COMMENT_ID`. 200 "Comment **{comment_id}** deleted." · 403 "You can only delete your own comments (a team admin can also delete any comment on this project)." · 404 "Comment {comment_id} not found." |
| More projects than one `projects` answer holds (`total` above the rows returned) | `GET /teams/TEAM_ID/projects?per_page=100&page=N`, plus `&status=done` / `&q=term` as asked; projects in `body.data`, paging in `body.meta` (`total_pages`) |

api.sh errors: `NO_CONFIG` or `NO_TOKEN` "Config not found. Run `/rkit:setup` first."; `CURL_FAILED` "Network error. Check your connection."; 401 "Unauthorized (401). Run `/rkit:setup` to update your token."; path `NOT_FOUND` "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`".

## Project Status Values

Projects use the same status field as items: `not_started` (not yet begun), `next` (queued next), `parked` (on hold), `blocked`, `done` (completed), `archived`, `draft`. **The default list is the team's active projects: `not_started` and `next` only.** Parked, blocked, done, archived and draft projects are left out until asked for with `status` (`status: "parked"`, `status: "done"`, …); a `status` outside these is refused by name. Muted projects are left out unless `include_muted: true`.

## Errors

| The tool answers | Say |
|---|---|
| tools missing, or an authorization error | "The ResultKit connector isn't connected. Connect it (https://mcp.resultkit.ai) and try again." |
| "Team not found or you don't have access to it." (`projects`) | "Team {team_id} not found." |
| "Item not found…" (`project_columns`) or "To-do or issue not found…" (comments) | "Project {project_id} not found." |
| "A comment cannot be blank." | "Comment text cannot be empty." |
| "Parent item not found." or "Cannot view parent item." (`create_item`) | "Column {column_id} not found." |
| "Give either to or after, not both." (either move tool) | "Pick one place: the top or bottom, or right after another one, not both." |
| "Item not found or you don't have access to it." (`move_project_item`) or "Column not found or you don't have access to it." (`move_project_column`) | "I can't find {name}, or you don't have access to it." |
| "The column or Project to move it into was not found or is not accessible." | "I can't find {destination}, or you don't have access to it." |
| "…is not a column or a Project…" | "{destination} is not a column or a project. Say which column, or which project." |
| "A column moves into a Project, not into another column." | "A column goes into a project, not into another column." |
| "This moves an item, not a Project." or "This moves a column, not a Project." | "Only a to-do or a column can be moved here, not a project." |
| "The item to place it after is not in …", "The column to place it after is not on …" or "… cannot be placed after itself." | Say it as returned: that one is not there (or is the one being placed). Nothing changed. |
| a move tool answers that the thing is a column, or is not a column, and names the other tool | Say it as returned. Nothing was moved; the tool comes from `project_columns` (a top-level row is a column, a row in `children` is an item). |
| a move answers "…is already …" | Say so. Nothing changed, and it is not an error. |
| any other `Error: …` | Show it as returned. |

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
