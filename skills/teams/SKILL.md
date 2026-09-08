---
name: rkit:teams
description: List your teams, view team members, change member roles, manage team logos, view team activity logs, and switch your active team. Use this skill when users ask about their teams, want to see who's on a team, list team members, check team frameworks, search for a team by name, change a member's role (admin/member), set or remove a team logo, view membership history, view their organization structure, switch teams, use a team, set active team, or change team context.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(scripts/api.sh PATCH *), Bash(jq *), Read, Glob, Grep, AskUserQuestion
---

# rkit:teams

List teams, view team members, change member roles, and view activity logs.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh: !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/teams/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/teams/scripts/api.sh "$HOME/.claude/skills/rkit:teams/scripts/api.sh" "$HOME/.agents/skills/teams/scripts/api.sh" "$HOME/.gemini/skills/teams/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes.** Role change (PATCH), set logo (POST), and remove logo (DELETE) require confirmation before executing. Activity logs and all list operations are GET — no confirmation needed.
- **Show IDs.** Always include team, member, and user IDs in output.
- **Concise output.** Tables and short summaries. No filler.
- **Direct execution.** Use Bash with api.sh for all API calls. Never use Task agents.

## Argument Parsing

| Input | Behavior |
|-------|----------|
| *(no args)* | List visible (non-muted) teams grouped by organization |
| `all` | Include muted teams in listing (muted teams marked) |
| `q "search term"` | Search teams by name (min 2 chars) |
| `all q "term"` | Search including muted teams |
| `members` | List members of the default team |
| `members {team_id}` | List members of the specified team |
| `role {user_id} {role} [team_id]` | Change a member's role (`admin` or `member`) on a team |
| `logs [team_id]` | View team activity logs (membership changes) |
| `logo set {url} [team_id]` | Set logo for a team (admin only) |
| `logo remove [team_id]` | Remove logo for a team (admin only) |
| `use {team_id}` | Set the server-side active team to the given team ID (requires confirmation) |

---

## Flow: List Teams

### Step 1: Resolve API path

- Default: `GET /teams` (excludes muted — server-side filtering confirmed)
- If `all` in args: `GET /teams?include_muted=true`
- If `q "term"` in args: add `q=term` param
- Combine as needed: `/teams?include_muted=true&q=term`

### Step 2: Fetch teams

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" GET "/teams?PARAMS")
echo "$RESPONSE"
```

### Step 3: Handle response

Parse the JSON response from api.sh.

**Error responses** (status 0 or non-200):
- `"error": "NO_CONFIG"` or `"error": "NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- Other non-200 → Show status code and error from response body.

**Success (status 200)**:

Extract the teams array from `body.data` (standard data envelope). Each element is a team object.

- **Empty array** (or no matches with `q`):
  - With search: "No teams matching '{term}'."
  - Without search: "No teams found."

- **Teams present**: Group by `organization_name` and display:

  ```
  ## Your Teams

  ### {organization_name}

  | ID | Name | Framework | Logo | |
  |----|------|-----------|------|-|
  | 345 | Engineering | eos | abc123handle | (default) |
  | 412 | Product | okr | — | |

  ### {another_org}

  | ID | Name | Framework | Logo | |
  |----|------|-----------|------|-|
  | 500 | Sales | srt | — | |

  {count} teams
  ```

  - `Framework` column: show value or "—" if null
  - `Logo` column: show the Filestack handle (last path segment of `logo_url`, e.g. `abc123handle`) or "—" if `logo_url` is null. Extract handle with `echo "$logo_url" | sed 's|.*/||'`
  - Mark the team matching `default_team_id` from config with `(default)`
  - If `all` was used, mark muted teams with `(muted)`
  - If only one organization, still show the org header
  - Show total count at the bottom

---

## Flow: List Members

### Step 1: Resolve team ID

- If a team ID is provided in args → use it
- Otherwise → use `default_team_id` from Current State config
- If neither available → "No team specified and no default configured. Run `/rkit:setup`."

### Step 2: Fetch members (all pages)

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" GET "/teams/TEAM_ID/members?per_page=100")
echo "$RESPONSE"
```

Replace `TEAM_ID` with actual value.

### Step 3: Handle response

**Error responses** (status 0 or non-200):
- `"error": "NO_CONFIG"` or `"error": "NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 404` → "Team {id} not found (404)."
- Other non-200 → Show status code and error from response body.

**Success (status 200)**:

Extract `body.data` array (members) and `body.meta` (pagination).

- **Empty data array**: "No members found for team {id}."

- **Members present**: Display as table:

  ```
  ## Members — Team {team_name} ({team_id})

  | Name | Role | User ID |
  |------|------|---------|
  | Jane Doe | admin | 101 |
  | John Smith | member | 205 |

  {count} members
  ```

  - `Name` column: `user.first_name` + `user.last_name`. If both empty, fall back to `user.login`.
  - `Role` column: `role` value (admin/member)
  - `User ID` column: `user.id`

- **Pagination**: If `meta.total_pages > 1`, fetch all remaining pages and combine results before displaying.

---

---

## Flow: Change Member Role

Triggered by: `role {user_id} {role} [team_id]`

### Step 1: Validate args

- Extract `user_id` and `role` from args (both required).
- If either missing: "Usage: `/rkit:teams role {user_id} {role} [team_id]`\n  Example: `/rkit:teams role 42 admin`" — stop.
- If `role` is not `admin` or `member`: "Invalid role '{role}'. Use 'admin' or 'member'." — stop.
- Resolve team ID: use provided `team_id` arg if present, else `default_team_id` from config. If neither: "No team specified and no default configured. Run `/rkit:setup`." — stop.

### Step 2: Fetch current member info

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" GET "/teams/TEAM_ID/members?per_page=100")
```

Find the member with `user.id == user_id` in the `body.data` array.

- If 401: "Unauthorized (401). Run `/rkit:setup` to update your token." — stop.
- If 403: "Access denied (403). Only team admins can change roles." — stop.
- If 404: "Team TEAM_ID not found (404)." — stop.
- If member not found in data: "User USER_ID is not a member of team TEAM_ID." — stop.

### Step 3: Confirm

Show the member's current state and proposed change, then ask for confirmation:

```
Change Jane Doe (ID: 42) from member to admin on team #345?
```

Use AskUserQuestion with Yes/No options. If user declines: "Role change cancelled." — stop.

### Step 4: Execute role change

```bash
RESPONSE=$("$API_SH" PATCH "/teams/TEAM_ID/members/USER_ID" '{"role":"ROLE"}')
```

### Step 5: Handle response

- If 401: "Unauthorized (401). Run `/rkit:setup` to update your token."
- If 403: "Access denied (403). Only team admins can change roles."
- If 404: "Team or member not found (404)."
- If 422: Show validation error from response body.
- If 200: Display result:

  ```
  Changed role: Jane Doe (ID: 42) is now admin on team #345.
  ```

  Display user name (`first_name last_name`, fallback to `login`), user ID, new role, and team ID.

---

## Flow: Set Logo

Triggered by: `logo set {url} [team_id]` or `set logo {url} [team_id]`

### Step 1: Resolve team ID and URL

- Extract URL arg (required). If missing: "Usage: `/rkit:teams logo set {url} [team_id]`\n  URL must be a Filestack CDN URL (https://cdn.filestackcontent.com/...)." — stop.
- If `team_id` provided in args → use it; else use `default_team_id` from config. If neither: "No team specified and no default configured. Run `/rkit:setup`." — stop.

### Step 2: Fetch team name for confirmation

```bash
API_SH="<api.sh path>"
TEAM_RESPONSE=$("$API_SH" GET "/teams/TEAM_ID")
```

- If 404: "Team TEAM_ID not found (404)." — stop.
- Extract `body.data.name` for display in confirmation.

### Step 3: Confirm

Show the proposed action and ask for confirmation:

```
Set logo for team #345 (Engineering) to: https://cdn.filestackcontent.com/abc123handle?
```

Use AskUserQuestion with Yes/No options. If user declines: "Logo set cancelled." — stop.

### Step 4: Execute

```bash
RESPONSE=$("$API_SH" POST "/teams/TEAM_ID/logo" '{"logo_url":"URL"}')
```

### Step 5: Handle response

- If 200: Display result:
  ```
  Logo set for team #345 (Engineering): https://cdn.filestackcontent.com/abc123handle
  ```
- If 403: "Access denied (403). Only team admins can set the logo."
- If 422: "Invalid URL (422). Logo URL must start with `https://cdn.filestackcontent.com/`."
- If 404: "Team TEAM_ID not found (404)."
- Other: Show status code and error from response body.

---

## Flow: Remove Logo

Triggered by: `logo remove [team_id]` or `remove logo [team_id]`

### Step 1: Resolve team ID

- If `team_id` provided in args → use it; else use `default_team_id` from config.
- If neither: "No team specified and no default configured. Run `/rkit:setup`." — stop.

### Step 2: Fetch team name for confirmation

```bash
API_SH="<api.sh path>"
TEAM_RESPONSE=$("$API_SH" GET "/teams/TEAM_ID")
```

- If 404: "Team TEAM_ID not found (404)." — stop.
- Extract `body.data.name` for display in confirmation.

### Step 3: Confirm

Show the proposed action and ask for confirmation:

```
Remove logo for team #345 (Engineering)?
```

Use AskUserQuestion with Yes/No options. If user declines: "Logo removal cancelled." — stop.

### Step 4: Execute

```bash
RESPONSE=$("$API_SH" DELETE "/teams/TEAM_ID/logo")
```

### Step 5: Handle response

- If 200: Display result:
  ```
  Logo removed for team #345 (Engineering).
  ```
- If 403: "Access denied (403). Only team admins can remove the logo."
- If 404: "Team TEAM_ID not found (404)."
- Other: Show status code and error from response body.

---

## Flow: View Activity Logs

Triggered by: `logs [team_id]`

### Step 1: Resolve team ID

- Use provided `team_id` arg if present, else `default_team_id` from config.
- If neither: "No team specified and no default configured. Run `/rkit:setup`." — stop.

### Step 2: Fetch activity logs (all pages)

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" GET "/teams/TEAM_ID/activity-logs?per_page=25")
```

If `meta.total_pages > 1`, fetch remaining pages and combine results.

### Step 3: Handle response

- If 401: "Unauthorized (401). Run `/rkit:setup` to update your token."
- If 403: "Access denied (403). You must be a team member to view activity logs."
- If 404: "Team TEAM_ID not found (404)."
- If `data` is empty: "No activity logs found for team #TEAM_ID."
- If 200 with entries: Display as table:

  ```
  ## Activity Logs — Team #345

  | Date       | Action        | Target              | Actor           |
  |------------|---------------|---------------------|-----------------|
  | 2026-02-15 | member_added  | Jane Doe (ID: 42)   | Admin (ID: 1)   |
  | 2026-02-10 | role_changed  | John Smith (ID: 55) | Admin (ID: 1)   |

  2 entries  (page 1 of 1)
  ```

  - `Date`: `created_at` formatted as `YYYY-MM-DD`
  - `Target`: `target_user.first_name last_name (ID: target_user.id)`, fallback to `login`
  - `Actor`: `actor.first_name last_name (ID: actor.id)`, fallback to `login`
  - Show total count and page info at bottom

---

## Edge Cases

- **No config**: "Config not found. Run `/rkit:setup` first."
- **api.sh not found**: "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"
- **Search term < 2 chars**: "Search requires at least 2 characters."
- **No teams match search**: "No teams matching '{term}'."
- **Team not found (404) on members**: "Team {id} not found (404)."
- **No members**: "No members found for team {id}."
- **Member with empty names**: Fall back to `login`.
- **Role change — missing args**: Show usage message.
- **Role change — invalid role**: "Invalid role '{role}'. Use 'admin' or 'member'."
- **Role change — user not a member**: "User {id} is not a member of team {team_id}."
- **Role change — not admin (403)**: "Access denied (403). Only team admins can change roles."
- **Role change — user changes own role**: API decides; show its response.
- **Set logo — missing URL arg**: Show usage message with Filestack URL requirement.
- **Set logo — non-Filestack URL (422)**: "Invalid URL (422). Logo URL must start with `https://cdn.filestackcontent.com/`."
- **Set logo — not admin (403)**: "Access denied (403). Only team admins can set the logo."
- **Set logo — team not found (404)**: "Team {id} not found (404)."
- **Remove logo — not admin (403)**: "Access denied (403). Only team admins can remove the logo."
- **Remove logo — team not found (404)**: "Team {id} not found (404)."
- **Remove logo — no logo set**: Still returns 200 (endpoint is idempotent); confirm success normally.
- **Activity logs — no entries**: "No activity logs found for team #{id}."
- **Activity logs — not a member (403)**: "Access denied (403). You must be a team member to view activity logs."
- **Activity logs — paginated results**: Fetch all pages and combine before displaying.

---

## Flow: Set Active Team

Triggered by: `use {team_id}`

### Step 1: Validate args

- Extract `team_id` from args.
- If missing or not numeric: "Usage: `/rkit:teams use {team_id}`\n  Example: `/rkit:teams use 8`" — stop.

### Step 2: Fetch team name for confirmation

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" GET "/teams/TEAM_ID")
```

- On 404: "Team {team_id} not found." — stop.
- On 401: "Unauthorized (401). Run `/rkit:setup` to update your token." — stop.
- Extract `body.data.name` for display in confirmation prompt.

### Step 3: Confirm

Show the proposed action and ask for confirmation using AskUserQuestion:

```
Set active team to **{name}** (ID: {team_id})?
```

If user declines: "Active team unchanged." — stop.

### Step 4: Execute

```bash
RESPONSE=$("$API_SH" PATCH "/users/me/team-context" '{"team_id": TEAM_ID}')
```

### Step 5: Handle response

- On 200: "Active team set to **{name}** (ID: {id})."
- On 401: "Unauthorized (401). Run `/rkit:setup` to update your token."
- On 422: "Cannot set team (422): {error message from API body}"
- On 400: "Bad request (400). Check your input."
- Other: Show status code and error message.

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
