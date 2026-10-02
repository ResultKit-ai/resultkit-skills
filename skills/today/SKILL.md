---
name: rkit:today
description: View and manage today's day plan — the committed list on your Personal Planner (also called the Prioritizer), what you've decided to do. Interprets user intent and routes to the correct API action. Use this skill when users mention their day plan, daily tasks, personal planner, prioritizer, today's items, checking off tasks, adding tasks to today, or want to manage what they're working on today or any specific date.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Bash(date *), Read, Glob, Grep, AskUserQuestion
---

# rkit:today

A single skill that handles all day plan operations by interpreting user intent against a tool routing table. It drives the ResultKit connector's MCP tools; `scripts/api.sh` is used only for the jobs under **Fallback**.

## Current State

- Today: !`date +%Y-%m-%d`
- api.sh (Fallback only): !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/today/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/today/scripts/api.sh "$HOME/.claude/skills/rkit:today/scripts/api.sh" "$HOME/.agents/skills/today/scripts/api.sh" "$HOME/.gemini/skills/today/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Interpret first, act second.** Match the user's message against the routing table below. Pick the best match. If ambiguous, ask: "Did you mean to [option A] or [option B]?"
- **Confirm writes.** Reads execute immediately. For writes, summarize all planned changes in a single prompt and ask for confirmation. Batch related mutations under one confirmation.
- **Concise output.** Tables and short summaries. No filler.
- **Direct execution.** Call the connector tools directly. Never use Task agents, never curl or hand-build a URL, and skip the connector's `guide` tool — the routing below is complete for this skill.
- **Date argument.** For today, omit `date` (today's plan is created on demand and recurring to-dos are filled in). Pass `date` as `YYYY-MM-DD` only for another day — never today's date.
- **IDs.** `sequence` returns no IDs, so views have no ID column. If the user asks for IDs, or names an item without giving its ID, use the Fallback plan read.

---

## Tool Routing Table

Match the user's message against the **Triggers** column. Pick the first matching row.

| Triggers | Intent | Tool/Flow |
|---|---|---|
| "show must items", "show priority only", "must priority only", "hide deferred", "not deferred and completed" | View a filtered plan | Fallback: filtered plan |
| "show my day", "what's on today", "daily plan", "day plan", "what do I have today", "show today", "my plan", "today's items", "what's planned", "show {date}", "prioritizer", "tasks for today", "hide done", "hide completed" | View day plan items with completion status | `sequence` |
| "add to today", "create a task", "new item", "add to my plan", "add to plan", "plan this for", "add to tomorrow", "put on my day", "add a to-do", "create to-do" | Create a new item on a day plan | `add_to_work_plan` |
| "attach to today", "put {id} on today", "add item {id}", "attach {id}", "move {id} to today", "add existing", "put {id} on my plan" | Attach an existing item to a day plan by ID | `attach_to_work_plan` |
| "mark done for today", "complete for today" | Check off one day's entry only | Fallback: one-day check-off |
| "mark done", "check off", "complete", "finish {id}", "done {id}" | Mark an item complete | `mark_done` |
| "undo {id}", "uncheck", "mark incomplete", "uncomplete" | Undo a completed item | `update_item` |
| "remove from today", "take off my plan", "remove {id}", "don't need this today", "skip this", "drop from plan", "remove from tomorrow" | Remove an item from a day plan | `remove_from_work_plan` |
| "comment on {id}", "add a comment to {id}", "leave a note on {id}", "leave a note on that to-do" | Add a comment to an item | `add_item_comment` |
| "show comments on {id}", "what did people say on {id}", "read the notes on {id}" | List comments on an item | `list_item_comments` |
| "edit comment {comment_id}", "update comment {comment_id}", "fix my comment {comment_id}" | Edit my comment | Fallback: edit comment |
| "delete comment {comment_id}", "remove comment {comment_id}" | Delete my comment | Fallback: delete comment |

---

## View: `sequence`

Call `sequence` (add `date` only for another day). It answers text: `Day plan for DATE (done/total completed):`, then one `- [ ] name` or `- [x] name` line per entry in plan order. For "hide done" / "hide completed", drop the `[x]` lines. A date with no plan answers "No day plan found for this date."; an empty plan answers "Your day plan for DATE is empty."

```
## Day Plan — {date_label}

| # | Name | Done |
|---|---|---|
| 1 | Write proposal | |
| 2 | Fix login bug | yes |

**{total} items** — {remaining} remaining
```

- `#` = row order. `Done` = "yes" for `[x]`, blank for `[ ]`. `remaining` = count of `[ ]` lines. `date_label` = "Today" when `date` was omitted, else the formatted date.
- Empty plan: "Nothing on today's plan yet. Use `add "action item name"` to add one." (`{date}'s` for another day).
- No plan for the date: "No plan exists for {date}."

## Writes

Confirm first, then call the tool. After create, attach, complete, undo or remove, show the updated plan (`sequence`, same date). Pass `date` only for another day.

| Flow | Tool and arguments | Confirm | On success |
|---|---|---|---|
| create | `add_to_work_plan`: `name`, `date?` | Create item "**{name}**" on {date_label}'s plan? | Created item **{id}**: "{name}" (the answer carries the new id) |
| attach | `attach_to_work_plan`: `todo` = ID, `date?` | Attach item **{id}** to {date_label}'s plan? | Item **{id}** attached to {date_label}'s plan. An "already in" answer means it is on the plan: say so, not an error. |
| complete | `mark_done`: `todo_or_issue` = ID | Mark item **{id}** as complete? | Item **{id}** marked complete. |
| undo | `update_item`: `todo_or_issue` = ID, `status` = `not_started` | Mark item **{id}** as incomplete? | Item **{id}** marked incomplete. |
| remove | `remove_from_work_plan`: `todo` = ID, `date?` | Remove item **{id}** from {date_label}'s plan? (Item will still exist in your items.) | Item **{id}** removed from {date_label}'s plan. |
| comment | `add_item_comment`: `todo_or_issue` = ID, `body` | Add comment to item **{id}**: "{text}" Proceed? | Comment added (ID: {comment_id}) to item **{id}**: "{text}" |

`list_item_comments` (`todo_or_issue` = ID) answers JSON `{total, comments: [{id, body, author, created_at, updated_at}]}`. Show `| ID | Author | Comment | Time |`, strip HTML from `body`, add `(edited)` when `updated_at` is later than `created_at`. None: "No comments on item {id}."

## Fallback — still `scripts/api.sh`

The connector has no tool for these jobs, so they run as before: `RESPONSE=$("<api.sh path>" METHOD PATH [BODY])` returns `{status, body}`. `DATE_SEGMENT` is `today` or `YYYY-MM-DD`. Confirm writes first, as above.

| Job | Call |
|---|---|
| Plan with IDs, status and position (also to find an item the user named without an ID) | `GET /day-plans/DATE_SEGMENT/items`, items in `body.data`. Table columns `#`, `ID`, `Name`, `Status`, `Done` from `position`, `id`, `name`, `status`, `completed`. |
| Filtered plan | `GET /day-plans/DATE_SEGMENT?show=must` or `?show=not%20deferred%20and%20completed`, items in `body.data.items` |
| One-day check-off (a #daily to-do stays open; `mark_done` completes it everywhere) | `PATCH /day-plans/DATE_SEGMENT/items/ITEM_ID` `{"completed":true}` |
| Edit comment | `PATCH /comments/COMMENT_ID` `{"body":"NEW_TEXT"}`; 403 "You can only edit your own comments." |
| Delete comment | `DELETE /comments/COMMENT_ID`; 403 "You can only delete your own comments (a team admin can also delete any comment on this item)." |

api.sh errors: `NO_CONFIG` or `NO_TOKEN` "Config not found. Run `/rkit:setup` first."; `CURL_FAILED` "Network error. Check your connection."; 401 "Unauthorized (401). Run `/rkit:setup` to update your token."; path `NOT_FOUND` "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`".

## How to Interpret

1. Look for trigger phrases in the table. Extract an **item ID** (integer: "415", "item 415", "#415"), a **date** (convert to `YYYY-MM-DD` using Today above), a **name** (quoted text, or text after "add"/"create") and a **completion intent** ("done", "undo", "check", "uncheck").
2. An ID with "add"/"attach"/"put" means attach; a name means create. With no clear write intent, view the plan.
3. **Dates:** nothing or "today" = omit `date`. "tomorrow", "yesterday", "Monday", "next Tuesday", "Feb 20" = that day as `YYYY-MM-DD`.

## Errors

| The tool answers | Say |
|---|---|
| tools missing, or an authorization error | "The ResultKit connector isn't connected. Connect it (https://mcp.resultkit.ai) and try again." |
| "No day plan found…", "Day plan not found" | "No plan exists for {date}." Only today's plan is created on demand. |
| "Item not in…" | "Item {id} not found on {date_label}'s plan." |
| "…not found or you don't have access…", "Item not found" | "Item {id} not found." |
| "Invalid date…" | Say the date is not a real day and ask for another. |
| "A comment cannot be blank." | "Comment text cannot be empty." |
| any other `Error: …` | Show it as returned. |
