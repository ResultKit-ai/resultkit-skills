# User Context Schema

Reference for `GET /users/me/context` — the full organizational snapshot endpoint.

Read this file when a user's request involves **multiple teams**, **a team referenced by name**, or **cross-team data** (rocks, issues, projects, measures across teams). This endpoint returns everything in one call so you can resolve names to IDs and navigate without extra round-trips.

## When to Call This Endpoint

Call `/users/me/context` when the user says things like:

- "show me rocks for **the Sales team**" (team name needs resolving to ID)
- "find my one-on-ones in **Team Alpha**" (need team ID to query meetings)
- "let's look at **two projects** in the Leadership team" (need team's project list)
- "what are **all my open issues**?" (cross-team collection)
- "compare measures between **Engineering and Product**" (multi-team)

Do NOT call it for simple operations where the team ID is already known from config (`current_team`), or when you only need the user's profile (`GET /users/me`).

## Request

```
GET /users/me/context
Authorization: Bearer <api_token>
```

No query parameters. No request body.

## Response Shape

```
data
├── user                          # Authenticated user profile
│   ├── id                        integer
│   ├── name                      string (full name)
│   ├── email                     string
│   ├── login                     string
│   └── avatar_url                string | null
│
├── organizations[]               # Every org the user belongs to — served from accounts today; an organization is a root team, not an account
│   ├── id                        integer (account ID)
│   ├── name                      string
│   ├── role                      "owner" | "member"
│   └── teams[]                   # Every team in this org
│       ├── id                    integer
│       ├── name                  string
│       ├── framework             string (eos, okr, 4dx, v2mom, srt, svep)
│       ├── is_root               boolean (true = org-level root team)
│       ├── role
│       │   ├── is_admin          boolean
│       │   ├── designation       string | null (visionary, integrator, leadership_team, front_line)
│       │   └── seats_owned[]     [{id, name}]
│       ├── vision
│       │   ├── core_values[]     [{id, name}]
│       │   ├── core_focus        {purpose, niche} | null
│       │   └── bhag              string | null (10-year target)
│       ├── three_year_plan       {text} | null
│       ├── one_year_plan         {goals: [{id, name, status}]} | null
│       ├── rocks[]               [{id, name, status, due, milestones: [{id, name, status, due}]}]
│       ├── measures[]            [{id, name, current_value, target_value, goal, unit}]
│       ├── projects[]            [{id, name, status, child_count, children: [{id, name, status}]}]
│       ├── todos[]               [{id, name, status, due}]
│       └── issues[]              [{id, name, is_long_term, owner: {id, name} | null}]
│
└── day_plan                      # Today's plan (root-level, not per-team) | null
    ├── id                        integer
    ├── date                      string (ISO date)
    └── items[]                   [{id, name, completed, position, team_id, team_name}]
```

## Disambiguation Patterns

These are the common workflows where `/users/me/context` unlocks the right data.

### Resolve a team name to an ID

User says: *"show me the rocks for Product Team"*

1. Call `GET /users/me/context`
2. Search `organizations[].teams[]` for `name` matching "Product Team" (fuzzy/case-insensitive)
3. Use the matched team's `rocks[]` directly from the response — or use `team.id` for follow-up API calls

### Collect items across all teams

User says: *"what are all my open issues?"*

1. Call `GET /users/me/context`
2. Iterate `organizations[].teams[].issues[]`
3. Group by team name for display

### Cross-team navigation

User says: *"let's look at two projects in the Leadership team"*

1. Call `GET /users/me/context`
2. Find the team whose name matches "Leadership" (fuzzy match)
3. Read `projects[]` from that team — present the list for the user to pick from
4. Use project IDs for deeper calls (e.g., `GET /items/{id}/children`)

### Meetings (not in context — use team ID)

User says: *"find my one-on-ones in the Sales team"*

1. Call `GET /users/me/context`
2. Resolve "Sales team" to a team ID
3. Call `GET /meetings?team_id={id}&meeting_type=one_on_one`

Meetings are **not** included in the context response. The context gives you the team ID you need to query them.

### Team role awareness

User says: *"am I an admin on the Engineering team?"*

1. Call `GET /users/me/context`
2. Find the Engineering team
3. Check `team.role.is_admin`, `team.role.designation`, `team.role.seats_owned`

## Response Behavior

- **Empty collections** return `[]`, absent objects return `null`
- **Active-item filtering**: realized, archived, and deleted items are excluded automatically
- **day_plan is root-level** — not nested under any team
- **Vision may be inherited** from the root team
- **Rocks are current quarter only**
- **Todos are filtered** to active/incomplete items assigned to the authenticated user
- **Projects include one level of children** only (immediate children, not full tree)
- **measures[].goal** is the tracking direction: `above` (higher is better), `below` (lower is better), `exact`
- **issues[].is_long_term**: `false` = L10 short-term issue, `true` = VTO long-term issue

## Error Handling

**401 Unauthorized**: Token is invalid or expired. Prompt user to re-run `/rkit:setup`.

## See Also

- `GET /users/me` — basic profile; add `?include=access` for role enrichment on current/default team only
- `PATCH /users/me/team-context` — set the active team (changes `current_team` in `/users/me`)
- `GET /meetings` — meetings are not in `/context`; use the team ID from context to query them
