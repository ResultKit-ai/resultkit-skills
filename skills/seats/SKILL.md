---
name: rkit:seats
description: View and manage your team's accountability chart (seats). Shows the accountability hierarchy, seat details, owners, measures, goals, and links. Supports creating, updating, deleting, moving, and restoring seats, plus aligning measures/goals and managing links. Use when users mention seats, accountability chart, org chart, who owns what role, vacant positions, or seat management.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Read, Glob, Grep, AskUserQuestion
---

# rkit:seats

View and manage the team accountability chart. It drives the ResultKit connector's MCP tools, named below by base name (the full name is `mcp__<server>__<tool>`; the server alias varies by install). Every job here has a live connector tool, so `scripts/api.sh` is not used.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`

## Rules

- **Confirm writes.** Reads execute immediately. Create, update, archive, move, restore, align/remove and link changes require user confirmation before executing.
- **Show IDs.** Always include entity IDs in output for follow-up reference (this overrides the connector's general "never print raw ids" note).
- **Concise output.** Trees, tables, and short summaries. No filler.
- **Direct execution.** Call the connector tools directly. Never use Task agents, never curl or hand-build a URL, and skip the connector's `guide` tool — the routing below is complete for this skill.
- **Framework-aware.** Use the team's `framework` field for terminology: EOS = "Accountability Chart", generic = "Org Chart". Measures = "Measurables" (EOS) or "KPIs". Goals = "Rocks" (EOS) or "Goals".

## Argument Parsing

| Input | Behavior | Tool |
|-------|----------|------|
| *(no args)* | View accountability chart tree for default team | `list_seats` |
| `--include-archived` | Include archived seats in chart view | `list_seats` |
| `{id}` | View seat detail by ID | `get_seat` |
| `--team {id}` | Use specified team instead of default | `list_seats` |
| `create "NAME" [--parent {id}]` | Create a new seat | `create_seat` |
| `update {id} [--name "..."] [--owner {uid}] [--notes "..."] [--accountabilities "..."] [--associated-team {tid}]` | Update seat fields | `update_seat` |
| `delete {id}` | Archive a seat | `archive_seat` |
| `move {id} --parent {id}` | Move seat to new parent | `move_seat` |
| `restore {id}` | Restore an archived seat | `restore_seat` |
| `align-measure {id} --measure {mid}` | Align a measure to a seat | `align_seat_measurable` |
| `remove-measure {id} --measure {mid}` | Remove a measure from a seat | `unalign_seat_measurable` |
| `align-goal {id} --goal {gid}` | Align a goal to a seat | `align_seat_goal` |
| `remove-goal {id} --goal {gid}` | Remove a goal from a seat | `unalign_seat_goal` |
| `add-link {id} --url "..." [--title "..."]` | Add a link to a seat | `add_seat_link` |
| `update-link {id} --link {lid} [--url "..."] [--title "..."]` | Update an existing link on a seat | `update_seat_link` |
| `remove-link {id} --link {lid}` | Remove a link from a seat | `remove_seat_link` |

**Team ID Resolution** (chart view and root-seat create): the `--team {id}` flag, else `default_team_id` in config, else prompt for a team ID — "No default team configured. Run `/rkit:setup` first."

## Flow: View Accountability Chart

Triggered when: no args, or only `--team {id}` / `--include-archived`. Resolve the team ID, then call `list_seats` with `scope: "team"`, `team_id`, and `include_archived: true` only when `--include-archived` was given. It answers a JSON array of root seats, each with recursive `children[]`.

- **Empty array**: > No seats found for this team. Create one with `/rkit:seats create "Role Name"`.
- **Seats present**: take the team name and framework from the first seat's `team` field. Header:
  ```
  Accountability Chart — {TeamName} [Team: {TeamID}]
  ```
  (Use "Org Chart" if framework is not "eos".) Then render the tree recursively, one line per seat:
  ```
  {prefix}{connector} {name} ({owner}) [ID: {id}]
  ```
  With `--include-archived`, a seat with `archived: true` gets ` [archived]` appended. Where `{owner}` = `{first_name} {last_name}` from `seat_owner`, or `Vacant` if null; `{connector}` = `├──` for non-last children, `└──` for the last child; `{prefix}` = accumulated `│   ` or `    ` from parent levels; root seats use the same logic, treating the array as children.

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

## Flow: View Seat Details

Triggered when: the first arg is a numeric ID (e.g., `/rkit:seats 11`). Call `get_seat` with `seat_id`; it answers one JSON seat. Display (the same format is used after create, update, move and restore):

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

- `seat_owner` null → "Vacant" for Owner; `parent` null → "None (root)"; `associated_team` null → "None"; `accountabilities` null → "None"; empty arrays → "None" instead of an empty table.
- **HTML stripping** for accountabilities: `<li>` → `- `, `<br>` and `</li>` → a newline, drop every other tag, drop blank lines.

## Writes

Confirm first (describe the change, ask for confirmation), then call the tool. Create, update, move and restore answer the full seat (show it as above); the rest answer one line. Align answers raw rows.

| Flow | Tool and arguments | Confirm | On success |
|---|---|---|---|
| create | `create_seat`: `name` and `team_id` (root seat, no `--parent`) or `parent_id` (child seat) | **Create seat**: "{name}" under {parent name or "as root seat"} in team {team_id} | The created seat detail. A refusal such as "Team already has a root seat": show it. |
| update | `update_seat`: `seat_id` plus `name`, `seat_owner_id` (`--owner`), `notes`, `accountabilities`, `associated_team_id` (`--associated-team`) | **Update seat** [ID: {id}]: {list of changes}. With `--owner`, add: Note: changing the owner will reassign all aligned measures and goals to the new owner. | The updated seat detail. |
| delete | `archive_seat`: `seat_id` | **Archive seat** [ID: {id}]? This will archive this seat AND all its descendants. This cannot be undone without restoring each seat individually. | Seat [ID: {id}] archived successfully. |
| move | `move_seat`: `seat_id`, `parent_id`. No `--parent` → "Missing `--parent {id}` flag. Usage: `/rkit:seats move {id} --parent {new_parent_id}`" | **Move seat** [ID: {id}] under new parent [ID: {parent_id}]? | The updated seat detail. A refusal such as "Cannot move root seat": show it. |
| restore | `restore_seat`: `seat_id` | **Restore seat** [ID: {id}]? Only this seat will be restored — descendant seats remain archived and must be restored individually. | The restored seat detail. "Seat is not archived" → "Seat is not archived." |
| align-measure | `align_seat_measurable`: `seat_id`, `measurable_id` (`--measure`) | **Align measure** [ID: {mid}] to seat [ID: {id}]? | The seat's measures as a table with ID, Name and Chart Type; Chart Type is the `chart_type` value when non-null, `—` when null. |
| remove-measure | `unalign_seat_measurable`: `seat_id`, `measurable_id` | **Remove measure** [ID: {mid}] from seat [ID: {id}]? | Measure [ID: {mid}] removed from seat [ID: {id}]. |
| align-goal | `align_seat_goal`: `seat_id`, `goal_id` (`--goal`) | **Align goal** [ID: {gid}] to seat [ID: {id}]? | The seat's goals as a table with ID and Name. |
| remove-goal | `unalign_seat_goal`: `seat_id`, `goal_id` | **Remove goal** [ID: {gid}] from seat [ID: {id}]? | Goal [ID: {gid}] removed from seat [ID: {id}]. |
| add-link | `add_seat_link`: `seat_id`, `url`, and `title` only when given (it defaults to the URL) | **Add link** "{title or url}" to seat [ID: {id}]? | The created link (ID, Title, URL). |
| update-link | `update_seat_link`: `seat_id`, `link_id` (`--link`), and only the `url` / `title` given. Neither given → "At least one of `--url` or `--title` is required. Usage: `/rkit:seats update-link {id} --link {lid} [--url \"...\"] [--title \"...\"]`" | **Update link** [ID: {lid}] on seat [ID: {id}]: {list of changes}? | The updated link (ID, Title, URL). |
| remove-link | `remove_seat_link`: `seat_id`, `link_id` | **Remove link** [ID: {lid}] from seat [ID: {id}]? | Link [ID: {lid}] removed from seat [ID: {id}]. |

## Fallback (api.sh)

None. Every job above has a live connector tool.

## Errors

| The tool answers | Say |
|---|---|
| tools missing, or an authorization error | "The ResultKit connector isn't connected. Connect it (https://mcp.resultkit.ai) and try again." |
| "Seat not found or you don't have access to it." | "Seat not found, or you don't have access to it. Check the ID and your team membership." |
| "Team not found or you don't have access to it." | "Team not found, or you don't have access to it. Check the team ID and your team membership." |
| any other `Error: …` (a validation refusal) | Show it as returned. |

**Edge cases.** No `default_team_id` and no `--team`: prompt for a team ID. Seat owner null: "Vacant" in tree and detail. Accountabilities, associated team or parent null: "None" / "None (root)" in the detail view. Empty seats array: "No seats found for this team. Create one with `/rkit:seats create \"Role Name\"`."
