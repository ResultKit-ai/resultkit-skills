---
name: rkit:result-feed
description: View and interact with team daily check-ins (result feeds). Shows what teammates got done, what's next, and what's blocking them. Supports reactions (high-five), comments, section notes, push to Slack/Discord, and team member detail views. Use this skill when users want to see team updates, daily check-ins, team progress, react to check-ins, comment, share to Slack/Discord, or manage section notes.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Bash(date *), Read, Glob, Grep, AskUserQuestion
---

# rkit:result-feed

A single skill that handles all result-feed operations by interpreting user intent against a tool routing table.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh: !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/result-feed/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/result-feed/scripts/api.sh "$HOME/.claude/skills/rkit:result-feed/scripts/api.sh" "$HOME/.agents/skills/result-feed/scripts/api.sh" "$HOME/.gemini/skills/result-feed/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`
- Today: !`date +%Y-%m-%d`

## Rules

- **Interpret first, act second.** Read the user's message. Match it against the Tool Routing Table below. Pick the best match. If ambiguous, ask.
- **Confirm writes.** GET requests execute immediately. POST/PUT/PATCH/DELETE: summarize all planned changes in a single prompt and ask for confirmation. Batch related mutations under one confirmation.
- **Show IDs.** Always include item IDs in output.
- **Concise output.** Tables and short summaries. No filler.
- **Direct execution.** Use Bash with api.sh for all API calls. Never use Task agents.

---

## Tool Routing Table

Match the user's message against the **Triggers** column. Pick the first matching row.

| Triggers | Intent | Tool/Flow |
|---|---|---|
| "team check-ins", "team feed", "show check-ins", "what did the team do", "team updates", "team result feed", *(no args)* | View team's shared check-ins | `view_team_feeds` |
| "show {user}'s check-in", "view {user}'s report", "team member report", "what did {user} do", "check-in for user {id}" | View a specific team member's report | `view_team_member_report` |
| "add notes", "update notes", "set notes on done", "set notes on next", "set notes on blocked", "edit section notes", "attach files", "add attachment", "clear notes" | Update section notes/attachments | `update_section_meta` |
| "high-five", "react", "high five {user}", "give kudos", "🙏", "toggle reaction" | React (high-five) to a check-in | `react_to_report` |
| "show reactions", "reaction count", "did I react", "high-five count", "how many reactions" | View reaction state without toggling | `view_reactions` |
| "show comments", "read comments", "comments on check-in", "comments on {date}" | List comments on a check-in | `list_comments` |
| "upload file", "attach file", "upload attachment" | Upload a file attachment to a check-in | `upload_attachment` |
| "comment on check-in", "add comment", "reply to {user}", "leave a comment" | Add a comment to a check-in | `add_comment` |
| "share to slack", "push to slack", "send to slack", "share check-in to slack" | Push check-in to Slack | `push_to_slack` |
| "share to discord", "push to discord", "send to discord", "share check-in to discord" | Push check-in to Discord | `push_to_discord` |
| "set team context", "switch team", "share to team {id}", "set group context" | Set active group context | `set_group_context` |

---

## Common Resolution

### Team ID Resolution

1. **`--team {id}` flag** in args → use that team ID
2. **`default_team_id` in config** → use that
3. **Neither** → "No default team configured. Run `/rkit:setup` first."

### Date Resolution

| User says | Segment value |
|---|---|
| *(nothing)* / "today" | `today` |
| "tomorrow" | tomorrow's date as `YYYY-MM-DD` |
| "yesterday" | yesterday's date as `YYYY-MM-DD` |
| "2026-04-27", "Apr 27" | `2026-04-27` |

Use the current date from **Current State** to resolve relative dates.

---

## Tool/Flow

### view_team_feeds

### Step 1: Resolve team and build query

Resolve team ID using Team ID Resolution. Build query params from args (page, per_page).

### Step 2: Fetch team result feeds

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" GET "/teams/TEAM_ID/result-feed?PARAMS")
echo "$RESPONSE"
```

Replace `TEAM_ID` with actual value. `PARAMS` = any page/per_page values.

### Step 3: Handle response

Parse the JSON response from api.sh.

**Error responses** (status 0 or non-200):
- Handle per Error Handling table below.
- `status: 404` → "Team not found or you are not a member."

**Success (status 200)**:

Extract `body.data` array and `body.meta` pagination.

- **Empty array**: Display:
  > No shared check-ins found for this team.

- **Feeds present**: For each TeamResultFeed in data, display:

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

  After all feeds, show pagination summary:
  > Page {page}/{total_pages} — {total} check-ins

---

### view_team_member_report

View a specific team member's check-in for a given date.

#### Step 1: Resolve parameters

- **team_id**: Use Team ID Resolution.
- **user_id**: Extract from args (e.g., "user 7", "user_id 7", "{user}'s check-in" → look up by name if needed, but prefer explicit ID).
- **date**: Use Date Resolution. Default to `today`.

#### Step 2: Fetch report

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" GET "/teams/TEAM_ID/result-feed/DATE/USER_ID")
echo "$RESPONSE"
```

#### Step 3: Handle response

- **Status 200**: Extract `body.data.report` and `body.data.is_quiet`. Display the full report using Section rendering rules (same as view_team_feeds) — render all four sections in order: Done, Review, Next, Blocked. If `is_quiet` is true, show `> ⚡ Quiet — shared to a different team context`.
- **Status 403**: "Not authorized — you are not a member of this team."
- **Status 404**: "No report found for this user on this date."
- **Other errors**: Handle per Error Handling table.

---

### update_section_meta

Update notes and/or attachments on a section of the user's result-feed.

#### Step 1: Resolve parameters

- **date**: Use Date Resolution. Default to `today`.
- **section**: Extract from args — must be `done`, `review`, `next`, or `blocked`.
- **notes**: Extract text from args. Use `null` if user says "clear notes".
- **attachment_ids**: Extract IDs if provided. These are pre-existing attachment IDs (upload is handled outside this skill).

#### Step 2: Confirm

Display:
> Update **{section}** section for {date}:
> - Notes: "{notes}" (or "clear" if null)
> - Attachment IDs: [{ids}] (or "unchanged" if not provided)
>
> Proceed?

Wait for confirmation.

#### Step 3: Execute

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" PUT "/result-feed/DATE/SECTION" '{"notes":"TEXT","attachment_ids":[IDS]}')
echo "$RESPONSE"
```

Only include fields the user specified. If only notes, omit `attachment_ids` from the body. If only attachments, omit `notes`.

#### Step 4: Handle response

- **Status 200**: "Section **{section}** updated."
- **Status 404**: "No report found for this date."
- **Other errors**: Handle per Error Handling table.

---

### react_to_report

Toggle a high-five reaction on a result-feed report.

#### Step 1: Resolve parameters

- **date**: Use Date Resolution. Default to `today`.

#### Step 2: Confirm

Display:
> Toggle high-five reaction on {date}'s check-in?

This is a non-destructive toggle (Constitution IV requires confirmation for POST).

Wait for confirmation.

#### Step 3: Resolve user_id

- **`user_id`**: Extract from args if specified (e.g., "high-five user 7", "react to {user}'s check-in"). If omitted, use the current user's ID from config or omit from body (server defaults to own report).

#### Step 4: Execute

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" POST "/result-feed/DATE/reactions" '{"user_id":USER_ID}')
echo "$RESPONSE"
```

#### Step 5: Handle response

- **Status 200**: Extract `body.data.reacted` and `body.data.count`. Display:
  > 🙌 High-five count: {count} — You: {reacted? "reacted ✓" : "not reacted"}
- **Other errors**: Handle per Error Handling table.

---

### view_reactions

View the current reaction state for a result-feed report without toggling.

#### Step 1: Resolve parameters

- **date**: Use Date Resolution. Default to `today`.
- **user_id**: Extract from args if specified (e.g., "reactions on user 7's check-in"). If omitted, use the current user's ID.

#### Step 2: Fetch reactions

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" GET "/result-feed/DATE/reactions?user_id=USER_ID")
echo "$RESPONSE"
```

#### Step 3: Handle response

- **Status 200**: Extract `body.data.reacted` and `body.data.count`. Display:
  > 🙌 High-five count: {count} — You: {reacted? "reacted ✓" : "not reacted"}
- **Other errors**: Handle per Error Handling table.

---

### list_comments

List comments on a result-feed report.

#### Step 1: Resolve parameters

- **date**: Use Date Resolution. Default to `today`.
- **user_id**: Extract from args if specified (e.g., "comments on user 7's check-in"). If omitted, use the current user's ID.

#### Step 2: Fetch comments

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" GET "/result-feed/DATE/comments?user_id=USER_ID")
echo "$RESPONSE"
```

#### Step 3: Handle response

- **Status 200**: Extract `body.data` array. If empty: "No comments on this check-in." If present, display:

  ```
  ## Comments — {date}

  | # | ID | User | Comment | Time |
  |---|---|---|---|---|
  | 1 | 12 | User 7 | Nice work! | 2026-04-26 14:00 |
  ```

  Use the `comment` field (not `body`) for the Comment column.

- **Other errors**: Handle per Error Handling table.

---

### add_comment

Add a comment to a result-feed report.

#### Step 1: Resolve parameters

- **date**: Use Date Resolution. Default to `today`.
- **body**: Extract comment text from args.
- **user_id**: Extract from args if specified. If omitted, use the current user's ID.

#### Step 2: Confirm

Display:
> Add comment to {date}'s check-in:
> "{body}"
>
> Proceed?

Wait for confirmation.

#### Step 3: Execute

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" POST "/result-feed/DATE/comments" '{"body":"COMMENT_TEXT","user_id":USER_ID}')
echo "$RESPONSE"
```

Escape any double quotes in COMMENT_TEXT.

#### Step 4: Handle response

- **Status 201**: Extract the created comment. Display:
  > Comment added (ID: {id}): "{comment}"
  
  Use the `comment` field (not `body`) for the text.
- **Status 422**: Show validation error (body is required, non-empty, max 10,000 chars).
- **Other errors**: Handle per Error Handling table.

---

### push_to_slack

Push a result-feed check-in to the team's Slack webhook.

#### Step 1: Resolve parameters

- **date**: Use Date Resolution. Default to `today`.
- **team_id**: Use Team ID Resolution.
- **exclude_item_ids**: Extract IDs if provided (optional).

#### Step 2: Check webhook availability

```bash
API_SH="<api.sh path>"
TEAM_RESPONSE=$("$API_SH" GET "/teams/TEAM_ID")
echo "$TEAM_RESPONSE"
```

Extract `body.data.has_slack_webhook`. If false:
> This team has no Slack webhook configured. Ask a team admin to set one up.

Stop — do not attempt the push.

Also display `has_discord_webhook` status for reference:
> Slack webhook: {yes/no} | Discord webhook: {yes/no}

#### Step 3: Confirm

Display:
> Push {date}'s check-in to Slack for team {team_id}?

Wait for confirmation.

#### Step 4: Execute

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" POST "/result-feed/DATE/push-to-slack" '{"group_context_id":TEAM_ID,"exclude_item_ids":[IDS]}')
echo "$RESPONSE"
```

#### Step 5: Handle response

- **Status 200**: "Check-in pushed to Slack."
- **Status 422**: "No Slack webhook configured for this team."
- **Status 502**: "Slack webhook delivery failed. The webhook URL may be invalid."
- **Status 403**: "Not authorized — you are not a member of this team."
- **Other errors**: Handle per Error Handling table.

---

### push_to_discord

Push a result-feed check-in to the team's Discord webhook. Same flow as `push_to_slack` but:
- Check `has_discord_webhook` instead of `has_slack_webhook`.
- Call `POST /result-feed/DATE/push-to-discord` instead of `push-to-slack`.
- Use `group_context_id` in the request body (same as push_to_slack).
- Replace "Slack" with "Discord" in all messages.

---

### set_group_context

Set the calling user's active group context (which team to share check-ins to).

#### Step 1: Resolve parameters

- **group_id**: Extract from args (e.g., "team 5", "group 5", "share to team 5").

#### Step 2: Confirm

Display:
> Set active group context to team **{group_id}**?

Wait for confirmation.

#### Step 3: Execute

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" POST "/users/me/group-context" '{"group_id":GROUP_ID}')
echo "$RESPONSE"
```

#### Step 4: Handle response

- **Status 200**: "Group context set to team {group_id}."
- **Other errors**: Handle per Error Handling table.

---

### upload_attachment

Upload a file attachment to a result-feed check-in. The returned document ID can be used as an `attachment_id` in `update_section_meta`.

#### Step 1: Resolve parameters

- **date**: Use Date Resolution. Default to `today`.
- **file_path**: Extract local file path from args (e.g., "upload /path/to/file.pdf", "attach ~/Downloads/report.pdf").

#### Step 2: Confirm

Display:
> Upload **{filename}** to {date}'s check-in?

Wait for confirmation.

#### Step 3: Execute

```bash
API_SH="<api.sh path>"
CONFIG="$HOME/.config/resultkit/config.json"
TOKEN=$(jq -r '.api_token' "$CONFIG")
BASE=$(jq -r '.api_base' "$CONFIG")
RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@FILE_PATH" \
  "$BASE/result-feed/DATE/attachments")
echo "$RESPONSE"
```

Replace `FILE_PATH` with the actual local path and `DATE` with the resolved date.

#### Step 4: Handle response

- **Status 200**: Extract `body.data`. Display:
  > Uploaded: {filename} (ID: {id}) — use this ID in "attach files" to add it to a section.
- **Status 400**: "Upload failed — unsupported file type or missing file."
- **Status 413**: "File too large — maximum size is 4.5 MB."
- **Other errors**: Handle per Error Handling table.

---

## How to Interpret

1. **Read the user's message.** Look for trigger words/phrases from the routing table.
2. **Extract parameters.** Look for:
   - A **team ID** (integer, e.g., "team 5", "--team 5")
   - A **user ID** (integer, e.g., "user 7", "user_id 7")
   - A **date** (e.g., "today", "yesterday", "2026-04-27") → convert to `YYYY-MM-DD`
   - A **section** ("done", "review", "next", "blocked")
   - **Text content** (comment body, notes text)
3. **Pick the matching tool row.** Use the routing table.
4. **Default to `view_team_feeds`** if no clear intent is detected.
5. **If ambiguous**, ask the user: "Did you mean to [option A] or [option B]?"

---

## Schemas

**TeamResultFeed:**
```json
{
  "id": 42,
  "date": "2026-02-26",
  "is_completed": true,
  "user": { "id": 1, "login": "pat", "first_name": "Pat", "last_name": "A" },
  "done":    { "items": [Item, ...], "notes": "string or null", "attachments": [Attachment, ...] },
  "review":  { "items": [Item, ...], "notes": null, "attachments": [] },
  "next":    { "items": [Item, ...], "notes": null, "attachments": [] },
  "blocked": { "items": [Item, ...], "notes": null, "attachments": [] }
}
```

**ResultFeedSection** (each of `done`, `review`, `next`, `blocked`):
```json
{
  "items": [Item, ...],
  "notes": "Free-text notes or null",
  "attachments": [
    { "id": 42, "filename": "spec.pdf", "content_type": "application/pdf", "size": 43008 }
  ]
}
```

**Item (within sections):**
```json
{
  "id": 415,
  "name": "Write proposal",
  "description": null,
  "due": "2026-02-25",
  "status": "next",
  "on_weekly": true,
  "team": { "id": 1, "name": "Acme Team" },
  "creator": { "id": 1, "login": "patrick", "first_name": "Patrick", "last_name": "Smith" },
  "assignees": [],
  "parent_id": null,
  "created_at": "2026-02-19T08:00:00Z",
  "updated_at": "2026-02-19T08:00:00Z"
}
```

**Attachment:**
```json
{
  "id": 42,
  "filename": "spec.pdf",
  "content_type": "application/pdf",
  "size": 43008
}
```

**Pagination:**
```json
{
  "page": 1,
  "per_page": 100,
  "total": 5,
  "total_pages": 1
}
```

---

## Error Handling

| Status | Response |
|---|---|
| `error: NO_CONFIG` | "Config not found. Run `/rkit:setup` first." |
| `error: NO_TOKEN` | "No API token. Run `/rkit:setup` to configure." |
| `error: CURL_FAILED` | "Network error. Check your connection." |
| `status: 401` | "Unauthorized. Run `/rkit:setup` to update your token." |
| `status: 403` | "Not authorized — you are not a member of this team." |
| `status: 404` | "Not found. Resource may not exist." |
| `status: 422` | Show validation error from response body. |
| `status: 502` | "Webhook delivery failed. The webhook URL may be invalid." |
| Other non-200 | Show status code and error message. |

### Edge Cases

- **No config**: "Config not found. Run `/rkit:setup` first."
- **api.sh not found**: "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"
- **No default_team_id and no --team**: Prompt user for team ID.
- **Empty feed list**: "No shared check-ins found for this team."
- **No webhook configured**: "No Slack/Discord webhook configured for this team. Ask an admin to set one up."
- **Empty comment body**: Show 422 validation error.

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
