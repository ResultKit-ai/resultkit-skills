---
name: rkit:open
description: Open anything in ResultKit in the user's web browser, or hand back the right link for it — an action item or to-do, a project (board, table, gantt), a page, a team, the Level 10 meeting, a rock, goal or milestone, a seat on the accountability chart, a person, a review, a 1-on-1, a roadmap, or the day plan. Use this skill whenever the user wants to see something in the app instead of the terminal — "open item 226310", "open this in resultkit", "pull it up", "take me to the L10", "show me the project board", "open my day plan", "give me the link to page 635", "what's the URL for this", "open that in my browser" — and whenever they paste a resultkit.ai or app.resultmaps.com link, or say "open it", "open #2", "open the first one" right after another rkit skill listed items. It knows the one link shape that survives a cold browser load and a login round-trip; never hand-build a ResultKit URL — route it through this skill.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(scripts/rk-open.sh *), Bash(jq *), Bash(open *), Bash(xdg-open *), Read, Glob, Grep, AskUserQuestion
---

# rkit:open

Open a ResultKit object in the browser, or produce its link. `scripts/rk-open.sh` builds the URL and launches the browser; this file decides *what* to open and *which shape* of link to use.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base, web_base: (.web_base // "https://resultkit.ai (default)")}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh: !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/open/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/open/scripts/api.sh "$HOME/.claude/skills/rkit:open/scripts/api.sh" "$HOME/.agents/skills/open/scripts/api.sh" "$HOME/.gemini/skills/open/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`
- rk-open.sh: !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/open/scripts/rk-open.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/open/scripts/rk-open.sh "$HOME/.claude/skills/rkit:open/scripts/rk-open.sh" "$HOME/.agents/skills/open/scripts/rk-open.sh" "$HOME/.gemini/skills/open/scripts/rk-open.sh" "skills/open/scripts/rk-open.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`
- Platform: !`uname -s`, over SSH: !`[ -n "$SSH_TTY$SSH_CONNECTION" ] && echo yes || echo no`

## Rules

- **Open means open.** "Open", "pull up", "take me to", "launch", "show me in the app" → launch the browser, no confirmation. Opening a tab is what the user asked for; asking again is friction. "Link", "URL", "address", "give me the link" → print the URL with `--print` and do not launch.
- **One request, one tab.** Never open more than one tab unless the user explicitly listed several things.
- **Resolve, don't guess.** A numeric ID is enough. A name goes through search, and more than one match means you ask. A wrong tab is worse than no tab.
- **The link shape matters.** An item is opened at `/items/{id}`. That is the only item link that survives a fresh browser load and a login round-trip — `https://resultkit.ai/?item={id}` looks right and silently lands on Home with nothing open. The mechanics are in `references/url-map.md`; you don't need them to act, you need the script.
- **Say what opened.** Reply with the object's name, its ID, and the URL, so the user can paste it into a message or a note. If the script reports `opened:false`, lead with the URL and the reason.
- **Direct execution.** Bash with `api.sh` and `rk-open.sh`. No Task agents.

---

## Tool Routing Table

Match the user's message against **Triggers**. Pick the first matching row. `{id}` is a number the user gave or one already on screen from an earlier rkit reply.

| Triggers | Intent | Flow |
|---|---|---|
| "open item {id}", "open {id}", "open task {id}", "open to-do {id}", "pull up {id}", "show me {id} in the app" | Open one item | `open_item` |
| "open the comments on {id}", "open {id} steps", "open {id} on the board", "open {id} in the L10" | Open one item on a tab or a surface | `open_item` with `--tab` / `--on` |
| "open project {id}", "open the board for …", "show me the project in the app", "open the gantt/table/overview for …" | Open a project page | `open_project` |
| "open page {id}", "open the … page", "take me to the wiki page" | Open a page | `open_page` |
| "open team {id}", "open the team page", "open my team" | Open a team home | `open_team` |
| "open the L10", "open level 10", "open the weekly meeting", "open the kanban", "take me to the meeting" | Open the Level 10 meeting | `open_l10` |
| "open rock …", "open goal …", "open milestone …", "pull up the rock" | Open a goal, rock, or milestone | `open_target` |
| "open the scorecard", "open the accountability chart", "open seat {id}", "open the org chart" | Open an EOS component | `open_component` |
| "open user {id}", "open {name}'s profile", "open my profile" | Open a person | `open_user` |
| "open review {id}", "open the 1:1 {id}", "open my 1 on 1 with …", "open roadmap {id}", "open today's result update" | Open another object by ID | `open_other` |
| "open my day plan", "open today", "open the prioritizer", "open home", "open resultkit" | Open a personal surface | `open_personal` |
| A pasted `resultkit.ai` or `app.resultmaps.com` link | Open (and repair or convert) a link | `open_url` |
| "open it", "open that", "open #2", "open the first one", "open the second" | Open something from an earlier reply | `open_from_context` |
| "open {name}" with no ID and no kind, "find and open …" | Resolve a name, then open | `resolve_by_name` |
| Any of the above phrased as "link", "URL", "give me the address" | Same flow, print only | add `--print` |

---

## Flows

Replace `<api.sh path>` and `<rk-open.sh path>` with the resolved paths from Current State. This is the whole interface of `rk-open.sh` — there is no need to read the script:

```
rk-open.sh item ID [--tab details|comments|steps|alignment] [--on /surface/path]
rk-open.sh project ID [--view overview|board|table|gantt|roadmap]
rk-open.sh page ID · team ID · user ID · review ID · 1on1 ID · roadmap ID · seat ID
rk-open.sh l10 TEAM_ID [--tab agenda|kanban|extras] · target ID --team TEAM_ID · scorecard TEAM_ID
rk-open.sh result-update YYYY-MM-DD · today · home · url "URL-or-/path"
any of the above + --print          → build the URL, don't launch
```

It prints one JSON line: `{"opened":true,"url":…,"opener":…}` or `{"opened":false,"url":…,"reason":"printed|headless|no_opener|launch_failed"}` or `{"error":"BAD_ID|BAD_OPTION|USAGE|FOREIGN_HOST|LEGACY_UNMAPPED","detail":…}`. `api.sh METHOD PATH` prints `{"status":…,"body":…}`.

### open_item

1. Confirm it exists and learn its name:
   ```bash
   API_SH="<api.sh path>"
   "$API_SH" GET "/items/ITEM_ID" | jq '{status, name: .body.data.name, team: .body.data.team.name, status_value: .body.data.status, error: .body.error.message}'
   ```
   404 → "Item {id} was not found, or you don't have access to it." Stop. Other errors → Error Handling below.
2. Check whether it is really a project — a project's own page is the better surface than a sheet over Home:
   ```bash
   "$API_SH" GET "/projects/ITEM_ID" | jq '{status, default_view: .body.data.default_view}'
   ```
   200 → continue with `open_project` (skip its lookup step). 404 → it is an item; continue.
3. Open it:
   ```bash
   RK_OPEN="<rk-open.sh path>"
   "$RK_OPEN" item ITEM_ID                                   # default: /items/{id}
   "$RK_OPEN" item ITEM_ID --tab comments                    # a tab needs a surface; defaults to /prioritizer
   "$RK_OPEN" item ITEM_ID --on "/level-10-meeting?team=TEAM_ID&tab=kanban"   # sheet over a chosen surface
   "$RK_OPEN" item ITEM_ID --print                           # link only
   ```
   Tabs: `details`, `comments`, `steps`, `alignment`. Surfaces: any authenticated path; `references/url-map.md` lists them.
4. Report per Reporting below.

### open_project

1. `"$API_SH" GET "/projects/PROJECT_ID" | jq '{status, name: .body.data.name, team: .body.data.team.name, default_view: .body.data.default_view}'`. 404 → the ID may be a plain item: run `open_item` instead.
2. `"$RK_OPEN" project PROJECT_ID` — with no `--view`, the app applies the project's shared default view and switches to the project's team. The user named a view → `--view overview|board|table|gantt` (`roadmap` is accepted and maps to `gantt`).
3. Report.

### open_page

`"$RK_OPEN" page PAGE_ID`. Pages carry their own team; nothing to look up. If the user gave a page *name*, go through `resolve_by_name` with `types=pages`.

### open_team

Team ID from the message, else `default_team_id` from config. `"$API_SH" GET "/teams/TEAM_ID"` for the name, then `"$RK_OPEN" team TEAM_ID`.

### open_l10

Team ID from the message, else `default_team_id`. `"$RK_OPEN" l10 TEAM_ID` opens the Agenda; `--tab kanban` or `--tab extras` when the user named one ("notes" is an alias of extras). Non-EOS teams have the same page under their framework's name; open it anyway.

### open_target

A goal, rock, or milestone opens in a drawer that finds the ID inside the **current team's** targets tree for the **current period**, so the team must ride along. Get the team ID from the search result (`team_id`), from the message, or from `default_team_id`; then `"$RK_OPEN" target TARGET_ID --team TEAM_ID`. For the name, `"$API_SH" GET "/teams/TEAM_ID/targets?year=All" | jq '[.body.data.targets[], (.body.data.unaligned // [])[] | .. | objects | select(.id == TARGET_ID)] | first | {name, object_type}'`. A target from an earlier year is not in the drawer's tree; open Traction for that year instead — `"$RK_OPEN" url "/components?tab=traction&team=TEAM_ID&year=YYYY"` — and say why.

### open_component

- Scorecard → `"$RK_OPEN" scorecard TEAM_ID`
- Accountability chart / a seat → `"$RK_OPEN" seat SEAT_ID`, or `"$RK_OPEN" url /plugins/accountability-chart` for the whole chart. The chart is scoped to the current team; say so if the seat belongs to another team.
- Vision, people, issues, process → `"$RK_OPEN" url "/components?tab=vision&team=TEAM_ID"` with the matching tab (`vision`, `people`, `data`, `issues`, `traction`, `process`).

### open_user

"me" → `"$API_SH" GET "/users/me" | jq '.body.data.id'`. A name → `resolve_by_name` with `types=people`. Then `"$RK_OPEN" user USER_ID`.

### open_other

`"$RK_OPEN" review ID` · `"$RK_OPEN" 1on1 ID` · `"$RK_OPEN" roadmap ID` · `"$RK_OPEN" result-update YYYY-MM-DD` (today's date for "today's result update").

### open_personal

`"$RK_OPEN" today` (the day plan / Personal Planner) · `"$RK_OPEN" home` · `"$RK_OPEN" url /notifications` · `"$RK_OPEN" url /customize` (profile and API token).

### open_url

1. Normalize without launching: `"$RK_OPEN" url "PASTED_URL" --print`. The script converts legacy `app.resultmaps.com` items, groups (→ teams), and users; repairs the broken root `?item=` shape into `/items/{id}`; and refuses any other host.
2. Route by the path that comes back so the user gets a name, not just an address: `/items/{id}` → `open_item` · `/teams/{id}` → `open_team` · `/users/{id}` → `open_user` · `/plugins/projects/{id}…` → `open_project` · anything else → `"$RK_OPEN" url "THE_URL"` as is.
3. `LEGACY_UNMAPPED` → tell the user that legacy path has no counterpart in ResultKit and offer the nearest surface from `references/url-map.md`. `FOREIGN_HOST` → "I only open ResultKit links."

### open_from_context

Take the ID from the most recent rkit reply in this conversation ("#2" = the second row shown, "the first one" = row 1). If that reply showed nothing with an ID, or the reference could fit more than one row, ask which one. Then run the flow for that object's kind (item, project, page, …).

### resolve_by_name

1. Search across types (URL-encode the query; two characters minimum):
   ```bash
   Q=$(jq -rn --arg q "THE NAME" '$q|@uri')
   "$API_SH" GET "/search?q=$Q&types=items,projects,pages,rocks,people,reviews&limit=5" | jq '.body.groups | to_entries[] | .value[] | {id, entity_type, name, team_name, team_id, status}'
   ```
   Narrow `types=` when the user's words name a kind ("project", "page", "rock", person's name).
2. Zero results → "Nothing named '…' that you can see." One → open it. Several → show a table (`#`, type, ID, name, team) and ask which one; then open that row.
3. Route by `entity_type`: `Item` → `open_item` · `Project` → `open_project` · `Page` → `open_page` · `Rock` → `open_target` with its `team_id` · `Person` → `open_user` · `Review` → `open_other` · `Measure` → `open_component` (scorecard for its `team_id`). Ignore `url_hint` — for rocks and measures it names paths that do not exist in the app. Details in `references/name-resolution.md`.

---

## Reporting

After `opened:true`:

> Opened **{name}** ({kind} {id}) — {url}

After `opened:false`:

- `reason: printed` → `**{name}** ({kind} {id}): {url}` — the user asked for a link, that is the whole reply.
- `reason: headless` → "No browser on this end (SSH session). Open this: {url}"
- `reason: no_opener` / `launch_failed` → give the URL and the one-line fix from `references/browser-opening.md` (install `xdg-utils`, set `BROWSER`, or open it by hand).

Include the URL every time. It is the artifact the user will paste somewhere else.

## Error Handling

- `"error": "NO_CONFIG"` / `"NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 403` → "You don't have access to {kind} {id}."
- `status: 404` → "{Kind} {id} was not found."
- rk-open.sh `BAD_ID` / `BAD_OPTION` → fix the call; never show the user a raw usage error.
- rk-open.sh `NOT_FOUND` in Current State → build the URL from `references/url-map.md` and launch with `open` (macOS) or `xdg-open` (Linux); print it when neither exists.

## References

- `references/url-map.md` — every ResultKit object → URL shape, the deep-link parameters (`item`, `target`, `seat`, `tab`, `team`), why `/items/{id}` is the item link, legacy conversions. Read it when the user asks for a surface or context this file doesn't list, or asks "why this link".
- `references/browser-opening.md` — how the launcher picks `open` / `xdg-open` / `wslview` / `$BROWSER`, headless and SSH behavior, choosing a specific browser, `web_base` for a local or staging app. Read it when `opened:false` or the user is on Windows, WSL, or a remote box.
- `references/name-resolution.md` — the search endpoint's shape and limits, disambiguation, fallbacks when search is thin. Read it when a name lookup is ambiguous or returns a type not covered above.
- `references/api-reference.md` — the full V2 API. Only for endpoints beyond the four used here.
