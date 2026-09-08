---
name: rkit:projects
description: List active projects for a team and manage project items. View project columns with item counts, add items to specific columns, and batch-add multiple items. Use this skill when users ask about projects, project boards, project columns, want to list team projects, add items to a project, or view project status.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Read, Glob, Grep, AskUserQuestion
---

# rkit:projects

List active projects for a team. Drill into a project to see its columns and add items.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh: !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/projects/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/projects/scripts/api.sh "$HOME/.claude/skills/rkit:projects/scripts/api.sh" "$HOME/.agents/skills/projects/scripts/api.sh" "$HOME/.gemini/skills/projects/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes.** Before any POST, summarize all planned changes in a single prompt and ask for confirmation. If the command implies multiple related mutations, batch them under one confirmation. GET requests execute immediately.
- **Show IDs.** Always include project and item IDs in output.
- **Concise output.** Tables and short summaries. No filler.
- **Direct execution.** Use Bash with api.sh for all API calls. Never use Task agents.
- **Two-level shape.** A project's direct children are usually **columns / section names**, not to-dos. The actual to-dos are **grandchildren** under those columns. A minority of projects are flat checklists (items as direct children, no columns). Never present direct children as to-dos without first checking. See the **Project Hierarchy** section in `references/api-reference.md` for detection and fetch patterns.

## Argument Parsing

| Input | Behavior |
|-------|----------|
| *(no args)* | List **active** projects for default team (excludes done/archived) |
| `{team_id}` | List active projects for specified team |
| `done` / `completed` | List done projects (passes `?status=done`) |
| `q "search term"` | Filter projects by name |
| `{project_id} columns` | Show columns (direct children) of a project |
| `{project_id} add "item name"` | Add an item to a project column (prompts for column if not specified) |
| `{project_id} add {column_id} "item name"` | Add an item directly to a specific column |

---

## Flow: List Projects

### Step 1: Resolve team ID

- If a team ID is provided in args → use it
- Otherwise → use `default_team_id` from Current State config
- If neither available → "No team specified and no default configured. Run `/rkit:setup`."

### Step 2: Build query params

Start with `per_page=100`. The API filters by status server-side (default: active only).

- If user asked for `done` / `completed` → add `status=done`
- If `q "term"` is in args → add `q=term`

### Step 3: Fetch projects

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" GET "/teams/TEAM_ID/projects?per_page=50&EXTRA_PARAMS")
echo "$RESPONSE"
```

Replace `TEAM_ID` and `EXTRA_PARAMS` with actual values.

### Step 4: Handle response

Parse the JSON response from api.sh:

**Error responses** (status 0 or non-200):
- `"error": "NO_CONFIG"` or `"error": "NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 404` → "Team not found (404)."
- Other non-200 → Show status code and error from response body.

**Success (status 200)**:

Extract `body.data` array (the projects) and `body.meta` (pagination info).

After extracting:

- **Empty result**: "No active projects for team {team_id}."

- **Projects present**: Display as a table:

  ```
  ## Active Projects — Team {team_id}

  | ID | Name | Status | Due | Creator |
  |----|------|--------|-----|---------|
  | 201 | Q1 Product Launch | not_started | 2026-03-31 | Jane D. |
  | 205 | API Migration | parked | — | John S. |

  {count} active projects ({total} total)
  ```

  - `Due` column: show date if present, "—" if null
  - `Creator` column: show `creator.first_name` + last initial (e.g., "Jane D.")
  - Show count of filtered results and total from API
  - If `meta.total_pages` > 1: show "Page {page} of {total_pages}" with note about additional pages
  - **Footer hint**: After the table, always show:
    ```
    Tip: `/rkit:projects {id} columns` to view columns · `/rkit:projects {id} add "item"` to add items · `/rkit:board {id}` for full board view
    ```

---

## Flow: View Project Columns

**Trigger**: `{project_id} columns`

### Step 1: Fetch project children (columns)

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" GET "/items/PROJECT_ID/children?per_page=50")
echo "$RESPONSE"
```

### Step 2: Handle response

- Error → use Error Handling from List Projects flow
- Success (status 200): Extract `body.data` (columns)
- **Empty data array** → "No columns found for project {project_id}."
- **Columns present** → display:

  ```
  ## Columns — {project_name} ({project_id})

  | ID | Column | Items |
  |----|--------|-------|
  | 207441 | Backlog | 12 |
  | 207442 | Do next | 3 |
  | 207443 | Working | 5 |
  | 207444 | Done | 8 |

  Tip: `/rkit:projects {project_id} add "item name"` to add an item · `/rkit:board {project_id}` for full board view
  ```

  To get item counts per column, fetch each column's children:

  ```bash
  API_SH="<api.sh path>"
  RESPONSE=$("$API_SH" GET "/items/COLUMN_ID/children?per_page=1")
  echo "$RESPONSE"
  ```

  Use `body.meta.total` for the count (only need 1 result to get the total).

---

## Flow: Add Item to Project Column

**Trigger**: `{project_id} add "item name"` or `{project_id} add {column_id} "item name"`

### Step 1: Resolve column

**If column ID is provided** (three args after project_id: column_id + item name): use that column ID directly.

**If no column ID** (just project_id + item name):

Fetch columns:

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" GET "/items/PROJECT_ID/children?per_page=50")
echo "$RESPONSE"
```

List columns with IDs and ask user to pick:

```
Which column?
1. Backlog (207441)
2. Do next (207442)
3. Working (207443)
4. Done (207444)
```

### Step 2: Confirm and execute

Describe the action:
> Create item "**{name}**" under **{column_name}** (ID: {column_id})?

Wait for confirmation. Then execute:

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" POST "/items" '{"name": "ITEM_NAME", "parent_id": COLUMN_ID}')
echo "$RESPONSE"
```

Escape any double quotes in ITEM_NAME.

### Step 3: Handle response

- **Status 201**: "Created item **{id}**: \"{name}\" under **{column_name}** (ID: {column_id})."
- **Status 422** → show validation error
- **Error** → use Error Handling from List Projects flow

### Batch add

If the user provides multiple item names (comma-separated, or multiple quoted strings), create each one under the same column. Confirm the full list before executing. Display results as a table:

```
Added to {column_name} ({column_id}):

| ID | Name |
|----|------|
| 211296 | CDW quote tool |
| 211297 | Research Pipedrive workflow |
```

---

## Project Status Values (from live API)

Projects use the same status field as items:

| Status | Meaning | Active? |
|--------|---------|---------|
| `not_started` | Not yet begun | yes |
| `parked` | On hold | yes |
| `done` | Completed | no |
| `archived` | Archived | no |

**"Active" = not done and not archived.** The API filters by status server-side: default returns only active projects. Use `?status=done` or `?status=parked` to get other statuses. Use `?include_muted=true` to include muted projects.

## Edge Cases

- **No config**: "Config not found. Run `/rkit:setup` first."
- **api.sh not found**: "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"
- **No projects**: "No active projects for team {team_id}."
- **Team not found (404)**: "Team {team_id} not found."
- **No columns**: "No columns found for project {project_id}." (project has no direct children)
- **Project not found (404)**: "Project {project_id} not found."
- **Ambiguous project_id vs team_id**: If the first arg is a number followed by `columns` or `add`, treat it as a project ID. Otherwise treat it as a team ID.

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
