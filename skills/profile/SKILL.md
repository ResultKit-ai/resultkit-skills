---
name: rkit:profile
description: View your profile stats, measurables (scorecard), rocks (quarterly goals), feedback (High5s), personal progress dashboard, and third-party integrations. Manage preferences, change your password, and manage account members. Use this skill when users ask about their personal stats, wins, goals realized, actions done, measurables, scorecard, rocks, quarterly goals, feedback, High5s, progress, integrations, want to view or update their preferences (timezone, notifications, startup view), change their account password, or manage account members (list, remove).
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), AskUserQuestion
---

# rkit:profile

View profile stats, manage preferences, change password, and manage account members.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh: !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/profile/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/profile/scripts/api.sh "$HOME/.claude/skills/rkit:profile/scripts/api.sh" "$HOME/.agents/skills/profile/scripts/api.sh" "$HOME/.gemini/skills/profile/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes.** PATCH preferences, POST password, and DELETE account member require confirmation before executing. All GET operations execute immediately.
- **Show IDs.** Always include user ID, account ID, and member IDs in output.
- **Concise output.** Tables for account members. Labeled key-value for stats and preferences. No filler.
- **Direct execution.** Use Bash with api.sh for all API calls. Never use Task agents.

## Argument Parsing

| Input | Behavior |
|-------|----------|
| *(no args)* | Show stats for the current user (same as `stats`) |
| `stats` | Show personal performance stats for current user |
| `stats {user_id}` | Show stats for another user (must share a team) |
| `prefs` | View all current preferences |
| `prefs set {field} {value}` | Update a single preference field (with confirmation) |
| `password` | Interactively change account password |
| `account` | Show current user's accounts with ownership status |
| `account members [{account_id}]` | List account members (prompts if multiple accounts) |
| `account members remove {user_id} [{account_id}]` | Remove a member from an account (owner-only, with confirmation) |
| `measurables` | Show scorecard metrics for current user |
| `measurables {user_id}` | Show scorecard metrics for another user (must share a team) |
| `rocks` | Show quarterly rocks for current user |
| `rocks {year}` | Show rocks for a specific year |
| `rocks {user_id}` | Show rocks for another user (must share a team) |
| `feedback given` | Show feedback given by current user |
| `feedback received` | Show feedback received by current user |
| `feedback {user_id} given\|received` | Show feedback for another user (must share a team) |
| `progress` | Show personal progress dashboard (strategy metrics + practice scorecard) |
| `progress {period}` | Progress filtered to period: `week`, `month`, or `quarter` |
| `integrations` | Show current third-party integration selections |
| `integrations set {category} {value}` | Update an integration selection (with confirmation) |

---

## Flow: Stats

Triggered by: *(no args)*, `stats`, or `stats {user_id}`

### Step 1: Resolve user ID and api.sh path

From Current State:
- Extract `API_SH` path. If NOT_FOUND: "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`" — stop.
- If config is MISSING: "Config not found. Run `/rkit:setup` first." — stop.
- If `stats {user_id}` in args: `USER_ID={user_id}`. Otherwise: `USER_ID=me`.

### Step 2: Fetch stats

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/users/${USER_ID}/stats")
echo "$RESPONSE"
```

### Step 3: Handle response

**Error responses:**
- `"error": "NO_CONFIG"` or `"error": "NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 403` → "Access denied (403). You must share a team with user {USER_ID} to view their stats."
- `status: 404` → "User {USER_ID} not found (404)."
- Other non-200 → Show status code and error from response body.

**Success (status 200):**

Extract from `body.data`. Display:

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

---

## Flow: View Preferences

Triggered by: `prefs`

### Step 1: Resolve api.sh and config

Same checks as Stats Step 1 (api.sh resolution, config check).

### Step 2: Fetch preferences

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/users/me/preferences")
echo "$RESPONSE"
```

### Step 3: Handle response

**Error responses:**
- `"error": "NO_CONFIG"` or `"error": "NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- Other non-200 → Show status code and error from response body.

**Success (status 200):**

Extract from `body.data`. Include user's numeric `id` in the header (use `body.data.id` if present). Format notification booleans as ON (true) or OFF (false). Display:

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

---

## Flow: Update Preferences

Triggered by: `prefs set {field} {value}`

### Known preference fields

Valid top-level fields: `login`, `first_name`, `last_name`, `time_zone`, `preferred_team_id`, `secondary_email`, `update_frequency`, `unsubscribe_all`, `startup_view_code`, `slack_username`

`first_name` / `last_name` are how a person corrects their own name; they apply only to the caller. Sending `""` (or whitespace) **clears** the field — omit the key to leave it alone. Max 100 chars, refused rather than truncated.

Valid notification fields: `notifications.morning_day_ahead`, `notifications.end_of_day_digest`, `notifications.weekly_digest_friday`, `notifications.week_ahead_sunday`

### Step 1: Validate args

- Extract `{field}` and `{value}` from args.
- If `{field}` is not in the known fields list: "Unknown preference field '{field}'. Run `/rkit:profile prefs` to see available fields." — stop.
- If `{value}` is missing: "Usage: `/rkit:profile prefs set {field} {value}`" — stop.

### Step 2: Fetch current preferences

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/users/me/preferences")
echo "$RESPONSE"
```

Handle errors as in View Preferences Step 3.

Extract the current value for `{field}` from `body.data` (for notification fields use `body.data.notifications.{subfield}`).

### Step 3: Confirm

Show the diff and use AskUserQuestion to confirm:

```
Update preferences?
  {field}: '{current_value}' → '{new_value}'
Confirm?
```

If user declines: "Cancelled." — stop.

### Step 4: Build request body

- Top-level field (e.g., `time_zone`): body = `{"time_zone": "{value}"}`
- Notification field (e.g., `notifications.morning_day_ahead`): body = `{"notifications": {"morning_day_ahead": {value_as_bool}}}`
- Boolean fields (`unsubscribe_all`, notification fields): accept "true"/"false" and "on"/"off" (on→true, off→false).

### Step 5: Send PATCH

```bash
RESPONSE=$("$API_SH" PATCH "/users/me/preferences" '{<body>}')
echo "$RESPONSE"
```

### Step 6: Handle response

- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 422` → Show validation error from `body.errors` or `body.error.message`.
- Other non-200 → Show status code and error.
- `status: 200` → "Preferences updated."

---

## Flow: Change Password

Triggered by: `password`

### Step 1: Resolve config and get email

From Current State:
- If config is MISSING: "Config not found. Run `/rkit:setup` first." — stop.
- Resolve api.sh path.

Fetch preferences to get the user's email for the confirmation prompt:

```bash
PREF_RESP=$("$API_SH" GET "/users/me/preferences")
```

Extract `email` from `body.data.email`. If fetch fails, proceed without email (use "your account").

### Step 2: Prompt for passwords

Use AskUserQuestion to collect, in sequence:
1. Current password (clarify: "Leave blank if you are an OAuth user without an existing password")
2. New password
3. Confirm new password

### Step 3: Client-side validation

If new password ≠ confirm password: "Password confirmation does not match." — stop (do NOT call the API).

### Step 4: Confirm

Use AskUserQuestion:

```
Change account password for {email}?
Confirm?
```

If user declines: "Cancelled." — stop.

### Step 5: Build request body and send

```bash
# Omit current_password if blank
if [ -n "$CURRENT_PASSWORD" ]; then
  BODY="{\"current_password\":\"$CURRENT_PASSWORD\",\"password\":\"$NEW_PASSWORD\",\"password_confirmation\":\"$CONFIRM_PASSWORD\"}"
else
  BODY="{\"password\":\"$NEW_PASSWORD\",\"password_confirmation\":\"$CONFIRM_PASSWORD\"}"
fi
RESPONSE=$("$API_SH" POST "/users/me/password" "$BODY")
echo "$RESPONSE"
```

### Step 6: Handle response

- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 422` → Show field-level errors from `body.errors` (e.g., "Current password is incorrect.").
- Other non-200 → Show status code and error.
- `status: 200` and `body.data.success == true`:
  - If current password was blank → "Password set successfully."
  - Otherwise → "Password changed successfully."

---

## Flow: List Account Members

Triggered by: `account`, `account members`, or `account members [{account_id}]`

### Step 1: Resolve api.sh and config

Same checks as Stats Step 1.

### Step 2: Fetch account list

```bash
API_SH="<api.sh path from Current State>"
ACCOUNTS_RESP=$("$API_SH" GET "/users/me/accounts")
echo "$ACCOUNTS_RESP"
```

**Error responses:**
- `"error": "NO_CONFIG"` or `"error": "NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- Other non-200 → Show status code and error.
- `status: 200` with empty `data` array → "No accounts found." — stop.

**For `account` subcommand (no `members`):**

Display the accounts list:

```
## My Accounts

| ID | Name       | Owner |
|----|------------|-------|
|  5 | Acme Corp  | Yes   |
| 12 | Beta Inc   | No    |

2 accounts
```

Then stop.

### Step 3: Resolve which account to use (for `account members`)

- If `{account_id}` provided in args: use it.
- If only one account in list: use it automatically.
- If multiple accounts and no `{account_id}`: use AskUserQuestion to display account options (ID + name) and ask which to view members for.

### Step 4: Fetch members with pagination

```bash
PAGE=1
ALL_MEMBERS="[]"
TOTAL_PAGES=1
while [ "$PAGE" -le "$TOTAL_PAGES" ]; do
  MEMBERS_RESP=$("$API_SH" GET "/accounts/${ACCOUNT_ID}/members?per_page=100&page=${PAGE}")
  # Append body.data to ALL_MEMBERS
  # Set TOTAL_PAGES from body.meta.total_pages on first page
  PAGE=$((PAGE + 1))
done
```

**Error responses:**
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 403` → "Access denied (403). You must be an account member to view this."
- `status: 404` → "Account {ACCOUNT_ID} not found (404)."
- Other non-200 → Show status code and error.

### Step 5: Display members

```
## Account Members — {account_name} (ID: {account_id})

| Name        | Email                | ID  | Owner |
|-------------|----------------------|-----|-------|
| Jane Doe    | jane@company.com     | 42  | Yes   |
| John Smith  | john@company.com     | 55  | No    |

{N} members
```

- Name: `first_name last_name`, fallback to `login`.
- Owner: `is_owner` → "Yes" or "No".

---

## Flow: Remove Account Member

Triggered by: `account members remove {user_id} [{account_id}]`

### Step 1: Validate args

- Extract `{user_id}` (required). If missing: "Usage: `/rkit:profile account members remove {user_id} [account_id]`" — stop.
- Resolve `{account_id}` using the same logic as List Account Members Step 3.

### Step 2: Fetch member details

Run the same account list and member pagination fetch as List Account Members Steps 2–4 to get the target member's name and email.

Find the member with `id == {user_id}`. If not found: "User {user_id} is not a member of account {account_id}." — stop.

### Step 3: Confirm

Use AskUserQuestion:

```
Remove {first_name last_name} ({email}, ID: {user_id}) from account {account_name} (ID: {account_id})?
This cannot be undone. Confirm?
```

If user declines: "Cancelled." — stop.

### Step 4: Send DELETE

```bash
RESPONSE=$("$API_SH" DELETE "/accounts/${ACCOUNT_ID}/members/${USER_ID}")
echo "$RESPONSE"
```

### Step 5: Handle response

- `status: 204` → "{name} (ID: {user_id}) removed from account."
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 403` → "Access denied (403). Only the account owner can remove members."
- `status: 404` → "Account or member not found (404)."
- `status: 422` → Show error message (e.g., "Cannot remove the account owner.").
- Other non-200 → Show status code and error.

---

## Flow: Progress

Triggered by: `progress` or `progress {period}`

### Step 1: Resolve api.sh and config

Same checks as Stats Step 1 (api.sh resolution, config check).

### Step 2: Build request

Extract optional `PERIOD` from args (valid values: `week`, `month`, `quarter`). Build URL:

```bash
API_SH="<api.sh path from Current State>"
URL="/users/me/progress"
[ -n "$PERIOD" ] && URL="${URL}?period=${PERIOD}"
RESPONSE=$("$API_SH" GET "$URL")
echo "$RESPONSE"
```

### Step 3: Handle response

**Error responses:**
- `"error": "NO_CONFIG"` or `"error": "NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- Other non-200 → Show status code and error from response body.

*(403/404 not applicable — endpoint is always `/users/me/progress`; no `{user_id}` param.)*

**Success (status 200):**

Extract from `body.data`. Display:

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

---

## Flow: Measurables

Triggered by: `measurables` or `measurables {user_id}`

### Step 1: Resolve api.sh and config

Same checks as Stats Step 1.

### Step 2: Resolve user ID

Extract numeric `USER_ID` from args. If a numeric argument is provided, use it. Otherwise: `USER_ID=me`.

### Step 3: Fetch measurables

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/users/${USER_ID}/measurables")
echo "$RESPONSE"
```

### Step 4: Handle response

**Error responses:**
- `"error": "NO_CONFIG"` or `"error": "NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 403` → "Access denied (403). You must share a team with user {USER_ID} to view their data."
- `status: 404` → "User {USER_ID} not found (404)."
- Other non-200 → Show status code and error.

**Success (status 200):**

Extract from `body.data`. For each measurable, read the most recent entry from the `values` array for `value` and `on_track`.

If array is empty: "No measurables found." — stop.

Header: `## My Measurables` (or `## Measurables for User {USER_ID}` if a specific user ID was given).

```
| ID  | Name | Target | Latest | On Track |
|-----|------|--------|--------|----------|
| {id} | {name} | {target_value} {target_unit} | {latest value or —} | ✓ / ✗ / — |

{N} measurables
```

- `target_value`: show as-is; if null show "—"; append `target_unit` if present.
- `on_track` from most recent `values` entry: `true` → ✓, `false` → ✗, null/absent → "—".

---

## Flow: Rocks

Triggered by: `rocks`, `rocks {year}`, or `rocks {user_id}`

### Step 1: Resolve api.sh and config

Same checks as Stats Step 1.

### Step 2: Parse args and build URL

- If arg is a 4-digit integer (e.g., `2025`): set `YEAR=${arg}`, `USER_ID=me`
- If arg is a non-year integer: set `USER_ID=${arg}`, no year filter
- If no arg: `USER_ID=me`, no year filter

### Step 3: Paginated fetch

```bash
API_SH="<api.sh path from Current State>"
PAGE=1
ALL_ROCKS="[]"
TOTAL_PAGES=1
while [ "$PAGE" -le "$TOTAL_PAGES" ]; do
  URL="/users/${USER_ID}/rocks?per_page=100&page=${PAGE}"
  [ -n "$YEAR" ] && URL="${URL}&year=${YEAR}"
  RESPONSE=$("$API_SH" GET "$URL")
  # On first page: extract TOTAL_PAGES from body.meta.total_pages
  # Append body.data items to ALL_ROCKS
  PAGE=$((PAGE + 1))
done
```

### Step 4: Handle response

**Error responses (on first page):**
- `"error": "NO_CONFIG"` or `"error": "NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 403` → "Access denied (403). You must share a team with user {USER_ID} to view their data."
- `status: 404` → "User {USER_ID} not found (404)."
- Other non-200 → Show status code and error.

**Success (status 200):**

If result is empty: "No rocks found." — stop.

Header: `## My Rocks` / `## Rocks ({YEAR})` / `## Rocks for User {USER_ID}` as appropriate.

```
| ID  | Rock | Status   | Due        | Milestones | Team |
|-----|------|----------|------------|------------|------|
| {id} | {name} | {status_label} | {due_date or —} | {milestones_completed}/{milestones_total} | {team.name} |

{N} rocks
```

Status labels: `on_track` → "On Track", `off_track` → "Off Track", `completed` → "Done", `dropped` → "Dropped".

---

## Flow: Feedback

Triggered by: `feedback given`, `feedback received`, or `feedback {user_id} given|received`

### Step 1: Resolve api.sh and config

Same checks as Stats Step 1.

### Step 2: Parse args

- Extract `DIRECTION`: first occurrence of "given" or "received" in args.
- Extract `USER_ID`: first numeric arg, or `me` if none.
- If `DIRECTION` is missing: use AskUserQuestion to prompt "Which direction?" with options "given" / "received".

### Step 3: Paginated fetch

```bash
API_SH="<api.sh path from Current State>"
PAGE=1
ALL_FEEDBACK="[]"
TOTAL_PAGES=1
while [ "$PAGE" -le "$TOTAL_PAGES" ]; do
  RESPONSE=$("$API_SH" GET "/users/${USER_ID}/feedback?direction=${DIRECTION}&per_page=100&page=${PAGE}")
  # On first page: extract TOTAL_PAGES from body.meta.total_pages
  # Append body.data items to ALL_FEEDBACK
  PAGE=$((PAGE + 1))
done
```

### Step 4: Handle response

**Error responses (on first page):**
- `"error": "NO_CONFIG"` or `"error": "NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 403` → "Access denied (403). You must share a team with user {USER_ID} to view their data."
- `status: 404` → "User {USER_ID} not found (404)."
- Other non-200 → Show status code and error.

**Success (status 200):**

If result is empty: "No feedback found." — stop.

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

---

## Flow: View Integrations

Triggered by: `integrations`

### Step 1: Resolve api.sh and config

Same checks as Stats Step 1.

### Step 2: Fetch integrations

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/users/me/integrations")
echo "$RESPONSE"
```

### Step 3: Handle response

**Error responses:**
- `"error": "NO_CONFIG"` or `"error": "NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- Other non-200 → Show status code and error.

**Success (status 200):**

Extract from `body.data`. Each category has `selected` (string or null) and `options` (array of strings).

```
## My Integrations

Task Management:   {task_management.selected or —}    (options: {task_management.options, comma-joined})
Sales / RevOps:    {sales_revops.selected or —}        (options: {sales_revops.options, comma-joined})
Team Comms:        {team_communication.selected or —}  (options: {team_communication.options, comma-joined})
```

---

## Flow: Update Integrations

Triggered by: `integrations set {category} {value}`

### Step 1: Resolve api.sh and config

Same checks as Stats Step 1.

### Step 2: Validate args

Extract `CATEGORY` and `VALUE` from args (the two words following `set`).

- If `CATEGORY` is not one of `task_management`, `sales_revops`, `team_communication`:
  "Unknown category '{CATEGORY}'. Valid categories: task_management, sales_revops, team_communication." — stop.
- If `VALUE` is missing: "Usage: `/rkit:profile integrations set {category} {value}`" — stop.

### Step 3: Translate value

- If `VALUE` is `none` or `null`: treat as JSON `null` (disconnects the integration).
- Otherwise: treat as a quoted string value.

### Step 4: Fetch current integrations

```bash
API_SH="<api.sh path from Current State>"
CURRENT_RESP=$("$API_SH" GET "/users/me/integrations")
```

Extract the current `selected` value for `CATEGORY` from `body.data.{CATEGORY}.selected` (show "—" if null).

### Step 5: Confirm

Use AskUserQuestion:

```
Update {category}: '{current_value or —}' → '{VALUE}'?
Confirm?
```

If user declines: "Cancelled." — stop.

### Step 6: Send PATCH

```bash
# null value:
BODY="{\"${CATEGORY}\": null}"
# string value:
BODY="{\"${CATEGORY}\": \"${VALUE}\"}"

RESPONSE=$("$API_SH" PATCH "/users/me/integrations" "$BODY")
echo "$RESPONSE"
```

### Step 7: Handle response

- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 422` → Show validation error from `body.errors` or `body.error.message`.
- Other non-200 → Show status code and error.
- `status: 200` → "Integrations updated."

---

## Edge Cases

- **No config**: "Config not found. Run `/rkit:setup` first."
- **api.sh not found**: "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"
- **Stats — 403 (no shared team)**: "Access denied (403). You must share a team with user {id} to view their stats."
- **Stats — 404**: "User {id} not found (404)."
- **Prefs update — unknown field**: "Unknown preference field '{field}'. Run `/rkit:profile prefs` to see available fields."
- **Prefs update — no value**: "Usage: `/rkit:profile prefs set {field} {value}`"
- **Password — mismatch**: "Password confirmation does not match." (client-side, no API call)
- **Password — wrong current password (422)**: "Current password is incorrect." (from `errors` object)
- **Password — OAuth user (no existing password)**: Leave current_password blank; skill omits it from request.
- **Account members — no accounts**: "No accounts found."
- **Account members — multiple accounts, none specified**: Prompt user to choose one.
- **Account member removal — not owner (403)**: "Access denied (403). Only the account owner can remove members."
- **Account member removal — remove owner (422)**: "Cannot remove the account owner."
- **Account member removal — user not in account**: "User {id} is not a member of account {account_id}."
- **Progress — invalid period**: The API returns an error; show the status code and error message from response body.
- **Measurables — 403 (no shared team)**: "Access denied (403). You must share a team with user {id} to view their data."
- **Measurables — 404**: "User {id} not found (404)."
- **Measurables — empty list**: "No measurables found."
- **Rocks — 403 (no shared team)**: "Access denied (403). You must share a team with user {id} to view their data."
- **Rocks — 404**: "User {id} not found (404)."
- **Rocks — empty list**: "No rocks found."
- **Feedback — direction missing**: Prompt user with AskUserQuestion for "given" or "received".
- **Feedback — 403 (no shared team)**: "Access denied (403). You must share a team with user {id} to view their data."
- **Feedback — 404**: "User {id} not found (404)."
- **Feedback — empty list**: "No feedback found."
- **Integrations set — invalid category**: "Unknown category '{cat}'. Valid categories: task_management, sales_revops, team_communication."
- **Integrations set — missing value**: "Usage: `/rkit:profile integrations set {category} {value}`"

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
