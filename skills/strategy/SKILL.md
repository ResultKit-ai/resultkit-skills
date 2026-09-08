---
name: rkit:strategy
description: View and manage your team's strategy tree (goals, rocks, objectives, key results, milestones, focus areas). Shows the hierarchical strategy for any management framework (EOS, OKR, 4DX). Supports creating, updating, aligning, and detaching strategy objects. Use when users mention strategy, goals, rocks, objectives, key results, OKRs, annual goals, quarterly priorities, focus areas, milestones, or strategy alignment.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Read, Glob, Grep, AskUserQuestion
---

# rkit:strategy

View and manage the team strategy tree.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh: !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/strategy/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/strategy/scripts/api.sh "$HOME/.claude/skills/rkit:strategy/scripts/api.sh" "$HOME/.agents/skills/strategy/scripts/api.sh" "$HOME/.gemini/skills/strategy/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes.** GET requests execute immediately. POST/PUT/PATCH/DELETE require user confirmation before executing.
- **Show IDs.** Always include object IDs and object_types in output for follow-up reference.
- **Concise output.** Indented trees and short summaries. No filler prose.
- **Direct execution.** Use Bash with api.sh for all API calls. Never use Task agents or subagents.
- **Framework-aware.** Use the team's `framework` field for terminology mapping (see Framework Label Mapping below).
- **Block inherited edits.** Nodes with `inherited: true` are read-only. Block create/update/align/detach on them with a clear message.
- **Scoped tools.** Use `Bash(scripts/api.sh *)` and `Bash(jq *)` — never raw curl.

## Argument Parsing

| Input | Behavior |
|-------|----------|
| *(no args)* | View strategy tree for default team (current year/quarter) |
| `--year YYYY` or `--year All` | Filter by year (default: current year) |
| `--quarter N` or `--quarter All` | Filter by quarter (default: current quarter) |
| `--team {id}` | Use specified team instead of default |
| `create "NAME" [under "PARENT"] [due=YYYY-MM-DD] [status=...] [assignees=ID,...] [--focus-area]` | Create a new strategy object |
| `update "NAME" [name=...] [description=...] [status=...] [due=...] [assignees=ID,...]` | Update a strategy object |
| `align "NAME" under "PARENT"` | Link an object to a parent in the tree |
| `detach "NAME" from "PARENT" [--archive]` | Unlink an object from a parent |

---

## Team ID Resolution

1. **`--team {id}` flag** in args → use that team ID
2. **`default_team_id` in config** → use that
3. **Neither** → error: "No default team configured. Run `/rkit:setup` first."

---

## Strategy Tree Fetch

Used by all flows. Fetch once and reuse.

```bash
API_SH="<resolved api.sh path>"
TEAM_ID="<resolved team ID>"
RESPONSE=$("$API_SH" GET "/teams/$TEAM_ID/targets?year=$YEAR&quarter=$QUARTER")
echo "$RESPONSE"
```

Default `YEAR` = current year, `QUARTER` = current quarter. If user specified `--year All` or `--quarter All`, pass those as query params.

Extract:
- `FRAMEWORK=$(echo "$RESPONSE" | jq -r '.body.data.framework')`
- `STRATEGY=$(echo "$RESPONSE" | jq '.body.data.targets')`
- `UNALIGNED=$(echo "$RESPONSE" | jq '.body.data.unaligned')`

---

## Object Name Resolution

Used by: `create` (for parent), `update`, `align`, `detach` subcommands.

### Step 1: Flatten the tree

Recursively walk both `targets` and `unaligned` arrays to build a flat list of all nodes:

```bash
FLAT=$(echo "$RESPONSE" | jq '
  [.body.data.targets, .body.data.unaligned] | add //[] |
  [recurse(.children[]?) | del(.children)]
')
```

### Step 2: Match

Given user input NAME:

1. **Case-insensitive exact match**: find nodes where `lower(name) == lower(NAME)`. If exactly one → use it.
2. **Case-insensitive substring match**: find nodes where `lower(name)` contains `lower(NAME)`. If exactly one → use it.
3. **Multiple matches** → show disambiguation list and stop:
   ```
   Multiple objects match "NAME". Which did you mean?
   1. Annual Goal (yearly_goal #6520, active, due 2026-12-31)
   2. Another Goal (yearly_goal #9466, active, due 2025-12-31)
   ```
4. **No match** → error: "No strategy object found matching '{NAME}'." and stop.

```bash
# Exact match (case-insensitive)
MATCH=$(echo "$FLAT" | jq --arg name "$NAME" \
  '[.[] | select((.name // "" | ascii_downcase) == ($name | ascii_downcase))]')

# If empty, substring match
if [ "$(echo "$MATCH" | jq 'length')" -eq 0 ]; then
  MATCH=$(echo "$FLAT" | jq --arg name "$NAME" \
    '[.[] | select((.name // "" | ascii_downcase) | contains($name | ascii_downcase))]')
fi

COUNT=$(echo "$MATCH" | jq 'length')
```

---

## Framework Label Mapping

Map `object_type` to framework-specific display labels:

| object_type | EOS | OKR | 4DX | Fallback |
|-------------|-----|-----|-----|----------|
| `yearly_goal` | Yearly Goal | Yearly Goal | Yearly Goal | Yearly Goal |
| `objective` | Objective | Objective | WIG | Objective |
| `rock` | Rock | Rock | Battle | Rock |
| `focus_area` | Focus Area | Focus Area | Focus Area | Focus Area |
| `key_result` | Milestone | Key Result | Lead Measure | Key Result |
| `milestone` | Milestone | Milestone | Milestone | Milestone |
| `action` | Action | Action | Action | Action |

Use the team's `framework` field to select the correct column. If framework is null or unrecognized, use Fallback.

---

## Status Emoji Mapping

| Status | Emoji |
|--------|-------|
| `active` | 🟢 |
| `complete` | ✅ |
| `archived` | 📦 |
| `deferred` | ⏸️ |
| `at_risk` | 🟡 |
| `off_track` | 🔴 |
| `draft` | 📝 |
| `cancelled` | ❌ |
| `review` | 🔍 |
| other/null | ⚪ |

---

## Flow: View Strategy Tree

Triggered when: no subcommand (no args, or only `--year`/`--quarter`/`--team` flags).

### Step 1: Resolve team ID

Use Team ID Resolution above.

### Step 2: Fetch strategy tree

Use Strategy Tree Fetch above.

### Step 3: Handle response

**Error responses** (status 0 or non-200): Handle per Error Handling table below.

**Success (status 200)**:

Display header:
```
Strategy for {TeamName} ({framework}) — {year} Q{quarter}
```

To get team name, call `GET /teams/$TEAM_ID` and extract `body.data.name` (or use `--team` context if available).

Then render the tree recursively. For each node in `strategy` array, output:

```
{indent}{emoji} {FrameworkLabel}: {name} (#{id}, due {due}[, → {assignee_names}])[, inherited from {team_name}]
```

Where:
- `{indent}` = 2 spaces per depth level
- `{emoji}` = from Status Emoji Mapping
- `{FrameworkLabel}` = from Framework Label Mapping using team's framework
- `{assignee_names}` = comma-separated `first_name last_initial.` from `assignees` array (omit if empty)
- `{due}` = due date or "no due date"
- Inherited nodes: append `[inherited from {inherited_from.team_name}]`

Recursively render `children` with increased indentation.

**Unaligned section**: If `unaligned` array is non-empty, show:
```

Unaligned:
  {emoji} {FrameworkLabel}: {name} (#{id}, due {due}[, → {assignees}])
```

**Empty state**: If both `strategy` and `unaligned` are empty:
> No strategy objects found for {year} Q{quarter}. Use `/rkit:strategy create "Name"` to get started.

---

## Flow: Create Strategy Object

Triggered when: first arg is `create`.

### Step 1: Parse args

Extract:
- `NAME` (required, quoted string after `create`). If missing → error: "Object name is required."
- `under "PARENT"` (optional) — parent name to create under
- `due=YYYY-MM-DD` (optional) — maps to `achieve_by` for goals/rocks, `due` for milestones
- `status=...` (optional, default: active)
- `assignees=ID,ID,...` (optional, comma-separated user IDs)

### Step 2: Determine object type and resolve parent

Fetch tree (if not already fetched).

**Type determination** (EOS hierarchy: goal → rock → milestone):

| Condition | Object Type | Endpoint |
|-----------|------------|----------|
| No parent specified (root level) | goal | `POST /teams/$TEAM_ID/goals` |
| Parent is a `yearly_goal` | rock | `POST /teams/$TEAM_ID/rocks` |
| Parent is a `rock` | milestone | `POST /teams/$TEAM_ID/milestones` |
| User explicitly says "create goal" | goal | `POST /teams/$TEAM_ID/goals` |
| User explicitly says "create rock" | rock | `POST /teams/$TEAM_ID/rocks` |
| User explicitly says "create milestone" | milestone | `POST /teams/$TEAM_ID/milestones` |

If parent specified, resolve parent name via Object Name Resolution.

If parent is inherited → error: "Cannot create children under inherited node '{name}' — it belongs to {inherited_from.team_name}."

Extract `parent_id` from matched node.

### Step 3: Confirm

> **Create {type}**: "{NAME}" {under "{PARENT}" (#{parent_id}) | at root level} in team {team_id}
> Fields: {due/achieve_by, status, assignees if set}

Ask for confirmation.

### Step 4: Execute

```bash
API_SH="<api.sh path>"
# For goals (root level):
RESPONSE=$("$API_SH" POST "/teams/$TEAM_ID/goals" '{"name":"NAME","achieve_by":"DATE","assignee_ids":[IDS]}')
# For rocks (under a goal):
RESPONSE=$("$API_SH" POST "/teams/$TEAM_ID/rocks" '{"name":"NAME","parent_id":GID,"assignee_ids":[IDS]}')
# For milestones (under a rock):
RESPONSE=$("$API_SH" POST "/teams/$TEAM_ID/milestones" '{"name":"NAME","parent_id":RID,"due":"DATE"}')
echo "$RESPONSE"
```

Omit null/unset fields from the JSON body. Only `name` is required. Use `parent_id` in the POST body to align on creation (single call, no separate PUT needed).

### Step 5: Handle response

- **201**: Extract `body.data.id` and `body.data.type`. Show: "Created: {NAME} ({type} #{id})."
- **422**: Show the validation error message. If "This endpoint is only available for EOS teams" → show clearly.
- **403**: "You don't have permission to create strategy objects in this team."
- Other errors: Handle per Error Handling table.

---

## Flow: Update Strategy Object

Triggered when: first arg is `update`.

### Step 1: Parse args

Extract:
- Object name (required, quoted string after `update`)
- `name=...`, `description=...`, `status=...`, `due=...`, `assignees=ID,...` (at least one required)

### Step 2: Resolve object

Fetch tree. Resolve object name via Object Name Resolution.

If object is inherited → error: "Cannot update inherited node '{name}' — it belongs to {inherited_from.team_name}."

Extract `object_type` and `id` from matched node.

### Step 3: Confirm

> **Update** "{name}" ({object_type} #{id}): set {field=value list}

If updating assignees, note: "Assignees list will be replaced entirely."

Ask for confirmation.

### Step 4: Execute

Route to the correct endpoint based on `object_type`:

```bash
API_SH="<api.sh path>"
# object_type == "yearly_goal":
RESPONSE=$("$API_SH" PATCH "/goals/$OBJECT_ID" '{"name":"...","status":"...","achieve_by":"...","assignee_ids":[...]}')
# object_type == "rock":
RESPONSE=$("$API_SH" PATCH "/rocks/$OBJECT_ID" '{"name":"...","status":"...","assignee_ids":[...]}')
# object_type == "milestone":
RESPONSE=$("$API_SH" PATCH "/milestones/$OBJECT_ID" '{"name":"...","status":"...","due":"..."}')
echo "$RESPONSE"
```

Include only the fields being updated. Note: goals/rocks use `achieve_by`, milestones use `due`.

### Step 5: Handle response

- **200**: "Updated: {name} ({object_type} #{id})."
- **403**: "You don't have permission to update this object."
- **404**: "Strategy object not found."
- **422**: Show the validation error message. If "This endpoint is only available for EOS teams" → show clearly.
- Other errors: Handle per Error Handling table.

---

## Flow: Align Strategy Object

Triggered when: first arg is `align`.

### Step 1: Parse args

Extract:
- Object name (required, quoted string after `align`)
- `under "PARENT"` (required)

If `under` is missing → error: "Usage: `/rkit:strategy align \"Object\" under \"Parent\"`"

### Step 2: Resolve both objects

Fetch tree. Resolve object name and parent name via Object Name Resolution (two separate resolutions).

If either is inherited → error and stop.

Extract from object: `object_id`, `object_type`
Extract from parent: `parent_id`

Validate alignment is valid:
- `object_type == "rock"` and parent is `yearly_goal` → OK
- `object_type == "milestone"` and parent is `rock` → OK
- Other combinations → error: "Cannot align {object_type} under {parent_type}. Rocks align to goals, milestones align to rocks."

### Step 3: Confirm

> **Link** "{object_name}" ({object_type} #{object_id}) under "{parent_name}" (#{parent_id})?

Ask for confirmation.

### Step 4: Execute

```bash
API_SH="<api.sh path>"
# object_type == "rock":
RESPONSE=$("$API_SH" PUT "/rocks/$OBJECT_ID" "{\"parent_id\":$PARENT_ID}")
# object_type == "milestone":
RESPONSE=$("$API_SH" PUT "/milestones/$OBJECT_ID" "{\"parent_id\":$PARENT_ID}")
echo "$RESPONSE"
```

### Step 5: Handle response

- **200**: "Linked: {object_name} now under {parent_name}."
- **403**: "You don't have permission to link objects in this team."
- **422**: Show the validation error message. If "This endpoint is only available for EOS teams" → show clearly.
- Other errors: Handle per Error Handling table.

---

## Flow: Detach / Archive Strategy Object

Triggered when: first arg is `detach`.

### Step 1: Parse args

Extract:
- Object name (required, quoted string after `detach`)
- `from "PARENT"` (optional — required for unlink, not needed for archive-only)
- `--archive` flag (optional)

If neither `from` nor `--archive` → error: "Usage: `/rkit:strategy detach \"Object\" from \"Parent\"` [--archive] or `/rkit:strategy detach \"Object\" --archive`"

### Step 2: Resolve object

Fetch tree. Resolve object name via Object Name Resolution.

If object is inherited → error: "Cannot detach inherited node '{name}' — it belongs to {inherited_from.team_name}."

Extract from object: `object_type`, `id`

### Step 3: Confirm

Two paths based on flags:

**Without `--archive`** (unlink only — move to unaligned):
> **Unlink** "{object_name}" ({object_type} #{id}) from its parent? Object will be preserved (moved to unaligned).

**With `--archive`** (archive the object):
> **Archive** "{object_name}" ({object_type} #{id})? Object will be archived permanently.

Ask for confirmation.

### Step 4: Execute

```bash
API_SH="<api.sh path>"

# Without --archive (unlink): PATCH to set parent_id to null
# object_type == "yearly_goal":
RESPONSE=$("$API_SH" PATCH "/goals/$OBJECT_ID" '{"parent_id":null}')
# object_type == "rock":
RESPONSE=$("$API_SH" PATCH "/rocks/$OBJECT_ID" '{"parent_id":null}')
# object_type == "milestone":
RESPONSE=$("$API_SH" PATCH "/milestones/$OBJECT_ID" '{"parent_id":null}')

# With --archive: DELETE to archive
# object_type == "yearly_goal":
RESPONSE=$("$API_SH" DELETE "/goals/$OBJECT_ID")
# object_type == "rock":
RESPONSE=$("$API_SH" DELETE "/rocks/$OBJECT_ID")
# object_type == "milestone":
RESPONSE=$("$API_SH" DELETE "/milestones/$OBJECT_ID")
echo "$RESPONSE"
```

### Step 5: Handle response

- **200 (unlink)**: "Unlinked: {object_name} moved to unaligned."
- **200 (archive)**: "Archived: {object_name} ({object_type} #{id})."
- **403**: "You don't have permission to modify objects in this team."
- **404**: "Strategy object not found."
- **422**: Show the validation error message. If "This endpoint is only available for EOS teams" → show clearly.
- Other errors: Handle per Error Handling table.

---

## Schemas

**TargetResponse (from GET /teams/{id}/targets):**
```json
{
  "data": {
    "framework": "eos",
    "targets": [
      {
        "id": 6520,
        "name": "Annual Goal",
        "description": null,
        "status": "active",
        "object_type": "yearly_goal",
        "type": 2,
        "color": null,
        "assignees": [{ "id": 591, "first_name": "Patrick", "last_name": "Angodung" }],
        "creator": { "id": 591, "first_name": "Patrick", "last_name": "Angodung" },
        "due": "2026-12-31",
        "children": [],
        "inherited": false,
        "inherited_from": null,
        "can_edit": true
      }
    ],
    "unaligned": []
  }
}
```

**Goal response (from POST/PATCH /goals, DELETE /goals):**
```json
{
  "data": {
    "id": 3645, "name": "Hit $10M ARR", "description": null, "status": "active",
    "type": "yearly_goal", "achieve_by": "2026-12-31", "color": null,
    "is_visible_to_team": true, "assignees": [...], "creator": {...},
    "created_at": "...", "updated_at": "..."
  }
}
```

**Rock response (from POST/PUT/PATCH /rocks, DELETE /rocks):**
```json
{
  "data": {
    "id": 3646, "name": "Launch enterprise tier", "description": null, "status": "active",
    "type": "rock", "achieve_by": "2026-03-31", "color": null,
    "is_visible_to_team": true, "parent_id": 3645, "persist_until_cleared": false,
    "assignees": [...], "creator": {...}, "created_at": "...", "updated_at": "..."
  }
}
```

**Milestone response (from POST/PUT/PATCH /milestones, DELETE /milestones):**
```json
{
  "data": {
    "id": 79874, "name": "Sign 3 enterprise customers", "description": null,
    "status": "active", "type": "milestone", "due": "2026-03-31", "color": null,
    "parent_id": 3646, "assignees": [...], "creator": {...}, "created_at": "..."
  }
}
```
Note: Milestone responses do NOT include `updated_at`.

**Response envelopes:**
- `GET /teams/{id}/targets` → `{ "data": { "framework": string, "targets": TargetNode[], "unaligned": TargetNode[] } }` (200)
- `POST /teams/{id}/goals` → `{ "data": Goal }` (201)
- `POST /teams/{id}/rocks` → `{ "data": Rock }` (201)
- `POST /teams/{id}/milestones` → `{ "data": Milestone }` (201)
- `PATCH /goals/{id}` → `{ "data": Goal }` (200)
- `PATCH /rocks/{id}` → `{ "data": Rock }` (200)
- `PATCH /milestones/{id}` → `{ "data": Milestone }` (200)
- `PUT /rocks/{id}` → `{ "data": Rock }` (200) — align
- `PUT /milestones/{id}` → `{ "data": Milestone }` (200) — align
- `DELETE /goals/{id}` → `{ "data": Goal }` (200, status: "archived")
- `DELETE /rocks/{id}` → `{ "data": Rock }` (200, status: "archived")
- `DELETE /milestones/{id}` → `{ "data": Milestone }` (200, status: "archived")

---

## Error Handling

| Status | Response |
|---|---|
| `error: NO_CONFIG` | "Config not found. Run `/rkit:setup` first." |
| `error: NO_TOKEN` | "No API token. Run `/rkit:setup` to configure." |
| `error: CURL_FAILED` | "Network error. Check your connection." |
| `status: 401` | "Unauthorized. Run `/rkit:setup` to update your token." |
| `status: 403` | "Not authorized for this team. Check your team membership." |
| `status: 404` | "Not found. Check the ID and try again." |
| `status: 422` | Show the validation error message from the response body. |
| `status: 422` (EOS-only) | If message contains "only available for EOS teams": "Goal/rock/milestone management is only available for EOS teams. The strategy tree view (`/rkit:strategy` with no args) works for all frameworks." |
| Other non-200 | Show status code and error message. |

### Edge Cases

- **No config**: "Config not found. Run `/rkit:setup` first."
- **api.sh not found**: "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"
- **No default_team_id and no --team**: Prompt user for team ID.
- **Empty strategy + empty unaligned**: Show empty state message.
- **Inherited node targeted for edit**: Block with clear message identifying the source team.
- **Multiple name matches**: Show disambiguation list with ID, object_type, status, and due date.
- **Unknown framework**: Use object_type as-is for labels (fallback column).

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
