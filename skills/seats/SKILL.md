---
name: rkit:seats
description: View and manage your team's accountability chart (seats). Shows the accountability hierarchy, seat details, owners, measures, goals, and links. Supports creating, updating, deleting, moving, and restoring seats, plus aligning measures/goals and managing links. Use when users mention seats, accountability chart, org chart, who owns what role, vacant positions, or seat management.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Read, Glob, Grep, AskUserQuestion
---

# rkit:seats

View and manage the team accountability chart.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh: !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/seats/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/seats/scripts/api.sh "$HOME/.claude/skills/rkit:seats/scripts/api.sh" "$HOME/.agents/skills/seats/scripts/api.sh" "$HOME/.gemini/skills/seats/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes.** GET requests execute immediately. POST/PUT/PATCH/DELETE require user confirmation before executing.
- **Show IDs.** Always include entity IDs in output for follow-up reference.
- **Concise output.** Trees, tables, and short summaries. No filler.
- **Direct execution.** Use Bash with api.sh for all API calls. Never use Task agents.
- **Framework-aware.** Use the team's `framework` field for terminology: EOS = "Accountability Chart", generic = "Org Chart". Measures = "Measurables" (EOS) or "KPIs". Goals = "Rocks" (EOS) or "Goals".

## Argument Parsing

| Input | Behavior |
|-------|----------|
| *(no args)* | View accountability chart tree for default team |
| `--include-archived` | Include archived seats in chart view |
| `{id}` | View seat detail by ID |
| `--team {id}` | Use specified team instead of default |
| `create "NAME" [--parent {id}]` | Create a new seat |
| `update {id} [--name "..."] [--owner {uid}] [--notes "..."] [--accountabilities "..."] [--associated-team {tid}]` | Update seat fields |
| `delete {id}` | Archive a seat |
| `move {id} --parent {id}` | Move seat to new parent |
| `restore {id}` | Restore an archived seat |
| `align-measure {id} --measure {mid}` | Align a measure to a seat |
| `remove-measure {id} --measure {mid}` | Remove a measure from a seat |
| `align-goal {id} --goal {gid}` | Align a goal to a seat |
| `remove-goal {id} --goal {gid}` | Remove a goal from a seat |
| `add-link {id} --url "..." [--title "..."]` | Add a link to a seat |
| `update-link {id} --link {lid} [--url "..."] [--title "..."]` | Update an existing link on a seat |
| `remove-link {id} --link {lid}` | Remove a link from a seat |

---

## Team ID Resolution

1. **`--team {id}` flag** in args → use that team ID
2. **`default_team_id` in config** → use that
3. **Neither** → "No default team configured. Run `/rkit:setup` first."

---

## Flow: View Accountability Chart

Triggered when: no args, or only `--team {id}`.

### Step 1: Resolve team ID

Use Team ID Resolution above.

### Step 2: Fetch seats tree

If `--include-archived` is present in args, append `?include_archived=true` to the URL.

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" GET "/teams/TEAM_ID/seats")           # without --include-archived
RESPONSE=$("$API_SH" GET "/teams/TEAM_ID/seats?include_archived=true")  # with --include-archived
echo "$RESPONSE"
```

Replace `TEAM_ID` with actual value. Use the appropriate URL based on whether `--include-archived` was provided.

### Step 3: Handle response

**Error responses** (status 0 or non-200): Handle per Error Handling table below.

**Success (status 200)**:

Extract `body.data` array. This is the root-level seats array — each seat has recursive `children[]`.

- **Empty array**: Display:
  > No seats found for this team. Create one with `/rkit:seats create "Role Name"`.

- **Seats present**: Extract the team name and framework from the first seat's `team` field.

  Display header:
  ```
  Accountability Chart — {TeamName} [Team: {TeamID}]
  ```
  (Use "Org Chart" if framework is not "eos".)

  Then render the tree recursively. For each seat node, output one line:
  ```
  {prefix}{connector} {name} ({owner}) [ID: {id}]
  ```

  When `--include-archived` was provided and a seat node has `archived: true`, append ` [archived]` to the line:
  ```
  {prefix}{connector} {name} ({owner}) [ID: {id}] [archived]
  ```

  Where:
  - `{owner}` = `{first_name} {last_name}` from `seat_owner`, or `Vacant` if null
  - `{connector}` = `├──` for non-last children, `└──` for last child
  - `{prefix}` = accumulated `│   ` or `    ` from parent levels
  - Root seats (top-level array items) use the same logic treating the array as children

  **Example output**:
  ```
  Accountability Chart — ResultMaps Incorporated [Team: 345]

  ├── Visionary (Scott Levy) [ID: 11]
  │   ├── Executive Assistant (Mary Mejia) [ID: 1138]
  │   ├── Integrator (TK) [ID: 12]
  │   │   ├── Engineering Lead (Vacant) [ID: 45]
  │   │   └── Product Lead (Pat) [ID: 46]
  │   └── Test Child Seat (Vacant) [ID: 1463]
  ```

---

## Flow: View Seat Details

Triggered when: first arg is a numeric ID (e.g., `/rkit:seats 11`).

### Step 1: Extract seat ID

Parse the numeric ID from args.

### Step 2: Fetch seat

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" GET "/seats/SEAT_ID")
echo "$RESPONSE"
```

### Step 3: Handle response

**Error responses**: Handle per Error Handling table. `status: 404` → "Seat not found. Check the ID and try again."

**Success (status 200)**:

Extract `body.data` object. Display:

```
## {name} [ID: {id}]
**Owner**: {first_name} {last_name} (@{login}) [ID: {uid}]
**Parent**: {parent.name} [ID: {parent.id}]
**Team**: {team.name} [ID: {team.id}]
**Associated Team**: {associated_team.name} [ID: {associated_team.id}]

**Accountabilities**:
{stripped HTML → plain text bullet list}

**Notes**: {notes or "None"}

**Measures** ({count}):
| ID | Name |
|----|------|
| {id} | {name} |

**Goals** ({count}):
| ID | Name |
|----|------|
| {id} | {name} |

**Links** ({count}):
| ID | Title | URL |
|----|-------|-----|
| {id} | {title} | {url} |

**Direct Reports** ({count}):
| ID | Name |
|----|------|
| {id} | {name} |
```

- If `seat_owner` is null → show "Vacant" for Owner
- If `parent` is null → show "None (root)" for Parent
- If `associated_team` is null → show "None" for Associated Team
- Empty arrays → show "None" instead of empty table
- **HTML stripping** for accountabilities: `echo "$HTML" | sed 's/<li[^>]*>/- /g; s/<br[^>]*>/\n/g; s/<\/li>/\n/g; s/<[^>]*>//g' | sed '/^$/d'`
- If accountabilities is null → show "None"

---

## Flow: Create Seat

Triggered when: first arg is `create`.

### Step 1: Parse args

Extract seat name (quoted string after `create`) and optional `--parent {id}`.

### Step 2: Resolve team ID

Use Team ID Resolution.

### Step 3: Confirm

Describe the action to the user:
> **Create seat**: "{name}" under {parent name or "as root seat"} in team {team_id}

Ask for confirmation before proceeding.

### Step 4: Execute

Use two distinct request bodies depending on whether `--parent` was provided:

**Root seat** (no `--parent` flag):
```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" POST "/seats" '{"name":"NAME","team_id":TEAM_ID}')
echo "$RESPONSE"
```

**Child seat** (with `--parent {id}`):
```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" POST "/seats" '{"name":"NAME","parent_id":PARENT_ID}')
echo "$RESPONSE"
```

### Step 5: Handle response

- **201**: Show the created seat detail (same format as View Seat Details).
- **422**: Show the validation error message (e.g., "Team already has a root seat").
- Other errors: Handle per Error Handling table.

---

## Flow: Update Seat

Triggered when: first arg is `update`.

### Step 1: Parse args

Extract seat ID and any combination of flags: `--name`, `--owner`, `--notes`, `--accountabilities`, `--associated-team`.

### Step 2: Build PATCH body

Map flags to API fields:
- `--name "..."` → `"name": "..."`
- `--owner {uid}` → `"seat_owner_id": {uid}`
- `--notes "..."` → `"notes": "..."`
- `--accountabilities "..."` → `"accountabilities": "..."`
- `--associated-team {tid}` → `"associated_team_id": {tid}`

### Step 3: Confirm

Describe the changes:
> **Update seat** [ID: {id}]: {list of changes}

If `--owner` flag is present, append to the confirm message:
> Note: changing the owner will reassign all aligned measures and goals to the new owner.

Ask for confirmation.

### Step 4: Execute

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" PATCH "/seats/SEAT_ID" '{"field":"value",...}')
echo "$RESPONSE"
```

### Step 5: Handle response

- **200**: Show the updated seat detail.
- Other errors: Handle per Error Handling table.

---

## Flow: Delete Seat

Triggered when: first arg is `delete`.

### Step 1: Parse seat ID from args

### Step 2: Confirm

> **Archive seat** [ID: {id}]? This will archive this seat AND all its descendants. This cannot be undone without restoring each seat individually.

Ask for confirmation.

### Step 3: Execute

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" DELETE "/seats/SEAT_ID")
echo "$RESPONSE"
```

### Step 4: Handle response

- **204**: "Seat [ID: {id}] archived successfully."
- Other errors: Handle per Error Handling table.

---

## Flow: Move Seat

Triggered when: first arg is `move`.

### Step 1: Parse seat ID and `--parent {id}` from args

If `--parent` is missing, error: "Missing `--parent {id}` flag. Usage: `/rkit:seats move {id} --parent {new_parent_id}`"

### Step 2: Confirm

> **Move seat** [ID: {id}] under new parent [ID: {parent_id}]?

Ask for confirmation.

### Step 3: Execute

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" PUT "/seats/SEAT_ID/move" '{"parent_id":PARENT_ID}')
echo "$RESPONSE"
```

### Step 4: Handle response

- **200**: Show the updated seat detail.
- **422**: Show validation error (e.g., "Cannot move root seat").
- Other errors: Handle per Error Handling table.

---

## Flow: Restore Seat

Triggered when: first arg is `restore`.

### Step 1: Parse seat ID from args

### Step 2: Confirm

> **Restore seat** [ID: {id}]? Only this seat will be restored — descendant seats remain archived and must be restored individually.

Ask for confirmation.

### Step 3: Execute

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" PUT "/seats/SEAT_ID/restore")
echo "$RESPONSE"
```

### Step 4: Handle response

- **200**: Show the restored seat detail.
- **422**: "Seat is not archived."
- Other errors: Handle per Error Handling table.

---

## Flow: Align Measure

Triggered when: first arg is `align-measure`.

### Step 1: Parse seat ID and `--measure {mid}` from args

### Step 2: Confirm

> **Align measure** [ID: {mid}] to seat [ID: {id}]?

### Step 3: Execute

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" PUT "/seats/SEAT_ID/measures" '{"measure_id":MID}')
echo "$RESPONSE"
```

### Step 4: Handle response

- **200**: Show updated measures list as a table with ID, Name, and Chart Type columns. For `chart_type`, display the value when non-null and `—` when null.
- Other errors: Handle per Error Handling table.

---

## Flow: Remove Measure

Triggered when: first arg is `remove-measure`.

### Step 1: Parse seat ID and `--measure {mid}` from args

### Step 2: Confirm

> **Remove measure** [ID: {mid}] from seat [ID: {id}]?

### Step 3: Execute

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" DELETE "/seats/SEAT_ID/measures/MID")
echo "$RESPONSE"
```

### Step 4: Handle response

- **204**: "Measure [ID: {mid}] removed from seat [ID: {id}]."
- Other errors: Handle per Error Handling table.

---

## Flow: Align Goal

Triggered when: first arg is `align-goal`.

### Step 1: Parse seat ID and `--goal {gid}` from args

### Step 2: Confirm

> **Align goal** [ID: {gid}] to seat [ID: {id}]?

### Step 3: Execute

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" PUT "/seats/SEAT_ID/goals" '{"goal_id":GID}')
echo "$RESPONSE"
```

### Step 4: Handle response

- **200**: Show updated goals list as a table with ID and Name columns.
- Other errors: Handle per Error Handling table.

---

## Flow: Remove Goal

Triggered when: first arg is `remove-goal`.

### Step 1: Parse seat ID and `--goal {gid}` from args

### Step 2: Confirm

> **Remove goal** [ID: {gid}] from seat [ID: {id}]?

### Step 3: Execute

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" DELETE "/seats/SEAT_ID/goals/GID")
echo "$RESPONSE"
```

### Step 4: Handle response

- **204**: "Goal [ID: {gid}] removed from seat [ID: {id}]."
- Other errors: Handle per Error Handling table.

---

## Flow: Add Link

Triggered when: first arg is `add-link`.

### Step 1: Parse seat ID, `--url "..."`, and optional `--title "..."` from args

### Step 2: Confirm

> **Add link** "{title or url}" to seat [ID: {id}]?

### Step 3: Execute

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" POST "/seats/SEAT_ID/links" '{"url":"URL","title":"TITLE"}')
echo "$RESPONSE"
```

Omit `title` from body if not provided (API defaults to URL).

### Step 4: Handle response

- **201**: Show the created link (ID, Title, URL).
- Other errors: Handle per Error Handling table.

---

## Flow: Update Link

Triggered when: first arg is `update-link`.

### Step 1: Parse args

Extract seat ID, `--link {lid}`, and optional `--url "..."` and/or `--title "..."` from args.

If neither `--url` nor `--title` is provided, error: "At least one of `--url` or `--title` is required. Usage: `/rkit:seats update-link {id} --link {lid} [--url \"...\"] [--title \"...\"]`"

### Step 2: Confirm

> **Update link** [ID: {lid}] on seat [ID: {id}]: {list of changes}?

Ask for confirmation.

### Step 3: Execute

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" PATCH "/seats/SEAT_ID/links/LID" '{"url":"URL","title":"TITLE"}')
echo "$RESPONSE"
```

Include only provided fields in the JSON body (omit `url` if not given, omit `title` if not given).

### Step 4: Handle response

- **200**: Show the updated link (ID, Title, URL).
- Other errors: Handle per Error Handling table.

---

## Flow: Remove Link

Triggered when: first arg is `remove-link`.

### Step 1: Parse seat ID and `--link {lid}` from args

### Step 2: Confirm

> **Remove link** [ID: {lid}] from seat [ID: {id}]?

### Step 3: Execute

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" DELETE "/seats/SEAT_ID/links/LID")
echo "$RESPONSE"
```

### Step 4: Handle response

- **204**: "Link [ID: {lid}] removed from seat [ID: {id}]."
- Other errors: Handle per Error Handling table.

---

## Schemas

**Seat (tree node — from GET /teams/{id}/seats):**
```json
{
  "id": 11,
  "name": "Visionary",
  "accountabilities": "<ul><li>Strategic direction</li></ul>",
  "notes": null,
  "parent": null,
  "creator": { "id": 1, "login": "scott", "first_name": "Scott", "last_name": "Levy" },
  "seat_owner": { "id": 1, "login": "scott", "first_name": "Scott", "last_name": "Levy" },
  "team": { "id": 345, "name": "ResultMaps Inc", "framework": "eos" },
  "associated_team": { "id": 1, "name": "W3mG", "framework": "eos" },
  "measures": [{ "id": 793, "name": "KPI", "description": "" }],
  "goals": [{ "id": 7315, "name": "Goal", "description": null }],
  "links": [{ "id": 2078, "title": "Wiki", "url": "https://example.com" }],
  "children": [ "...recursive Seat objects..." ],
  "created_at": "2018-01-23T18:59:28.000Z",
  "updated_at": "2026-03-04T05:53:47.000Z"
}
```

**Seat (detail — from GET /seats/{id}):**
Same as above but `children` contains simplified objects: `[{ "id": 1138, "name": "Executive Assistant" }]`

**Response envelopes:**
- `GET /teams/{id}/seats` → `{ "data": [ Seat, ... ] }` (array of root seats, recursive children)
- `GET /seats/{id}` → `{ "data": { ...Seat } }` (single seat object)
- `POST /seats` → `{ "data": { ...Seat } }` (created seat)
- `PATCH /seats/{id}` → `{ "data": { ...Seat } }` (updated seat)
- `DELETE /seats/{id}` → 204 no content
- `PUT /seats/{id}/move` → `{ "data": { ...Seat } }` (moved seat)
- `PUT /seats/{id}/restore` → `{ "data": { ...Seat } }` (restored seat)
- Sub-resource lists → `{ "data": [ { "id", "name", "description" }, ... ] }`

---

## Error Handling

| Status | Response |
|---|---|
| `error: NO_CONFIG` | "Config not found. Run `/rkit:setup` first." |
| `error: NO_TOKEN` | "No API token. Run `/rkit:setup` to configure." |
| `error: CURL_FAILED` | "Network error. Check your connection." |
| `status: 401` | "Unauthorized. Run `/rkit:setup` to update your token." |
| `status: 403` | "Not authorized for this team/seat. Check your team membership." |
| `status: 404` | "Not found. Check the ID and try again." |
| `status: 422` | Show the validation error message from the response body. |
| Other non-200 | Show status code and error message. |

### Edge Cases

- **No config**: "Config not found. Run `/rkit:setup` first."
- **api.sh not found**: "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"
- **No default_team_id and no --team**: Prompt user for team ID.
- **Empty seats array**: "No seats found for this team. Create one with `/rkit:seats create \"Role Name\"`."
- **Seat owner is null**: Display "Vacant" in tree and detail views.
- **Accountabilities is null**: Display "None" in detail view.
- **Associated team is null**: Display "None" in detail view.
- **Parent is null**: Display "None (root)" in detail view.

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
