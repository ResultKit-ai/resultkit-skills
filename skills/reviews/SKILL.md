---
name: rkit:reviews
description: View and manage performance reviews, submit assessments, sign off, and rate core values. Use this skill when users mention reviews, performance reviews, assessments, self-assessments, reviewer assessments, sign-off, core values, or core value ratings.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Read, Glob, Grep, AskUserQuestion
---

# rkit:reviews

Performance reviews, assessments, sign-off, core values and review templates. The ResultKit connector has no live tool for reviews, review templates, assessments or core values, so nothing here uses connector tools and every flow below is a **Fallback** that runs through `scripts/api.sh`. Do not look for a connector tool for these jobs.

## Current State

- Config status: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING"; fi`
- api.sh (Fallback only): !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/reviews/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/reviews/scripts/api.sh "$HOME/.claude/skills/rkit:reviews/scripts/api.sh" "$HOME/.agents/skills/reviews/scripts/api.sh" "$HOME/.gemini/skills/reviews/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes**: Before any POST/PUT/PATCH/DELETE, summarize all planned changes in a single prompt and ask for confirmation. If the command implies multiple related mutations, batch them under one confirmation. GET requests execute immediately.
- **Show IDs**: Always include review, template, and core value IDs in output so users can reference them.
- **Concise output**: Tables and short summaries. No verbose prose.
- **Direct execution**: Use Bash for all API calls via api.sh. Never use Task agents or subagents.

## Error Handling

`RESPONSE=$("<api.sh path from Current State>" METHOD PATH [BODY])` returns `{status, body}`. Handle:

| Answer | Say |
|---|---|
| `error: NO_CONFIG` or `NO_TOKEN` | "Config not found. Run `/rkit:setup` first." |
| `error: CURL_FAILED` | "Network error. Check your connection." |
| 401 | "Unauthorized (401). Run `/rkit:setup` to update your token." |
| 400 on reviews list | Error contains "team_id": "Invalid team ID." Otherwise the API's message. |
| 400 on template PATCH | Message contains "owning organization": "Cannot change owning organization after creation." Otherwise the API's message. |
| 422 on template POST/PATCH | Message contains "not root teams": "Organization ID(s) must be root teams (no sub-teams)." Otherwise the validation error from the body. |
| 404 on reviews list with `team_id` | "Team not found or not accessible." |
| 403 | Sign-off: "You must be the reviewer to sign off." Template create/update/delete: "Admin on the owning team required." Create/void/archive: "Admin/people-ops permissions required." Assessment actions: the API's message. |
| 404 | "Not found (404)." |
| 422 | The validation error from the body. |
| other non-200 | The status code and the error from the body. |

A flow's own 403 message (below) wins over this table.

## Team ID Resolution

`--team {id}` flag, else `default_team_id` from the config above, else no team filter.

## Argument Parsing

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

## Fallback (api.sh)

Every flow below is Fallback. "Confirm" means: show the summary and wait for the user's go-ahead before the write.

### List Reviews — no args (or only `--team {id}`)

`GET /reviews?per_page=50`, adding `&team_id=TEAM_ID` when a team ID resolves.

```
## Reviews

| ID | Reviewee | Reviewer | Status | Period |
|----|----------|----------|--------|--------|
| 42 | Jane Doe | John Smith | in_progress | 2026-01-01 – 2026-03-31 |
| 38 | Mary Mejia | Scott Levy | signed_off | 2025-10-01 – 2025-12-31 |

{count} reviews
```

Reviewee/Reviewer: `first_name last_name`, falling back to `login` when names are empty. Period: `start_date – end_date`, "—" for a null date. API default order. Empty: "No reviews found."

### View Review Detail — `{id}` or `show {id}`

`GET /reviews/REVIEW_ID`.

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

- Header `Review #{id}: {reviewee_name} ← {reviewer_name}`: `first_name last_name`, `login` if empty. Template: `name (ID: {id})`, or "None" if null. Period: `start_date – end_date`, "—" for null dates.
- **Self Assessment**: the `responses` array as a table, one row per prompt: number, `description`, `response_value` (or "—"), `score` (or "—"). `is_draft` shows "Status: Draft" or "Status: Submitted". "(none)" if `self_assessment` is null.
- **Reviewer Assessment**: same format; "(none)" if null. The API omits this field for reviewees until the review reaches `signed_off`.
- **Core Values Ratings**: value name, score, rater name; "(none)" if empty. **Action Items**: ID, title, assignee name; "(none)" if empty. **Attachments**: bulleted filenames; "(none)" if empty.

### Assess Review — `{id} assess`

1. `GET /reviews/REVIEW_ID`. `status` not `in_progress` → "Review must be in progress to assess. Current status: {status}." and stop.
2. Ask with AskUserQuestion: "Are you the reviewee (self-assessment) or the reviewer?" — **Self-assessment** → `respondent_type = "self"`; **Reviewer assessment** → `"reviewer"`. A reviewer whose template has `reviewer_instructions` sees them before the prompts.
3. Template (`template` not null): `GET /review-templates/TEMPLATE_ID`, then walk `prompts` ordered by `position`, showing `[{position}/{total}] {description}` and the `hint` if present, one AskUserQuestion per prompt by `answer_type`: `range` → numeric options from `answer_meta_data` (e.g. 1–5), record as `score`; `text` → free-form short answer and `textarea` → free-form answer, record as `response_value`; `boolean` → Yes (score 1) / No (score 0), record as `score`; `multiple` → options from `answer_meta_data`, record as `response_value`. No template: ask one free-form "Enter your assessment response."
4. Core values: `GET /teams/TEAM_ID/core-values` (team from Team ID Resolution). If any exist, ask "Would you like to include core values ratings?" Yes → per value, a score (1–5) and an optional justification (text up to 5000 characters, or blank) via AskUserQuestion. `core_value_id` in the body must be the label `id` this endpoint returns.
5. Confirm with this summary, then `POST /reviews/REVIEW_ID/submit-assessment`:

```
## Assessment Summary (Review #{id})

**Type**: Self-assessment
**Responses**: {count} prompts answered
**Core values rated**: {count} (or "None")

Submit this assessment?
```

Body: `{"respondent_type":"self","assessment_responses":[{"prompt_id":10,"response_value":"Led the migration project."},{"prompt_id":11,"score":4}],"core_values_ratings":[{"core_value_id":3,"score":4,"justification":"Strong teamwork on Q4 launch"}]}` — `justification` only when the user gave one (omit or null if blank).

6. 200 → "Assessment submitted for review #{id}." When both assessments are now submitted the review moves to `assessed`: say so. Errors → Error Handling.

### Draft Assessment — `{id} draft`

Assess Review steps 1–4, with one addition in step 3: when a draft already exists for the matching respondent type (`self_assessment.is_draft == true` or `reviewer_assessment.is_draft == true`), show its `response_value` / `score` as the default for each prompt. Step 5 confirm:

```
## Draft Assessment Summary (Review #{id})

**Type**: Self-assessment
**Responses**: {count} prompts answered
**Core values rated**: {count} (or "None")

Save as draft? (This does NOT advance the review state.)
```

Then `PUT /reviews/REVIEW_ID/draft-assessment` with the same body. 200 → "Draft saved for review #{id}. Use `/rkit:reviews {id} assess` to submit when ready."

### Sign Off Review — `{id} sign-off`

`GET /reviews/REVIEW_ID`. `status` not `assessed` → "Review must be in assessed status to sign off. Current status: {status}." and stop. Show "Review #{id}: {reviewee_name} ← {reviewer_name} (Status: assessed)". Ask for initials with AskUserQuestion: "Enter your initials to sign off (e.g., JS):". Confirm: > Sign off review #{id} with initials "{initials}"? Then `POST /reviews/REVIEW_ID/sign-off` `{"initials":"INITIALS"}`. 200 → "Review #{id} signed off. Status: signed_off." 403 → "You must be the reviewer to sign off."

### Create Review — `create`

Ask with AskUserQuestion, one at a time: "Enter the reviewee's user ID:", "Enter the reviewer's user ID:"; then `GET /review-templates?per_page=50` and show

| ID | Name | Prompts | Owning Team |
|----|------|---------|-------------|
| 5 | Q1 2026 Review | 8 | Engineering |
| 3 | Annual Review | 12 | — |

(`owning_organization.name`, or "—" if null), ask "Select a template ID:", then "Enter start date (YYYY-MM-DD) or leave blank:" and "Enter end date (YYYY-MM-DD) or leave blank:". Confirm:

```
Create review?
- Reviewee: User #{reviewee_id}
- Reviewer: User #{reviewer_id}
- Template: {template_name} (ID: {template_id})
- Period: {start_date} – {end_date}
```

Then `POST /reviews` `{"reviewee_id":ID,"reviewer_id":ID,"template_id":ID,"start_date":"DATE","end_date":"DATE"}`. 201 → "Review #{id} created. Status: in_progress." 400 containing "is not a member of any team" → "Reviewee or reviewer must be a member of at least one team in this account." (otherwise the API's message). 403 → "Admin/people-ops permissions required."

### Void Review — `{id} void`

`GET /reviews/REVIEW_ID`; show "Review #{id}: {reviewee_name} ← {reviewer_name} (Status: {status})". Ask for the reason: "Enter reason for voiding this review:". Confirm: > Void review #{id}? Reason: "{reason}" — This blocks all further lifecycle actions. Then `PUT /reviews/REVIEW_ID/void` `{"reason":"REASON"}`. 200 → "Review #{id} voided." 403 → "Admin/people-ops permissions required."

### Archive Review — `{id} archive`

`GET /reviews/REVIEW_ID`; show the same status line. Confirm: > Archive review #{id}? This removes it from the default review list. Then `DELETE /reviews/REVIEW_ID`. 200/204 → "Review #{id} archived." 403 → "Admin/people-ops permissions required."

### List Core Values — `values`

`GET /teams/TEAM_ID/core-values`.

```
## Core Values

| ID | Name | Description |
|----|------|-------------|
| 3 | Integrity | Act with honesty and transparency |
| 7 | Innovation | Embrace creative problem-solving |

{count} core values
```

Empty: "No core values defined for your organization."

### Rate Core Values — `rate {user_id}`

`GET /teams/TEAM_ID/core-values`; empty → "No core values defined for your organization. Nothing to rate." and stop. For each value ask "Rate **{value_name}** (1–5):" with options 1, 2, 3, 4, 5. Confirm:

```
## Core Values Ratings for User #{user_id}

| Value | Score |
|-------|-------|
| Integrity | 4 |
| Innovation | 5 |

Submit these ratings?
```

Then `POST /core-values-ratings` `{"subject_id":USER_ID,"ratings":[{"core_value_id":3,"score":4},{"core_value_id":7,"score":5}]}`. 201 → "Core values ratings submitted for user #{user_id}."

### List Templates — `templates` or `templates list`

`GET /review-templates?per_page=50`.

```
## Review Templates

| ID | Name | Prompts | Owning Organization |
|----|------|---------|---------------------|
| 5  | Q1 2026 Review | 8 | Engineering |
| 3  | Annual Review | 12 | — |

{count} templates
```

`owning_organization.name`, "—" if null. Empty: "No templates found." Archived templates are excluded; use `templates {id}` (detail fetch) to view an archived one by ID.

### Create Template — `templates create`

Ask with AskUserQuestion: "Enter template name:" (required), "Enter target role (or leave blank to omit):", "Enter reviewer instructions (or leave blank to omit):", "Enter owning organization ID (must be a root team — or leave blank to use API default):". Confirm:

```
Create template?
- Name: {name}
- Target role: {target_role | "—"}
- Reviewer instructions: {reviewer_instructions | "—"}
- Owning organization ID: {owning_organization_id | "API default"}
```

Then `POST /review-templates` with only the provided fields. 201 → show the template block below with the heading `## Template #{id} created`. 403 → "Admin on the owning organization required."

```
## Template #{id} created

**Name**: {name} | **ID**: {id}
**Owning Organization**: {owning_organization.name | "—"} (ID: {owning_organization.id | "—"})
**Shared With**: {shared_with_organizations names joined by ", " | "None"}
```

### Update Template — `templates {id} update`

`GET /review-templates/TEMPLATE_ID` and show the current values:

```
## Template #{id}: {name}

**Owning Organization**: {owning_organization.name | "—"}
**Shared With**: {shared_with_organizations names | "None"}
**Target Role**: {target_role | "—"}
**Reviewer Instructions**: {reviewer_instructions | "—"}
```

Ask with AskUserQuestion, showing each current value (blank = keep): "New name (or leave blank to keep):", "New target role (or leave blank to keep):", "New reviewer instructions (or leave blank to keep):", "Organization IDs to share with, comma-separated (must be root teams — enter 'none' to remove all sharing, or leave blank to keep unchanged):". Sharing: `none` → `"shared_with_organization_ids": []`; blank → omit it; IDs → `[id1, id2, ...]`. Confirm the changes, then `PATCH /review-templates/TEMPLATE_ID` with only the changed fields. 200 → the same block with the heading `## Template #{id} updated`. 400 → Error Handling (400 on template PATCH); a request naming `owning_team_id` → "Cannot change owning team after creation." 403 → "Admin on the owning organization required."

### Delete Template — `templates {id} delete`

`GET /review-templates/TEMPLATE_ID`; show `Template #{id}: {name}` and `Owning Team: {owning_team.name | "—"}`. Confirm: > Delete template #{id} "{name}" (Owning team: {owning_team.name | "—"})? This is permanent. Then `DELETE /review-templates/TEMPLATE_ID`. 200/204 → "Template #{id} deleted." 403 → "Admin on the owning team required."

### Archive / Unarchive Template — `templates {id} archive`, `templates {id} unarchive` or `restore`

`GET /review-templates/TEMPLATE_ID`; show `Template #{id}: {name}`, `Owning Organization: {owning_organization.name | "—"}`, `Archived: {archived}` (a missing `archived` field counts as not archived).

- **Archive**: already archived → "Template #{id} is already archived." and stop. Confirm: > Archive template #{id} "{name}"? It will be hidden from the template list but can still be accessed by ID. Then `PATCH /review-templates/TEMPLATE_ID` `{"archived":true}`. 200 → "Template #{id} archived. It no longer appears in the template list."
- **Unarchive**: not archived → "Template #{id} is not archived." and stop. Confirm: > Restore template #{id} "{name}"? It will reappear in the template list. Then `PATCH /review-templates/TEMPLATE_ID` `{"archived":false}`. 200 → "Template #{id} restored. It now appears in the template list."
- 403 (both) → "Admin on the owning organization required."

## Edge Cases

- **No config** → "Config not found. Run `/rkit:setup` first."
- **api.sh not found** → "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"
- **Review not found (404)** → "Review {id} not found."
- **No template on a review** → in assess/draft, skip the prompt walk-through and collect one free-form response. **Existing draft** → pre-populate `response_value` / `score` as defaults.
- **Void already-voided, archive already-archived review** → show the API's error response.
- **Names empty** → fall back to `login` for every user name. **Template `owning_team` null** → "—"; **`shared_with_teams` empty** → "None".

## References

- [ResultMaps V2 API Reference](references/api-reference.md) — payloads for these calls.
