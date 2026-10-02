---
name: rkit:projects
description: List active projects for a team and manage project items. View project columns with item counts, add items to specific columns, and batch-add multiple items. Use this skill when users ask about projects, project boards, project columns, want to list team projects, add items to a project, or view project status.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Read, Glob, Grep, AskUserQuestion
---

# rkit:projects

List active projects for a team. Drill into a project to see its columns and add items. It drives the ResultKit connector's MCP tools, named below by base name (the full name is `mcp__<server>__<tool>`; the server alias varies by install). `scripts/api.sh` is used only for the jobs under **Fallback (api.sh)**.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh (Fallback only): !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/projects/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/projects/scripts/api.sh "$HOME/.claude/skills/rkit:projects/scripts/api.sh" "$HOME/.agents/skills/projects/scripts/api.sh" "$HOME/.gemini/skills/projects/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes.** Reads execute immediately. Before any write, summarize all planned changes in a single prompt and ask for confirmation. If the command implies multiple related mutations, batch them under one confirmation.
- **Show IDs.** Always include project and item IDs in output (this overrides the connector's general "never print raw ids" note).
- **Concise output.** Tables and short summaries. No filler.
- **Direct execution.** Call the connector tools directly. Fallback jobs use Bash with api.sh. Never use Task agents, never curl or hand-build a URL, and skip the connector's `guide` tool — the routing below is complete for this skill.
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
| any other `Error: …` | Show it as returned. |

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
