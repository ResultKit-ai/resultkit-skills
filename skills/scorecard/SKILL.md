---
name: rkit:scorecard
description: View and manage your team's scorecard (measures/measurables). Shows current-year measures with recent weekly history values, and supports recording weekly and monthly values, creating, updating, and archiving measures. Use when users mention scorecard, KPIs, measurables, weekly metrics, monthly metrics, measures, recording values, monthly scorecard entry, or team scorecard management.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Bash(date *), Read, Glob, Grep, AskUserQuestion
---

# rkit:scorecard

View and manage the team weekly KPI scorecard. It drives the ResultKit connector's MCP tools, named below by base name: the full tool name is `mcp__<server>__<tool>` and the server alias varies by install, so match on the base name. Every job here has a live connector tool, so `scripts/api.sh` is not used.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- Today: !`date +%Y-%m-%d`
- Week starts (oldest first, last is this week): !`d=$(date +%u); for w in 3 2 1 0; do n=$((d-1+7*w)); date -d "-$n days" +%F 2>/dev/null || date -v-${n}d +%F; done | tr '\n' ' '`

## Rules

- **Confirm writes.** Reads execute immediately. Writes (record, note, add, update, archive) require user confirmation before the tool is called.
- **Show IDs.** Always include measure IDs and history entry IDs in output for follow-up reference.
- **Concise output.** Tables and short summaries. No filler prose.
- **Direct execution.** Call the connector tools directly. Never use Task agents or subagents, never curl or hand-build a URL, and skip the connector's `guide` tool: the flows below are complete for this skill.
- **Framework-aware.** `get_team` answers a `**Framework**:` line (none when unset). EOS teams use "Measurables" instead of "Measures" in labels. "Scorecard" is universal.
- **Monthly entries.** Use `period=month` on the `record` command to record a monthly value. Weekly is the default when `period=` is omitted.

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

**Team ID.** `--team {id}` if given, else `default_team_id` from the config above, else the error "No default team configured. Run `/rkit:setup` first." (config MISSING: "Config not found. Run `/rkit:setup` first.").

## Tools

| Job | Tool and arguments |
|---|---|
| Team name and framework | `get_team`: `team_id`. Answers `# {name}` and `**Framework**: {value}`. |
| Read the scorecard | `list_measurables`: `team_id`, `year?`, `include_archived?`. Answers JSON `{measures, meta}`: per measure `id`, `name`, `unit`, `direction`, `target_value`, `owner` (or null), `is_archived`, `data_source_type`, `roll_up_type`, `chart_type`, `can_record_value`, `can_edit`, and `histories` (`date`, `value`, `note`; one slot per Monday of the year, so the answer is large: read only these fields). |
| Record a value | `record_measurable_value`: `measurable_id`, `value` (a string), `date?`, `period?` (`month`). Answers `{id, measure_id, date, value}`. |
| Record or clear a note | `record_measurable_note`: `measurable_id`, `note` (text, or null to clear), `date?`. |
| Create | `create_measurable`: `team_id`, `name`, `unit?`, `direction?`, `target_value?`, `target_period?`, `aggregation_type?`, `chart_type?`. |
| Update | `update_measurable`: `measurable_id` and only the changed fields (field names as in Create; `chart_type` null clears). |
| Archive | `archive_measurable`: `measurable_id`. Answers "Measurable {id} archived." |

Argument names map: `target` is `target_value`, `period` (on `add`/`update`) is `target_period`, `aggregation` is `aggregation_type`; `period=month` on `record` is the tool's `period`.

## Measure Name Resolution

Used by `record`, `note`, `update`, `archive`. Call `list_measurables` with the team and `include_archived: true`. Take the measures whose `name` equals NAME ignoring case; if none, those whose `name` contains NAME ignoring case.

- **One match** → use it (keep its `id`, `name`, `data_source_type`).
- **Several** → show the list and stop:
  ```
  Multiple measures match "NAME". Which did you mean?
  1. Measure Alpha (ID: 1)
  2. Measure Beta (ID: 2)
  ```
- **None** → "No measure found matching '{NAME}'." and stop.

## Flow: List Scorecard

Triggered when: no args, or only `--year`/`--include-archived`/`--team`. Resolve the team ID; call `get_team`; call `list_measurables` (`year` = `--year` or the current year; `include_archived` from the flag). The four week columns are the **Week starts** above; label each `Mon D` (H1..H4, e.g. `Sep 7`).

If `measures` is empty and `--include-archived` is not set: "No active measures on this scorecard. Use `/rkit:scorecard add "Name"` to create one." Otherwise:

```
Team Scorecard — {TEAM_NAME} ({FRAMEWORK_UPPER}) — {YEAR}
Showing last 4 weeks

ID   Name                  Unit  Dir     Target  Owner       {H1}    {H2}    {H3}    {H4}    Chart
──   ────────────────────  ────  ──────  ──────  ──────────  ──────  ──────  ──────  ──────  ──────────────
...
```

One row per measure, columns padded with spaces, header and separator line first: ID; name + ` [archived]` when `is_archived` + ` [roll-up: {roll_up_type, or ?}]` when `data_source_type` is 3; `unit`; `direction`; `target_value` (or `—`); owner as `first_name L.` (or `(none)`); the `value` of the history slot dated each week start (or `—`), with `*` appended when that slot's `note` is not null; `chart_type` (or `—`). After the table, one footnote per non-null note in the four displayed weeks, `* {Mon D}: {note}`; none → nothing extra.

## Flow: Record Value

Triggered when: first arg is `record`.

1. **Parse.** NAME (arg 2), VALUE (arg 3), `date=` (`YYYY-MM-DD` or `YYYY-MM`), `period=` (only `month`; default week). No NAME: "Usage: `/rkit:scorecard record \"Measure Name\" VALUE [date=YYYY-MM-DD|YYYY-MM] [period=month]`" and stop. No VALUE: "Value is required. Usage: `/rkit:scorecard record \"Name\" VALUE`" and stop. If no `period=` and the date is a full `YYYY-MM-DD`, ask with AskUserQuestion: `"{DATE_ARG}" looks like a full date. Record this as a weekly or monthly entry?` (options weekly/monthly) and set the period from the answer.
2. **Validate.** VALUE must match `^-?[0-9]+(\.[0-9]+)?$`, else `Value must be a number. Got: "{VALUE}"` and stop, no tool call.
3. **Date.** Monthly → `YYYY-MM`: strip `YYYY-MM-DD` to its first 7 characters; keep `YYYY-MM`; read a month name or month + year (year absent → current year, no prompt); none → current month (from Today). Weekly → the Monday of the week of the given date (a mid-week date moves back to its Monday), or this week's Monday (last Week start) when none. Call it RECORD_DATE.
4. **Resolve** the name. **Roll-up guard:** `data_source_type` 3 → print `"{MEASURE_NAME}" is a roll-up measure (auto-calculated from other measures). Manual value entry is not supported.` and stop: no confirmation, no tool call.
5. **Confirm** with AskUserQuestion: `Record value "{VALUE}" for "{MEASURE_NAME}" (ID: {MEASURE_ID}) for week of {RECORD_DATE}? [y/N]` (monthly: `for month of {RECORD_DATE}`). Anything but `y`/`yes` → "Cancelled."
6. **Call** `record_measurable_value` (`period` only when monthly; RECORD_DATE as `date`).
7. **Answer.** Success: "Recorded: {MEASURE_NAME} (ID: {MEASURE_ID}) — {VALUE} for week of {date} (history ID: {id})." (monthly: `for month of`), with `date` and `id` from the answer. "Measurable not found or you don't have access to it." (the ID just came from the list, so this is a refusal): "You can't record values for this measure — its `can_record_value` is `false` for you." Rights come back on every measure from `list_measurables`: `can_record_value` says whether this call would be accepted, `can_edit` whether the definition can be changed, and both are computed against the team that **owns** the measure. A plain member of the owning team can record values; an admin of a child team that merely inherits the scorecard cannot. Never gate value entry on `can_edit`: that would take entry away from plain members who have it.

## Flow: Record Note / Clear Note

Triggered when: first arg is `note`. `note clear` clears; otherwise TEXT is required.

1. **Parse.** `note`: NAME, TEXT, `date=`. No NAME: "Usage: `/rkit:scorecard note \"Measure Name\" \"Note text\" [date=YYYY-MM-DD]`"; no TEXT: "Note text is required. Usage: `/rkit:scorecard note \"Name\" \"Note text\"`". `note clear`: NAME is arg 3; none: "Usage: `/rkit:scorecard note clear \"Measure Name\" [date=YYYY-MM-DD]`". Stop on a usage error.
2. **Validate.** TEXT over 255 characters: "Note is too long (max 255 characters). Got {N} characters." and stop.
3. **Date.** The Monday of the week of `date=`, or this week's Monday. Call it NOTE_DATE. **Resolve** the name.
4. **Confirm** with AskUserQuestion; anything but `y`/`yes` → "Cancelled." Note: `Record note for "{MEASURE_NAME}" (ID: {MEASURE_ID}) for week of {NOTE_DATE}:` then `  "{TEXT}"` then `[y/N]`. Clear: `Clear note for "{MEASURE_NAME}" (ID: {MEASURE_ID}) for week of {NOTE_DATE}? [y/N]`.
5. **Call** `record_measurable_note` (`note` TEXT, or null to clear; `date` NOTE_DATE).
6. **Answer.** Note: `Noted: {MEASURE_NAME} (ID: {MEASURE_ID}) — week of {NOTE_DATE}` then `  "{TEXT}"`. Clear: `Note cleared: {MEASURE_NAME} (ID: {MEASURE_ID}) — week of {NOTE_DATE}`. "Measurable not found or you don't have access to it." → "You don't have permission to record notes for this measure." (clear: "You don't have permission to modify notes for this measure.").

## Flow: Create Measure

Triggered when: first arg is `add`. NAME (arg 2) required, else: "Measure name is required. Usage: `/rkit:scorecard add "Name" [unit=...] [direction=higher|lower] [target=...] [period=week|month|quarter|year] [aggregation=sum|last|average] [chart_type=...]`" and stop. Defaults: `unit` "", `direction` "higher", the rest none (the tool uses `week` and `sum`). Validate before anything else and stop on a bad value:

- `period`: `Invalid period "{PERIOD}". Valid values: week, month, quarter, year`
- `aggregation`: `Invalid aggregation "{AGGREGATION}". Valid values: sum, last, average`
- `chart_type`: `Invalid chart_type "{CHART_TYPE}". Valid values: pie, progress_circle, progress_bar, trend, bar_chart`

Confirm: `Create measure "{NAME}" (unit: {UNIT or "none"}, direction: {DIRECTION}, target: {TARGET or "none"}, period: {PERIOD or "week"}, aggregation: {AGGREGATION or "sum"}, chart_type: {CHART_TYPE or "none"})? [y/N]` (not `y`/`yes` → "Cancelled."). Call `create_measurable` with only the provided fields (always `team_id`, `name`). Success, from the answer: "Created: {name} (ID: {id}, unit: {unit or "none"}, direction: {direction}, target: {target_value or "none"}, period: {target_period}, aggregation: {aggregation_type}, chart_type: {chart_type or "none"})." "Team not found or you don't have access to it.": "You don't have permission to add measures to this team."

## Flow: Update Measure

Triggered when: first arg is `update`. NAME (arg 2) required, else "Usage: `/rkit:scorecard update \"Name\" [name=...] [unit=...] [direction=...] [target=...] [period=week|month|quarter|year] [aggregation=sum|last|average] [chart_type=...]`" and stop. No fields: "No fields to update. Specify at least one of: name, unit, direction, target, period, aggregation, chart_type." and stop. Validate `period` and `aggregation` as in Create; `chart_type` too, except `null` clears it: `Invalid chart_type "{CHART_TYPE}". Valid values: pie, progress_circle, progress_bar, trend, bar_chart (or "null" to clear)`.

Resolve the name. Change summary lists only the changed fields, each as `field → "value"` (`name`, `unit`, `direction`, `target`, `period`, `aggregation`, `chart_type`; `chart_type` shows `cleared` for `null`). Confirm `Update "{MEASURE_NAME}" (ID: {MEASURE_ID}) — set {change summary}? [y/N]` (not `y`/`yes` → "Cancelled."). Call `update_measurable`. Success: "Updated: {name from the answer} (ID: {MEASURE_ID}) — {change summary}." "Measurable not found or you don't have access to it." → "You don't have permission to edit this measure."

## Flow: Archive Measure

Triggered when: first arg is `archive`. NAME (arg 2) required, else "Usage: `/rkit:scorecard archive \"Name\"`" and stop. Resolve the name (archived included). Confirm `Archive "{MEASURE_NAME}" (ID: {MEASURE_ID})? It will be hidden from the default scorecard view. [y/N]` (not `y`/`yes` → "Cancelled."). Call `archive_measurable`. Success: "Archived: {MEASURE_NAME} (ID: {MEASURE_ID}). It will no longer appear in the default scorecard view." "Measurable not found or you don't have access to it." → "You don't have permission to archive this measure."

## Errors

| The tool answers | Say |
|---|---|
| tools missing, or an authorization error | "The ResultKit connector isn't connected. Connect it (https://mcp.resultkit.ai) and try again." |
| "Team not found or you don't have access to it." (`list_measurables`), or "Team not found." / "You don't have access to this team." (`get_team`) | "Team ID {id} not found, or you don't have permission to view this team's scorecard." |
| "Measurable not found or you don't have access to it." | The permission message of the flow above. |
| any other `Error: …` (bad date, bad value, owner, roll-up) | Show it as returned. |

Edge cases: owner null → `(none)`; `period=month` with a `YYYY-MM-DD` date is stripped to `YYYY-MM` with no error; a full date without `period=` asks weekly or monthly; a month name without a year uses the current year, no prompt; a date the tool refuses (e.g. `date must be a calendar date in YYYY-MM-DD format.`, `date must be YYYY-MM or YYYY-MM-DD for a monthly value.`) is shown as returned.
