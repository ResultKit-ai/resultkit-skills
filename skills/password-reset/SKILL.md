---
name: rkit:password-reset
description: Trigger a password reset email for a user (admin only). Use this skill when users mention password reset, reset password, or send password reset.
disable-model-invocation: true
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Read, Glob, Grep, AskUserQuestion
---

# rkit:password-reset

## Current State

- Config status: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING"; fi`
- api.sh: !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/password-reset/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/password-reset/scripts/api.sh "$HOME/.claude/skills/rkit:password-reset/scripts/api.sh" "$HOME/.agents/skills/password-reset/scripts/api.sh" "$HOME/.gemini/skills/password-reset/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes**: Before calling POST /passwords/reset, show a confirmation prompt. GET requests execute immediately.
- **Concise output**: Short messages. No verbose prose.
- **Direct execution**: Use Bash for all API calls via api.sh. Never use Task agents or subagents.

## Error Handling

Parse the JSON response from api.sh. Handle these cases:

- `"error": "NO_CONFIG"` or `"error": "NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 403` → "Admin access required."
- `status: 422` → Show validation error from response body.
- Other non-200 → Show status code and error from response body.

---

## Argument Parsing

Parse the user input to determine which flow to follow:

| Input | Flow |
|-------|------|
| `{user_id}` | Trigger Password Reset |
| *(no args)* | Show usage message |

If no user ID is provided, show: "Usage: `/rkit:password-reset {user_id}`"

---

## Flow: Trigger Password Reset

**Trigger**: `{user_id}` provided

### Step 1: Validate input

Extract `user_id` from the arguments. If not a valid integer, show: "Usage: `/rkit:password-reset {user_id}`"

### Step 2: Confirm

Ask the user:

> Send password reset email to user #{user_id}?

Wait for confirmation before proceeding.

### Step 3: Call API

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" POST "/passwords/reset" "{\"user_id\": USER_ID}")
echo "$RESPONSE"
```

### Step 4: Handle response

- **Status 200**: "Password reset email sent to user #{user_id}."
- **Error** → use Error Handling above

---

## Edge Cases

- **No config** → "Config not found. Run `/rkit:setup` first."
- **api.sh not found** → "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"
- **No user ID** → "Usage: `/rkit:password-reset {user_id}`"
- **Non-admin (403)** → "Admin access required."
- **Invalid user / no email (422)** → Show validation error from response body.
- **Expired token (401)** → "Unauthorized (401). Run `/rkit:setup` to update your token."

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
