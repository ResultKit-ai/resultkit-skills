---
name: rkit:scorecard
description: View and manage your team's scorecard (measures/measurables). Shows current-year measures with recent weekly history values, and supports recording weekly and monthly values, creating, updating, and archiving measures. Use when users mention scorecard, KPIs, measurables, weekly metrics, monthly metrics, measures, recording values, monthly scorecard entry, or team scorecard management.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Bash(date *), Read, Glob, Grep, AskUserQuestion
---

# rkit:scorecard

View and manage the team weekly KPI scorecard.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh: !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/scorecard/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/scorecard/scripts/api.sh "$HOME/.claude/skills/rkit:scorecard/scripts/api.sh" "$HOME/.agents/skills/scorecard/scripts/api.sh" "$HOME/.gemini/skills/scorecard/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes.** GET requests execute immediately. POST/PATCH/DELETE require user confirmation before executing.
- **Show IDs.** Always include measure IDs and history entry IDs in output for follow-up reference.
- **Concise output.** Tables and short summaries. No filler prose.
- **Direct execution.** Use Bash with api.sh for all API calls. Never use Task agents or subagents.
- **Framework-aware.** Use the team's `framework` field: EOS teams use "Measurables" instead of "Measures" in labels. "Scorecard" is universal.
- **Scoped tools.** Use `Bash(scripts/api.sh *)` and `Bash(jq *)` — never raw curl.
- **Monthly entries.** Use `period=month` flag on the `record` command to record a monthly value. Weekly is the default when `period=` is omitted.

## Argument Parsing

| Input | Behavior |
|-------|----------|
| *(no args)* | List scorecard for default team, current year |
| `--year YYYY` | Show history for specified year |
| `--include-archived` | Include archived measures in list view |
| `--team {id}` | Use specified team instead of default |
| `record "NAME" VALUE [date=YYYY-MM-DD|YYYY-MM] [period=month]` | Record a value for a measure (weekly by default; add `period=month` for a monthly entry) |
| `note "NAME" "TEXT" [date=YYYY-MM-DD]` | Record a per-week note for a measure |
| `note clear "NAME" [date=YYYY-MM-DD]` | Clear the note for a measure's week |
| `add "NAME" [unit=...] [direction=...] [target=...] [period=week\|month\|quarter\|year] [aggregation=sum\|last\|average] [chart_type=...]` | Create a new measure |
| `update "NAME" [name=...] [unit=...] [direction=...] [target=...] [period=week\|month\|quarter\|year] [aggregation=sum\|last\|average] [chart_type=...]` | Update measure fields |
| `archive "NAME"` | Archive (soft-delete) a measure |

---

## Team ID Resolution

1. **`--team {id}` flag** in args → use that team ID
2. **`default_team_id` in config** → use that
3. **Neither** → error: "No default team configured. Run `/rkit:setup` first."

---

## Measure Name Resolution

Used by: `record`, `update`, `archive` subcommands.

### Step 1: Fetch full measure list

```bash
API_SH="<resolved api.sh path>"
TEAM_ID="<resolved team ID>"
MEASURES_RESP=$("$API_SH" GET "/teams/$TEAM_ID/measures?include_archived=true")
```

Extract `MEASURES_RESP.body.data` as the candidate list.

### Step 2: Match

Given user input NAME:

1. **Case-insensitive exact match**: find measures where `lower(measure.name) == lower(NAME)`. If exactly one → use it.
2. **Case-insensitive substring match**: find measures where `lower(measure.name)` contains `lower(NAME)`. If exactly one → use it.
3. **Multiple matches** → show disambiguation list and stop:
   ```
   Multiple measures match "NAME". Which did you mean?
   1. Measure Alpha (ID: 1)
   2. Measure Beta (ID: 2)
   ```
4. **No match** → error: "No measure found matching '{NAME}'." and stop.

Use jq for matching:
```bash
# Exact match (case-insensitive)
MATCH=$(echo "$MEASURES_RESP" | jq --arg name "$NAME" \
  '[.body.data[] | select((.name | ascii_downcase) == ($name | ascii_downcase))]')

# If empty, substring match
if [ "$(echo "$MATCH" | jq 'length')" -eq 0 ]; then
  MATCH=$(echo "$MEASURES_RESP" | jq --arg name "$NAME" \
    '[.body.data[] | select((.name | ascii_downcase) | contains($name | ascii_downcase))]')
fi

COUNT=$(echo "$MATCH" | jq 'length')
```

---

## Flow: List Scorecard

Triggered when: no args, or only `--year`/`--include-archived`/`--team` flags.

### Step 1: Resolve team ID

Use Team ID Resolution. Error if not configured.

Verify config and api.sh are present:
- If config missing: "Config not found. Run `/rkit:setup` first."
- If api.sh shows `NOT_FOUND`: "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"

### Step 2: Resolve year and flags

```bash
YEAR=$(date +%Y)  # default current year
INCLUDE_ARCHIVED="false"
# Parse from args: if --year YYYY present, set YEAR; if --include-archived present, set INCLUDE_ARCHIVED=true
```

### Step 3: Fetch team info (for framework-aware terminology)

```bash
API_SH="<resolved api.sh path>"
TEAM_RESP=$("$API_SH" GET "/teams/$TEAM_ID")
FRAMEWORK=$(echo "$TEAM_RESP" | jq -r '.body.data.framework // ""')
TEAM_NAME=$(echo "$TEAM_RESP" | jq -r '.body.data.name // "Team"')
MEASURE_LABEL=$([ "$FRAMEWORK" = "eos" ] && echo "Measurables" || echo "Measures")
```

### Step 4: Fetch measures

```bash
RESPONSE=$("$API_SH" GET "/teams/$TEAM_ID/measures?year=$YEAR&include_archived=$INCLUDE_ARCHIVED")
STATUS=$(echo "$RESPONSE" | jq -r '.status // "error"')
ERROR=$(echo "$RESPONSE" | jq -r '.error // ""')
```

**Handle errors**: See Error Handling table at bottom.

Handle API errors first:
- `error` field non-empty → check ERROR HANDLING table
- `status: 401` → "Auth failed. Run `/rkit:setup` to update your token."
- `status: 403` → "You don't have permission to view this team's scorecard."
- `status: 404` → "Team ID $TEAM_ID not found."
- Other non-200 status → "API error ($STATUS): $(echo "$RESPONSE" | jq -r '.body.error.message // .body // ""')"

### Step 5: Compute the 4 most recent calendar-week columns

```bash
TODAY=$(date +%Y-%m-%d)
DOW=$(date +%u)  # 1=Monday, 7=Sunday
OFFSET=$((DOW - 1))

# Monday of current week (Linux)
THIS_MON=$(date -d "$TODAY - ${OFFSET} days" +%Y-%m-%d 2>/dev/null)
# macOS fallback
if [ -z "$THIS_MON" ]; then
  THIS_MON=$(date -v-${OFFSET}d +%Y-%m-%d)
fi

# 4 week columns (oldest first: W1, W2, W3, W4)
W4=$THIS_MON
W3=$(date -d "$THIS_MON - 7 days" +%Y-%m-%d 2>/dev/null || date -j -v-7d -f "%Y-%m-%d" "$THIS_MON" +%Y-%m-%d)
W2=$(date -d "$THIS_MON - 14 days" +%Y-%m-%d 2>/dev/null || date -j -v-14d -f "%Y-%m-%d" "$THIS_MON" +%Y-%m-%d)
W1=$(date -d "$THIS_MON - 21 days" +%Y-%m-%d 2>/dev/null || date -j -v-21d -f "%Y-%m-%d" "$THIS_MON" +%Y-%m-%d)

# Format for display (e.g. "Jan 5")
fmt_date() {
  date -d "$1" "+%b %-d" 2>/dev/null || date -j -f "%Y-%m-%d" "$1" "+%b %e" | sed 's/  / /'
}
H1=$(fmt_date "$W1")
H2=$(fmt_date "$W2")
H3=$(fmt_date "$W3")
H4=$(fmt_date "$W4")
```

### Step 6: Display

**If `data` array is empty and `--include-archived` is not set**:
```
No active measures on this scorecard. Use `/rkit:scorecard add "Name"` to create one.
```

**Otherwise**, display:

```
Team Scorecard — {TEAM_NAME} ({FRAMEWORK_UPPER}) — {YEAR}
Showing last 4 weeks

ID   Name                  Unit  Dir     Target  Owner       {H1}    {H2}    {H3}    {H4}    Chart
──   ────────────────────  ────  ──────  ──────  ──────────  ──────  ──────  ──────  ──────  ──────────────
...
```

Use jq to extract and format each row, appending `*` to cells that have a note:

```bash
echo "$RESPONSE" | jq -r \
  --arg w1 "$W1" --arg w2 "$W2" --arg w3 "$W3" --arg w4 "$W4" \
  '.body.data[] |
   . as $m |
   ($m.histories | map({(.date): (.value // "—")}) | add // {}) as $h |
   ($m.histories | map({(.date): .note}) | add // {}) as $notes |
   [
     ($m.id | tostring),
     ($m.name + (if $m.is_archived then " [archived]" else "" end) + (if $m.data_source_type == 3 then " [roll-up: " + ($m.roll_up_type // "?") + "]" else "" end)),
     ($m.unit // ""),
     $m.direction,
     ($m.target_value // "—"),
     (if $m.owner then ($m.owner.first_name + " " + $m.owner.last_name[0:1] + ".") else "(none)" end),
     (($h[$w1] // "—") + (if $notes[$w1] then "*" else "" end)),
     (($h[$w2] // "—") + (if $notes[$w2] then "*" else "" end)),
     (($h[$w3] // "—") + (if $notes[$w3] then "*" else "" end)),
     (($h[$w4] // "—") + (if $notes[$w4] then "*" else "" end)),
     ($m.chart_type // "—")
   ] | @tsv'
```

Format the tsv output as a readable table. Align columns by padding with spaces. Display the header row with column names and separator line before the data rows.

After the table, collect all non-null notes across the four displayed weeks from all measures and print as footnotes:

```bash
echo "$RESPONSE" | jq -r \
  --arg w1 "$W1" --arg w2 "$W2" --arg w3 "$W3" --arg w4 "$W4" \
  --arg h1 "$H1" --arg h2 "$H2" --arg h3 "$H3" --arg h4 "$H4" \
  '[.body.data[] | .histories[] | select(.note != null) |
    {date, note}] |
   unique_by(.date) |
   map(. as $e |
     (if $e.date == $w1 then $h1
      elif $e.date == $w2 then $h2
      elif $e.date == $w3 then $h3
      elif $e.date == $w4 then $h4
      else $e.date end) as $label |
     "* \($label): \($e.note)") |
   .[]'
```

If that produces no output, print nothing extra.

---

## Flow: Record Value

Triggered when: first arg is `record`.

### Step 1: Parse args

Extract:
- `NAME` = arg 2 (measure name, required)
- `VALUE` = arg 3 (numeric value, required)
- `DATE_ARG` = from `date=...` if present in args (optional; may be `YYYY-MM-DD` or `YYYY-MM`)
- `PERIOD` = from `period=...` if present in args (optional; must be `"month"` if provided; default: `"week"`)

If NAME is missing: "Usage: `/rkit:scorecard record \"Measure Name\" VALUE [date=YYYY-MM-DD|YYYY-MM] [period=month]`" and stop.
If VALUE is missing: "Value is required. Usage: `/rkit:scorecard record \"Name\" VALUE`" and stop.

**Period-ambiguity check**: If no `period=` arg was provided AND `DATE_ARG` is in `YYYY-MM-DD` format, ask:
```
"{DATE_ARG}" looks like a full date. Record this as a weekly or monthly entry?
```
Use AskUserQuestion with options `[weekly/monthly]`. Set PERIOD based on the user's answer.

### Step 2: Validate value (client-side)

Check that VALUE matches `^-?[0-9]+(\.[0-9]+)?$`. If not numeric:
```
Value must be a number. Got: "{VALUE}"
```
Stop — do not call the API.

### Step 3: Compute date

**Monthly path** (`PERIOD == "month"`):
- If `DATE_ARG` is in `YYYY-MM-DD` format: strip to first 7 chars → `YYYY-MM` (e.g. `2026-03-15` → `2026-03`).
- If `DATE_ARG` is in `YYYY-MM` format: use as-is.
- If `DATE_ARG` contains only a month name (e.g. "March") or month+year (e.g. "March 2026"): resolve to `YYYY-MM`. If year is absent, default to current year (`date +%Y`) — no prompt.
- If no `DATE_ARG`: default to current month (`date +%Y-%m`).

Set `RECORD_DATE` to the resolved `YYYY-MM` string.

**Weekly path** (`PERIOD == "week"`, default):
- If `DATE_ARG` is provided: use as `RECORD_DATE`.
- Otherwise compute current Monday:
```bash
TODAY=$(date +%Y-%m-%d)
DOW=$(date +%u)
OFFSET=$((DOW - 1))
RECORD_DATE=$(date -d "$TODAY - ${OFFSET} days" +%Y-%m-%d 2>/dev/null)
if [ -z "$RECORD_DATE" ]; then
  RECORD_DATE=$(date -v-${OFFSET}d +%Y-%m-%d)
fi
```

### Step 4: Resolve measure name

Use Measure Name Resolution. Stop on disambiguation or no-match.

Extract `MEASURE_ID`, `MEASURE_NAME`, and `DATA_SOURCE_TYPE` from the matched measure.

### Step 4b: Roll-up guard

If `DATA_SOURCE_TYPE` equals `3`:
- Print: `"{MEASURE_NAME}" is a roll-up measure (auto-calculated from other measures). Manual value entry is not supported.`
- Stop. Do not show the confirmation prompt and do not call the API.

### Step 5: Confirm

Show period-aware confirmation prompt:
- **Weekly**: `Record value "{VALUE}" for "{MEASURE_NAME}" (ID: {MEASURE_ID}) for week of {RECORD_DATE}? [y/N]`
- **Monthly**: `Record value "{VALUE}" for "{MEASURE_NAME}" (ID: {MEASURE_ID}) for month of {RECORD_DATE}? [y/N]`

Ask for confirmation using AskUserQuestion. If user says anything other than `y`/`yes`, cancel and show "Cancelled."

### Step 6: Execute

Build API body based on period:

```bash
API_SH="<resolved api.sh path>"
if [ "$PERIOD" = "month" ]; then
  BODY="{\"date\": \"$RECORD_DATE\", \"value\": \"$VALUE\", \"period\": \"month\"}"
else
  BODY="{\"date\": \"$RECORD_DATE\", \"value\": \"$VALUE\"}"
fi
RESPONSE=$("$API_SH" POST "/measures/$MEASURE_ID/history" "$BODY")
STATUS=$(echo "$RESPONSE" | jq -r '.status // "error"')
```

### Step 7: Handle response

```bash
HISTORY_ID=$(echo "$RESPONSE" | jq -r '.body.data.id // "?"')
CONFIRMED_DATE=$(echo "$RESPONSE" | jq -r '.body.data.date // "$RECORD_DATE"')
```

- **200**:
  - Weekly: "Recorded: {MEASURE_NAME} (ID: {MEASURE_ID}) — {VALUE} for week of {CONFIRMED_DATE} (history ID: {HISTORY_ID})."
  - Monthly: "Recorded: {MEASURE_NAME} (ID: {MEASURE_ID}) — {VALUE} for month of {CONFIRMED_DATE} (history ID: {HISTORY_ID})."
- **422**: Show API error message: `$(echo "$RESPONSE" | jq -r '.body.error.message // .body // "Validation error"')`
- **403**: "You can't record values for this measure — its `can_record_value` is `false` for you." Rights come back on every measure from `GET /teams/{id}/measures`: `can_record_value` says whether this call would be accepted, `can_edit` whether the definition can be changed, and both are computed against the team that **owns** the measure. A plain member of the owning team can record values; an admin of a child team that merely inherits the scorecard cannot. Never gate value entry on `can_edit` — that would take entry away from plain members who have it.
- **404**: "Measure ID {MEASURE_ID} not found."
- Other: "API error ($STATUS): $(echo "$RESPONSE" | jq -r '.body.error.message // ""')"

---

## Flow: Record Note

Triggered when: first arg is `note` AND second arg is NOT `clear`.

### Step 1: Parse args

Extract:
- `NAME` = arg 2 (measure name, required)
- `TEXT` = arg 3 (note text, required)
- `DATE` = from `date=YYYY-MM-DD` if present in args (optional)

If NAME is missing: "Usage: `/rkit:scorecard note \"Measure Name\" \"Note text\" [date=YYYY-MM-DD]`" and stop.
If TEXT is missing: "Note text is required. Usage: `/rkit:scorecard note \"Name\" \"Note text\"`" and stop.

### Step 2: Validate note (client-side)

Check note length:
```bash
if [ "${#TEXT}" -gt 255 ]; then
  echo "Note is too long (max 255 characters). Got ${#TEXT} characters."
  # stop
fi
```

### Step 3: Compute date

If `date=YYYY-MM-DD` was provided, use that.

Otherwise compute current Monday:
```bash
TODAY=$(date +%Y-%m-%d)
DOW=$(date +%u)
OFFSET=$((DOW - 1))
NOTE_DATE=$(date -d "$TODAY - ${OFFSET} days" +%Y-%m-%d 2>/dev/null)
if [ -z "$NOTE_DATE" ]; then
  NOTE_DATE=$(date -v-${OFFSET}d +%Y-%m-%d)
fi
```

### Step 4: Resolve measure name

Use Measure Name Resolution. Stop on disambiguation or no-match.

Extract `MEASURE_ID` and `MEASURE_NAME` from the matched measure.

### Step 5: Confirm

```
Record note for "{MEASURE_NAME}" (ID: {MEASURE_ID}) for week of {NOTE_DATE}:
  "{TEXT}"
[y/N]
```

Ask for confirmation using AskUserQuestion. If user says anything other than `y`/`yes`, cancel and show "Cancelled."

### Step 6: Execute

```bash
API_SH="<resolved api.sh path>"
RESPONSE=$("$API_SH" POST "/measures/$MEASURE_ID/history/note" \
  "{\"date\": \"$NOTE_DATE\", \"note\": \"$TEXT\"}")
STATUS=$(echo "$RESPONSE" | jq -r '.status // "error"')
```

### Step 7: Handle response

- **200**: Show: "Noted: {MEASURE_NAME} (ID: {MEASURE_ID}) — week of {NOTE_DATE}\n  \"{TEXT}\""
- **401**: "Unauthorized. Run `/rkit:setup` to update your token."
- **403**: "You don't have permission to record notes for this measure."
- **404**: "Measure ID {MEASURE_ID} not found."
- **422**: Show API error message: `$(echo "$RESPONSE" | jq -r '.body.error.message // "Validation error"')`
- **Other**: "API error ($STATUS): $(echo "$RESPONSE" | jq -r '.body.error.message // ""')"

---

## Flow: Clear Note

Triggered when: first arg is `note` AND second arg is `clear`.

### Step 1: Parse args

Extract:
- `NAME` = arg 3 (measure name, required)
- `DATE` = from `date=YYYY-MM-DD` if present in args (optional)

If NAME is missing: "Usage: `/rkit:scorecard note clear \"Measure Name\" [date=YYYY-MM-DD]`" and stop.

### Step 2: Compute date

Same Monday-default logic as Flow: Record Note (Step 3).

### Step 3: Resolve measure name

Use Measure Name Resolution. Stop on disambiguation or no-match.

Extract `MEASURE_ID` and `MEASURE_NAME`.

### Step 4: Confirm

```
Clear note for "{MEASURE_NAME}" (ID: {MEASURE_ID}) for week of {NOTE_DATE}? [y/N]
```

Ask for confirmation using AskUserQuestion. If user says anything other than `y`/`yes`, cancel and show "Cancelled."

### Step 5: Execute

```bash
API_SH="<resolved api.sh path>"
RESPONSE=$("$API_SH" POST "/measures/$MEASURE_ID/history/note" \
  "{\"date\": \"$NOTE_DATE\", \"note\": null}")
STATUS=$(echo "$RESPONSE" | jq -r '.status // "error"')
```

### Step 6: Handle response

- **200**: "Note cleared: {MEASURE_NAME} (ID: {MEASURE_ID}) — week of {NOTE_DATE}"
- **401**: "Unauthorized. Run `/rkit:setup` to update your token."
- **403**: "You don't have permission to modify notes for this measure."
- **404**: "Measure ID {MEASURE_ID} not found."
- **422**: Show API error message: `$(echo "$RESPONSE" | jq -r '.body.error.message // "Validation error"')`
- **Other**: "API error ($STATUS): $(echo "$RESPONSE" | jq -r '.body.error.message // ""')"

---

## Flow: Create Measure

Triggered when: first arg is `add`.

### Step 1: Parse args

Extract from args:
- `NAME` = arg 2 (required, the measure name)
- `UNIT` = value from `unit=...` if present (default: `""`)
- `DIRECTION` = value from `direction=...` if present (default: `"higher"`)
- `TARGET` = value from `target=...` if present (default: none)
- `PERIOD` = value from `period=...` if present (default: none — API will use `"week"`)
- `AGGREGATION` = value from `aggregation=...` if present (default: none — API will use `"sum"`)
- `CHART_TYPE` = value from `chart_type=...` if present (default: none)

If NAME is missing or blank:
```
Measure name is required. Usage: `/rkit:scorecard add "Name" [unit=...] [direction=higher|lower] [target=...] [period=week|month|quarter|year] [aggregation=sum|last|average] [chart_type=...]`
```
Stop.

If `PERIOD` is provided, validate against enum (`week`, `month`, `quarter`, `year`). If invalid, stop with:
```
Invalid period "{PERIOD}". Valid values: week, month, quarter, year
```

If `AGGREGATION` is provided, validate against enum (`sum`, `last`, `average`). If invalid, stop with:
```
Invalid aggregation "{AGGREGATION}". Valid values: sum, last, average
```

If `CHART_TYPE` is provided, validate against enum (`pie`, `progress_circle`, `progress_bar`, `trend`, `bar_chart`). If invalid, stop with:
```
Invalid chart_type "{CHART_TYPE}". Valid values: pie, progress_circle, progress_bar, trend, bar_chart
```

### Step 2: Resolve team ID

Use Team ID Resolution.

### Step 3: Confirm

```
Create measure "{NAME}" (unit: {UNIT or "none"}, direction: {DIRECTION}, target: {TARGET or "none"}, period: {PERIOD or "week"}, aggregation: {AGGREGATION or "sum"}, chart_type: {CHART_TYPE or "none"})? [y/N]
```

Ask for confirmation. If not `y`/`yes`, show "Cancelled."

### Step 4: Execute

Build JSON body. Include only fields that were provided. Always include `name`. Include `unit` and `direction` with their defaults if not provided:

```bash
API_SH="<resolved api.sh path>"
# Build body with provided fields
BODY="{\"measure\": {\"name\": \"$NAME\", \"unit\": \"$UNIT\", \"direction\": \"$DIRECTION\""
if [ -n "$TARGET" ]; then
  BODY="$BODY, \"target_value\": \"$TARGET\""
fi
if [ -n "$PERIOD" ]; then
  BODY="$BODY, \"target_period\": \"$PERIOD\""
fi
if [ -n "$AGGREGATION" ]; then
  BODY="$BODY, \"aggregation_type\": \"$AGGREGATION\""
fi
if [ -n "$CHART_TYPE" ]; then
  BODY="$BODY, \"chart_type\": \"$CHART_TYPE\""
fi
BODY="$BODY}}"

RESPONSE=$("$API_SH" POST "/teams/$TEAM_ID/measures" "$BODY")
STATUS=$(echo "$RESPONSE" | jq -r '.status // "error"')
```

### Step 5: Handle response

- **201**: Show: "Created: {name} (ID: {id}, unit: {unit or "none"}, direction: {direction}, target: {target_value or "none"}, period: {target_period}, aggregation: {aggregation_type}, chart_type: {chart_type or "none"})."
  Extract from `RESPONSE.body.data`.
- **422**: Show API error message: `$(echo "$RESPONSE" | jq -r '.body.error.message // "Validation error"')`
- **403**: "You don't have permission to add measures to this team."
- Other: "API error ($STATUS): $(echo "$RESPONSE" | jq -r '.body.error.message // ""')"

---

## Flow: Update Measure

Triggered when: first arg is `update`.

### Step 1: Parse args

Extract:
- `NAME` = arg 2 (measure name to look up, required)
- `NEW_NAME` = value from `name=...` if present
- `UNIT` = value from `unit=...` if present
- `DIRECTION` = value from `direction=...` if present
- `TARGET` = value from `target=...` if present
- `PERIOD` = value from `period=...` if present
- `AGGREGATION` = value from `aggregation=...` if present
- `CHART_TYPE` = value from `chart_type=...` if present (may be `"null"` to clear)

If NAME is missing: "Usage: `/rkit:scorecard update \"Name\" [name=...] [unit=...] [direction=...] [target=...] [period=week|month|quarter|year] [aggregation=sum|last|average] [chart_type=...]`" and stop.
If no update fields provided: "No fields to update. Specify at least one of: name, unit, direction, target, period, aggregation, chart_type." and stop.

If `PERIOD` is provided, validate against enum (`week`, `month`, `quarter`, `year`). If invalid, stop with:
```
Invalid period "{PERIOD}". Valid values: week, month, quarter, year
```

If `AGGREGATION` is provided, validate against enum (`sum`, `last`, `average`). If invalid, stop with:
```
Invalid aggregation "{AGGREGATION}". Valid values: sum, last, average
```

If `CHART_TYPE` is provided and is not the string `"null"`, validate against enum (`pie`, `progress_circle`, `progress_bar`, `trend`, `bar_chart`). If invalid, stop with:
```
Invalid chart_type "{CHART_TYPE}". Valid values: pie, progress_circle, progress_bar, trend, bar_chart (or "null" to clear)
```

### Step 2: Resolve measure name

Use Measure Name Resolution. Stop on disambiguation or no-match.

Extract `MEASURE_ID` and `MEASURE_NAME`.

### Step 3: Build change summary

List only the fields being changed:
```
name → "{NEW_NAME}"
unit → "{UNIT}"
direction → "{DIRECTION}"
target → "{TARGET}"
period → "{PERIOD}"
aggregation → "{AGGREGATION}"
chart_type → "{CHART_TYPE}" (or "cleared" when CHART_TYPE is "null")
```

### Step 4: Confirm

```
Update "{MEASURE_NAME}" (ID: {MEASURE_ID}) — set {change summary}? [y/N]
```

Ask for confirmation. If not `y`/`yes`, show "Cancelled."

### Step 5: Execute

Build partial PATCH body with only provided fields:

```bash
API_SH="<resolved api.sh path>"
FIELDS=""
[ -n "$NEW_NAME" ] && FIELDS="$FIELDS\"name\": \"$NEW_NAME\","
[ -n "$UNIT" ] && FIELDS="$FIELDS\"unit\": \"$UNIT\","
[ -n "$DIRECTION" ] && FIELDS="$FIELDS\"direction\": \"$DIRECTION\","
[ -n "$TARGET" ] && FIELDS="$FIELDS\"target_value\": \"$TARGET\","
[ -n "$PERIOD" ] && FIELDS="$FIELDS\"target_period\": \"$PERIOD\","
[ -n "$AGGREGATION" ] && FIELDS="$FIELDS\"aggregation_type\": \"$AGGREGATION\","
if [ -n "$CHART_TYPE" ]; then
  if [ "$CHART_TYPE" = "null" ]; then
    FIELDS="$FIELDS\"chart_type\": null,"
  else
    FIELDS="$FIELDS\"chart_type\": \"$CHART_TYPE\","
  fi
fi
FIELDS="${FIELDS%,}"  # remove trailing comma
BODY="{\"measure\": {$FIELDS}}"

RESPONSE=$("$API_SH" PATCH "/measures/$MEASURE_ID" "$BODY")
STATUS=$(echo "$RESPONSE" | jq -r '.status // "error"')
```

### Step 6: Handle response

- **200**: "Updated: {name from response} (ID: {MEASURE_ID}) — {change summary}."
- **403**: "You don't have permission to edit this measure."
- **404**: "Measure ID {MEASURE_ID} not found."
- **422**: Show API error message: `$(echo "$RESPONSE" | jq -r '.body.error.message // "Validation error"')`
- Other: "API error ($STATUS): $(echo "$RESPONSE" | jq -r '.body.error.message // ""')"

---

## Flow: Archive Measure

Triggered when: first arg is `archive`.

### Step 1: Parse args

Extract `NAME` = arg 2 (required).

If NAME is missing: "Usage: `/rkit:scorecard archive \"Name\"`" and stop.

### Step 2: Resolve measure name

Use Measure Name Resolution (fetches all including archived). Stop on disambiguation or no-match.

Extract `MEASURE_ID` and `MEASURE_NAME`.

### Step 3: Confirm

```
Archive "{MEASURE_NAME}" (ID: {MEASURE_ID})? It will be hidden from the default scorecard view. [y/N]
```

Ask for confirmation. If not `y`/`yes`, show "Cancelled."

### Step 4: Execute

```bash
API_SH="<resolved api.sh path>"
RESPONSE=$("$API_SH" DELETE "/measures/$MEASURE_ID")
STATUS=$(echo "$RESPONSE" | jq -r '.status // "error"')
```

### Step 5: Handle response

- **200**: "Archived: {MEASURE_NAME} (ID: {MEASURE_ID}). It will no longer appear in the default scorecard view."
- **403**: "You don't have permission to archive this measure."
- **404**: "Measure ID {MEASURE_ID} not found."
- Other: "API error ($STATUS): $(echo "$RESPONSE" | jq -r '.body.error.message // ""')"

---

## Error Handling

| Status | Response |
|--------|----------|
| `error: NO_CONFIG` | "Config not found. Run `/rkit:setup` first." |
| `error: NO_TOKEN` | "No API token. Run `/rkit:setup` to configure." |
| `error: CURL_FAILED` | "Network error. Check your connection." |
| `status: 401` | "Unauthorized. Run `/rkit:setup` to update your token." |
| `status: 403` | "Not authorized for this operation. Check your team membership." |
| `status: 404` | "Not found. Check the ID or name and try again." |
| `status: 422` | Show the validation error message from the response body. |
| `api.sh = NOT_FOUND` | "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`" |
| Other non-200 | Show status code and error message from response body. |

### Edge Cases

- **No config**: "Config not found. Run `/rkit:setup` first."
- **No default_team_id and no --team**: "No default team configured. Run `/rkit:setup` first."
- **Empty measures array**: "No active measures on this scorecard. Use `/rkit:scorecard add \"Name\"` to create one."
- **Measure owner is null**: Display "(none)" in table.
- **Non-numeric record value**: Catch client-side before API call. "Value must be a number." (applies to both weekly and monthly entries)
- **Measure name matches multiple**: Show numbered disambiguation list. Do not proceed.
- **Measure name matches none**: "No measure found matching '{name}'."
- **API 422 on record**: Surface the API error message (e.g. "Date must be a Monday" for bad weekly date; "Invalid date format" for bad monthly date).
- **`period=month` with non-numeric value**: Caught client-side (Step 2) — same "Value must be a number" check applies.
- **`period=month` with invalid date format**: API returns 422; skill surfaces the error message from the response body.
- **`period=month` with `YYYY-MM-DD` date**: Automatically stripped to `YYYY-MM` — no error shown to user.
- **Full date (`YYYY-MM-DD`) without `period=`**: Skill asks "Record as weekly or monthly?" before proceeding (Step 1 period-ambiguity check).
- **Natural-language month without year (e.g. "March")**: Resolved to current year by default — no prompt unless year is genuinely ambiguous.

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
