---
name: rkit:profile
description: View your profile stats, measurables (scorecard), rocks (quarterly goals), feedback (High5s), personal progress dashboard, and third-party integrations. Manage preferences, change your password, and manage account members. Use this skill when users ask about their personal stats, wins, goals realized, actions done, measurables, scorecard, rocks, quarterly goals, feedback, High5s, progress, integrations, want to view or update their preferences (timezone, notifications, startup view), change their account password, or manage account members (list, remove).
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), AskUserQuestion
---

# rkit:profile

View profile stats, manage preferences, change password, and manage account members. The ResultKit connector's MCP tools cover only `measurables` (tool `list_measurables`): the connector deliberately has no profile, preferences, account-member or high-five tools, so every other flow here still runs through `scripts/api.sh` — see **Fallback**. Tools are named below by base name: the full name is `mcp__<server>__<tool>`, and the server alias varies by install.

## Current State

- Config (Fallback): !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh (Fallback): !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/profile/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/profile/scripts/api.sh "$HOME/.claude/skills/rkit:profile/scripts/api.sh" "$HOME/.agents/skills/profile/scripts/api.sh" "$HOME/.gemini/skills/profile/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes.** PATCH preferences, POST password, and DELETE account member require confirmation before executing. All GET operations execute immediately.
- **Show IDs.** Always include user ID, account ID, and member IDs in output.
- **Concise output.** Tables for account members. Labeled key-value for stats and preferences. No filler.
- **Direct execution.** Call the connector tool where one exists; every other call goes through api.sh. Never use Task agents, never curl or hand-build a URL, and skip the connector's `guide` tool.

## Argument Parsing

| Input | Behavior | Via |
|-------|----------|-----|
| *(no args)* | Show stats for the current user (same as `stats`) | Fallback |
| `stats` | Show personal performance stats for current user | Fallback |
| `stats {user_id}` | Show stats for another user (must share a team) | Fallback |
| `prefs` | View all current preferences | Fallback |
| `prefs set {field} {value}` | Update a single preference field (with confirmation) | Fallback |
| `password` | Interactively change account password | Fallback |
| `account` | Show current user's accounts with ownership status | Fallback |
| `account members [{account_id}]` | List account members (prompts if multiple accounts) | Fallback |
| `account members remove {user_id} [{account_id}]` | Remove a member from an account (owner-only, with confirmation) | Fallback |
| `measurables` | Show scorecard metrics for current user | `list_measurables` · Fallback |
| `measurables {user_id}` | Show scorecard metrics for another user (must share a team) | `list_measurables` |
| `rocks` | Show quarterly rocks for current user | Fallback |
| `rocks {year}` | Show rocks for a specific year | Fallback |
| `rocks {user_id}` | Show rocks for another user (must share a team) | Fallback |
| `feedback given` | Show feedback given by current user | Fallback |
| `feedback received` | Show feedback received by current user | Fallback |
| `feedback {user_id} given\|received` | Show feedback for another user (must share a team) | Fallback |
| `progress` | Show personal progress dashboard (strategy metrics + practice scorecard) | Fallback |
| `progress {period}` | Progress filtered to period: `week`, `month`, or `quarter` | Fallback |
| `integrations` | Show current third-party integration selections | Fallback |
| `integrations set {category} {value}` | Update an integration selection (with confirmation) | Fallback |

---

## Measurables — `list_measurables`

Triggered by: `measurables` or `measurables {user_id}`.

Call `list_measurables` with `user_id` (never `team_id`). The connector has no "me": for `measurables {user_id}` pass that ID; for the user's own list pass their own numeric ID only when it is already known in this conversation (never guess), otherwise use the Fallback read `GET /users/me/measurables` with the same display. It answers JSON `{data, meta}`; each row has `id`, `name`, `target_value`, `is_archived` and `values` (archived rows are left out by default).

For each measurable, read the most recent entry from the `values` array for `value` and `on_track`. If `data` is empty: "No measurables found." — stop.

Header: `## My Measurables` (or `## Measurables for User {USER_ID}` if a specific user ID was given).

```
| ID  | Name | Target | Latest | On Track |
|-----|------|--------|--------|----------|
| {id} | {name} | {target_value} {target_unit} | {latest value or —} | ✓ / ✗ / — |

{N} measurables
```

- `target_value`: show as-is; if null show "—"; append `target_unit` if present.
- `on_track` from most recent `values` entry: `true` → ✓, `false` → ✗, null/absent → "—".

Errors: "Person not found or you don't have access to them." → "User {USER_ID} not found, or you don't share a team with them." Tools missing, or an authorization error → "The ResultKit connector isn't connected. Connect it (https://mcp.resultkit.ai) and try again." Any other `Error: …` → show it as returned.

---

## Fallback (api.sh)

The connector has no tool for the flows below (`list_rocks` reads one quarter at a time — the current quarter by default, no all-quarters option — so it cannot replace the Rocks read), so they run as before: `RESPONSE=$("<api.sh path>" METHOD PATH [BODY])` returns `{status, body}`.

**Before every call.** Set `API_SH` to the api.sh path from Current State. NOT_FOUND → "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`" — stop. Config MISSING → "Config not found. Run `/rkit:setup` first." — stop.

**Errors common to every call.** `"error": "NO_CONFIG"` or `"NO_TOKEN"` → "Config not found. Run `/rkit:setup` first." · `"error": "CURL_FAILED"` → "Network error. Check your connection." · `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token." · other non-200 → show the status code and error from the response body. Flow-specific statuses are listed with each flow. **Pagination** (members, rocks, feedback): request `per_page=100&page=N` from `N=1`, read `body.meta.total_pages` on the first page, append each page's `body.data`, and stop after the last page.

### Stats — *(no args)*, `stats`, `stats {user_id}`

`USER_ID` is `{user_id}` from args, else `me`. `GET /users/${USER_ID}/stats`. `403` → "Access denied (403). You must share a team with user {USER_ID} to view their stats." · `404` → "User {USER_ID} not found (404)." On 200 show, from `body.data`:

```
## My Stats
```
(or `## Stats for User {USER_ID}` if a specific user ID was given)

```
Wins given:       {wins_given}
Wins received:    {wins_received}
Goals aspired:    {goals_aspired}
Goals realized:   {goals_realized}
Actions done:     {actions_done}
```

### View preferences — `prefs`

`GET /users/me/preferences`. From `body.data`; include the user's numeric `id` in the header (use `body.data.id` if present). Format notification booleans as ON (true) or OFF (false):

```
## My Preferences (ID: {id})

**Profile**
Login:            {login}
Name:             {first_name} {last_name}
Email:            {email}
Timezone:         {time_zone}
Preferred team:   {preferred_team_id}

**Notifications**
  Morning day-ahead:   {morning_day_ahead → ON/OFF}
  End-of-day digest:   {end_of_day_digest → ON/OFF}
  Weekly digest (Fri): {weekly_digest_friday → ON/OFF}
  Week-ahead (Sun):    {week_ahead_sunday → ON/OFF}

**Settings**
Update frequency:   {update_frequency}
Startup view:       {startup_view_label} ({startup_view_code})
Slack username:     {slack_username or "—"}
Subscriber persona: {subscriber_persona}
```

### Update preferences — `prefs set {field} {value}`

Valid top-level fields: `login`, `first_name`, `last_name`, `time_zone`, `preferred_team_id`, `secondary_email`, `update_frequency`, `unsubscribe_all`, `startup_view_code`, `slack_username`

`first_name` / `last_name` are how a person corrects their own name; they apply only to the caller. Sending `""` (or whitespace) **clears** the field — omit the key to leave it alone. Max 100 chars, refused rather than truncated.

Valid notification fields: `notifications.morning_day_ahead`, `notifications.end_of_day_digest`, `notifications.weekly_digest_friday`, `notifications.week_ahead_sunday`

1. **Validate.** `{field}` not in the lists above: "Unknown preference field '{field}'. Run `/rkit:profile prefs` to see available fields." — stop. `{value}` missing: "Usage: `/rkit:profile prefs set {field} {value}`" — stop.
2. **Fetch current** with `GET /users/me/preferences` (errors as above); the current value of `{field}` is in `body.data` (notification fields: `body.data.notifications.{subfield}`).
3. **Confirm** with AskUserQuestion, showing the diff — declined: "Cancelled." — stop.

   ```
   Update preferences?
     {field}: '{current_value}' → '{new_value}'
   Confirm?
   ```

4. **Body.** Top-level field: `{"time_zone": "{value}"}`. Notification field: `{"notifications": {"morning_day_ahead": {value_as_bool}}}`. Boolean fields (`unsubscribe_all`, notification fields) accept "true"/"false" and "on"/"off" (on→true, off→false).
5. **Send** `PATCH /users/me/preferences` with the body. `422` → show the validation error from `body.errors` or `body.error.message`. `200` → "Preferences updated."

### Change password — `password`

1. Config MISSING → "Config not found. Run `/rkit:setup` first." — stop. Fetch `GET /users/me/preferences` and take `body.data.email` for the confirmation prompt; if the fetch fails, use "your account".
2. AskUserQuestion, in sequence: current password (clarify: "Leave blank if you are an OAuth user without an existing password"), new password, confirm new password.
3. New password ≠ confirm password: "Password confirmation does not match." — stop (do NOT call the API).
4. AskUserQuestion — declined: "Cancelled." — stop:

   ```
   Change account password for {email}?
   Confirm?
   ```

5. Send `POST /users/me/password` with `{"current_password":"…","password":"…","password_confirmation":"…"}`, omitting `current_password` when it was left blank.
6. `422` → show the field-level errors from `body.errors` (e.g., "Current password is incorrect."). `200` and `body.data.success == true` → current password blank: "Password set successfully."; otherwise "Password changed successfully."

### Accounts and members — `account`, `account members [{account_id}]`

`GET /users/me/accounts`. `200` with empty `data` → "No accounts found." — stop. For `account` (no `members`) display, then stop:

```
## My Accounts

| ID | Name       | Owner |
|----|------------|-------|
|  5 | Acme Corp  | Yes   |
| 12 | Beta Inc   | No    |

2 accounts
```

For `account members`, resolve the account: `{account_id}` from args; else the only account; else (several, none given) AskUserQuestion listing each ID and name. Then page through `GET /accounts/${ACCOUNT_ID}/members?per_page=100&page=${PAGE}`.

`403` → "Access denied (403). You must be an account member to view this." · `404` → "Account {ACCOUNT_ID} not found (404)." Display (Name: `first_name last_name`, fallback to `login`; Owner: `is_owner` → "Yes"/"No"):

```
## Account Members — {account_name} (ID: {account_id})

| Name        | Email                | ID  | Owner |
|-------------|----------------------|-----|-------|
| Jane Doe    | jane@company.com     | 42  | Yes   |
| John Smith  | john@company.com     | 55  | No    |

{N} members
```

### Remove account member — `account members remove {user_id} [{account_id}]`

1. `{user_id}` is required: "Usage: `/rkit:profile account members remove {user_id} [account_id]`" — stop. Resolve `{account_id}` as above.
2. Fetch the account list and the members (as above) to get the target's name and email. No member with `id == {user_id}`: "User {user_id} is not a member of account {account_id}." — stop.
3. AskUserQuestion — declined: "Cancelled." — stop:

   ```
   Remove {first_name last_name} ({email}, ID: {user_id}) from account {account_name} (ID: {account_id})?
   This cannot be undone. Confirm?
   ```

4. `DELETE /accounts/${ACCOUNT_ID}/members/${USER_ID}`. `204` → "{name} (ID: {user_id}) removed from account." · `403` → "Access denied (403). Only the account owner can remove members." · `404` → "Account or member not found (404)." · `422` → show the error message (e.g., "Cannot remove the account owner.").

### Progress — `progress`, `progress {period}`

`PERIOD` is `week`, `month` or `quarter` when given. `GET /users/me/progress`, adding `?period=${PERIOD}` when `PERIOD` is set (an invalid period: the API returns an error — show the status code and message from the response body). `403`/`404` do not apply (always `/users/me/progress`).

From `body.data`:

```
## My Progress

**Targets**
Rocks realized (all time):          {targets.rocks_realized_all_time}
Milestones realized (all time):     {targets.milestones_realized_all_time}
Milestones realized (this quarter): {targets.milestones_realized_this_quarter}

**Practice Streak**
Current streak:  {practice_totals.current_streak} days
Longest streak:  {practice_totals.longest_streak} days
All-time days:   {practice_totals.all_time}

**Practice Scorecard**
{for each entry in practice_scorecard.days: "{day_name} {date}  ✓" or "{day_name} {date}  ✗"}
```

### Rocks — `rocks`, `rocks {year}`, `rocks {user_id}`

A 4-digit integer is a year (`YEAR`, `USER_ID=me`); another integer is `USER_ID` (no year filter); no arg is `USER_ID=me`, no year filter. Page through `GET /users/${USER_ID}/rocks?per_page=100&page=${PAGE}`, adding `&year=${YEAR}` when `YEAR` is set.

On the first page: `403` → "Access denied (403). You must share a team with user {USER_ID} to view their data." · `404` → "User {USER_ID} not found (404)." Empty result: "No rocks found." — stop. Header: `## My Rocks` / `## Rocks ({YEAR})` / `## Rocks for User {USER_ID}` as appropriate.

```
| ID  | Rock | Status   | Due        | Milestones | Team |
|-----|------|----------|------------|------------|------|
| {id} | {name} | {status_label} | {due_date or —} | {milestones_completed}/{milestones_total} | {team.name} |

{N} rocks
```

Status labels: `on_track` → "On Track", `off_track` → "Off Track", `completed` → "Done", `dropped` → "Dropped".

### Feedback — `feedback given`, `feedback received`, `feedback {user_id} given|received`

`DIRECTION` is the first "given" or "received" in args; `USER_ID` is the first numeric arg, else `me`. `DIRECTION` missing → AskUserQuestion "Which direction?" with options "given" / "received". Page through `GET /users/${USER_ID}/feedback?direction=${DIRECTION}&per_page=100&page=${PAGE}`.

On the first page: `403` → "Access denied (403). You must share a team with user {USER_ID} to view their data." · `404` → "User {USER_ID} not found (404)." Empty result: "No feedback found." — stop.

**For `received`:** Header: `## Feedback Received` (or `## Feedback Received by User {USER_ID}`).

```
| ID  | From | Message | Date |
|-----|------|---------|------|
| {id} | {from_user.first_name} {from_user.last_name} | {message truncated at 60 chars} | {created_at, date only} |

{N} items
```

**For `given`:** Header: `## Feedback Given` (or `## Feedback Given by User {USER_ID}`).

```
| ID  | To | Message | Date |
|-----|-----|---------|------|
| {id} | {to_user.first_name} {to_user.last_name} | {message truncated at 60 chars} | {created_at, date only} |

{N} items
```

### Integrations — `integrations`, `integrations set {category} {value}`

View: `GET /users/me/integrations`. Each category in `body.data` has `selected` (string or null) and `options` (array of strings):

```
## My Integrations

Task Management:   {task_management.selected or —}    (options: {task_management.options, comma-joined})
Sales / RevOps:    {sales_revops.selected or —}        (options: {sales_revops.options, comma-joined})
Team Comms:        {team_communication.selected or —}  (options: {team_communication.options, comma-joined})
```

Set: `CATEGORY` and `VALUE` are the two words after `set`.

1. `CATEGORY` not one of `task_management`, `sales_revops`, `team_communication`: "Unknown category '{CATEGORY}'. Valid categories: task_management, sales_revops, team_communication." — stop. `VALUE` missing: "Usage: `/rkit:profile integrations set {category} {value}`" — stop.
2. `VALUE` of `none` or `null` is JSON `null` (disconnects the integration); otherwise a quoted string.
3. Fetch the current `selected` for `CATEGORY` (`GET /users/me/integrations`, `body.data.{CATEGORY}.selected`; show "—" if null).
4. Confirm with AskUserQuestion — declined: "Cancelled." — stop:

   ```
   Update {category}: '{current_value or —}' → '{VALUE}'?
   Confirm?
   ```

5. Send `PATCH /users/me/integrations` with `{"${CATEGORY}": null}` for `null`, else `{"${CATEGORY}": "${VALUE}"}`.
6. `422` → show the validation error from `body.errors` or `body.error.message`. `200` → "Integrations updated."

---

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
