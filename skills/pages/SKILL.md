---
name: rkit:pages
description: List, read, create, update, move, and delete team Pages (the team wiki/docs tree) via the ResultMaps API. Use this skill when users ask about pages, team docs, team wiki, team notes, want to list pages, open or read a page, create a new page or doc, write content to a page, rename a page, move or nest a page under another, reorder pages, or delete a page.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Bash(pandoc *), Bash(npx *), Read, Glob, Grep, AskUserQuestion
---

# rkit:pages

Team-scoped hierarchical document pages ("team wiki"). Pages form a tree via `parent_id`; the list endpoint returns a flat array — build the tree client-side.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh: !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/pages/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/pages/scripts/api.sh "$HOME/.claude/skills/rkit:pages/scripts/api.sh" "$HOME/.agents/skills/pages/scripts/api.sh" "$HOME/.gemini/skills/pages/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes.** Before any POST/PATCH/DELETE, summarize all planned changes in a single prompt and ask for confirmation. Batch related mutations under one confirmation. GET requests execute immediately.
- **Body is markdown by default.** Send the user's markdown as written with `?format=markdown` on create/update — the API converts it and stores the markdown source, so a markdown read gives back exactly what was written. Never convert locally. Say which format you used and name the alternative: markdown is the default (it uses fewer tokens and reads back unchanged); HTML is there for finer control of formatting. If the user says "use HTML", send their HTML unchanged with no `format` param. Never make them guess.
- **Show IDs.** Always include page IDs (and parent IDs) in output.
- **Concise output.** Trees and short summaries. No filler.
- **Direct execution.** Use Bash with api.sh for all API calls. Never use Task agents.
- **Respect the flags.** Use each page's `can_edit` / `can_delete` / `can_manage_permissions` to gate write suggestions, and `can_create_pages` from `GET /teams/{id}/settings` to gate create — never re-derive any of them from admin status.

## Argument Parsing

| Input | Behavior |
|-------|----------|
| *(no args)* | List pages for default team as a tree |
| `{team_id}` | List pages for specified team |
| `{page_id}` or `read {page_id}` | Show a single page (title + rendered body) |
| `create "title"` | Create a top-level page (empty body unless content given) |
| `create "title" under {parent_id}` | Create a nested page |
| `write {page_id} <file-or-content>` | Set a page's body from a markdown file or inline text |
| `rename {page_id} "new title"` | Update the title |
| `move {page_id} under {parent_id}` | Re-parent a page (`under top` → `parent_id: null`) |
| `reorder {page_id} to {position}` | Change position among siblings (0-based) |
| `delete {page_id}` | Soft-delete a page (restorable) |
| `restore {page_id}` | Restore a soft-deleted page |

Permissions (share page, grant/revoke editor, list roles) are also available — see the **Pages** section of `references/api-reference.md` for `/pages/{id}/permissions`; page author or team admin.

---

## Flow: List Pages (tree)

### Step 1: Resolve team ID

- Team ID in args → use it; otherwise `default_team_id` from Current State config.
- Neither → "No team specified and no default configured. Run `/rkit:setup`."

### Step 2: Fetch

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" GET "/teams/TEAM_ID/pages")
echo "$RESPONSE"
```

### Step 3: Handle response

Errors → see Error Handling below.

Success (status 200): `body.data` is a **flat array** (no `meta` on this endpoint). Build the tree from `parent_id`, order siblings by `position`, and display as an indented tree:

```
## Pages — Team {team_id}

- 18 Processes
  - 29 BDD Skill
- 15 Platform Development Process
  - 16 Pricing Tool Development
- 32 Platform Design Specs
  - 34 Internal
    - 31 ITAD Check-in BDD

{count} pages
Tip: `/rkit:pages read {id}` to open · `/rkit:pages create "title" under {id}` to add
```

## Flow: Read a Page

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" GET "/teams/TEAM_ID/pages/PAGE_ID?format=markdown")
echo "$RESPONSE"
```

`?format=markdown` returns `body` as markdown — the stored source, byte-for-byte, for a page that was written as markdown; converted from HTML for one that wasn't. Drop the param to see the raw HTML instead.

Success: show title, id, parent (title if known), and the body as returned. Note `can_edit`/`can_delete` if the user is about to modify.

## Flow: Create a Page

Creation is governed by the team's `pages_creatable_by` setting — `all_members` by default, so a plain member can usually create; `admins_only` restricts it (403 otherwise). Check `can_create_pages` on `GET /teams/TEAM_ID/settings` if you need to know before asking. The creator automatically gets the `author` role, and a sub-page copies its parent's audience.

Confirm: "Create page **{title}** in team {team_id}{ under **{parent title}** ({parent_id})}?"

```bash
API_SH="<api.sh path>"
PAYLOAD=$(jq -n --arg title "TITLE" --arg body "MARKDOWN_BODY" '{title: $title, body: $body}')
# nested: add  --argjson parent PARENT_ID  and  parent_id: $parent
RESPONSE=$("$API_SH" POST "/teams/TEAM_ID/pages?format=markdown" "$PAYLOAD")
echo "$RESPONSE"
```

- Omit `body` for an empty page; omit `parent_id` for top-level.
- Drop `?format=markdown` when the user asked for HTML.
- **Status 201**: "Created page **{id}**: {title} (saved as markdown)" (+ parent if nested).

## Flow: Write Body Content

For `write {page_id} <file>` or any create with content — send the markdown as-is:

```bash
BODY=$(cat "FILE.md")
PAYLOAD=$(jq -n --arg body "$BODY" '{body: $body}')
RESPONSE=$("$API_SH" PATCH "/teams/TEAM_ID/pages/PAGE_ID?format=markdown" "$PAYLOAD")
```

No local conversion, and no converter needed — the API does it. For HTML, send the user's HTML unchanged and drop the `?format=markdown` param.

Say which format was used and what the other one buys: markdown is the default (fewer tokens, and it reads back as the same markdown); HTML gives finer control of formatting. If the user then says "use HTML", re-send as HTML.

Limits: body ≤ 100KB; title ≤ 255 chars. If the source exceeds 100KB, tell the user and suggest splitting into child pages.

A write's response carries the page's identity but **no `body`** — confirm by the `id` it names, never by comparing an echoed body to what you sent. To show the saved page, `GET` it back.

## Flow: Rename / Move / Reorder

All are PATCH with only the changed fields:

```bash
"$API_SH" PATCH "/teams/TEAM_ID/pages/PAGE_ID" '{"title": "New Title"}'
"$API_SH" PATCH "/teams/TEAM_ID/pages/PAGE_ID" '{"parent_id": 34}'      # move; null → top-level
"$API_SH" PATCH "/teams/TEAM_ID/pages/PAGE_ID" '{"position": 0}'        # reorder among siblings
```

- Moving to one of the page's own descendants → 400 (cycle detected). Parent must be in the same team.
- After a move/reorder, re-fetch the list and show the affected subtree so the user sees the new shape.

## Flow: Delete a Page

**Soft delete — restorable.** The page and its comments survive; they just stop appearing in reads. Before confirming, fetch the list and count the page's descendants so the user knows what goes with it:

> Delete page **{title}** ({id}){ and its {n} descendant pages}? Restore it later with `/rkit:pages restore {id}`.

```bash
"$API_SH" DELETE "/teams/TEAM_ID/pages/PAGE_ID"
```

Status 204. Allowed for team admin or the page's author (403 otherwise). A deleted page 404s from every page read until restored.

## Flow: Restore a Page

```bash
"$API_SH" POST "/teams/TEAM_ID/pages/PAGE_ID/restore"
```

Brings back a soft-deleted page with its comments intact. Report: "Restored page **{id}**: {title}."

## Error Handling

api.sh wraps every response as `{"status": N, "body": {...}}` — always read fields via `.body.…`.

- `"error": "NO_CONFIG"` / `"NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 400` → show the validation message (empty title, title > 255, body > 100KB, cross-team parent, cycle).
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 403` → "You don't have permission — editing needs an author/editor/contributor role on the page, or team admin. If it was a create, this team is set to `admins_only`."
- `status: 404` → "Team or page not found (404)." — also what you get for a page outside your audience, or one that's been deleted.

## Edge Cases

- **api.sh not found**: "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"
- **Empty team**: "No pages for team {team_id} yet. `/rkit:pages create \"title\"` to start."
- **Untitled pages**: display as *(untitled)* with the ID so they're still addressable.
- **No converter installed**: irrelevant — markdown goes to the API as-is. Never refuse a write for a missing pandoc or npx.
- **Missing parent**: `parent_id: null` on a page whose real parent exists but is hidden from the caller. Render it top-level; it isn't corruption.

## References

- [ResultMaps V2 API Reference](references/api-reference.md) — see the **Pages** section for full payloads, the permission model (author > editor > contributor > viewer), and `/pages/{id}/permissions`.
