---
name: rkit:setup
description: First-run configuration for ResultKit. Creates and manages ~/.config/resultkit/config.json with API token, default team, and API base URL. Use this skill when users need to set up ResultKit for the first time, reconfigure their token, change default team, or update API settings. Triggers on "setup", "configure", "connect my account", "change team", "update token", or any first-time rkit usage issues.
user-invocable: true
allowed-tools: Bash(curl *), Bash(jq *), Bash(mkdir -p *), Read, Glob, Grep, Write, AskUserQuestion
---

# rkit:setup

## Current State

- Config status: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING"; fi`
- Env var: !`[ -n "${RESULTKIT_TOKEN:-}" ] && echo "RESULTKIT_TOKEN is set" || echo "RESULTKIT_TOKEN not set"`
- api.sh: !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/setup/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/setup/scripts/api.sh "$HOME/.claude/skills/rkit:setup/scripts/api.sh" "$HOME/.agents/skills/setup/scripts/api.sh" "$HOME/.gemini/skills/setup/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes**: Before writing config, summarize all planned changes in a single prompt and ask for confirmation. Batch related operations under one confirmation.
- **Show IDs**: Always include entity IDs (team ID, user ID) in output.
- **Concise output**: Tables and short summaries. No verbose prose.
- **Direct execution**: Use Bash for all API calls. Never use Task agents or subagents.

## Flow

Use the **Current State** above to determine which flow to follow:

- Config **MISSING** → First-Time Setup (Step 1)
- Config **EXISTS** → Reconfigure (Step 10)

---

### Step 1: Check for environment variable token

If `RESULTKIT_TOKEN` is set (see Current State above):
> "Found `RESULTKIT_TOKEN` environment variable. Use this token for setup?"
- Yes → use env var value, go to Step 3.
- No → go to Step 2.

If not set → go to Step 2.

### Step 2: Ask for API token

> "Enter your ResultMaps API token (you can find it in your ResultMaps profile settings at https://app.resultmaps.com/customize):"

Wait for user input.

### Step 3: Verify token

Call `GET /users/me` with the token. Use curl directly (config doesn't exist yet):

```bash
RESPONSE=$(curl -s -w '\n%{http_code}' \
  -H "Authorization: Bearer TOKEN_HERE" \
  -H "Accept: application/json" \
  "https://api.resultmaps.com/api/v2/users/me")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
RESP_BODY=$(echo "$RESPONSE" | sed '$d')
echo "Status: $HTTP_CODE"
echo "$RESP_BODY"
```

Replace `TOKEN_HERE` with the actual token.

- **200**: Response is wrapped in `{ "data": { ... } }`. Extract `data.id`, `data.first_name`, `data.last_name`, `data.email`, `data.default_team`, `data.current_team`. Display:
  > Verified: **{first_name} {last_name}** ({email})
  Proceed to Step 4.

- **401**: Display error, go back to Step 2.

- **Other**: Show status code and error. Ask to retry or change API base URL.

### Step 4: List user's teams

Call `GET /teams` (returns teams in standard data envelope):

```bash
RESPONSE=$(curl -s -w '\n%{http_code}' \
  -H "Authorization: Bearer TOKEN_HERE" \
  -H "Accept: application/json" \
  "https://api.resultmaps.com/api/v2/teams")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
RESP_BODY=$(echo "$RESPONSE" | sed '$d')
echo "Status: $HTTP_CODE"
echo "$RESP_BODY"
```

The response is a standard data envelope: `{ "data": [...] }`. Extract
the teams array from the `data` field. Each team has `is_default` — the
default team appears first.

- **Teams found**: Display as table:

  | # | ID | Name | Framework | Default |
  |---|----|------|-----------|---------|
  | 1 | 1 | Engineering | EOS | yes |
  | 2 | 2 | Product | OKR | |

  If a team has `is_default: true`, pre-select it and ask:
  > "Your default team is **{name}** (ID: {id}). Use this, or pick a different one?"

  Otherwise ask: "Enter the number of your default team:"

- **API error**: Show error. Offer to retry.

### Step 5: Confirm and write config

Present summary for confirmation:

> **Ready to save configuration:**
> - Token: {first 3}...{last 4}
> - Default team: {team_name} (ID: {team_id})
> - API base: https://api.resultmaps.com/api/v2
>
> Save this configuration?

On confirmation, write:

```bash
mkdir -p "$HOME/.config/resultkit"
cat > "$HOME/.config/resultkit/config.json" << 'JSONEOF'
{
  "api_token": "ACTUAL_TOKEN",
  "default_team_id": ACTUAL_TEAM_ID,
  "api_base": "https://api.resultmaps.com/api/v2"
}
JSONEOF
```

Replace placeholders with actual values.

### Step 6: Done

> **Setup complete!**
> - User: {first_name} {last_name} ({email})
> - Team: {team_name} (ID: {team_id})
> - Config: ~/.config/resultkit/config.json
>
> Try `/rkit:today` to see your day plan.

---

### Step 10: Reconfigure Flow

Config exists (see Current State for current values).

Display:

> **Current configuration:**
> - Token: {masked from Current State}
> - Default team: ID {team_id}
> - API base: {api_base}
>
> What would you like to update?
> 1. API token
> 2. Default team
> 3. API base URL
> 4. Cancel

#### Option 1: Update token

Ask for new token → verify via `GET /users/me` (same as Step 3) → on success:

```bash
CONFIG_FILE="$HOME/.config/resultkit/config.json"
jq --arg token "NEW_TOKEN" '.api_token = $token' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
```

Confirm the change.

#### Option 2: Update default team

Use current token → call `GET /teams` → display table (same as Step 4). Mark current default with `(current)`.

On selection:

```bash
CONFIG_FILE="$HOME/.config/resultkit/config.json"
jq --argjson team TEAM_ID '.default_team_id = $team' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
```

Confirm the change.

#### Option 3: Update API base URL

Ask for new URL. Default: `https://api.resultmaps.com/api/v2`.

```bash
CONFIG_FILE="$HOME/.config/resultkit/config.json"
jq --arg base "NEW_BASE" '.api_base = $base' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
```

Confirm the change.

#### Option 4: Cancel

> No changes made.

---

## Edge Cases

- **Corrupted config**: File exists but invalid JSON → treat as missing, offer to recreate with confirmation.
- **Config dir fails**: Display filesystem error with path.
- **Token OK but teams fail**: Save token + api_base, suggest retry later.

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
