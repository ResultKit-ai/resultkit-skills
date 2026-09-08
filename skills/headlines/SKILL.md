---
name: rkit:headlines
description: View and manage EOS headlines (People & Customer Headlines) for a team. List active headlines, add new ones, archive (soft-delete), and update text or expiration. Uses L10-specific API routes for EOS teams. Use this skill when users mention headlines, people headlines, customer headlines, team announcements, or want to add, remove, or update headlines for their team.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Read, Glob, Grep, AskUserQuestion
---

# rkit:headlines

## Current State

- Config status: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING"; fi`
- api.sh: !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/headlines/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/headlines/scripts/api.sh "$HOME/.claude/skills/rkit:headlines/scripts/api.sh" "$HOME/.agents/skills/headlines/scripts/api.sh" "$HOME/.gemini/skills/headlines/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes**: Before any POST/PATCH/DELETE, summarize all planned changes in a single prompt and ask for confirmation. If the command implies multiple related mutations, batch them under one confirmation. GET requests execute immediately.
- **Show IDs**: Always include headline IDs in output so users can reference them.
- **Concise output**: Tables and short summaries. No verbose prose.
- **Direct execution**: Use Bash for all API calls via api.sh. Never use Task agents or subagents.

## Argument Parsing

Parse the user input to determine which flow to follow:

| Input | Flow |
|-------|------|
| *(no args)* | View Headlines |
| `add "text"` | Add Headline |
| `remove {headline_id}` | Archive Headline |
| `update {headline_id} ...` | Update Headline |
| `--team {id}` *(anywhere in args)* | Override team ID for any flow |

If the input doesn't match any pattern, show this usage summary and ask what they'd like to do.

---

## Team ID Resolution

1. **`--team {id}` flag** in args → use that team ID
2. **`default_team_id` in config** → use that
3. **Neither** → "No default team configured. Run `/rkit:setup` first."

---

## Error Handling

Parse the JSON response from api.sh. Handle these cases:

- `"error": "NO_CONFIG"` or `"error": "NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 403` → Show the error message from the response body (permission denied).
- `status: 404` → "Headline not found (404)." or "Team not found (404)."
- `status: 422` → Check if the error message mentions "EOS framework". If so, show: "Headlines are only available for teams using the EOS framework." Otherwise, show the validation error from the response body.
- Other non-200 → Show status code and error from response body.

## L10 Route Selection

After fetching the team detail, check the `framework` field. For EOS teams, use L10-specific API routes for listing and creating headlines. The L10 routes are aliases that return identical responses.

| Operation | EOS Route | Non-EOS Route |
|-----------|-----------|---------------|
| List headlines | `GET /teams/{id}/l10/headlines` | `GET /teams/{id}/headlines` |
| Create headline | `POST /teams/{id}/l10/headlines` | `POST /teams/{id}/headlines` |
| Archive headline | `DELETE /teams/{id}/headlines/{headline_id}` | `DELETE /teams/{id}/headlines/{headline_id}` |
| Update headline | `PATCH /teams/{id}/headlines/{headline_id}` | `PATCH /teams/{id}/headlines/{headline_id}` |

Archive and update always use generic routes — L10 routes only support GET and POST.

---

## Flow: View Headlines

**Trigger**: No args (or only `--team {id}`)

### Step 1: Resolve team and fetch headlines

Resolve team ID using Team ID Resolution. Fetch team detail for team name and framework:

```bash
API_SH="<api.sh path from Current State>"
TEAM=$("$API_SH" GET "/teams/TEAM_ID")
echo "$TEAM"
```

Extract the team's `framework` from the response. Then fetch headlines using the route from the **L10 Route Selection** table:

**If framework is `eos`**:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/teams/TEAM_ID/l10/headlines?per_page=100")
echo "$RESPONSE"
```

**Otherwise**:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/teams/TEAM_ID/headlines?per_page=100")
echo "$RESPONSE"
```

**Handle response**:
- Error → use Error Handling above
- Success (status 200): Extract `body.data` (headlines array) and `body.meta`
- **Empty data array** → "No active headlines for {team_name}."
- **Headlines present** → continue to Step 2

### Step 2: Display headlines

Display a header with team name, then the headline table:

```
Headlines: {team_name} (ID: {team_id})

| ID | Text | Creator | Expires | Created |
|----|------|---------|---------|---------|
| 201 | New client signed | John Smith | 2026-03-03 | 2026-02-24 |
| 202 | Office lease renewed | Jane Doe | 2026-03-04 | 2026-02-25 |

{N} headlines shown
```

**Display rules**:
- Each headline shows ID, text, creator name, expiration date, and creation date
- Creator shows `first_name last_name`. If both are empty, fall back to `login`
- Dates show YYYY-MM-DD format. Extract date portion from ISO 8601 `created_at` timestamp
- If `expires_at` is null, show "—"
- If `meta.total` > 100, show "(showing 100 of {total})" after the table

---

## Flow: Add Headline

**Trigger**: `add "text"` or `add "text" --expires {YYYY-MM-DD}`

### Step 1: Parse arguments and validate

Extract the headline text — everything after `add` that is not a flag (`--expires`, `--team`).

- If text is empty or whitespace-only → "Headline text cannot be empty."
- If `--expires` is provided, use that date. Otherwise compute default: 7 days from today in YYYY-MM-DD format.

### Step 2: Resolve team and confirm

Resolve team ID using Team ID Resolution. Fetch team detail for team name:

```bash
API_SH="<api.sh path from Current State>"
TEAM=$("$API_SH" GET "/teams/TEAM_ID")
echo "$TEAM"
```

Describe the action and ask for confirmation:
> Create headline "**{text}**" for **{team_name}** (expires {date})?

Wait for confirmation.

### Step 3: Execute

Use the route from the **L10 Route Selection** table based on the team's framework:

**If framework is `eos`**:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" POST "/teams/TEAM_ID/l10/headlines" '{"text": "HEADLINE_TEXT", "expires_at": "YYYY-MM-DD"}')
echo "$RESPONSE"
```

**Otherwise**:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" POST "/teams/TEAM_ID/headlines" '{"text": "HEADLINE_TEXT", "expires_at": "YYYY-MM-DD"}')
echo "$RESPONSE"
```

Escape any double quotes in HEADLINE_TEXT.

### Step 4: Handle response

- **Status 201**: Extract the new headline from `body.data`. Display: "Created headline **{id}**: \"{text}\" (expires {date})."
- **Status 422** → show validation error
- **Error** → use Error Handling above

---

## Flow: Archive Headline

**Trigger**: `remove {headline_id}`

### Step 1: Resolve team and confirm

Resolve team ID using Team ID Resolution. Fetch team detail for team name:

```bash
API_SH="<api.sh path from Current State>"
TEAM=$("$API_SH" GET "/teams/TEAM_ID")
echo "$TEAM"
```

Describe the action and ask for confirmation:
> Archive headline **{headline_id}** from **{team_name}**?

Wait for confirmation.

### Step 2: Execute

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" DELETE "/teams/TEAM_ID/headlines/HEADLINE_ID")
echo "$RESPONSE"
```

### Step 3: Handle response

- **Status 204**: "Archived headline **{headline_id}**."
- **Status 403** → "You do not have permission to archive this headline."
- **Status 404** → "Headline {headline_id} not found."
- **Error** → use Error Handling above

---

## Flow: Update Headline

**Trigger**: `update {headline_id} --text "new text"` and/or `--expires {YYYY-MM-DD}`

### Step 1: Parse arguments and validate

Extract `headline_id` (first argument after `update`), `--text` value, and `--expires` value.

- If neither `--text` nor `--expires` is provided → "Provide at least one of --text or --expires to update."

### Step 2: Resolve team and confirm

Resolve team ID using Team ID Resolution. Fetch team detail for team name:

```bash
API_SH="<api.sh path from Current State>"
TEAM=$("$API_SH" GET "/teams/TEAM_ID")
echo "$TEAM"
```

Build a description of what will change:
- If `--text` provided: "text → \"{new_text}\""
- If `--expires` provided: "expires → {new_date}"
- If both: show both changes

Describe the action and ask for confirmation:
> Update headline **{headline_id}** on **{team_name}**: {changes}?

Wait for confirmation.

### Step 3: Execute

Build the JSON body with only the provided fields:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" PATCH "/teams/TEAM_ID/headlines/HEADLINE_ID" '{"text": "NEW_TEXT", "expires_at": "YYYY-MM-DD"}')
echo "$RESPONSE"
```

Only include `text` in the body if `--text` was provided. Only include `expires_at` if `--expires` was provided.

### Step 4: Handle response

- **Status 200**: Extract the updated headline from `body.data`. Display: "Updated headline **{id}**: \"{text}\" (expires {date})."
- **Status 403** → "You do not have permission to update this headline."
- **Status 404** → "Headline {headline_id} not found."
- **Status 422** → show validation error
- **Error** → use Error Handling above

---

## Edge Cases

- **No config** → "Config not found. Run `/rkit:setup` first."
- **api.sh not found** → "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"
- **Non-EOS team (422)** → "Headlines are only available for teams using the EOS framework."
- **Headline not found (404)** → "Headline {id} not found."
- **Permission denied (403)** → Show the API's error message
- **No active headlines** → "No active headlines for {team_name}."
- **Empty headline text** → "Headline text cannot be empty."
- **Invalid expires_at format** → "Expiration date must be in YYYY-MM-DD format."
- **More than 100 headlines** → show first 100 with "(showing 100 of {total})"
- **Network error** → "Network error. Check your connection."
- **Unauthorized (401)** → "Unauthorized (401). Run `/rkit:setup` to update your token."
- **Team not found (404)** → "Team {id} not found (404)."

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
