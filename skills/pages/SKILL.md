---
name: rkit:pages
description: List, read, create, update, move, and delete team Pages (the team wiki/docs tree); show, filter, add, or remove labels on pages; and lock, unlock, or check the lock state of a page, via the ResultMaps API. Use this skill when users ask about pages, team docs, team wiki, team notes, want to list pages, open or read a page, create a new page or doc, write content to a page, rename a page, move or nest a page under another, reorder pages, delete a page, show a page's labels, list pages by label, filter pages that carry a label, label or tag a page, remove/unlabel a page's label, lock a page, unlock a page, unlock a page for themselves, re-lock a page for themselves, make a page read-only, or check whether a page is locked.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Bash(pandoc *), Bash(npx *), Read, Glob, Grep, AskUserQuestion
---

# rkit:pages

Team-scoped hierarchical document pages ("team wiki"). Pages form a tree via `parent_id`; the list read returns a flat array — build the tree client-side. It drives the ResultKit connector's MCP tools, named below by base name (the full name is `mcp__<server>__<tool>`; the server alias varies by install). `scripts/api.sh` is used only for the jobs under **Fallback (api.sh)**.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh (Fallback only): !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/pages/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/pages/scripts/api.sh "$HOME/.claude/skills/rkit:pages/scripts/api.sh" "$HOME/.agents/skills/pages/scripts/api.sh" "$HOME/.gemini/skills/pages/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes.** Reads execute immediately. Before any create, update, move, delete, restore, lock or label change, summarize all planned changes in a single prompt and ask for confirmation. Batch related mutations under one confirmation.
- **Body is markdown by default.** Send the user's markdown as written with `markdown: true` on `create_page` / `update_page` — the API converts it and stores the markdown source, so a markdown read (`get_page` with `markdown: true`) gives back exactly what was written. Never convert locally. Say which format you used and name the alternative: markdown is the default (it uses fewer tokens and reads back unchanged); HTML is there for finer control of formatting. If the user says "use HTML", send their HTML unchanged and leave `markdown` out. Never make them guess.
- **What markdown renders.** As on GitHub: headings, bold/italic, bullet and numbered lists, `- [ ]` / `- [x]` checklists (real checkboxes), tables, quotes, code, links, and images (kept, never stripped). A single newline inside a paragraph is a line break; a blank line starts a new paragraph. So an address or a list of names can be written one per line and reads that way.
- **Show IDs.** Always include page IDs (and parent IDs) in output (this overrides the connector's general "never print raw ids" note).
- **Concise output.** Trees and short summaries. No filler.
- **Direct execution.** Call the connector tools directly. Fallback jobs use Bash with api.sh. Never use Task agents, never curl or hand-build a URL, and skip the connector's `guide` tool — the routing below is complete for this skill.
- **Respect the flags.** Use each page's `can_edit` / `can_delete` / `can_manage_permissions` to gate write suggestions, and `can_create_pages` (Fallback) to gate create — never re-derive any of them from admin status.
- **Lock/unlock needs edit rights.** Locking, unlocking, personal-unlock, and re-lock all require the same gate as editing the page — team admin, or author/editor/contributor role. Locking itself is never blocked by the lock (anyone who can edit can always toggle it), and it never changes who can edit — a view-only member still gets `forbidden`, never `page_locked`. While a page is locked, `rename`/`write` are refused for everyone but a personal-unlock holder; `move`/`reorder` still work — the lock gates content, not the page's place in the tree.
- **Labels cost one call each.** No labels field on the pages list, no label filter — reading labels means `GET /custom-labels/content` per page (Fallback). Fetch them only when the user asks for labels; never on a plain list. More than 50 pages in scope → say how many calls that is and get a yes before fetching.

## Argument Parsing

| Input | Behavior | Tool / flow |
|-------|----------|-------------|
| *(no args)* | List pages for default team as a tree | `list_pages` |
| `{team_id}` | List pages for specified team | `list_pages` |
| `{page_id}` or `read {page_id}` | Show a single page (title + rendered body) | `get_page` |
| `create "title"` | Create a top-level page (empty body unless content given) | `create_page` |
| `create "title" under {parent_id}` | Create a nested page | `create_page` |
| `write {page_id} <file-or-content>` | Set a page's body from a markdown file or inline text | Inline: `update_page`. File: Fallback |
| `rename {page_id} "new title"` | Update the title | `update_page` |
| `move {page_id} under {parent_id}` | Re-parent a page (`under top` → `parent_id: null`) | `update_page` |
| `reorder {page_id} to {position}` | Change position among siblings (0-based) | `update_page` |
| `delete {page_id}` | Soft-delete a page (restorable) | `delete_page` |
| `restore {page_id}` | Restore a soft-deleted page | `restore_page` |
| `lock {page_id}` / `unlock {page_id}` | Lock / unlock a page for everyone (confirms first) | Fallback: lock |
| `unlock {page_id} for me` / `relock {page_id} for me` | Personally unlock a locked page, just for the caller / undo that (confirms first) | Fallback: lock |
| `{page_id} locked?` | Report whether a page is locked, and for whom (read-only, no confirm) | Fallback: check lock |
| `labels`, `{team_id} labels`, `under {parent_id} labels` | List pages as a tree, each with its labels | `list_pages`, then Fallback |
| `{page_id} labels` | Show one page's labels only | Fallback |
| `labeled "name"`, `{team_id} labeled "name"`, `under {parent_id} labeled "name"` | List pages carrying that label (flat, with IDs) | `list_pages`, then Fallback |
| `label {page_id} "name"` / `unlabel {page_id} "name"` | Attach / remove a label (confirms first) | Fallback: label |

Permissions (share page, grant/revoke editor, list roles) are also available through api.sh — see **Fallback**.

## Flow: List Pages (tree)

Team ID: the arg if given, else `default_team_id` from Current State config; neither → "No team specified and no default configured. Run `/rkit:setup`." Call `list_pages` with `team_id`. It answers a **flat JSON array** (no paging), each page with `id`, `title`, `parent_id`, `position`, `can_edit`, `can_delete`. Build the tree from `parent_id`, order siblings by `position`, and display as an indented tree:

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

Call `get_page` with `team_id`, `page_id` and `markdown: true` (leave `markdown` out to see the raw HTML). Markdown is the stored source, byte-for-byte, for a page that was written as markdown; converted from HTML for one that wasn't. Show title, id, parent (title if known), and the body as returned. Note `can_edit`/`can_delete` if the user is about to modify. If `locked` is true, say so — and whether the caller holds a personal unlock (`unlocked_for_me`) — so a blocked edit isn't a surprise.

## Flow: Create a Page

Creation is governed by the team's `pages_creatable_by` setting — `all_members` by default, so a plain member can usually create; `admins_only` restricts it. Check `can_create_pages` (Fallback) if you need to know before asking. The creator automatically gets the `author` role, and a sub-page copies its parent's audience.

Confirm: "Create page **{title}** in team {team_id}{ under **{parent title}** ({parent_id})}?" Then `create_page` with `team_id`, `title`, and `markdown: true` with `body` when there is content; add `parent_id` when nested. Omit `body` for an empty page and `parent_id` for top-level; for HTML leave `markdown` out. It answers the new page's identity (`id`, `title`, `parent_id`, `position`) and **no body**: "Created page **{id}**: {title} (saved as markdown)" (+ parent if nested).

## Flow: Write Body Content

For `write {page_id} <content>` — send the markdown as-is: `update_page` with `team_id`, `page_id`, `body` and `markdown: true`. No local conversion, and no converter needed — the API does it. For HTML, send the user's HTML unchanged and leave `markdown` out. Say which format was used and what the other one buys (see the Body rule); if the user then says "use HTML", re-send as HTML.

Limits: title ≤ 255 chars; body ≤ 2MB. If the source exceeds 2MB, tell the user and suggest splitting into child pages. **Content from a local file goes through Fallback**, so the file's bytes never pass through the model.

A write's answer carries the page's identity but **no body** — confirm by the `id` it names, never by comparing an echoed body to what you sent. To show the saved page, `get_page` it back.

## Flow: Rename / Move / Reorder

All are `update_page` with `team_id`, `page_id` and only the changed fields: `title` (rename), `parent_id` (move; `null` → top-level), `position` (reorder among siblings).

- Moving under one of the page's own descendants is refused (cycle). The parent must be in the same team.
- After a move/reorder, call `list_pages` again and show the affected subtree so the user sees the new shape.

## Flow: Delete a Page

**Soft delete — restorable.** The page and every page beneath it go; they stop appearing in reads. Before confirming, call `list_pages` and count the page's descendants so the user knows what goes with it:

> Delete page **{title}** ({id}){ and its {n} descendant pages}? Restore it later with `/rkit:pages restore {id}`.

Then `delete_page` with `team_id` and `page_id`. Allowed for team admin or the page's author. A deleted page is "not found" from every page read until restored.

## Flow: Restore a Page

`restore_page` with `team_id` and `page_id` brings back the soft-deleted page and the pages that were beneath it. Report: "Restored page **{id}**: {title}." (the title from earlier in the conversation, else read it back with `get_page`).

## Fallback (api.sh)

The connector has no live tool for these jobs (none locks, unlocks or labels a page or reads a team's settings; the three page-permission tools are held back; `update_page` takes its body as text only), so they run as before: `RESPONSE=$("<api.sh path>" METHOD PATH [BODY])` returns `{status, body}` — always read fields via `.body.…`. Confirm writes first, as above.

| Job | Call |
|---|---|
| Body from a local file (`write {page_id} <file>`, or a create with file content) | `BODY=$(cat "FILE.md")`; `PAYLOAD=$(jq -n --arg body "$BODY" '{body: $body}')`; `PATCH /teams/TEAM_ID/pages/PAGE_ID?format=markdown` with `$PAYLOAD`. Create: `jq -n --arg title "TITLE" --arg body "$BODY" '{title: $title, body: $body}'` (nested: add `--argjson parent PARENT_ID` and `parent_id: $parent`), `POST /teams/TEAM_ID/pages?format=markdown`; 201 → "Created page **{id}**: {title} (saved as markdown)". For HTML send the user's HTML unchanged and drop `?format=markdown`. |
| Whether the caller may create pages in a team | `GET /teams/TEAM_ID/settings` → `can_create_pages` |
| Page permissions (share, grant/revoke editor, list roles; page author or team admin) | the **Pages** section of `references/api-reference.md`, `/pages/{id}/permissions` |
| A page by id alone (title, real `team_id`, `locked`, `unlocked_for_me`, `can_edit`), and the lock check | `GET /pages/PAGE_ID` (team-agnostic — the team-scoped read 404s for a page on another team). `get_page` also answers `locked`, `unlocked_for_me` and `can_edit` when the page's team is already known. |

**Check lock** (`{page_id} locked?` and any plain "is this page locked" question; read-only, no confirm), from `body.data`:
- `locked: false` → "Page **{id}: {title}** is not locked."
- `locked: true`, `unlocked_for_me: true` → "Page **{id}: {title}** is locked for the team, but you hold a personal unlock — you can still edit it."
- `locked: true`, `unlocked_for_me: false`, `can_edit: true` → "Page **{id}: {title}** is locked. You can unlock it for everyone (`/rkit:pages unlock {id}`) or just for yourself (`/rkit:pages unlock {id} for me`)."
- `locked: true`, `unlocked_for_me: false`, `can_edit: false` → "Page **{id}: {title}** is locked, and you don't have edit rights on it."

### Lock / unlock a page

Covers "lock this page", "lock the doc", "make it read-only" (→ lock); "unlock it" with no "for me" (→ global unlock); "unlock for me", "let me edit the locked page" (→ personal unlock); "re-lock for me" (→ personal re-lock). Plain "unlock" is the **global** lock — it reopens the page for everyone with edit rights. "Unlock for me" leaves the global lock in place and grants the caller a **personal** unlock instead. "Re-lock for me" undoes that personal unlock only; it never touches the global lock.

1. **Load** `PAGE=$("$API_SH" GET "/pages/PAGE_ID")`: title from `PAGE.body.data.title`; the page's real `team_id` from `PAGE.body.data.team_id` (this is `TEAM_ID` below); state from `.locked` and `.unlocked_for_me`.
2. **Then, per the table:** if the page is already in the asked state, say so and stop — no write; otherwise confirm, execute, and report from the response.

| Command | No-op when | Confirm | Call | Report |
|---|---|---|---|---|
| `lock` | `locked: true` → "Page **{id}: {title}** is already locked." | "Lock page **{title}** ({id}) for everyone? No one will be able to edit it until it's unlocked." | `PATCH /teams/TEAM_ID/pages/PAGE_ID/lock` `{"locked": true}` | `.body.data.locked == true` → "Locked page **{id}: {title}**. Only someone with a personal unlock can still edit it." |
| `unlock` | `locked: false` → "Page **{id}: {title}** is already unlocked." | "Unlock page **{title}** ({id}) for everyone?" | same, `{"locked": false}` | `.body.data.locked == false` → "Unlocked page **{id}: {title}**. Anyone with edit rights can edit it again." |
| `unlock … for me` | `unlocked_for_me: true` → "You already have a personal unlock on page **{id}: {title}**." | "Unlock page **{title}** ({id}) just for you? It stays locked for everyone else." | `PATCH /teams/TEAM_ID/pages/PAGE_ID/lock/me` `{"unlocked": true}` | `.body.data.unlocked_for_me == true` → "Unlocked page **{id}: {title}** just for you — it's still locked for everyone else." |
| `relock … for me` | `unlocked_for_me: false` → "You don't have a personal unlock on page **{id}: {title}** to undo." | "Re-lock page **{title}** ({id}) for yourself? You'll lose your personal unlock." | same, `{"unlocked": false}` | `.body.data.unlocked_for_me == false` → "Re-locked page **{id}: {title}** for yourself." |

### Labels

**Label name → ID resolution** (every flow below that takes a label **name**). Match case-insensitively against two sources — never `creator_labels` from `/custom-labels/content`, which in testing returned labels from unrelated teams too:

```bash
TEAM_LABELS=$("$API_SH" GET "/teams/PAGE_TEAM_ID/labels")         # team labels, inherited ones included
PERSONAL_LABELS=$("$API_SH" GET "/custom-labels?scope=personal")  # the caller's own personal labels
```

- `PAGE_TEAM_ID` is the page's (or scope's) own `team_id` — not necessarily the default team. Both are paginated (`.body.meta.page` / `.total_pages`) — page through with `&page=N`.
- Exact name match, case-insensitive. **No match** → say so; list the closest existing names if any are close; never create a label. **One match** → use its `id`. **Several** (team labels don't require unique names) → list each as `{id} — {name} ({scope})`, scope `team` or `personal`, adding `, inherited from team {source_team_id}` when a team label's `inherited` is true, and ask which.

**List pages with labels** (`labels`, `{team_id} labels`, `under {parent_id} labels`, `{page_id} labels`):

1. **Scope.** `under {parent_id}` → `GET /pages/PARENT_ID` for the parent's title and `team_id`, then `list_pages` for that team and take the parent plus every descendant. `{team_id}` → every page in that team. Neither → `default_team_id`, every page in it. Build the tree as in List Pages, narrowed to the scope. Scope over 50 pages → "Fetching labels for {n} pages is {n} API calls — proceed?" and wait for yes.
2. **Labels.** One call per page in scope: `GET /custom-labels/content?labeled_type=Page&labeled_id=PAGE_ID`; collect `.body.data.attached_labels[].name`.
3. **Display** the same tree with labels in brackets; a page with none shows no bracket:
   ```
   ## Pages — Team 345

   - 371 Help
     - 372 How to: Archive a One-on-One  [help-ready-for-review]

   {count} pages
   ```
   For `{page_id} labels` (one page, no tree): `GET /pages/PAGE_ID` for the title, then the content call; one line — `{id} {title}  [{names}]`, or "No labels." when `attached_labels` is empty.

**Filter pages by label** (`labeled "name"`, `{team_id} labeled "name"`, `under {parent_id} labeled "name"`): resolve the scope as above and the name to an `id` against that scope's team. No match → stop; never fall through to an unfiltered list. Same 50-call gate, then the content call for every page in scope. Show a flat list of only the pages whose `attached_labels` include the id, with all of each page's labels for context:

```
## Pages labeled "help-ready-for-review" — under 371

- 372 How to: Archive a One-on-One  [help-ready-for-review]

1 page
```

None → "No pages {in team {team_id} / under {parent_id}} carry the label \"{name}\"."

**Label / unlabel a page** (`label {page_id} "name"`, `unlabel {page_id} "name"`):

1. **Load** `PAGE=$("$API_SH" GET "/pages/PAGE_ID")` (title, real `team_id`) and `CURRENT=$("$API_SH" GET "/custom-labels/content?labeled_type=Page&labeled_id=PAGE_ID")` (current ids from `CURRENT.body.data.attached_labels[].id`).
2. **Resolve** the name per **Label name → ID resolution**, scoped to the page's own `team_id`.
3. **No-ops** — stop, no write: `label` with the id already attached → "Page **{id}: {title}** already has **{name}**."; `unlabel` with it not attached → "Page **{id}: {title}** doesn't have **{name}**."
4. **Confirm:** "Add label **{name}** to page **{id}: {title}**?" (or "Remove label **{name}** from page **{id}: {title}**?")
5. **Sync the full set.** `custom_label_ids` is the whole desired set — current ids plus the new one (label), or minus it (unlabel); every other label already on the page is included unchanged:
   ```bash
   PAYLOAD=$(jq -n --argjson ids '[DESIRED_LABEL_IDS]' '{labeled_type: "Page", labeled_id: PAGE_ID, custom_label_ids: $ids}')
   RESPONSE=$("$API_SH" POST "/custom-labels/manage" "$PAYLOAD")
   ```
6. **Report from the response.** `label`, id in `.body.data.applied` → "Added **{name}** to page **{id}: {title}**." `unlabel`, id in `.body.data.removed` → "Removed **{name}** from page **{id}: {title}**." `unlabel`, id **not** in `.body.data.removed` (still 200) → "**{name}** stays on page **{id}: {title}** — you don't have edit rights on that team label." Not a failure; report it plainly.

**api.sh errors.** `NO_CONFIG` / `NO_TOKEN` → "Config not found. Run `/rkit:setup` first."; `CURL_FAILED` → "Network error. Check your connection."; 401 → "Unauthorized (401). Run `/rkit:setup` to update your token."; 403 on a lock write → "You don't have permission — editing needs an author/editor/contributor role on the page, or team admin."; 404 → "Team or page not found (404)."; path `NOT_FOUND` → "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`". Label calls carry their message in `.body.error.message`: 403 from `/custom-labels/content` → "You can't open page {id} (403)."; 403 from `/custom-labels/manage` ("Edit permission required to manage team labels on this page") → "You don't have edit rights on this page's team labels — nothing changed."; 404 → "Page not found (404) — it may have been deleted."; 422 mentioning "Project labels" → "Project labels can't go on a page."; other 422 → show `.body.error.message` as-is.

## Errors

| The tool answers | Say |
|---|---|
| tools missing, or an authorization error | "The ResultKit connector isn't connected. Connect it (https://mcp.resultkit.ai) and try again." |
| "You do not have permission to view pages in this team" | "You don't have permission to view pages in team {team_id}." |
| "Page not found" | "Team or page not found." — also what you get for a page outside your audience, or one that's been deleted. |
| "You do not have permission to edit this page" | "You don't have permission — editing needs an author/editor/contributor role on the page, or team admin." |
| "You do not have permission to delete this page" or "…restore this page" | "Deleting or restoring needs the page's author role or team admin." |
| "Team not found or you don't have access to it." (`create_page`) | "You can't create pages in team {team_id} — the team may be set to `admins_only`, or you're not a member." |
| "This page is locked" (a title or body write only — never move/reorder) | Surface it verbatim: "This page is locked." Then offer the way through: "`/rkit:pages unlock {id} for me`" if the caller has edit rights, or "ask someone with edit rights to `/rkit:pages unlock {id}`" otherwise. |
| "Title cannot be empty", "Title cannot exceed 255 characters", "Body cannot exceed 2MB", "A page cannot be its own parent", "Cannot move page under one of its own descendants", "Parent page not found in this team", "Position must be a non-negative integer" | Show the message (validation). |
| any other `Error: …` | Show it as returned. |

## Edge Cases

- **Empty team**: "No pages for team {team_id} yet. `/rkit:pages create \"title\"` to start."
- **Untitled pages**: display as *(untitled)* with the ID so they're still addressable.
- **No converter installed**: irrelevant — markdown goes to the API as-is. Never refuse a write for a missing pandoc or npx.
- **Missing parent**: `parent_id: null` on a page whose real parent exists but is hidden from the caller. Render it top-level; it isn't corruption.
- **Personal labels are private**: a personal label in `attached_labels` shows only to the user who owns it; another viewer of the same page won't see it and can't resolve it by name.
- **Ambiguous / unknown label name, team label removed without edit rights**: handled in the Labels flows above (list the matches and ask; never create a label; a plain `200` that leaves it attached is expected, not an error).

## References

- [ResultMaps V2 API Reference](references/api-reference.md) — see the **Pages** section for full payloads, the permission model (author > editor > contributor > viewer), page locking (**Page Lifecycle**), and `/pages/{id}/permissions`; see **Custom Labels** for the label object's fields and the personal/team/project scope model.
