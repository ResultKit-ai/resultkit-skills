---
name: rkit:pages
description: List, read, create, update, move, and delete team Pages (the team wiki/docs tree); show, filter, add, or remove labels on pages; and lock, unlock, or check the lock state of a page, via the ResultMaps API. Use this skill when users ask about pages, team docs, team wiki, team notes, want to list pages, open or read a page, create a new page or doc, write content to a page, rename a page, move or nest a page under another, reorder pages, delete a page, show a page's labels, list pages by label, filter pages that carry a label, label or tag a page, remove/unlabel a page's label, lock a page, unlock a page, unlock a page for themselves, re-lock a page for themselves, make a page read-only, or check whether a page is locked.
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
- **What markdown renders.** As on GitHub: headings, bold/italic, bullet and numbered lists, `- [ ]` / `- [x]` checklists (real checkboxes), tables, quotes, code, links, and images (kept, never stripped). A single newline inside a paragraph is a line break; a blank line starts a new paragraph. So an address or a list of names can be written one per line and reads that way.
- **Show IDs.** Always include page IDs (and parent IDs) in output.
- **Concise output.** Trees and short summaries. No filler.
- **Direct execution.** Use Bash with api.sh for all API calls. Never use Task agents.
- **Respect the flags.** Use each page's `can_edit` / `can_delete` / `can_manage_permissions` to gate write suggestions, and `can_create_pages` from `GET /teams/{id}/settings` to gate create — never re-derive any of them from admin status.
- **Lock/unlock needs edit rights.** Locking, unlocking, personal-unlock, and re-lock all require the same gate as editing the page — team admin, or author/editor/contributor role. Locking itself is never blocked by the lock (anyone who can edit can always toggle it), and it never changes who can edit — a view-only member still gets `forbidden`, never `page_locked`. While a page is locked, `rename`/`write` are refused for everyone but a personal-unlock holder; `move`/`reorder` still work — the lock gates content, not the page's place in the tree.
- **Labels cost one call each.** No labels field on the pages list, no label filter — reading labels means `GET /custom-labels/content` per page. Fetch them only when the user asks for labels; never on a plain list. More than 50 pages in scope → say how many calls that is and get a yes before fetching.

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
| `lock {page_id}` | Lock a page for everyone (confirms first) |
| `unlock {page_id}` | Unlock a page for everyone (confirms first) |
| `unlock {page_id} for me` | Personally unlock a locked page, just for the caller (confirms first) |
| `relock {page_id} for me` | Undo a personal unlock — re-lock for the caller only (confirms first) |
| `{page_id} locked?` | Report whether a page is locked, and for whom (read-only, no confirm) |
| `labels` | List pages for default team as a tree, each with its labels |
| `{team_id} labels` | List pages for specified team as a tree, each with its labels |
| `under {parent_id} labels` | List a page and its descendants as a tree, each with its labels |
| `{page_id} labels` | Show one page's labels only |
| `labeled "name"` | List default-team pages carrying that label (flat, with IDs) |
| `{team_id} labeled "name"` | List a team's pages carrying that label (flat, with IDs) |
| `under {parent_id} labeled "name"` | List pages under a parent carrying that label (flat, with IDs) |
| `label {page_id} "name"` | Attach a label to a page (confirms first) |
| `unlabel {page_id} "name"` | Remove a label from a page (confirms first) |

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

Success: show title, id, parent (title if known), and the body as returned. Note `can_edit`/`can_delete` if the user is about to modify. If `locked` is true, say so — and whether the caller holds a personal unlock (`unlocked_for_me`) — so a blocked edit isn't a surprise.

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

## Flow: Lock / Unlock a Page

For `lock {page_id}`, `unlock {page_id}`, `unlock {page_id} for me`, and `relock {page_id} for me` — covers "lock this page", "lock the doc", "make it read-only" (→ lock); "unlock it" with no "for me" (→ global unlock); "unlock for me", "let me edit the locked page" (→ personal unlock); "re-lock for me" (→ personal re-lock).

Plain "unlock" (no "for me") means the **global** lock — it reopens the page for everyone with edit rights. "Unlock for me" leaves the global lock in place and grants the caller a **personal** unlock instead. "Re-lock for me" undoes that personal unlock only; it never touches the global lock.

### Step 1: Load the page and its current lock state

```bash
API_SH="<api.sh path>"
PAGE=$("$API_SH" GET "/pages/PAGE_ID")   # team-agnostic; the team-scoped read 404s for a page on another team
```

Title from `PAGE.body.data.title`; the page's real `team_id` from `PAGE.body.data.team_id`; current state from `PAGE.body.data.locked` and `PAGE.body.data.unlocked_for_me`.

### Step 2: Short-circuit no-ops

- `lock`, already `locked: true` → "Page **{id}: {title}** is already locked." Stop — no write.
- `unlock`, already `locked: false` → "Page **{id}: {title}** is already unlocked." Stop — no write.
- `unlock for me`, already `unlocked_for_me: true` → "You already have a personal unlock on page **{id}: {title}**." Stop — no write.
- `relock for me`, already `unlocked_for_me: false` → "You don't have a personal unlock on page **{id}: {title}** to undo." Stop — no write.

### Step 3: Confirm

- Lock: "Lock page **{title}** ({id}) for everyone? No one will be able to edit it until it's unlocked."
- Unlock: "Unlock page **{title}** ({id}) for everyone?"
- Unlock for me: "Unlock page **{title}** ({id}) just for you? It stays locked for everyone else."
- Re-lock for me: "Re-lock page **{title}** ({id}) for yourself? You'll lose your personal unlock."

### Step 4: Execute

```bash
# Global lock / unlock
"$API_SH" PATCH "/teams/TEAM_ID/pages/PAGE_ID/lock" '{"locked": true}'    # lock
"$API_SH" PATCH "/teams/TEAM_ID/pages/PAGE_ID/lock" '{"locked": false}'   # unlock

# Personal unlock / re-lock — never touches the global lock
"$API_SH" PATCH "/teams/TEAM_ID/pages/PAGE_ID/lock/me" '{"unlocked": true}'    # unlock for me
"$API_SH" PATCH "/teams/TEAM_ID/pages/PAGE_ID/lock/me" '{"unlocked": false}'   # re-lock for me
```

`TEAM_ID` is the page's own `team_id` from Step 1.

### Step 5: Report from the response

- Lock (`.body.data.locked == true`) → "Locked page **{id}: {title}**. Only someone with a personal unlock can still edit it."
- Unlock (`.body.data.locked == false`) → "Unlocked page **{id}: {title}**. Anyone with edit rights can edit it again."
- Unlock for me (`.body.data.unlocked_for_me == true`) → "Unlocked page **{id}: {title}** just for you — it's still locked for everyone else."
- Re-lock for me (`.body.data.unlocked_for_me == false`) → "Re-locked page **{id}: {title}** for yourself."

Errors → see **Error Handling**.

## Flow: Check Whether a Page Is Locked

For `{page_id} locked?` and any plain "is this page locked" question.

```bash
API_SH="<api.sh path>"
PAGE=$("$API_SH" GET "/pages/PAGE_ID")
```

Report from `PAGE.body.data`:
- `locked: false` → "Page **{id}: {title}** is not locked."
- `locked: true`, `unlocked_for_me: true` → "Page **{id}: {title}** is locked for the team, but you hold a personal unlock — you can still edit it."
- `locked: true`, `unlocked_for_me: false`, `can_edit: true` → "Page **{id}: {title}** is locked. You can unlock it for everyone (`/rkit:pages unlock {id}`) or just for yourself (`/rkit:pages unlock {id} for me`)."
- `locked: true`, `unlocked_for_me: false`, `can_edit: false` → "Page **{id}: {title}** is locked, and you don't have edit rights on it."

Read-only — executes immediately, no confirmation.

## Label Name → ID Resolution

Used by every flow below that takes a label **name**. Match case-insensitively against two sources — never `creator_labels` from `/custom-labels/content`, which in testing returned labels from unrelated teams too (broader than "this page's team plus the caller's own"):

```bash
API_SH="<api.sh path>"
TEAM_LABELS=$("$API_SH" GET "/teams/PAGE_TEAM_ID/labels")         # team labels, inherited ones included
PERSONAL_LABELS=$("$API_SH" GET "/custom-labels?scope=personal")  # the caller's own personal labels
```

- `PAGE_TEAM_ID` is the page's (or scope's) own `team_id` — not necessarily the default team.
- Both are paginated (`.body.meta.page` / `.total_pages`) — page through with `&page=N` if `total_pages > 1`.
- Compare the requested name to each label's `name`, case-insensitive, exact match only.
- **No match** → say so; list the closest existing names if any are close. Never create a label.
- **One match** → use its `id`.
- **Several matches** (team labels don't require unique names) → list each as `{id} — {name} ({scope})`, where scope is `team` or `personal` from the list it came from, adding `, inherited from team {source_team_id}` when a team label's `inherited` is true, and ask which one.

## Flow: List Pages With Labels

For `labels`, `{team_id} labels`, `under {parent_id} labels`, and `{page_id} labels`.

### Step 1: Resolve scope

- `under {parent_id}` → `GET /pages/PARENT_ID` (team-agnostic — the team-scoped read 404s when the page belongs to another team) for the parent's title and its `team_id`; then list that team's pages and take the parent plus every descendant reached by following `parent_id` down from it.
- `{team_id}` → scope is every page in that team.
- *(no team/parent)* → `default_team_id`; scope is every page in it.

### Step 2: Fetch pages, count the scope

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" GET "/teams/TEAM_ID/pages")
```

Build the tree exactly as in **Flow: List Pages (tree)**, narrowed to the scope from Step 1.

- Scope > 50 pages → "Fetching labels for {n} pages is {n} API calls — proceed?" Wait for yes before Step 3.

### Step 3: Fetch each page's labels

One call per page in scope — there's no bulk label field:

```bash
"$API_SH" GET "/custom-labels/content?labeled_type=Page&labeled_id=PAGE_ID"
```

Collect `.body.data.attached_labels[].name` per page.

### Step 4: Display

Same tree as the plain list, labels appended in brackets; a page with none shows no bracket:

```
## Pages — Team 345

- 371 Help
  - 372 How to: Archive a One-on-One  [help-ready-for-review]

{count} pages
```

For `{page_id} labels` (a single page, no tree): `GET /pages/PAGE_ID` for the title, then `GET /custom-labels/content?labeled_type=Page&labeled_id=PAGE_ID`, and report one line — `{id} {title}  [{names}]`, or "No labels." when `attached_labels` is empty.

## Flow: Filter Pages by Label

For `labeled "name"`, `{team_id} labeled "name"`, and `under {parent_id} labeled "name"`.

### Step 1: Resolve scope and label

- Resolve scope exactly as in **Flow: List Pages With Labels** Step 1.
- Resolve `"name"` to an `id` against that scope's team, per **Label Name → ID Resolution**. No match → stop; never fall through to an unfiltered list.

### Step 2: Fetch

Same 50-call gate as **Flow: List Pages With Labels**; fetch `/custom-labels/content?labeled_type=Page&labeled_id=PAGE_ID` for every page in scope.

### Step 3: Display only matches

Flat list, not a tree — only pages whose `attached_labels` include the resolved id, showing all of that page's labels for context:

```
## Pages labeled "help-ready-for-review" — under 371

- 372 How to: Archive a One-on-One  [help-ready-for-review]

1 page
```

No matches → "No pages {in team {team_id} / under {parent_id}} carry the label \"{name}\"."

## Flow: Label / Unlabel a Page

For `label {page_id} "name"` and `unlabel {page_id} "name"`.

### Step 1: Load the page and its current labels

```bash
API_SH="<api.sh path>"
PAGE=$("$API_SH" GET "/pages/PAGE_ID")   # team-agnostic; the team-scoped read 404s for a page on another team
CURRENT=$("$API_SH" GET "/custom-labels/content?labeled_type=Page&labeled_id=PAGE_ID")
```

Title from `PAGE.body.data.title`; the page's real `team_id` from `PAGE.body.data.team_id`; current attached ids from `CURRENT.body.data.attached_labels[].id`.

### Step 2: Resolve the label name

Per **Label Name → ID Resolution**, scoped to the page's own `team_id` from Step 1.

### Step 3: Short-circuit no-ops

- `label`, id already in the current set → "Page **{id}: {title}** already has **{name}**." Stop — no write.
- `unlabel`, id not in the current set → "Page **{id}: {title}** doesn't have **{name}**." Stop — no write.

### Step 4: Confirm

Confirm: "Add label **{name}** to page **{id}: {title}**?" (or "Remove label **{name}** from page **{id}: {title}**?")

### Step 5: Sync the full set

`custom_label_ids` is the whole desired set — current ids plus the new one (label), or current ids minus it (unlabel). Every other label already on the page is included unchanged either way, so it survives the sync:

```bash
PAYLOAD=$(jq -n --argjson ids '[DESIRED_LABEL_IDS]' '{labeled_type: "Page", labeled_id: PAGE_ID, custom_label_ids: $ids}')
RESPONSE=$("$API_SH" POST "/custom-labels/manage" "$PAYLOAD")
echo "$RESPONSE"
```

### Step 6: Report from the response

- `label`, id in `.body.data.applied` → "Added **{name}** to page **{id}: {title}**."
- `unlabel`, id in `.body.data.removed` → "Removed **{name}** from page **{id}: {title}**."
- `unlabel`, id **not** in `.body.data.removed` (still status 200) → "**{name}** stays on page **{id}: {title}** — you don't have edit rights on that team label." Not a failure; report it plainly.

Errors → see **Error Handling**.

## Error Handling

api.sh wraps every response as `{"status": N, "body": {...}}` — always read fields via `.body.…`.

- `"error": "NO_CONFIG"` / `"NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 400` → show the validation message (empty title, title > 255, body > 100KB, cross-team parent, cycle).
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 403` → "You don't have permission — editing needs an author/editor/contributor role on the page, or team admin. If it was a create, this team is set to `admins_only`."
- `status: 403`, `.body.error.code == "page_locked"` (only from a `rename`/`write` carrying title or body — never from `lock`/`unlock` themselves, `create`, `move`, `delete`, or a `parent_id`/`position`-only PATCH) → surface the server's message verbatim: "This page is locked." Then offer the way through: "`/rkit:pages unlock {id} for me`" if the caller has edit rights, or "ask someone with edit rights to `/rkit:pages unlock {id}`" otherwise.
- `status: 404` → "Team or page not found (404)." — also what you get for a page outside your audience, or one that's been deleted.

**Label calls** (`/custom-labels/content`, `/custom-labels/manage`) carry their own message in `.body.error.message`:

- `status: 403` from `/custom-labels/content` → the caller can't open the page: "You can't open page {id} (403)."
- `status: 403` from `/custom-labels/manage`, message *"Edit permission required to manage team labels on this page"* → a team-label add was refused; nothing was applied: "You don't have edit rights on this page's team labels — nothing changed."
- `status: 404` → "Page not found (404) — it may have been deleted." (Covers a soft-deleted page too.)
- `status: 422`, message mentions "Project labels" → shouldn't arise here (this skill never resolves a project-scope label for a page); if seen, report "Project labels can't go on a page."
- `status: 422`, other → show `.body.error.message` as-is.

## Edge Cases

- **api.sh not found**: "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"
- **Empty team**: "No pages for team {team_id} yet. `/rkit:pages create \"title\"` to start."
- **Untitled pages**: display as *(untitled)* with the ID so they're still addressable.
- **No converter installed**: irrelevant — markdown goes to the API as-is. Never refuse a write for a missing pandoc or npx.
- **Missing parent**: `parent_id: null` on a page whose real parent exists but is hidden from the caller. Render it top-level; it isn't corruption.
- **Ambiguous label name**: team labels don't require unique names. List every match with its id and scope and ask which.
- **Unknown label name**: never create one — say it wasn't found and name the closest existing labels, if any.
- **Personal labels are private**: a personal label in `attached_labels` shows only to the user who owns it; another viewer of the same page won't see it and can't resolve it by name.
- **Team label removed without edit rights**: the sync leaves it attached and off `removed`, with a plain `200` — that's expected, not an error.

## References

- [ResultMaps V2 API Reference](references/api-reference.md) — see the **Pages** section for full payloads, the permission model (author > editor > contributor > viewer), page locking (**Page Lifecycle**), and `/pages/{id}/permissions`; see **Custom Labels** for the label object's fields and the personal/team/project scope model.
