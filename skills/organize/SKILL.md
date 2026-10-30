---
name: rkit:organize
description: Organize a string of to-dos from a Level 10 / Weekly board, a 1-on-1, a day plan or My Work into a project's columns without taking them off the surface they live on. Snapshots first, creates missing columns, places items one at a time, verifies, and can optionally take them off the source at the end. Use this skill whenever users want to sort, file, bucket, group, align or "put these to-dos under" a project's columns, organize the Level 10 into a project board, or tidy a pile of to-dos into columns while keeping them on the Level 10, 1-on-1 or day plan.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Bash(mkdir *), Read, Write, Glob, Grep, AskUserQuestion
---

# rkit:organize

Put a string of to-dos into a project's columns while they stay where they live. Reads and the common writes use the ResultKit connector's MCP tools, named below by base name (the full name is `mcp__<server>__<tool>`; the server alias varies by install). `scripts/api.sh` runs the jobs under **Fallback (api.sh)**.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh (Fallback only): !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/organize/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/organize/scripts/api.sh "$HOME/.claude/skills/rkit:organize/scripts/api.sh" "$HOME/.agents/skills/organize/scripts/api.sh" "$HOME/.gemini/skills/organize/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## How placement works (read before any write)

These are verified facts about the API. They are why this skill is safe, so do not soften them.

- An item has **one parent** (`parent_id`). "Putting an item in a project column" means setting its parent to the column item. Legacy Rails called this "align to parent"; in the V2 API it is `PUT /items/{id}/move` with `{parent_id}`.
- **Level 10 / Weekly board** membership is `group_id` + `is_wow` (the API's `on_weekly`) + status + the name hashtag (`#next` / `#parkinglot`). The parent is never read, so moving an item under a column never moves it on or off a Level 10.
- **Day plan** membership is a `day_plan_actions` row; **1-on-1** membership is a `work_session_alignments` row. Neither reads the parent.
- The project board, the columns read, project stats and the roadmap all read children by `parent_id`.
- `PUT /teams/{id}/projects/{item_id}` converts any item into a team project in place and keeps its own parent, so an item can be a child of a roadmap column and a project at the same time.

**Never use**, even if they look like the obvious tool: `PATCH /items/bulk-move` (documented as removing items from weekly boards), `POST /items/{id}/align` (writes a row no view reads), `POST /items/{id}/move-to-long-term-issues`, `place-on-weekly`, and any status change (`mark_done`, `move_on_L10`, `update_item` with `status`). Each either takes items off their surface or changes what the user has not asked to change.

## Rules

- **Snapshot before any write.** Write the restore list first, show it, and wait for confirmation. Keep the restore list and move log as files the user names (default: `./organize-<project_id>-<date>/`, files `restore-list.md` and `move-log.md`).
- **Confirm writes.** Reads run immediately. Before each write phase (create columns, convert to project, place, leave), summarize the whole phase in one prompt and wait.
- **Show IDs.** Item, column and project IDs in every table (this overrides the connector's general "never print raw ids" note).
- **One call per item, sequential.** Never bulk-move. Append to the move log after every call, so a stopped run can resume and be undone.
- **Concise output.** Tables and short summaries.
- **Direct execution.** Call connector tools directly; fallback jobs use Bash with api.sh. No Task agents, no curl, no hand-built URLs, and skip the connector's `guide` tool.

## Argument Parsing

| Input | Behavior |
|-------|----------|
| `l10 into {project_id}` | Source = the default team's Level 10 / Weekly board (`--team {id}` overrides) |
| `1on1 {meeting_id} into {project_id}` | Source = a 1-on-1 |
| `day [YYYY-MM-DD] into {project_id}` | Source = a day plan (default today) |
| `mywork into {project_id}` | Source = My Work |
| `--label NAME`, `--hashtag TAG`, `--parent {id}`, `--match REGEX` *(repeatable, ANDed)* | Pick candidate items: by label, hashtag in the name, current parent, or a regex over the description (and name) |
| `--map "regex=Column name"` *(repeatable)* | Target column for items whose description/name matches the regex |
| `--dir PATH` | Where the restore list and move log go |
| `--leave` | Run the optional last step (take items off the source) |

Missing source or project → ask. Team ID: `--team`, else `default_team_id` from Current State, else "No default team configured. Run `/rkit:setup`." Level 10 sources need an EOS team: call `get_team` first and stop on a non-EOS framework with "Level 10 is EOS only; use `/rkit:weekly`."

## Flow 1: Snapshot

Read the source surface and the candidate items. The connector's Level 10 rows carry only `id`, `name`, `status`, `due`, `assignees`, `creator`; the snapshot needs `parent_id`, labels and descriptions to filter and to record "parent before", so **read candidates with api.sh** (the full Item shape: `parent_id`, `description`, `custom_labels`, `on_weekly`). Use the connector tools only for the section counts check.

| Source | Connector (counts / quick look) | Fallback read (full Item rows, paginate with `page` until `meta.total_pages`) |
|---|---|---|
| Level 10 | `L10_todos_issues` (`team_id`), `list_L10_section` (`team_id`, `section` = `todos`, `done`, `issues`, `parked`) | `GET /teams/TEAM_ID/l10/todos?all=true&per_page=100&page=N`, and `/l10/done`, `/l10/issues`, `/l10/parked`. `all=true` is documented for `todos` and `done`; `issues` and `parked` take no `all` (no time filter) |
| 1-on-1 | `get_1on1` (`meeting_id`) answers `items: {next, done, issues}` | `GET /1-on-1/MEETING_ID/items?per_page=100&page=N` (`status` = `active`, `realized`, `blocked`; omit for all) |
| Day plan | `sequence` (`date?`): names only, no IDs | `GET /day-plans/DATE/items?per_page=100&page=N` (`DATE` = `today` or `YYYY-MM-DD`); rows carry `day_plan_action_id` |
| My Work | none documented in this skill | `GET /items?per_page=100&page=N` (params: `status`, `team_id`, `q`, `include_archived`); `GET /teams/TEAM_ID/open-work` for the Team tab, `GET /users/me/assigned-to-me` for Assigned to Me |

The API reference documents no filter by label or description on these reads, so apply the filters (`--label`, `--hashtag`, `--parent`, `--match`) yourself over the rows with `jq`.

1. Read every section of the source (so the baseline covers the whole surface, not only the candidates). Record per-section counts.
2. Filter to candidates. Assign each to a target column by `--map` rules, or propose a mapping and ask.
3. Write `restore-list.md`: one row per candidate with `id | section | parent_id before | target column | name`. Write the baseline counts at the top.
4. Show: counts per target column, then the **unmapped items** with a proposed column for each. Also flag candidates that already sit under a column of the target project.
5. **Stop and confirm** (Constitution IV). Nothing is written to ResultKit yet.

## Flow 2: Columns

1. Read the target. Connector `project_columns` (`project_id`) answers JSON `{items, page, perPage, total}`; `items` are the columns. No columns → either the project is flat or the item is not a project yet.
2. Not a project yet → offer `PUT /teams/TEAM_ID/projects/ITEM_ID` (Fallback; idempotent; sets type to project and assigns the team, keeps the item's own parent). Confirm first.
3. Create each missing column: `POST /projects/PROJECT_ID/columns` `{"name": "..."}` (Fallback; the connector has no create-column tool; returns 201 with the column and its `id`). Confirm the full list of names first, then one call per column.
4. Re-read `project_columns` and add the column IDs to the restore list.

## Flow 3: Place

1. **Test on one item.** Confirm, then `PUT /items/ITEM_ID/move` with `{"parent_id": COLUMN_ID}` (Fallback). Re-read the source surface (Flow 1 read for that section, or `get_1on1` / `sequence`) and confirm the item is **still there**, in the same section. If it is gone or changed, stop, report, and do not continue.
2. Append the call to `move-log.md`: `id | column | column id | parent before | result`.
3. After the test passes, confirm once for the rest, then loop sequentially, one `PUT /items/ITEM_ID/move` per item, appending to the log after each. Do not send `left_id`, `right_id`, `position` or `group_by`: only `parent_id`.
4. A non-200 on an item: log it, keep going, list failures at the end. 403 "no access" and 404 "not found" are per-item facts, not reasons to stop; two failures in a row with the same error → stop and ask.
5. Per-item rules: a column's Process Rules fire when `parent_id` changes (failures are logged, not blocking). Newly created columns have none; if the target project has rule-bearing columns, say so before the loop.

## Flow 4: Verify

1. Re-read the source surface. The item set and per-section counts must equal the Flow 1 baseline. Report any difference by ID.
2. Connector `project_columns` (`project_id`), or `GET /projects/PROJECT_ID/columns` (each column carries `items[]`): every candidate appears **once**, in its mapped column; none missing, none extra.
3. Report: "Verified: {n} items, {c} columns, source unchanged." or the exact differences.

## Flow 5: Leave the surface (optional, off by default)

Only when the user asks (`--leave` or says so). Confirm the exact list first; one item at a time, logged. This is the only step that changes what is on the surface; it keeps the item and its column.

| Source | Connector | Fallback |
|---|---|---|
| Level 10 | `remove_from_L10`: `team_id`, `todo_or_issue` | `DELETE /teams/TEAM_ID/l10/items/ITEM_ID` (sets `on_weekly` false, keeps the item) |
| Day plan | `remove_from_work_plan`: `todo`, `date?` | `DELETE /day-plans/DATE/items/ITEM_ID` (keeps the item) |
| 1-on-1 | `remove_from_1on1`: `meeting_id`, `todo_or_issue` | `DELETE /1-on-1/MEETING_ID/items/ITEM_ID` (keeps the item; same as `POST /1-on-1/{id}/unalign` with `alignable_type: "Item"`) |
| My Work | none | Not applicable: My Work is a view of assignments, and the API reference documents no "remove from My Work" call. Say so and stop. |

Re-read the source afterward and confirm only the intended items left.

## Edge Cases

- **Already under a column of this project:** skip it and note "already placed" (a move to the current parent is harmless but pointless).
- **Candidate is itself a project, or has children:** it moves as one unit under the column; tell the user before moving.
- **Already a child of another project or a roadmap column:** moving replaces that parent. The restore list holds the old `parent_id`; surface these in the Flow 1 summary.
- **Unmapped items:** never guessed. List them with a proposed column and wait.
- **More than one page:** paginate every read; a snapshot from page 1 is not a snapshot.
- **Resume:** if `restore-list.md` and `move-log.md` exist at the path, read them, skip logged successes, and continue at Flow 3.
- **Undo:** for each logged move, `PUT /items/ITEM_ID/move` with `{"parent_id": <parent before>}` (or `null` for no parent); confirm first, same one-at-a-time loop.
- **Reads the API reference does not document:** no read spans several day plans or several 1-on-1s at once, and My Work has no connector read in this skill. Read one date or one meeting at a time; do not invent a path.

## Fallback (api.sh)

`RESPONSE=$("<api.sh path>" METHOD PATH [BODY])` returns `{status, body}`; escape double quotes in JSON bodies. Confirm writes first, as above.

api.sh errors: `NO_CONFIG` or `NO_TOKEN` "Config not found. Run `/rkit:setup` first."; `CURL_FAILED` "Network error. Check your connection."; 401 "Unauthorized (401). Run `/rkit:setup` to update your token."; 403 "No access to that item or project."; 404 "Not found (404)."; 422 show the validation error body; path `NOT_FOUND` "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`". Connector tools missing or an authorization error: "The ResultKit connector isn't connected. Connect it (https://mcp.resultkit.ai) and try again."

## References

- [ResultMaps V2 API Reference](references/api-reference.md) — Items (move), Team Projects, Project Columns, EOS Level 10, Day Plans, One-on-Ones
