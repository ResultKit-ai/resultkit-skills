---
name: rkit:vision
description: View a team's vision and mission data (framework-aware). Shows vision, mission, core values, and for EOS teams the full V/TO composite. Works for any management framework (EOS, OKR, 4DX, V2MOM, SRT). Use when users ask about team vision, mission, core values, strategic direction, what's our vision, team mission, or the V/TO overview.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Read, Glob, Grep
---

# rkit:vision

View a team's vision and mission data (cross-framework).

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh: !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/vision/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/vision/scripts/api.sh "$HOME/.claude/skills/rkit:vision/scripts/api.sh" "$HOME/.agents/skills/vision/scripts/api.sh" "$HOME/.gemini/skills/vision/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Read-only.** This skill only calls GET endpoints. No writes.
- **Show IDs.** Include team ID in the header.
- **Concise output.** Labeled sections, no filler prose.
- **Direct execution.** Use Bash with api.sh for all API calls. Never use Task agents or subagents.
- **Framework-aware.** Render only the sections relevant to the team's framework.

## Argument Parsing

| Input | Behavior |
|-------|----------|
| *(no args)* | Show vision for the default team |
| `--team {id}` | Use specified team instead of default |

---

## Team ID Resolution

1. **`--team {id}` flag** in args → use that team ID
2. **`default_team_id` in config** → use that
3. **Neither** → error: "No default team configured. Run `/rkit:setup` first."

---

## Flow: View Team Vision

### Step 1: Resolve team ID and api.sh

From Current State:
- Extract `API_SH` path. If NOT_FOUND: "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`" — stop.
- If config is MISSING: "Config not found. Run `/rkit:setup` first." — stop.
- Resolve `TEAM_ID` using Team ID Resolution above.

### Step 2: Fetch vision data

```bash
API_SH="<resolved api.sh path>"
TEAM_ID="<resolved team ID>"
RESPONSE=$("$API_SH" GET "/teams/$TEAM_ID/vision")
echo "$RESPONSE"
```

### Step 3: Handle response

**Error responses:**
- `"error": "NO_CONFIG"` or `"error": "NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 400` → "Invalid team ID (400). Team ID must be a number."
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 403` → "Access denied (403). You are not a member of team {TEAM_ID}."
- `status: 404` → "Team {TEAM_ID} not found (404)."
- Other non-200 → Show status code and error from response body.

**Success (status 200):**

Extract from `body.data`:
- `FRAMEWORK` = `.framework`
- `SUPPORTED` = `.framework_supported`
- `VISION` = `.vision`
- `MISSION` = `.mission`
- `CORE_VALUES` = `.core_values`
- `EOS_VISION` = `.eos_vision`

Also fetch the team name for the header:

```bash
TEAM_RESP=$("$API_SH" GET "/teams/$TEAM_ID")
TEAM_NAME=$(echo "$TEAM_RESP" | jq -r '.body.data.name // "Team \($TEAM_ID)"')
```

Display header:
```
Vision — {TEAM_NAME} (ID: {TEAM_ID}) [{FRAMEWORK}]
```

---

### Framework: unsupported (framework_supported = false)

If `SUPPORTED` is `false`, display:

```
Vision — {TEAM_NAME} (ID: {TEAM_ID}) [{FRAMEWORK}]

Vision data is not available for the {FRAMEWORK} framework in V2.
```

Stop — do not render any further sections.

---

### Framework: EOS (framework = "eos")

For EOS teams, render the full V/TO composite from `eos_vision`. The `vision` and `mission` fields are present but the EOS V/TO is the authoritative source.

Extract from `EOS_VISION`:

**Core Focus** (`.core_focus`):
```
## Core Focus
Purpose:  {core_focus.purpose or —}
Niche:    {core_focus.niche or —}
```

**BHAG** (`.bhag`):
```
## BHAG (10-Year Target)
{bhag.text or —}
```

**Core Values** — use `CORE_VALUES` array (cross-framework field, ordered by position):
```
## Core Values
- {name}: {description or —}
(repeat for each core value; if empty: "None defined.")
```

**Marketing Strategy** (`.marketing_strategy`):
```
## Marketing Strategy
Target Market:  {marketing_strategy.targetMarket or —}
Uniques:        {marketing_strategy.uniques or —}
Proven Process: {marketing_strategy.provenProcess or —}
Guarantee:      {marketing_strategy.guarantee or —}
```

**Three-Year Picture** (`.three_year_picture`):
```
## Three-Year Picture
Future Date:   {three_year_picture.futureDate or —}
Revenue:       {three_year_picture.revenue or —}
Profit:        {three_year_picture.profit or —}
Description:   {three_year_picture.description or —}
Measurables:   {three_year_picture.measurables or —}
```

**Vision** (`.vision`):
```
## Vision
{eos_vision.vision.description or body.data.vision.description or —}
```

**Mission** (`.mission`):
```
## Mission
{mission.name or —}
{mission.description or —}
```

---

### Framework: OKR or 4DX (framework = "okr" or "4dx")

For OKR/4DX teams, render vision, mission, and core values.

```
## Vision
{vision.description or —}

## Mission
{mission.name or —}
{mission.description or —}

## Core Values
- {name}: {description or —}
(repeat for each core value; if empty: "None defined.")
```

---

## Edge Cases

- **No config**: "Config not found. Run `/rkit:setup` first."
- **api.sh not found**: "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"
- **No default_team_id and no --team**: "No default team configured. Run `/rkit:setup` first."
- **Unsupported framework**: Display the unsupported message and stop.
- **EOS team, eos_vision is null**: Render vision/mission from the top-level `vision`/`mission` fields instead. Core values from `core_values`.
- **Empty core_values**: "None defined."
- **Null vision or mission fields**: Show "—" for any null string fields.
- **Team name fetch fails**: Use "Team {TEAM_ID}" as fallback.

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
