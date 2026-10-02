---
name: rkit:meetings
description: Build and refresh a local "ResultMaps Team and Project IDs" reference doc by interactively asking which teams/orgs the user works with, then fetching each team's projects and one-on-one meetings via the ResultMaps V2 API. Use this skill whenever the user wants to seed or refresh their team/project/1:1 ID catalog, mentions running it after /rkit:setup, or asks anything like "list my teams and 1:1s", "build my meetings doc", "refresh team IDs", "catalog my 1:1s by team", "update my IDs reference", or anything else that requires a consolidated reference of team IDs, project IDs, and 1:1 IDs across multiple orgs. Trigger this skill liberally — users won't always say "rkit:meetings" but will describe what they want.
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Bash(date *), Bash(mkdir -p *), Bash(test *), Bash(grep *), Bash(sed *), Read, Write, Edit, AskUserQuestion
---

# rkit:meetings

Builds and refreshes a single local markdown file that catalogs the teams, projects, and 1:1 meetings you care about across orgs. The file is meant to be the stable reference Claude greps when you say things like "show me Mender's project board" or "open my 1:1 with Stacy" — so the IDs need to be accurate and the doc needs to be friendly to skim.

It reads projects and one-on-ones through the ResultKit connector's MCP tools; `scripts/api.sh` is used only for the jobs under **Fallback (api.sh)**. Tools are named by base name below; the callable name is `mcp__<server>__<tool>` and the `<server>` alias varies by install, so match on the base name.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then jq -r '"OK — meetings_doc_path: " + (.meetings_doc_path // "(default)")' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup first"; fi`
- Doc target: !`jq -r '.meetings_doc_path // "/Users/scottilevy/Development/rk-chief-of-staff/ResultMaps Team and Project IDs.md"' "$HOME/.config/resultkit/config.json" 2>/dev/null || echo "(default path)"`
- Doc state: !`DOC=$(jq -r '.meetings_doc_path // "/Users/scottilevy/Development/rk-chief-of-staff/ResultMaps Team and Project IDs.md"' "$HOME/.config/resultkit/config.json" 2>/dev/null); if [ -f "$DOC" ]; then if grep -q '<!-- rkit:meetings:start -->' "$DOC" 2>/dev/null; then echo "EXISTS (with markers)"; else echo "EXISTS (no markers — confirm before overwrite)"; fi; else echo "NOT YET — first run will create"; fi`

## Rules

- **Read references before improvising.** [`references/doc-format.md`](references/doc-format.md) defines the exact markdown structure and marker fences. [`references/team-selection.md`](references/team-selection.md) defines the selection UX. Don't reinvent either.
- **Confirm writes.** Before writing the doc, show a one-line summary ("3 teams, 12 projects, 18 1:1s") and ask the user to confirm.
- **Preserve human edits.** Only the content between `<!-- rkit:meetings:start -->` and `<!-- rkit:meetings:end -->` is auto-managed. Anything outside the markers is the user's; never touch it.
- **Concise output.** Tables and short summaries. Don't echo raw tool or API JSON to the user.
- **Default to the right action.** On refresh, default to "use the same teams as last time." Make the lazy path correct.
- **Direct execution.** Call the connector tools directly. Never use Task agents or subagents, never curl or hand-build a URL, and skip the connector's `guide` tool — the flow below is complete for this skill.

## Flow

### Step 1: Preflight

If `Current State → Config` shows MISSING, tell the user to run `/rkit:setup` first and stop.

Determine the doc path: `meetings_doc_path` from config, else default `/Users/scottilevy/Development/rk-chief-of-staff/ResultMaps Team and Project IDs.md`. If the parent directory doesn't exist, ask the user before creating it (`mkdir -p`).

### Step 2: Detect first-run vs refresh

Check whether the doc file exists.

- **First run** (no file): no defaults; jump to Step 3 with an empty pre-selection.
- **Refresh** (file exists): parse the Teams table inside the markers to get the currently-tracked team IDs. These become the default selection.

If the file exists but has no markers, ask before overwriting. Offer to wrap the existing auto-looking sections in markers if the user confirms.

### Step 3: Select teams

Follow [`references/team-selection.md`](references/team-selection.md). High-level:

1. Run the Fallback teams read: `GET /teams?per_page=100` (paginate if `meta.total_pages > 1`). The connector's `list_teams` answers names and ids only — no `parent_id` — so it cannot build the Org column or the grouping under parent orgs.
2. **On refresh, ask first**: "Refresh with the current selection ({N} teams), or change which teams are tracked?" — Options: `Refresh same`, `Change selection`, `Cancel`. If `Refresh same`, skip to Step 4.
3. **Multi-select** the teams to track. Group teams visually under their parent org (indent children by 2 spaces). On refresh, pre-check the previous selection.

### Step 4: Fetch projects + 1:1s

For each selected team, in parallel:

- `projects` (`team_id`) — projects. Answers JSON `{items, page, perPage, total}`; each project has `id` and `name`.
- `list_1on1s` (`team_id`, `per_page` 100) — 1:1s. Answers JSON `{one_on_ones, page, per_page, total}`; each has `id`, `human_name` and `created_at`.

Paginate `list_1on1s` (`page` 2, 3, … while `page × per_page < total`). `projects` has no page input, so when its `total` > 100 fetch the rest with the Fallback projects read. If a team has zero projects or zero 1:1s, render `_None._` in the corresponding subsection — don't omit the heading.

While fetching, give one short status line per team ("Fetched Mender: 5 projects, 10 1:1s"). Don't dump the JSON.

### Step 5: Confirm + write

Build the assembled markdown per [`references/doc-format.md`](references/doc-format.md). Print a one-line summary and ask:

> About to write {N} teams, {M} projects, {K} 1:1s to `{path}`. Proceed?

On confirm:
- If the file exists with markers → replace only the content between markers (preserve everything outside).
- If the file exists without markers → user already confirmed in Step 2; do the agreed action.
- If the file doesn't exist → create it with the full template (header above markers, auto-managed block inside, empty space after markers for human notes).

### Step 6: Done

Print:
> Wrote `{path}` — {N} teams, {M} projects, {K} 1:1s. Last updated {YYYY-MM-DD}.

## Edge Cases

- **No teams selected** → confirm "Empty catalog — are you sure?" then exit without writing.
- **API failure mid-run** → don't write a partial doc. Tell the user which call failed and stop.
- **Doc path outside `$HOME`** → fine if `meetings_doc_path` is configured, but warn before creating new directories outside `$HOME`.
- **Team disappeared between runs** (was in old Teams table, no longer in `/teams` response) → drop it silently from the new doc; don't error. The user removed access; respect that.
- **`meetings_doc_path` set but unreachable** (e.g., external drive unmounted) → tell the user, offer to fall back to the default path for this run only.

## Fallback (api.sh)

The connector has no tool for these jobs, so they run as before: `scripts/api.sh GET PATH` (this skill's script) returns `{status, body}`. Reads need no confirmation.

| Job | Call |
|---|---|
| All teams with their parent (Step 3) | `GET /teams?per_page=100`; teams in `body.data` with `id`, `name`, `parent_id`; paginate while `meta.total_pages` is greater than the page |
| Projects past the first 100 (Step 4) | `GET /teams/{id}/projects?per_page=100&page=N`; projects in `body.data` with `id`, `name`; `meta.total_pages` |

api.sh errors: `NO_CONFIG` or `NO_TOKEN` "Config not found. Run `/rkit:setup` first."; `CURL_FAILED` "Network error. Check your connection."; 401 "Unauthorized (401). Run `/rkit:setup` to update your token."; path `NOT_FOUND` "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"

## Errors

Tools missing, or an authorization error → "The ResultKit connector isn't connected. Connect it (https://mcp.resultkit.ai) and try again." and stop without writing. Any other `Error: …` from a tool is an API failure mid-run (see Edge Cases).

## References

- [Output doc format and markers](references/doc-format.md)
- [Team selection UX](references/team-selection.md)
- [ResultMaps V2 API Reference](references/api-reference.md)
