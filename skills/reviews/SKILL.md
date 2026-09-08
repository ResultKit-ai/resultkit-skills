---
name: rkit:reviews
description: View and manage performance reviews, submit assessments, sign off, and rate core values. Use this skill when users mention reviews, performance reviews, assessments, self-assessments, reviewer assessments, sign-off, core values, or core value ratings.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Read, Glob, Grep, AskUserQuestion
---

# rkit:reviews

## Current State

- Config status: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING"; fi`
- api.sh: !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/reviews/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/reviews/scripts/api.sh "$HOME/.claude/skills/rkit:reviews/scripts/api.sh" "$HOME/.agents/skills/reviews/scripts/api.sh" "$HOME/.gemini/skills/reviews/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes**: Before any POST/PUT/PATCH/DELETE, summarize all planned changes in a single prompt and ask for confirmation. If the command implies multiple related mutations, batch them under one confirmation. GET requests execute immediately.
- **Show IDs**: Always include review, template, and core value IDs in output so users can reference them.
- **Concise output**: Tables and short summaries. No verbose prose.
- **Direct execution**: Use Bash for all API calls via api.sh. Never use Task agents or subagents.

## Error Handling

Parse the JSON response from api.sh. Handle these cases:

- `"error": "NO_CONFIG"` or `"error": "NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 400` on reviews list → If error contains "team_id": "Invalid team ID." Otherwise show the API's error message.
- `status: 400` on template PATCH → If error message contains "owning organization": "Cannot change owning organization after creation." Otherwise show the API's error message.
- `status: 422` on template POST/PATCH → If error message contains "not root teams": "Organization ID(s) must be root teams (no sub-teams)." Otherwise show validation error from response body.
- `status: 404` on reviews list with `team_id` → "Team not found or not accessible."
- `status: 403` → Review-specific messages:
  - Sign-off actions: "You must be the reviewer to sign off."
  - Template create/update/delete actions: "Admin on the owning team required."
  - Create/void/archive actions: "Admin/people-ops permissions required."
  - Assessment actions: Show the API's error message.
- `status: 404` → "Not found (404)."
- `status: 422` → Show validation error from response body.
- Other non-200 → Show status code and error from response body.

---

## Team ID Resolution

1. **`--team {id}` flag** in args → use that team ID
2. **`default_team_id` in config** → use that
3. **Neither** → no team filter applied

---

## Argument Parsing

Parse the user input to determine which flow to follow:

| Input | Flow |
|-------|------|
| *(no args)* | List Reviews |
| `{id}` or `show {id}` | View Review Detail |
| `{id} assess` | Assess Review |
| `{id} draft` | Draft Assessment |
| `{id} sign-off` | Sign Off Review |
| `create` | Create Review |
| `{id} void` | Void Review |
| `{id} archive` | Archive Review |
| `values` | List Core Values |
| `rate {user_id}` | Rate Core Values |
| `templates` or `templates list` | List Templates |
| `templates create` | Create Template |
| `templates {id} update` | Update Template |
| `templates {id} delete` | Delete Template |
| `templates {id} archive` | Archive Template |
| `templates {id} unarchive` or `templates {id} restore` | Unarchive Template |
| `--team {id}` *(anywhere in args)* | Override team ID for any flow |

If the input doesn't match any pattern, show this usage summary and ask what they'd like to do.

---

## Flow: List Reviews

**Trigger**: No args (or only `--team {id}`)

### Step 1: Fetch reviews

Resolve TEAM_ID using Team ID Resolution above. If a team ID is available, pass `team_id` to filter reviews by organization.

```bash
API_SH="<api.sh path from Current State>"
TEAM_ID="<team ID from Team ID Resolution, or empty>"
if [ -n "$TEAM_ID" ]; then
  RESPONSE=$("$API_SH" GET "/reviews?per_page=50&team_id=$TEAM_ID")
else
  RESPONSE=$("$API_SH" GET "/reviews?per_page=50")
fi
echo "$RESPONSE"
```

### Step 2: Display reviews

Display as a table:

```
## Reviews

| ID | Reviewee | Reviewer | Status | Period |
|----|----------|----------|--------|--------|
| 42 | Jane Doe | John Smith | in_progress | 2026-01-01 – 2026-03-31 |
| 38 | Mary Mejia | Scott Levy | signed_off | 2025-10-01 – 2025-12-31 |

{count} reviews
```

**Display rules**:
- `Reviewee` / `Reviewer`: show `first_name last_name`; fall back to `login` if names are empty.
- `Period`: show `start_date – end_date`; show "—" for either date if null.
- Sort by API default order.

**Empty result**: "No reviews found."

---

## Flow: View Review Detail

**Trigger**: `{id}` or `show {id}`

### Step 1: Fetch review detail

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/reviews/REVIEW_ID")
echo "$RESPONSE"
```

### Step 2: Display review

Display format:

```
## Review #42: Jane Doe ← John Smith

**Status**: in_progress | **Template**: Q1 2026 Review (ID: 5) | **Period**: 2026-01-01 – 2026-03-31

### Self Assessment

| # | Prompt | Response | Score |
|---|--------|----------|-------|
| 1 | What were your key accomplishments? | Led the migration project. | — |
| 2 | Rate your overall performance (1-5) | — | 4 |

Status: Submitted

### Reviewer Assessment

| # | Prompt | Response | Score |
|---|--------|----------|-------|
| 1 | What were your key accomplishments? | Strong leadership on migration. | — |

Status: Submitted

### Core Values Ratings

| Value | Score | Rater |
|-------|-------|-------|
| Integrity | 4 | John Smith |
| Innovation | 5 | John Smith |

### Action Items

| ID | Title | Assignee |
|----|-------|----------|
| 101 | Follow up on migration docs | Jane Doe |

### Attachments

- performance-summary.pdf
```

**Display rules**:
- Header: `Review #{id}: {reviewee_name} ← {reviewer_name}` — use `first_name last_name`; fall back to `login`.
- Template: show `name (ID: {id})` or "None" if null.
- Period: `start_date – end_date`; "—" for null dates.
- **Self Assessment**: Show `responses` array as table. Each row: prompt number, `description`, `response_value` (or "—"), `score` (or "—"). Show `is_draft` as "Status: Draft" or "Status: Submitted". Show "(none)" if `self_assessment` is null.
- **Reviewer Assessment**: Same format. Show "(none)" if `reviewer_assessment` is null. Note: API omits this field for reviewees until review reaches `signed_off` status.
- **Core Values Ratings**: Table with value name, score, rater name. Show "(none)" if empty.
- **Action Items**: Table with ID, title, assignee name. Show "(none)" if empty.
- **Attachments**: Bulleted list of filenames. Show "(none)" if empty.

---

## Flow: Assess Review

**Trigger**: `{id} assess`

### Step 1: Fetch review and validate

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/reviews/REVIEW_ID")
echo "$RESPONSE"
```

Check the `status` field. If not `in_progress` → "Review must be in progress to assess. Current status: {status}." and stop.

### Step 2: Determine respondent type

Ask the user via AskUserQuestion: "Are you the reviewee (self-assessment) or the reviewer?"

Options:
- **Self-assessment** (reviewee) → `respondent_type = "self"`
- **Reviewer assessment** → `respondent_type = "reviewer"`

If `respondent_type` is "reviewer" and the template has `reviewer_instructions`, display them before starting prompts.

### Step 3: Fetch template and walk through prompts

**If the review has a template** (`template` is not null):

```bash
API_SH="<api.sh path from Current State>"
TEMPLATE=$("$API_SH" GET "/review-templates/TEMPLATE_ID")
echo "$TEMPLATE"
```

Walk through each prompt in `prompts` array (ordered by `position`). For each prompt, use AskUserQuestion with the input method matching `answer_type`:

| Answer Type | Input Method |
|-------------|-------------|
| `range` | AskUserQuestion with numeric options derived from `answer_meta_data` (e.g., 1–5). Record as `score`. |
| `text` | AskUserQuestion with free-form short answer. Record as `response_value`. |
| `textarea` | AskUserQuestion with free-form answer. Record as `response_value`. |
| `boolean` | AskUserQuestion with Yes (score: 1) / No (score: 0). Record as `score`. |
| `multiple` | AskUserQuestion with options from `answer_meta_data`. Record as `response_value`. |

For each prompt, show: `[{position}/{total}] {description}` and the `hint` if present.

**If the review has no template** (`template` is null):

Prompt the user for a single free-form text response via AskUserQuestion: "Enter your assessment response."

### Step 4: Optional core values ratings

```bash
API_SH="<api.sh path from Current State>"
VALUES=$("$API_SH" GET "/teams/TEAM_ID/core-values")
echo "$VALUES"
```

Use TEAM_ID from Team ID Resolution above. If core values exist, ask: "Would you like to include core values ratings?" If yes, for each core value, prompt for a score (1–5) and an optional justification (text comment, up to 5000 chars, or leave blank) via AskUserQuestion. The `core_value_id` in the request body must be the label `id` returned by this endpoint.

### Step 5: Confirm and submit

Show a summary of all responses:

```
## Assessment Summary (Review #{id})

**Type**: Self-assessment
**Responses**: {count} prompts answered
**Core values rated**: {count} (or "None")

Submit this assessment?
```

Wait for confirmation. Then build the request body:

```json
{
  "respondent_type": "self",
  "assessment_responses": [
    {"prompt_id": 10, "response_value": "Led the migration project."},
    {"prompt_id": 11, "score": 4}
  ],
  "core_values_ratings": [
    {"core_value_id": 3, "score": 4, "justification": "Strong teamwork on Q4 launch"}
  ]
}
```

Include `justification` only if the user provided one (omit or set to null if blank).

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" POST "/reviews/REVIEW_ID/submit-assessment" 'REQUEST_BODY')
echo "$RESPONSE"
```

### Step 6: Handle response

- **Status 200**: "Assessment submitted for review #{id}." If both assessments are now submitted, the review transitions to `assessed` status — note this in output.
- **Error** → use Error Handling above

---

## Flow: Draft Assessment

**Trigger**: `{id} draft`

This flow is identical to **Assess Review** (Steps 1–4) with these differences:

- **Step 1**: Same — fetch review, validate `in_progress` status.
- **Step 2**: Same — determine respondent type.
- **Step 3**: Same — walk through template prompts. **Additionally**: if an existing draft exists (check `self_assessment.is_draft == true` or `reviewer_assessment.is_draft == true` for the matching respondent type), show existing `response_value` / `score` as defaults for each prompt.
- **Step 4**: Same — optional core values.
- **Step 5**: Change summary message and API call:

```
## Draft Assessment Summary (Review #{id})

**Type**: Self-assessment
**Responses**: {count} prompts answered
**Core values rated**: {count} (or "None")

Save as draft? (This does NOT advance the review state.)
```

Wait for confirmation. Then:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" PUT "/reviews/REVIEW_ID/draft-assessment" 'REQUEST_BODY')
echo "$RESPONSE"
```

- **Step 6**: "Draft saved for review #{id}. Use `/rkit:reviews {id} assess` to submit when ready."
- **Error** → use Error Handling above

---

## Flow: Sign Off Review

**Trigger**: `{id} sign-off`

### Step 1: Fetch review and validate

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/reviews/REVIEW_ID")
echo "$RESPONSE"
```

Check the `status` field. If not `assessed` → "Review must be in assessed status to sign off. Current status: {status}." and stop.

### Step 2: Collect initials and confirm

Show review summary: "Review #{id}: {reviewee_name} ← {reviewer_name} (Status: assessed)"

Prompt for initials via AskUserQuestion: "Enter your initials to sign off (e.g., JS):"

Confirm:
> Sign off review #{id} with initials "{initials}"?

Wait for confirmation. Then:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" POST "/reviews/REVIEW_ID/sign-off" '{"initials":"INITIALS"}')
echo "$RESPONSE"
```

### Step 3: Handle response

- **Status 200**: "Review #{id} signed off. Status: signed_off."
- **Status 403** → "You must be the reviewer to sign off."
- **Error** → use Error Handling above

---

## Flow: Create Review

**Trigger**: `create`

### Step 1: Collect review details

Prompt for each field via AskUserQuestion:

1. **Reviewee user ID**: "Enter the reviewee's user ID:"
2. **Reviewer user ID**: "Enter the reviewer's user ID:"
3. **Template selection**: Fetch available templates:

```bash
API_SH="<api.sh path from Current State>"
TEMPLATES=$("$API_SH" GET "/review-templates?per_page=50")
echo "$TEMPLATES"
```

Display template table:

| ID | Name | Prompts | Owning Team |
|----|------|---------|-------------|
| 5 | Q1 2026 Review | 8 | Engineering |
| 3 | Annual Review | 12 | — |

Display `owning_organization.name` for each template, or "—" if `owning_organization` is null.

Prompt: "Select a template ID:"

4. **Start date** (optional): "Enter start date (YYYY-MM-DD) or leave blank:"
5. **End date** (optional): "Enter end date (YYYY-MM-DD) or leave blank:"

### Step 2: Confirm and create

```
Create review?
- Reviewee: User #{reviewee_id}
- Reviewer: User #{reviewer_id}
- Template: {template_name} (ID: {template_id})
- Period: {start_date} – {end_date}
```

Wait for confirmation. Then:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" POST "/reviews" '{"reviewee_id":ID,"reviewer_id":ID,"template_id":ID,"start_date":"DATE","end_date":"DATE"}')
echo "$RESPONSE"
```

### Step 3: Handle response

- **Status 201**: "Review #{id} created. Status: in_progress."
- **Status 400** → If error contains "is not a member of any team": "Reviewee or reviewer must be a member of at least one team in this account." Otherwise show the API's error message.
- **Status 403** → "Admin/people-ops permissions required."
- **Error** → use Error Handling above

---

## Flow: Void Review

**Trigger**: `{id} void`

### Step 1: Fetch review

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/reviews/REVIEW_ID")
echo "$RESPONSE"
```

Show: "Review #{id}: {reviewee_name} ← {reviewer_name} (Status: {status})"

### Step 2: Collect reason and confirm

Prompt for reason via AskUserQuestion: "Enter reason for voiding this review:"

Confirm:
> Void review #{id}? Reason: "{reason}" — This blocks all further lifecycle actions.

Wait for confirmation. Then:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" PUT "/reviews/REVIEW_ID/void" '{"reason":"REASON"}')
echo "$RESPONSE"
```

### Step 3: Handle response

- **Status 200**: "Review #{id} voided."
- **Status 403** → "Admin/people-ops permissions required."
- **Error** → use Error Handling above

---

## Flow: Archive Review

**Trigger**: `{id} archive`

### Step 1: Fetch review

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/reviews/REVIEW_ID")
echo "$RESPONSE"
```

Show: "Review #{id}: {reviewee_name} ← {reviewer_name} (Status: {status})"

### Step 2: Confirm and archive

> Archive review #{id}? This removes it from the default review list.

Wait for confirmation. Then:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" DELETE "/reviews/REVIEW_ID")
echo "$RESPONSE"
```

### Step 3: Handle response

- **Status 200/204**: "Review #{id} archived."
- **Status 403** → "Admin/people-ops permissions required."
- **Error** → use Error Handling above

---

## Flow: List Core Values

**Trigger**: `values`

### Step 1: Fetch core values

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/teams/TEAM_ID/core-values")
echo "$RESPONSE"
```

Use TEAM_ID from Team ID Resolution above.

### Step 2: Display core values

Display as a table:

```
## Core Values

| ID | Name | Description |
|----|------|-------------|
| 3 | Integrity | Act with honesty and transparency |
| 7 | Innovation | Embrace creative problem-solving |

{count} core values
```

**Empty result**: "No core values defined for your organization."

---

## Flow: Rate Core Values

**Trigger**: `rate {user_id}`

### Step 1: Fetch core values

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/teams/TEAM_ID/core-values")
echo "$RESPONSE"
```

Use TEAM_ID from Team ID Resolution above.

If empty → "No core values defined for your organization. Nothing to rate." and stop.

### Step 2: Collect ratings

For each core value, prompt via AskUserQuestion: "Rate **{value_name}** (1–5):"

Options: 1, 2, 3, 4, 5

### Step 3: Confirm and submit

Show summary:

```
## Core Values Ratings for User #{user_id}

| Value | Score |
|-------|-------|
| Integrity | 4 |
| Innovation | 5 |

Submit these ratings?
```

Wait for confirmation. Then build the request body:

```json
{
  "subject_id": USER_ID,
  "ratings": [
    {"core_value_id": 3, "score": 4},
    {"core_value_id": 7, "score": 5}
  ]
}
```

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" POST "/core-values-ratings" 'REQUEST_BODY')
echo "$RESPONSE"
```

### Step 4: Handle response

- **Status 201**: "Core values ratings submitted for user #{user_id}."
- **Error** → use Error Handling above

---

## Flow: List Templates

**Trigger**: `templates` or `templates list`

### Step 1: Fetch templates

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/review-templates?per_page=50")
echo "$RESPONSE"
```

### Step 2: Display templates

Display as a table:

```
## Review Templates

| ID | Name | Prompts | Owning Organization |
|----|------|---------|---------------------|
| 5  | Q1 2026 Review | 8 | Engineering |
| 3  | Annual Review | 12 | — |

{count} templates
```

**Display rules**:
- `Owning Organization`: show `owning_organization.name`; show "—" if `owning_organization` is null.

**Empty result**: "No templates found."

**Note**: Archived templates are excluded from this list. Use `templates {id}` (detail fetch) to view an archived template by ID.

---

## Flow: Create Template

**Trigger**: `templates create`

### Step 1: Collect template details

Prompt for each field via AskUserQuestion:

1. **Name** (required): "Enter template name:"
2. **Target role** (optional): "Enter target role (or leave blank to omit):"
3. **Reviewer instructions** (optional): "Enter reviewer instructions (or leave blank to omit):"
4. **Owning organization ID** (optional): "Enter owning organization ID (must be a root team — or leave blank to use API default):"

### Step 2: Confirm and create

```
Create template?
- Name: {name}
- Target role: {target_role | "—"}
- Reviewer instructions: {reviewer_instructions | "—"}
- Owning organization ID: {owning_organization_id | "API default"}
```

Wait for confirmation. Build request body with only provided fields (omit blank optional fields). Then:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" POST "/review-templates" 'REQUEST_BODY')
echo "$RESPONSE"
```

### Step 3: Handle response

- **Status 201**: Display template detail:

```
## Template #{id} created

**Name**: {name} | **ID**: {id}
**Owning Organization**: {owning_organization.name | "—"} (ID: {owning_organization.id | "—"})
**Shared With**: {shared_with_organizations names joined by ", " | "None"}
```

- **Status 403** → "Admin on the owning organization required."
- **Error** → use Error Handling above

---

## Flow: Update Template

**Trigger**: `templates {id} update`

### Step 1: Fetch current template

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/review-templates/TEMPLATE_ID")
echo "$RESPONSE"
```

Show current values:

```
## Template #{id}: {name}

**Owning Organization**: {owning_organization.name | "—"}
**Shared With**: {shared_with_organizations names | "None"}
**Target Role**: {target_role | "—"}
**Reviewer Instructions**: {reviewer_instructions | "—"}
```

### Step 2: Collect updates

Prompt for each field via AskUserQuestion (show current value as context; blank = keep unchanged):

1. **Name** (current: "{name}"): "New name (or leave blank to keep):"
2. **Target role** (current: "{target_role | "—"}"): "New target role (or leave blank to keep):"
3. **Reviewer instructions** (current: "{reviewer_instructions | "—"}"): "New reviewer instructions (or leave blank to keep):"
4. **Share with organization IDs**: "Organization IDs to share with, comma-separated (must be root teams — enter 'none' to remove all sharing, or leave blank to keep unchanged):"

Sharing input logic:
- `none` → send `"shared_with_organization_ids": []`
- blank → omit `shared_with_organization_ids` from request body
- comma-separated IDs → send `"shared_with_organization_ids": [id1, id2, ...]`

### Step 3: Confirm and update

Show summary of changes. Wait for confirmation. Build request body with only changed fields. Then:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" PATCH "/review-templates/TEMPLATE_ID" 'REQUEST_BODY')
echo "$RESPONSE"
```

### Step 4: Handle response

- **Status 200**: Display updated template detail:

```
## Template #{id} updated

**Name**: {name} | **ID**: {id}
**Owning Organization**: {owning_organization.name | "—"} (ID: {owning_organization.id | "—"})
**Shared With**: {shared_with_organizations names joined by ", " | "None"}
```

- **Status 400** → use Error Handling above (400 on template PATCH)
- **Status 403** → "Admin on the owning organization required."
- **Error** → use Error Handling above

---

## Flow: Delete Template

**Trigger**: `templates {id} delete`

### Step 1: Fetch template

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/review-templates/TEMPLATE_ID")
echo "$RESPONSE"
```

Show:

```
Template #{id}: {name}
Owning Team: {owning_team.name | "—"}
```

### Step 2: Confirm and delete

> Delete template #{id} "{name}" (Owning team: {owning_team.name | "—"})? This is permanent.

Wait for confirmation. Then:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" DELETE "/review-templates/TEMPLATE_ID")
echo "$RESPONSE"
```

### Step 3: Handle response

- **Status 200/204**: "Template #{id} deleted."
- **Status 403** → "Admin on the owning team required."
- **Error** → use Error Handling above

---

## Flow: Archive Template

**Trigger**: `templates {id} archive`

### Step 1: Fetch template

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/review-templates/TEMPLATE_ID")
echo "$RESPONSE"
```

Show:

```
Template #{id}: {name}
Owning Organization: {owning_organization.name | "—"}
Archived: {archived}
```

If already archived (`archived == true`), report "Template #{id} is already archived." and stop.

### Step 2: Confirm and archive

> Archive template #{id} "{name}"? It will be hidden from the template list but can still be accessed by ID.

Wait for confirmation. Then:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" PATCH "/review-templates/TEMPLATE_ID" '{"archived":true}')
echo "$RESPONSE"
```

### Step 3: Handle response

- **Status 200**: "Template #{id} archived. It no longer appears in the template list."
- **Status 403** → "Admin on the owning organization required."
- **Error** → use Error Handling above

---

## Flow: Unarchive Template

**Trigger**: `templates {id} unarchive` or `templates {id} restore`

### Step 1: Fetch template

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" GET "/review-templates/TEMPLATE_ID")
echo "$RESPONSE"
```

Show:

```
Template #{id}: {name}
Owning Organization: {owning_organization.name | "—"}
Archived: {archived}
```

If not archived (`archived == false`), report "Template #{id} is not archived." and stop.

### Step 2: Confirm and unarchive

> Restore template #{id} "{name}"? It will reappear in the template list.

Wait for confirmation. Then:

```bash
API_SH="<api.sh path from Current State>"
RESPONSE=$("$API_SH" PATCH "/review-templates/TEMPLATE_ID" '{"archived":false}')
echo "$RESPONSE"
```

### Step 3: Handle response

- **Status 200**: "Template #{id} restored. It now appears in the template list."
- **Status 403** → "Admin on the owning organization required."
- **Error** → use Error Handling above

---

## Edge Cases

- **No config** → "Config not found. Run `/rkit:setup` first."
- **api.sh not found** → "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"
- **No reviews** → "No reviews found."
- **Review not found (404)** → "Review {id} not found."
- **No template on review** → In assess/draft flow, skip template prompt walk-through; collect a single free-form response instead.
- **Existing draft** → In draft flow, pre-populate existing `response_value` / `score` as defaults when re-prompting.
- **Assess when not in_progress** → "Review must be in progress to assess. Current status: {status}."
- **Sign off when not assessed** → "Review must be in assessed status to sign off. Current status: {status}."
- **Void already-voided** → Show the API's error response.
- **Archive already-archived** → Show the API's error response.
- **Archive already-archived template** → Detect via `archived == true` in prefetch; report "Template #{id} is already archived." and stop.
- **Unarchive non-archived template** → Detect via `archived == false` in prefetch; report "Template #{id} is not archived." and stop.
- **Template `archived` field missing** → Treat as not archived (API default).
- **Non-reviewer signs off** → "You must be the reviewer to sign off."
- **Non-admin creates/voids/archives** → "Admin/people-ops permissions required."
- **No core values defined** → "No core values defined for your organization."
- **Names empty** → Fall back to `login` field for all user name displays.
- **Template `owning_team` is null** → Display "—" in all template listings and detail views; no error.
- **Template `shared_with_teams` is empty** → Display "None" in template detail views.
- **PATCH template with `owning_team_id`** → API returns 400; display "Cannot change owning team after creation."
- **Non-admin on owning team attempts template create/update/delete** → "Admin on the owning team required."

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
