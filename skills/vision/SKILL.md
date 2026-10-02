---
name: rkit:vision
description: View a team's vision and mission data (framework-aware). Shows vision, mission, core values, and for EOS teams the full V/TO composite. Works for any management framework (EOS, OKR, 4DX, V2MOM, SRT). Use when users ask about team vision, mission, core values, strategic direction, what's our vision, team mission, or the V/TO overview.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Read, Glob, Grep
---

# rkit:vision

View a team's vision and mission data (cross-framework). It drives the ResultKit connector's MCP tools, named below by base name (the full name is `mcp__<server>__<tool>`; the server alias varies by install). `scripts/api.sh` is used only for the one job under **Fallback (api.sh)**.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh (Fallback only): !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/vision/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/vision/scripts/api.sh "$HOME/.claude/skills/rkit:vision/scripts/api.sh" "$HOME/.agents/skills/vision/scripts/api.sh" "$HOME/.gemini/skills/vision/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Read-only.** This skill only reads. No writes.
- **Show IDs.** Include team ID in the header (this overrides the connector's general "never print raw ids" note).
- **Concise output.** Labeled sections, no filler prose.
- **Direct execution.** Call the connector tools directly. The Fallback job uses Bash with api.sh. Never use Task agents or subagents, never curl or hand-build a URL, and skip the connector's `guide` tool — the flow below is complete for this skill.
- **Framework-aware.** Render only the sections relevant to the team's framework.
- **Null fields show "—".** The connector's tool notes say to leave out what is not set; this skill shows "—" instead, as before.

## Argument Parsing

| Input | Behavior |
|-------|----------|
| *(no args)* | Show vision for the default team |
| `--team {id}` | Use specified team instead of default |

## Team ID Resolution

1. **`--team {id}` flag** in args → use that team ID
2. **`default_team_id` in config** → use that
3. **Neither** → error: "No default team configured. Run `/rkit:setup` first."

## Flow: View Team Vision

### Step 1: Resolve team ID and api.sh

From Current State:
- If config is MISSING: "Config not found. Run `/rkit:setup` first." — stop.
- If api.sh is NOT_FOUND: "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`" — stop.
- Resolve `TEAM_ID` using Team ID Resolution above.

### Step 2: Read the team and the vision rows

Do these two together:

- **Team name** — `get_team` with `team_id`. The first line of its answer, `# {name}`, is `TEAM_NAME`. If the call fails, use "Team {TEAM_ID}".
- **Framework gate and the generic rows** — the connector has no tool for the generic Vision and Mission text or for `framework` / `framework_supported` (its vision tools carry only the V/TO parts), so this read stays on api.sh (**Fallback (api.sh)**):

```bash
API_SH="<resolved api.sh path>"
TEAM_ID="<resolved team ID>"
RESPONSE=$("$API_SH" GET "/teams/$TEAM_ID/vision")
echo "$RESPONSE"
```

**Error responses:**
- `"error": "NO_CONFIG"` or `"error": "NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 400` → "Invalid team ID (400). Team ID must be a number."
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 403` → "Access denied (403). You are not a member of team {TEAM_ID}."
- `status: 404` → "Team {TEAM_ID} not found (404)."
- Other non-200 → Show status code and error from response body.

**Success (status 200)** — extract from `body.data`: `FRAMEWORK` = `.framework`, `SUPPORTED` = `.framework_supported`, `VISION` = `.vision`, `MISSION` = `.mission`, `CORE_VALUES` = `.core_values`. Ignore `.eos_vision`: for an EOS team the connector carries those sections (see Framework: EOS).

Display header:
```
Vision — {TEAM_NAME} (ID: {TEAM_ID}) [{FRAMEWORK}]
```

### Framework: unsupported (framework_supported = false)

If `SUPPORTED` is `false`, display:

```
Vision — {TEAM_NAME} (ID: {TEAM_ID}) [{FRAMEWORK}]

Vision data is not available for the {FRAMEWORK} framework in V2.
```

Stop — do not render any further sections.

### Framework: EOS (framework = "eos")

Call `get_vision_components` and `get_3_year_vision`, both with `team_id` (together). Their answers are JSON; a part nobody has filled in comes back empty or null, shown as "—". Render the full V/TO in this order; Vision and Mission come from Step 2. Text can carry simple HTML — show it as plain text.

**Core Focus** (`coreFocus` from `get_vision_components`):
```
## Core Focus
Purpose:  {coreFocus.purpose or —}
Niche:    {coreFocus.niche or —}
```

**BHAG** (`tenYearTarget` from `get_vision_components`):
```
## BHAG (10-Year Target)
{tenYearTarget.text or —}
```

**Core Values** — use `CORE_VALUES` (cross-framework field, ordered by position):
```
## Core Values
- {name}: {description or —}
(repeat for each core value; if empty: "None defined.")
```

**Marketing Strategy** (`marketingStrategy` from `get_vision_components`; `uniques` is a list — show it comma-separated):
```
## Marketing Strategy
Target Market:  {marketingStrategy.targetMarket or —}
Uniques:        {marketingStrategy.uniques or —}
Proven Process: {marketingStrategy.provenProcess or —}
Guarantee:      {marketingStrategy.guarantee or —}
```

**Three-Year Picture** (`threeYearPicture` from `get_3_year_vision`):
```
## Three-Year Picture
Future Date:   {threeYearPicture.futureDate or —}
Revenue:       {threeYearPicture.revenue or —}
Profit:        {threeYearPicture.profit or —}
Description:   {threeYearPicture.description or —}
Measurables:   {threeYearPicture.measurables or —}
```

**Vision** (`VISION`):
```
## Vision
{VISION.description or —}
```

**Mission** (`MISSION`):
```
## Mission
{MISSION.name or —}
{MISSION.description or —}
```

### Framework: OKR or 4DX (framework = "okr" or "4dx")

For OKR/4DX teams, render vision, mission, and core values — all from Step 2; no further call.

```
## Vision
{VISION.description or —}

## Mission
{MISSION.name or —}
{MISSION.description or —}

## Core Values
- {name}: {description or —}
(repeat for each core value; if empty: "None defined.")
```

## Fallback (api.sh)

| Job | Call |
|---|---|
| Framework gate, generic Vision and Mission text, Core Values | `GET /teams/$TEAM_ID/vision` (Step 2): `framework`, `framework_supported`, `vision`, `mission`, `core_values` in `body.data`. No live connector tool carries these; `get_vision_components` and `get_3_year_vision` read only the V/TO parts. api.sh errors are listed in Step 2. |

## Edge Cases

- **EOS team, a V/TO part empty or null**: Show "—" for it. Vision and Mission still come from Step 2.
- **Empty core_values**: "None defined." **Team name fetch fails**: Use "Team {TEAM_ID}".
- **Connector tools missing, or an authorization error** (`get_team`, `get_vision_components`, `get_3_year_vision`): for an EOS V/TO say "The ResultKit connector isn't connected. Connect it (https://mcp.resultkit.ai) and try again." Any other `Error: …` from a tool: show it as returned.
