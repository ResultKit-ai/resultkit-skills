---
name: rkit:result-update
description: Compose and submit your daily check-in — the 90-second update practice. Add and remove items in done/next/blocked sections, then submit to share with your team. Use this skill when users want to write their daily update, compose a check-in, add items to their update, submit their daily report, or share progress with the team.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Bash(date *), Read, Glob, Grep, AskUserQuestion
---

# rkit:result-update

A single skill that handles all result update composition operations by interpreting user intent against a tool routing table. It drives the ResultKit connector's MCP tools; `scripts/api.sh` is used only for the jobs under **Fallback**. Tools are named below by base name: the full name is `mcp__<server>__<tool>`, and the server alias varies by install.

## Current State

- Config (default team, Fallback): !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh (Fallback only): !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/result-update/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/result-update/scripts/api.sh "$HOME/.claude/skills/rkit:result-update/scripts/api.sh" "$HOME/.agents/skills/result-update/scripts/api.sh" "$HOME/.gemini/skills/result-update/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`
- Today: !`date +%Y-%m-%d`

## Rules

- **Interpret first, act second.** Read the user's message. Match it against the Tool Routing Table below. Pick the best match. If ambiguous, ask.
- **Confirm writes.** Reads execute immediately. For writes, summarize all planned changes in a single prompt and ask for confirmation. Batch related mutations under one confirmation.
- **Show IDs.** Always include item IDs in output.
- **Concise output.** Tables and short summaries. No filler.
- **Direct execution.** Call the connector tools directly. Never use Task agents, never curl or hand-build a URL, and skip the connector's `guide` tool — the routing below is complete for this skill.
- **Date argument.** For today, omit `date`. Pass `date` as `YYYY-MM-DD` only for another day.

---

## Tool Routing Table

Match the user's message against the **Triggers** column. Pick the first matching row.

| Triggers | Intent | Tool/Flow |
|---|---|---|
| "show my update", "my check-in", "90 seconds", "daily report", "what did I do", "show {date}", "check-in", "what did I get done", "my result update" | View my update for today or a date | `get_result_update` |
| "add done", "add next", "add blocked", "new done item", "create done", "add to done", "add to next", "add to blocked" | Create a new item in a section | `add_result_update_todo` (done, next) · `add_result_update_issue` (blocked) |
| "add item {id} to done", "put {id} in next", "attach {id} to blocked", "attach {id} to done", "move {id} to next" | Attach an existing item to a section by ID | `place_on_result_update` |
| "remove {id} from done", "take {id} off next", "drop {id} from blocked", "remove {id}" | Remove an item from a section | `remove_from_result_update` |
| "submit", "finalize", "done for the day", "submit check-in", "share check-in", "submit update", "send update" | Submit and share update | `submit_result_update` |
| "comment on {id}", "add a comment to {id}", "leave a note on {id}" | Add a comment to an item in my update | `add_item_comment` |
| "show comments on {id}", "what did people say on {id}" | List comments on an item in my update | `list_item_comments` |
| "edit comment {comment_id}", "update comment {comment_id}" | Edit my comment | Fallback: edit comment |
| "delete comment {comment_id}", "remove comment {comment_id}" | Delete my comment | Fallback: delete comment |

---

## View: `get_result_update`

Call `get_result_update` with no arguments for today, or with `date` for another day (never `team_id` or `user_id` here). Reading starts the day's update when there is none; that is expected. It answers JSON: `id`, `date`, `is_completed` and the sections `done`, `review`, `next`, `blocked`, each `{items, notes, attachments}`; every item has `id` and `name`. Show Done, Next and Blocked from each section's `items`.

- **All sections empty**: Display:
  > ## My Update — {date_label}
  >
  > Status: Not submitted
  >
  > Nothing yet. Use `add done "action item name"` to add one.

- **Items present**: Display as:

  ```
  ## My Update — {date_label}

  Status: {Submitted ✓ | Not submitted}

  ### Done
  | # | ID | Name |
  |---|---|---|
  | 1 | 415 | Write proposal |

  ### Next
  | # | ID | Name |
  |---|---|---|
  | 1 | 420 | Review PR |

  ### Blocked
  No items.

  **{total} items** — {done_count} done, {next_count} next, {blocked_count} blocked
  ```

  - `date_label`: "Today" when `date` was omitted, or the formatted date
  - `Status`: "Submitted ✓" if `is_completed` is true, "Not submitted" if false
  - Empty sections show "No items."
  - Summary line counts items across all sections

## Writes

Confirm first, then call the tool. After create, attach or remove, re-read with `get_result_update` and show the updated update (same date). Pass `date` only for another day.

| Flow | Tool and arguments | Confirm | On success |
|---|---|---|---|
| create | `add_result_update_todo`: `section` (`done` or `next`), `name` · for blocked, `add_result_update_issue`: `name` | Create item "**{name}**" in **{section}** section? | Created item **{id}**: "{name}" in {section} (the answer is the new item: take its `id`) |
| attach | `place_on_result_update`: `section`, `item_id` | Add item **{id}** to **{section}** section? | Item **{id}** added to {section}. An item already in the section is fine (idempotent). |
| remove | `remove_from_result_update`: `section`, `item_id` | Remove item **{id}** from **{section}**? (Item will not be deleted.) | Item **{id}** removed from {section}. |
| submit | `submit_result_update`: `team_id` | Submit update for **{date_label}** and share with team "**{team_name}**" (ID: {team_id})? | Update submitted and shared with **{team_name}**. The answer is the updated update: show it as in the view, with no second read. Re-submitting is fine (idempotent). |
| comment | `add_item_comment`: `todo_or_issue` = ID, `body` | Add comment to item **{id}**: "{text}" Proceed? | Comment added (ID: {comment_id}) to item **{item_id}**: "{text}" (the answer reads "Comment N added to …": take N) |

**Submit — team.** Use the team ID the user gave; else `default_team_id` from Current State's config; else ask "No default team configured. Which team ID should this be shared with?" (`list_teams` lists the teams and their IDs). Before the confirmation, read the team's name with `get_team` (`team_id`): its answer opens with `# {team_name}`.

**Comments.** Items in your Done/Next/Blocked sections are ordinary items: comments go straight to the item, not to the check-in report. `list_item_comments` (`todo_or_issue` = ID) answers JSON `{todo_or_issue, page, per_page, total, comments}`, each comment `{id, body, author, created_at, updated_at}`. None: "No comments on item {id}." Otherwise show the table below (Author = `author.first_name` `author.last_name`), strip HTML from `body`, and append `(edited)` after the time when `updated_at` is later than `created_at`:

```
| ID | Author | Comment | Time |
|----|--------|---------|------|
| 9001 | Sarah Lee | Talked to the vendor. | 2026-03-07 14:02 |
```

## Fallback (api.sh)

The connector has no tool to edit or delete a comment, so these two run as before: `RESPONSE=$("<api.sh path>" METHOD PATH [BODY])` returns `{status, body}`. Confirm first, as above.

| Job | Confirm, then call | Answers |
|---|---|---|
| Edit comment | Edit comment **{comment_id}** to: "{text}"? → `PATCH /comments/COMMENT_ID` `{"body":"NEW_TEXT"}` (escape any double quotes in NEW_TEXT) | 200 "Comment **{comment_id}** updated." · 403 "You can only edit your own comments." · 404 "Comment {comment_id} not found." · 422 "Comment text cannot be empty." |
| Delete comment | Delete comment **{comment_id}**? This cannot be undone. → `DELETE /comments/COMMENT_ID` | 200 "Comment **{comment_id}** deleted." · 403 "You can only delete your own comments (a team admin can also delete any comment on this item)." · 404 "Comment {comment_id} not found." |

api.sh errors: `NO_CONFIG` "Config not found. Run `/rkit:setup` first."; `NO_TOKEN` "No API token. Run `/rkit:setup` to configure."; `CURL_FAILED` "Network error. Check your connection."; 401 "Unauthorized. Run `/rkit:setup` to update your token."; any other non-200 shows the status code and error message; path `NOT_FOUND` "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`".

## How to Interpret

1. Look for trigger phrases in the table. Extract an **item ID** (integer: "415", "item 415", "#415"), a **date**, a **name** (quoted text, or text after "add done"/"add next"/"add blocked") and a **section**.
2. An ID with "add"/"attach"/"put" means attach; a name or text means create. With no clear write intent, view the update. If ambiguous, ask: "Did you mean to [option A] or [option B]?"
3. **Dates:** nothing or "today" = omit `date`. "tomorrow", "yesterday", "Monday", "next Tuesday", "Feb 20", "2026-02-20" = that day as `YYYY-MM-DD`, resolved from Today above.
4. **Sections:** "done", "completed", "finished" → `done`; "next", "up next", "planned" → `next`; "blocked", "issues", "blockers", "stuck" → `blocked`. If the section is unclear when creating, ask: "Which section — done, next, or blocked?"

## Errors

| The tool answers | Say |
|---|---|
| tools missing, or an authorization error | "The ResultKit connector isn't connected. Connect it (https://mcp.resultkit.ai) and try again." |
| "Invalid date format…" | "Invalid date format. Use YYYY-MM-DD or 'today'." |
| "Unsupported section…" | "Invalid section. Use: done, next, or blocked." |
| "To-do or issue not found or you don't have access to it." | On attach: "Item {id} not found or not viewable." On comments: "Item {id} not found." |
| "…is not in the {section} section." | "Item {id} not found in {section} section." |
| "Team not found or you don't have access to it." | "Team not found." |
| "Done section must have at least one item" or "Next section must have at least one item" | Show it as returned (Done and Next must each hold at least one item). |
| "A comment cannot be blank." | "Comment text cannot be empty." |
| any other `Error: …` | Show it as returned. |

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
