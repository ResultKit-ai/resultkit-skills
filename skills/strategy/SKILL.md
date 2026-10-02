---
name: rkit:strategy
description: View and manage your team's strategy tree (goals, rocks, objectives, key results, milestones, focus areas). Shows the hierarchical strategy for any management framework (EOS, OKR, 4DX). Supports creating, updating, aligning, and detaching strategy objects. Use when users mention strategy, goals, rocks, objectives, key results, OKRs, annual goals, quarterly priorities, focus areas, milestones, or strategy alignment.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Read, Glob, Grep, AskUserQuestion
---

# rkit:strategy

View and manage the team strategy tree. It drives the ResultKit connector's MCP tools, named below by base name: the full tool name is `mcp__<server>__<tool>` and the server alias varies by install, so match on the base name. The tree read and a few other jobs have no connector tool and run through `scripts/api.sh`; they are under **Fallback**.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- Today: !`date +%Y-%m-%d`
- api.sh (Fallback only): !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/strategy/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/strategy/scripts/api.sh "$HOME/.claude/skills/rkit:strategy/scripts/api.sh" "$HOME/.agents/skills/strategy/scripts/api.sh" "$HOME/.gemini/skills/strategy/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes.** Reads execute immediately. Create, update, align, detach, archive and comment require user confirmation before the call.
- **Show IDs.** Always include object IDs and object_types in output for follow-up reference.
- **Concise output.** Indented trees and short summaries. No filler prose.
- **Direct execution.** Call the connector tools directly (`scripts/api.sh` only for the Fallback jobs). Never use Task agents or subagents, never curl or hand-build a URL, and skip the connector's `guide` tool: the flows below are complete for this skill.
- **Framework-aware.** Use the team's `framework` field for terminology mapping (see Framework Label Mapping below).
- **Block inherited edits.** Nodes with `inherited: true` are read-only. Block create/update/align/detach on them with a clear message.

## Argument Parsing

| Input | Behavior |
|-------|----------|
| *(no args)* | View strategy tree for default team (current year/quarter) |
| `--year YYYY` or `--year All` | Filter by year (default: current year) |
| `--quarter N` or `--quarter All` | Filter by quarter (default: current quarter) |
| `--team {id}` | Use specified team instead of default |
| `create "NAME" [under "PARENT"] [due=YYYY-MM-DD] [status=...] [assignees=ID,...] [--focus-area]` | Create a new strategy object |
| `update "NAME" [name=...] [description=...] [status=...] [due=...] [assignees=ID,...]` | Update a strategy object |
| `align "NAME" under "PARENT"` | Link an object to a parent in the tree |
| `detach "NAME" from "PARENT" [--archive]` | Unlink an object from a parent |
| `comment "NAME" "text"` | Add a comment — **milestones only**, see Flow: Comment on a Strategy Object |
| `comments "NAME"` | List comments — **milestones only** |
| `edit comment {comment_id} "text"` | Edit my comment |
| `delete comment {comment_id}` | Delete my comment |

**Team ID.** `--team {id}` if given, else `default_team_id` from the config above, else the error "No default team configured. Run `/rkit:setup` first."

## Tools

| Job | Tool and arguments |
|---|---|
| Team name | `get_team`: `team_id`. Answers `# {name}`. |
| Create | `create_goal`: `team_id`, `name`, `achieve_by?`, `assignee_ids?`. `create_rock`: the same plus `parent_id?` (a goal). `create_milestone`: `team_id`, `name`, `due?`, `assignee_ids?`, `parent_id?` (a Rock). |
| Update | `update_goal` (`goal_id`), `update_rock` (`rock_id`), `update_milestone` (`milestone_id`), with only the changed fields: `name`, `description`, `assignee_ids`; goal and Rock `achieve_by`, `current_state`; Milestone `due`, `status`. |
| Align | `align_rock`: `rock_id`, `parent_id`. `align_milestone`: `milestone_id`, `parent_id`. |
| Unlink (Rock, Milestone) | `update_rock` / `update_milestone` with `parent_id` null. |
| Archive | `archive_goal` (`goal_id`), `archive_rock` (`rock_id`), `archive_milestone` (`milestone_id`). |
| Milestone comments | `add_item_comment`: `todo_or_issue` (the Milestone's id), `body`. `list_item_comments`: `todo_or_issue`. A Milestone is stored as an item, so its id works there. |

Argument names map: `due=` is `achieve_by` for a goal or Rock and `due` for a Milestone; `assignees=` is `assignee_ids`; `status=` is `current_state` on a goal or Rock (`complete` means `realized`; `active` reopens) and `status` on a Milestone (`complete` or `active`). A create has no status or focus-area argument, so `status=` and `--focus-area` are not sent.

## Fallback — still `scripts/api.sh`

The connector has no tool for these jobs, so they run as before: `RESPONSE=$("<api.sh path>" METHOD PATH [BODY])` returns `{status, body}`. Confirm writes first, as above.

| Job | Call |
|---|---|
| **Strategy tree** (the view, and every name lookup). The connector's `list_goals` and `list_rocks` are a different read: a team's own 1-Year Goals and Rocks (with Milestones; Rocks for one quarter), with no inherited nodes, no `inherited` or `can_edit` flags, no Objectives, key results or focus areas for other frameworks, and no `All`. | `GET /teams/$TEAM_ID/targets?year=$YEAR&quarter=$QUARTER` → `body.data.framework`, `.targets`, `.unaligned` |
| Unlink a 1-Year Goal (no connector tool) | `PATCH /goals/$OBJECT_ID` `{"parent_id":null}` |
| Edit comment | `PATCH /comments/$COMMENT_ID` `{"body":"NEW_TEXT"}` |
| Delete comment | `DELETE /comments/$COMMENT_ID` |

`YEAR` and `QUARTER` default to the current year and quarter (from Today); `--year All` / `--quarter All` pass through as the query values. Tree node fields: `id`, `name`, `status`, `object_type`, `due`, `assignees` (`first_name`, `last_name`), `children`, `inherited`, `inherited_from.team_name`, `can_edit`.

api.sh errors: `NO_CONFIG` "Config not found. Run `/rkit:setup` first."; `NO_TOKEN` "No API token. Run `/rkit:setup` to configure."; `CURL_FAILED` "Network error. Check your connection."; 401 "Unauthorized. Run `/rkit:setup` to update your token."; 403 "Not authorized for this team. Check your team membership."; 404 "Not found. Check the ID and try again."; 422 show the validation message from the body; other non-200 show the status code and the error message; path `NOT_FOUND` "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`".

---

## Object Name Resolution

Used by `create` (for the parent), `update`, `align`, `detach`, `comment`, `comments`. Fetch the tree once (Fallback read) and reuse it. Flatten every node of `targets` and `unaligned`, children included. Take the nodes whose `name` equals NAME ignoring case; if none, those whose `name` contains NAME ignoring case.

- **One match** → use it.
- **Several** → show the list and stop:
  ```
  Multiple objects match "NAME". Which did you mean?
  1. Annual Goal (yearly_goal #6520, active, due 2026-12-31)
  2. Another Goal (yearly_goal #9466, active, due 2025-12-31)
  ```
- **None** → "No strategy object found matching '{NAME}'." and stop.

## Framework Label Mapping

Map `object_type` to the team's `framework` column; null or unrecognized framework uses Fallback.

| object_type | EOS | OKR | 4DX | Fallback |
|-------------|-----|-----|-----|----------|
| `yearly_goal` | Yearly Goal | Yearly Goal | Yearly Goal | Yearly Goal |
| `objective` | Objective | Objective | WIG | Objective |
| `rock` | Rock | Rock | Battle | Rock |
| `focus_area` | Focus Area | Focus Area | Focus Area | Focus Area |
| `key_result` | Milestone | Key Result | Lead Measure | Key Result |
| `milestone` | Milestone | Milestone | Milestone | Milestone |
| `action` | Action | Action | Action | Action |

## Status Emoji Mapping

`active` 🟢 · `complete` ✅ · `archived` 📦 · `deferred` ⏸️ · `at_risk` 🟡 · `off_track` 🔴 · `draft` 📝 · `cancelled` ❌ · `review` 🔍 · other/null ⚪

## Flow: View Strategy Tree

Triggered when: no subcommand (no args, or only `--year`/`--quarter`/`--team`). Resolve the team ID, fetch the tree (Fallback read), and call `get_team` for the team name. Header:

```
Strategy for {TeamName} ({framework}) — {year} Q{quarter}
```

Render `targets` recursively, children indented 2 spaces per depth level:

```
{indent}{emoji} {FrameworkLabel}: {name} (#{id}, due {due}[, → {assignee_names}])[, inherited from {team_name}]
```

`{due}` is the due date or "no due date"; `{assignee_names}` are comma-separated `first_name last_initial.` (omit if empty). Inherited nodes append `[inherited from {inherited_from.team_name}]`. If `unaligned` is non-empty:

```

Unaligned:
  {emoji} {FrameworkLabel}: {name} (#{id}, due {due}[, → {assignees}])
```

Both empty: > No strategy objects found for {year} Q{quarter}. Use `/rkit:strategy create "Name"` to get started.

## Flow: Create Strategy Object

Triggered when: first arg is `create`. NAME is required ("Object name is required."); optional `under "PARENT"`, `due=`, `status=`, `assignees=`.

**Type** (EOS hierarchy goal → rock → milestone): no parent → goal (`create_goal`); parent is a `yearly_goal` → rock (`create_rock`, `parent_id`); parent is a `rock` → milestone (`create_milestone`, `parent_id`); the user can also say "create goal", "create rock" or "create milestone". Resolve a named parent (Object Name Resolution). Parent inherited → "Cannot create children under inherited node '{name}' — it belongs to {inherited_from.team_name}."

**Confirm:** > **Create {type}**: "{NAME}" {under "{PARENT}" (#{parent_id}) | at root level} in team {team_id}
> Fields: {due/achieve_by, status, assignees if set}

**Call** the create tool; omit unset fields (only `name` is required; `parent_id` aligns on creation, no second call). **Answer:** the new object, with its `id`: "Created: {NAME} ({type} #{id})." — `{type}` is `yearly_goal`, `rock` or `milestone`. "This endpoint requires an EOS team" → "Goal/rock/milestone management is only available for EOS teams. The strategy tree view (`/rkit:strategy` with no args) works for all frameworks." "Team not found or you don't have access to it." or "Access denied" → "You don't have permission to create strategy objects in this team."

## Flow: Update Strategy Object

Triggered when: first arg is `update`. Object name required, plus at least one of `name=`, `description=`, `status=`, `due=`, `assignees=`. Resolve the object; inherited → "Cannot update inherited node '{name}' — it belongs to {inherited_from.team_name}." Take `object_type` and `id`.

**Confirm:** > **Update** "{name}" ({object_type} #{id}): set {field=value list}

Assignees given: add "Assignees list will be replaced entirely." **Call** `update_goal` (`yearly_goal`), `update_rock` (`rock`) or `update_milestone` (`milestone`) with only the changed fields. **Answer:** "Updated: {name} ({object_type} #{id})." "Access denied" → "You don't have permission to update this object." "… not found" → "Strategy object not found." "This endpoint requires an EOS team" → the EOS message above.

## Flow: Align Strategy Object

Triggered when: first arg is `align`. Object name and `under "PARENT"` required, else "Usage: `/rkit:strategy align \"Object\" under \"Parent\"`". Resolve both; either inherited → error and stop. Valid: a `rock` under a `yearly_goal`, a `milestone` under a `rock`; else "Cannot align {object_type} under {parent_type}. Rocks align to goals, milestones align to rocks."

**Confirm:** > **Link** "{object_name}" ({object_type} #{object_id}) under "{parent_name}" (#{parent_id})?

**Call** `align_rock` or `align_milestone` (`parent_id`). **Answer:** "Linked: {object_name} now under {parent_name}." "Access denied" → "You don't have permission to link objects in this team." Not found and EOS messages as in Update.

## Flow: Detach / Archive Strategy Object

Triggered when: first arg is `detach`. Object name required, plus `from "PARENT"` (to unlink) and/or `--archive`; neither → "Usage: `/rkit:strategy detach \"Object\" from \"Parent\"` [--archive] or `/rkit:strategy detach \"Object\" --archive`". Resolve the object; inherited → "Cannot detach inherited node '{name}' — it belongs to {inherited_from.team_name}." Take `object_type` and `id`.

- **Without `--archive`** — confirm > **Unlink** "{object_name}" ({object_type} #{id}) from its parent? Object will be preserved (moved to unaligned). Call `update_rock` / `update_milestone` with `parent_id` null (a `yearly_goal`: the Fallback `PATCH`). Answer: "Unlinked: {object_name} moved to unaligned."
- **With `--archive`** — confirm > **Archive** "{object_name}" ({object_type} #{id})? Object will be archived permanently. Call `archive_goal` / `archive_rock` / `archive_milestone`. Answer: "Archived: {object_name} ({object_type} #{id})."

"Access denied" → "You don't have permission to modify objects in this team." "… not found" → "Strategy object not found." EOS message as above.

## Flow: Comment on a Strategy Object

Triggered when: first arg is `comment` or `comments`. **Comments only exist for milestones.** A yearly goal and a rock are Goal rows, not items, and the API has no comment route for them, so nothing here can be called on their behalf. Never call the comment tools with a goal or rock id: it would answer "not found", which reads as a bad ID rather than an unsupported action.

Resolve the object. `object_type` `milestone` → continue. `yearly_goal` or `rock` → stop and show: > Comments aren't supported for {FrameworkLabel} objects — only {milestone FrameworkLabel, e.g. "Milestone"/"Key Result"} objects carry comments. Rocks and goals are Goal objects in the API, not Items, and there is no comment endpoint for them.

- **Add** — comment text required (empty → "Comment text cannot be empty."). Confirm > Add comment to **{name}** (milestone #{id}): > "{text}" > > Proceed? Call `add_item_comment` (`todo_or_issue` = the Milestone id, `body`). The answer names the new comment id: "Comment added (ID: {id}) to {name}: \"{body}\"." with the text you sent. "A comment cannot be blank." → "Comment text cannot be empty."
- **List** — `list_item_comments`; answers JSON `{total, comments: [{id, body, author, created_at, updated_at}]}`. None → "No comments on {name}." Else a table of ID, Author, Comment, Time (strip HTML from `body`; append "(edited)" when `updated_at` is later than `created_at`).

"To-do or issue not found or you don't have access to it." → "Milestone {id} not found."

## Flow: Edit / Delete My Comment

Triggered when: first arg is `edit comment` or `delete comment`. Unscoped by object type — these act on a comment id directly. Both are Fallback.

**Edit** — confirm `Edit comment **{comment_id}** to: "{text}"?`, then `PATCH /comments/$COMMENT_ID`. 200 → "Comment **{comment_id}** updated." · 403 → "You can only edit your own comments." · 404 → "Comment {comment_id} not found." · 422 → "Comment text cannot be empty."

**Delete** — confirm `Delete comment **{comment_id}**? This cannot be undone.`, then `DELETE /comments/$COMMENT_ID`. 200 → "Comment **{comment_id}** deleted." · 403 → "You can only delete your own comments (a team admin can also delete any comment on this milestone)." · 404 → "Comment {comment_id} not found."

---

## Errors

| The tool answers | Say |
|---|---|
| tools missing, or an authorization error | "The ResultKit connector isn't connected. Connect it (https://mcp.resultkit.ai) and try again." |
| "Access denied" | The permission message of the flow above. |
| "Goal not found", "Rock not found", "Milestone not found" | "Strategy object not found." |
| "This endpoint requires an EOS team" | "Goal/rock/milestone management is only available for EOS teams. The strategy tree view (`/rkit:strategy` with no args) works for all frameworks." |
| any other `Error: …` | Show it as returned. |

## Edge Cases

- **No config**: "Config not found. Run `/rkit:setup` first."
- **No default_team_id and no --team**: Prompt user for team ID.
- **Unknown framework**: Use object_type as-is for labels (fallback column).

## References

- [ResultMaps V2 API Reference](references/api-reference.md) — payloads for the Fallback calls.
