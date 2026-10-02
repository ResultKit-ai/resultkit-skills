---
name: rkit:teams
description: List your teams, view team members, change member roles, manage team logos, view team activity logs, and switch your active team. Use this skill when users ask about their teams, want to see who's on a team, list team members, check team frameworks, search for a team by name, change a member's role (admin/member), set or remove a team logo, view membership history, view their organization structure, switch teams, use a team, set active team, or change team context.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(scripts/api.sh PATCH *), Bash(jq *), Read, Glob, Grep, AskUserQuestion
---

# rkit:teams

List teams, view team members, change member roles, and view activity logs. It drives the ResultKit connector's MCP tools, named below by base name (the full name is `mcp__<server>__<tool>`; the server alias varies by install). `scripts/api.sh` is used only for the jobs under **Fallback (api.sh)**.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh (Fallback only): !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/teams/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/teams/scripts/api.sh "$HOME/.claude/skills/rkit:teams/scripts/api.sh" "$HOME/.agents/skills/teams/scripts/api.sh" "$HOME/.gemini/skills/teams/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes.** Role change, set logo, remove logo and set active team require confirmation before executing (AskUserQuestion, Yes/No). Listings, members and activity logs are reads — no confirmation needed.
- **Show IDs.** Always include team, member, and user IDs in output (this overrides the connector's general "never print raw ids" note).
- **Concise output.** Tables and short summaries. No filler.
- **Direct execution.** Call the connector tools directly. Fallback jobs use Bash with api.sh. Never use Task agents, never curl or hand-build a URL, and skip the connector's `guide` tool — the routing below is complete for this skill.

## Argument Parsing

| Input | Behavior | Tool / flow |
|-------|----------|-------------|
| *(no args)* | List visible (non-muted) teams grouped by organization | Fallback: list teams |
| `all` | Include muted teams in listing (muted teams marked) | Fallback: list teams |
| `q "search term"` | Search teams by name (min 2 chars) | Fallback: list teams |
| `all q "term"` | Search including muted teams | Fallback: list teams |
| `members` | List members of the default team | `get_team` (Fallback roster if refused) |
| `members {team_id}` | List members of the specified team | `get_team` (Fallback roster if refused) |
| `role {user_id} {role} [team_id]` | Change a member's role (`admin` or `member`) on a team | `get_team`, then `change_member_role` |
| `logs [team_id]` | View team activity logs (membership changes) | `list_activity` |
| `logo set {url} [team_id]` | Set logo for a team (admin only) | Fallback: set logo |
| `logo remove [team_id]` | Remove logo for a team (admin only) | Fallback: remove logo |
| `use {team_id}` | Set the server-side active team to the given team ID (requires confirmation) | Fallback: set active team |

**Team ID** (members, role, logs, logo): the `team_id` arg if present, else `default_team_id` from Current State config. Neither → "No team specified and no default configured. Run `/rkit:setup`." — stop.

## Flow: List Members

Resolve the team ID, then call `get_team` with `team_id`. It answers text: `# {team name}`, the description, `**Framework**: …`, then `**Members** (N):` with one line per member, `- {name} (user_id: {id}, {role})` (`, pending` after the role for a pending invitation), then `**Sub-teams**:`. Show:

```
## Members — Team {team_name} ({team_id})

| Name | Role | User ID |
|------|------|---------|
| Jane Doe | admin | 101 |
| John Smith | member | 205 |

{count} members
```

- `Name` = the name on the member's line (full name, else login). `Role` = admin or member, with "(pending)" added for a pending invitation. `User ID` = the line's `user_id`.
- No member lines → "No members found for team {id}."
- `get_team` answers "You don't have access to this team." → read the roster through Fallback (**Roster `get_team` refuses**) before saying the team isn't found.

## Flow: Change Member Role

Triggered by: `role {user_id} {role} [team_id]`

1. **Validate.** `user_id` and `role` are both required; if either is missing: "Usage: `/rkit:teams role {user_id} {role} [team_id]`\n  Example: `/rkit:teams role 42 admin`" — stop. A `role` other than `admin` or `member` → "Invalid role '{role}'. Use 'admin' or 'member'." — stop. Resolve the team ID.
2. **Find the member.** Call `get_team` with `team_id` (or the Fallback roster read when `get_team` refuses) and find the member with `user_id: {user_id}`. Not there → "User USER_ID is not a member of team TEAM_ID." — stop.
3. **Confirm** with AskUserQuestion (Yes/No): "Change Jane Doe (ID: 42) from member to admin on team #345?" Declined → "Role change cancelled." — stop.
4. **Execute.** Call `change_member_role` with `team_id`, `user_id`, `role`.
5. **Report.** "Changed role: Jane Doe (ID: 42) is now admin on team #345." (user name, user ID, new role, team ID). Changing your own role: the tool decides; show its answer.

## Flow: View Activity Logs

Triggered by: `logs [team_id]`. Resolve the team ID, then call `list_activity` with `team_id`. It answers JSON `{page, per_page, total, activity}`, newest first, up to 100 entries a page; if `total` is more than one page, call again with `page` 2, 3, … and combine the results. No entries → "No activity logs found for team #TEAM_ID." Otherwise:

```
## Activity Logs — Team #345

| Date       | Action        | Target              | Actor           |
|------------|---------------|---------------------|-----------------|
| 2026-02-15 | member_added  | Jane Doe (ID: 42)   | Admin (ID: 1)   |
| 2026-02-10 | role_changed  | John Smith (ID: 55) | Admin (ID: 1)   |

2 entries  (page 1 of 1)
```

- `Date`: `created_at` formatted as `YYYY-MM-DD`. `Action`: `action`. `Target`: `target_user.first_name last_name (ID: target_user.id)`, fallback to `login`. `Actor`: the same from `actor`. Show total count and page info at the bottom.

## Fallback (api.sh)

The connector has no live tool for these jobs, so they run as before: `RESPONSE=$("<api.sh path>" METHOD PATH [BODY])` returns `{status, body}`. `list_teams` is not used for the listing: it answers only name and ID, with no organization, framework, logo, default or muted marks, and it takes no `all` or `q`. `set_team_logo` and `remove_team_logo` are held back from the connector, and no tool switches the active team.

### List teams (no args, `all`, `q`)

`GET /teams`; add `include_muted=true` for `all` and `q=term` for a search (`/teams?include_muted=true&q=term`). A search term under 2 chars → "Search requires at least 2 characters." Teams are in `body.data`. None (or no match for `q`) → "No teams matching '{term}'." with a search, else "No teams found." Otherwise group by `organization_name`:

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

- `Framework`: the value, or "—" if null. `Logo`: the Filestack handle (last path segment of `logo_url`, e.g. `abc123handle`), or "—" if `logo_url` is null.
- Mark the team matching `default_team_id` from config with `(default)`; with `all`, mark muted teams `(muted)`. With one organization, still show the org header. Show the total count at the bottom.

### Roster `get_team` refuses

`get_team` admits direct members, public-team viewers and role holders. The REST roster read also admits someone who can open a standard team without belonging to it (an ancestor or organization root-team member, a team admin, a global admin or org owner). When `get_team` answers "You don't have access to this team.", read the roster the old way: `GET /teams/TEAM_ID/members?per_page=100`; members are in `body.data` (`user.first_name` + `user.last_name`, fallback `user.login`; `role`; `user.id`); if `meta.total_pages` > 1 fetch the remaining pages and combine. Show the same Members table. 404 → "Team {id} not found (404)."; 401 → "Unauthorized (401). Run `/rkit:setup` to update your token."

### Set logo / remove logo

Triggered by `logo set {url} [team_id]` or `set logo {url} [team_id]`; `logo remove [team_id]` or `remove logo [team_id]`.

1. **Resolve.** Set needs the URL: if missing → "Usage: `/rkit:teams logo set {url} [team_id]`\n  URL must be a Filestack CDN URL (https://cdn.filestackcontent.com/...)." — stop. Team ID as above.
2. **Name for the confirmation.** `GET /teams/TEAM_ID`; 404 → "Team TEAM_ID not found (404)." — stop; `body.data.name` is the name.
3. **Confirm** with AskUserQuestion (Yes/No). Set: "Set logo for team #345 (Engineering) to: https://cdn.filestackcontent.com/abc123handle?" — declined → "Logo set cancelled." Remove: "Remove logo for team #345 (Engineering)?" — declined → "Logo removal cancelled."
4. **Execute.** Set: `POST /teams/TEAM_ID/logo` `{"logo_url":"URL"}`. Remove: `DELETE /teams/TEAM_ID/logo`.
5. **Report.** 200 set: "Logo set for team #345 (Engineering): https://cdn.filestackcontent.com/abc123handle"; 200 remove: "Logo removed for team #345 (Engineering)." (removing when no logo is set still returns 200 — the endpoint is idempotent; confirm success normally). 403 → set: "Access denied (403). Only team admins can set the logo."; remove: "Access denied (403). Only team admins can remove the logo." 422 (set) → "Invalid URL (422). Logo URL must start with `https://cdn.filestackcontent.com/`." 404 → "Team TEAM_ID not found (404)." Other: show the status code and error from the response body.

### Set active team

Triggered by: `use {team_id}`.

1. **Validate.** Missing or non-numeric → "Usage: `/rkit:teams use {team_id}`\n  Example: `/rkit:teams use 8`" — stop.
2. **Name for the confirmation.** `GET /teams/TEAM_ID`; 404 → "Team {team_id} not found." — stop; 401 → "Unauthorized (401). Run `/rkit:setup` to update your token." — stop; `body.data.name` is the name.
3. **Confirm** with AskUserQuestion: "Set active team to **{name}** (ID: {team_id})?" Declined → "Active team unchanged." — stop.
4. **Execute.** `PATCH /users/me/team-context` `{"team_id": TEAM_ID}`.
5. **Report.** 200 → "Active team set to **{name}** (ID: {id})." 401 → "Unauthorized (401). Run `/rkit:setup` to update your token." 422 → "Cannot set team (422): {error message from API body}" 400 → "Bad request (400). Check your input." Other: show the status code and error message.

api.sh errors: `NO_CONFIG` or `NO_TOKEN` "Config not found. Run `/rkit:setup` first."; `CURL_FAILED` "Network error. Check your connection."; 401 "Unauthorized (401). Run `/rkit:setup` to update your token."; other non-200: show the status code and error from the response body; path `NOT_FOUND` "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`".

## Errors

| The tool answers | Say |
|---|---|
| tools missing, or an authorization error | "The ResultKit connector isn't connected. Connect it (https://mcp.resultkit.ai) and try again." |
| "Team not found." (`get_team`) | "Team {id} not found." |
| "You don't have access to this team." (`get_team`) | Read the roster through Fallback; if that also fails, "Team {id} not found." |
| "Team not found or you don't have access to it." (`list_activity`) | "Team {id} not found, or you must be a team member to view activity logs." |
| "Access denied" (`change_member_role`) | "Access denied. Only team admins can change roles." |
| "Team not found" or "Member not found" (`change_member_role`) | "Team or member not found." |
| "Validation failed: …" (`change_member_role`) | Show it as returned (e.g. the team's creator or last admin cannot be demoted). |
| any other `Error: …` | Show it as returned. |
