---
name: rkit:result-feed
description: View and interact with team daily check-ins (result feeds). Shows what teammates got done, what's next, and what's blocking them. Supports reactions (high-five), comments, section notes, and team member detail views. Use this skill when users want to see team updates, daily check-ins, team progress, react to check-ins, comment, or manage section notes.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Bash(date *), Read, Glob, Grep, AskUserQuestion
---

# rkit:result-feed

A single skill that handles all result-feed operations by interpreting user intent against a tool routing table. It drives the ResultKit connector's MCP tools; `scripts/api.sh` is used only for the jobs under **Fallback**. Tools are named below by base name: the full name is `mcp__<server>__<tool>`, and the server alias varies by install.

## Current State

- Config (default team, Fallback): !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh (Fallback only): !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/result-feed/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/result-feed/scripts/api.sh "$HOME/.claude/skills/rkit:result-feed/scripts/api.sh" "$HOME/.agents/skills/result-feed/scripts/api.sh" "$HOME/.gemini/skills/result-feed/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`
- Today: !`date +%Y-%m-%d`

## Rules

- **Interpret first, act second.** Read the user's message. Match it against the Tool Routing Table below. Pick the best match. If ambiguous, ask.
- **Confirm writes.** Reads execute immediately. For writes, summarize all planned changes in a single prompt and ask for confirmation. Batch related mutations under one confirmation.
- **Show IDs.** Always include item IDs in output.
- **Concise output.** Tables and short summaries. No filler.
- **Direct execution.** Call the connector tools directly. Never use Task agents, never curl or hand-build a URL, and skip the connector's `guide` tool — the routing below is complete for this skill.

---

## Tool Routing Table

Match the user's message against the **Triggers** column. Pick the first matching row.

| Triggers | Intent | Tool/Flow |
|---|---|---|
| "team check-ins", "team feed", "show check-ins", "what did the team do", "team updates", "team result feed", *(no args)* | View team's shared check-ins | `list_result_updates` |
| "show {user}'s check-in", "view {user}'s report", "team member report", "what did {user} do", "check-in for user {id}" | View a specific team member's report | `get_result_update` |
| "add notes", "update notes", "set notes on done", "set notes on next", "set notes on blocked", "edit section notes", "attach files", "add attachment", "clear notes" | Update section notes/attachments | `place_on_result_update` |
| "high-five", "react", "high five {user}", "give kudos", "🙏", "toggle reaction" | React (high-five) to a check-in | Fallback: react |
| "show reactions", "reaction count", "did I react", "high-five count", "how many reactions" | View reaction state without toggling | Fallback: view reactions |
| "show comments", "read comments", "comments on check-in", "comments on {date}" | List comments on a check-in | `list_result_update_comments` |
| "upload file", "attach file", "upload attachment" | Upload a file attachment to a check-in | `add_result_update_attachment` |
| "comment on check-in", "add comment", "reply to {user}", "leave a comment" | Add a comment to a check-in | `add_result_update_comment` |
| "set team context", "switch team", "share to team {id}", "set group context" | Set active group context | Fallback: team context |

---

## Common Resolution

**Team ID.** 1. `--team {id}` flag in args → that team. 2. `default_team_id` in config (Current State) → that team. 3. Neither → "No default team configured. Run `/rkit:setup` first." (or name a team: `list_teams` lists the teams and their IDs).

**Date.** Nothing or "today" → omit `date`: every own-check-in tool defaults to today in the user's timezone. "tomorrow", "yesterday", "2026-04-27", "Apr 27" → that day as `YYYY-MM-DD`, resolved from Today above. Exception: `get_result_update` with `team_id` takes only a literal `YYYY-MM-DD` — for today pass Today above, never "today".

**The user's own ID.** The connector has no "who am I" read. When a tool needs the user's own numeric ID, use one already known in this conversation; else read it with `GET /users/me` through api.sh and take only `body.data.id` (that answer also carries `api_token`: never print it); if api.sh is unavailable, ask. Never guess. A teammate's ID is in `get_team`'s member list (`Name (user_id: N, role)`).

---

## View team feeds: `list_result_updates`

Resolve the team (Team ID). Call `list_result_updates`: `team_id`, `page?`, `per_page?`. It answers JSON `{page, per_page, total, result_updates}`, newest date first; each entry has `date`, `user` (`login`, `first_name`, `last_name`) and the sections `done`, `review`, `next`, `blocked`, each `{items, notes, attachments}`.

- **Empty list**: Display:
  > No shared check-ins found for this team.

- **Feeds present**: For each entry, display:

  ```
  ### {first_name} {last_name} (@{login}) — {date}

  **Done**
  - [{id}] {name}
  > Notes: {done.notes}                              ← only when notes non-null
  > Attachments: file.pdf (application/pdf, 42 KB)   ← only when attachments non-empty

  **Review**
  - [{id}] {name}                                    ← only when review.items non-empty

  **Next**
  - [{id}] {name}

  **Blocked**
  - [{id}] {name}
  ```

  **Section rendering rules** (IMPORTANT — sections are objects, not arrays):
  - Items: read from `section.items` (array), NOT directly from the section. Display each as `- [{id}] {name}`.
  - Notes: if `section.notes` is non-null and non-empty, display `> Notes: {section.notes}` after the items. Omit if null or empty.
  - Attachments: if `section.attachments` is non-empty, display `> Attachments: filename1 (content_type, size), filename2 (content_type, size)`. Show size human-readable: < 1024 → "N B"; < 1048576 → "N KB"; else → "N MB". Omit if empty array.
  - Empty sections (no items, no notes, no attachments): show "None."
  - Section order: Done → Review → Next → Blocked.

  After all feeds, show pagination summary (`total_pages` = `total` ÷ `per_page`, rounded up; the answer carries no `total_pages`):
  > Page {page}/{total_pages} — {total} check-ins

## View a team member's report: `get_result_update` with `team_id`

Resolve `team_id` (Team ID), `date` (Date; default today, as a literal `YYYY-MM-DD`) and `user_id`: an explicit ID from the args ("user 7", "user_id 7"); for "{user}'s check-in" by name, find the ID in `get_team`'s member list. Call `get_result_update` with `team_id`, `user_id`, `date`. It answers one flat report: `id`, `date`, `is_completed`, the four sections, plus `user`, `shared_team_id` and `shared_item_ids`. Display it with the feed's header and Section rendering rules — all four sections in order: Done, Review, Next, Blocked.

## Update section notes/attachments: `place_on_result_update`

Sets notes and/or attachments on one section (`done`, `review`, `next`, `blocked`) of the user's own update. This is the only tool that sets them, and it always places an existing to-do or issue in that section: `section`, `item_id`, `date?`, `notes?` (plain text), `attachment_ids?` (IDs from `add_result_update_attachment`). Ask for the item ID when the user named none (`get_result_update` shows what is in the section). Cautions: placing re-applies the section's status to that item (done = marks it complete), and notes and attachments are replaced together — read the section first and resend whatever the user did not change. To clear notes, send the section's current `attachment_ids` and no `notes` (a call with neither does nothing).

Confirm first:
> Update **{section}** section for {date}:
> - Item: {item_id}
> - Notes: "{notes}" (or "clear", or "unchanged")
> - Attachment IDs: [{ids}] (or "unchanged")
>
> Proceed?

On success: "Section **{section}** updated."

## Comments and attachments

- **List — `list_result_update_comments`**: `user_id` (required: whose check-in; see The user's own ID), `date?`. It answers a JSON list, oldest first: each comment `id`, `comment`, `user_id`, `created_at`. On someone else's check-in only the comments you wrote come back. Empty: "No comments on this check-in." Otherwise display (use the `comment` field, not `body`):

  ```
  ## Comments — {date}

  | # | ID | User | Comment | Time |
  |---|---|---|---|---|
  | 1 | 12 | User 7 | Nice work! | 2026-04-26 14:00 |
  ```

- **Add — `add_result_update_comment`**: `body`, `date?`, `user_id?` (whose check-in; the user's own when omitted). Confirm:
  > Add comment to {date}'s check-in:
  > "{body}"
  >
  > Proceed?

  The answer is the created comment: "Comment added (ID: {id}): "{comment}"" (the `comment` field, not `body`).

- **Upload — `add_result_update_attachment`**: `url`, `filename`, `date?`. It registers a file that already lives at a reachable link; nothing is uploaded, and a local file path cannot be uploaded (here or through api.sh), so ask for a link to the hosted file. Confirm "Upload **{filename}** to {date}'s check-in?". The answer is `{id}`: "Uploaded: {filename} (ID: {id}) — use this ID in "attach files" to add it to a section."

## Fallback (api.sh)

The connector has no tool for these jobs (high-fives and team-context switching are deliberately not in it), so they run as before: `RESPONSE=$("<api.sh path>" METHOD PATH [BODY])` returns `{status, body}`. `DATE_SEGMENT` is `today` or `YYYY-MM-DD`. Confirm writes first.

| Job | Confirm, then call | On 200 |
|---|---|---|
| React (high-five) | Toggle high-five reaction on {date}'s check-in? → `POST /result-feed/DATE_SEGMENT/reactions` `{"user_id":USER_ID}` (USER_ID from the args, e.g. "high-five user 7"; omit the body for the user's own report) | `body.data.reacted`, `body.data.count` → `🙌 High-five count: {count} — You: {reacted ? "reacted ✓" : "not reacted"}` |
| View reactions | none → `GET /result-feed/DATE_SEGMENT/reactions?user_id=USER_ID` (USER_ID from the args, else the user's own ID) | the same display |
| Set team context | Set active group context to team **{group_id}**? → `PATCH /users/me/team-context` `{"team_id":GROUP_ID}` (GROUP_ID from the args: "team 5", "group 5", "share to team 5") | "Group context set to team {group_id}." |

api.sh errors: `NO_CONFIG` "Config not found. Run `/rkit:setup` first."; `NO_TOKEN` "No API token. Run `/rkit:setup` to configure."; `CURL_FAILED` "Network error. Check your connection."; 401 "Unauthorized. Run `/rkit:setup` to update your token."; 404 "Not found. Resource may not exist."; 422 shows the validation error from the response body; any other non-200 shows the status code and error message; path `NOT_FOUND` "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`".

## How to Interpret

Look for trigger words/phrases from the routing table and extract a **team ID** ("team 5", "--team 5"), a **user ID** ("user 7", "user_id 7", "comments on user 7's check-in", "react to {user}'s check-in"), a **date** ("today", "yesterday", "2026-04-27" → `YYYY-MM-DD`), a **section** ("done", "review", "next", "blocked") and **text content** (comment body, notes text). Pick the matching row; default to viewing the team feed when no clear intent is detected. If ambiguous, ask: "Did you mean to [option A] or [option B]?"

## Errors

| The tool answers | Say |
|---|---|
| tools missing, or an authorization error | "The ResultKit connector isn't connected. Connect it (https://mcp.resultkit.ai) and try again." |
| "Team not found or you don't have access to it." | Team feed: "Team not found or you are not a member." Member report: "No report found for this user on this date, or you are not a member of this team." |
| "To-do or issue not found or you don't have access to it." | "Item {id} not found or not viewable." |
| "Unsupported section…" | "Invalid section. Use: done, review, next, or blocked." |
| "Report not found" | "Not found. Resource may not exist." |
| "Invalid date…" | Show it as returned. |
| "A comment cannot be empty." | Show it as returned (the comment text is required). |
| any other `Error: …` | Show it as returned. |

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
