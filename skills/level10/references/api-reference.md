# ResultMaps V2 API Reference

**Source**: https://api.resultmaps.com/api-docs/v2 — refresh from here when endpoints change or docs seem stale.

Base URL: `https://api.resultmaps.com/api/v2`
Web App: `https://resultkit.ai` — Web URL column values are paths relative to this base. NEVER link users to the legacy `app.resultmaps.com` UI.
Deep links: the cold link for an item is `https://resultkit.ai/items/{id}` — it renders Home with the item sheet open and survives a fresh tab and a login round-trip. `?item={id}` appended to any authenticated path (e.g. `/prioritizer?item={id}&tab=comments`) opens the same sheet over that surface, but NOT at the root: `https://resultkit.ai/?item={id}` lands on the marketing page and its bounce to `/?app=1` drops the item. `?target={id}` opens the goal/rock/milestone drawer, which resolves the id in the current team, so pair it with `?team=`: `/components?tab=traction&team={team_id}&target={id}`. `?team={id}` switches the team on `/level-10-meeting`, `/plugins/projects`, and `/components`. `/teams/{id}` is the team home page. Full map and rationale: `rkit:open` skill, `references/url-map.md`.
Auth: Bearer token in `Authorization` header or `token` query param. Find your token in your profile settings at https://resultkit.ai/customize.
Interactive docs: <https://api.resultmaps.com/api-docs/v2>

## Common Query Parameters

Many list endpoints accept these shared params:

| Param | Type | Description |
|-------|------|-------------|
| `page` | integer | Page number (default: 1) |
| `per_page` | integer | Results per page, 1–100 (default: 100) |
| `q` | string | Filter by name (min 2 chars, case-insensitive contains match) |
| `include_archived` | string | When `"true"`, includes archived items (default: `"false"`) |

Endpoints that support `q` and `include_archived` are noted below.

`include_archived`: by default, archived items are excluded from all list endpoints. Pass `include_archived=true` to include them. Supported on `GET /items` and `GET /projects`.

## Items

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/items` | List authenticated user's items (params: page, per_page, q, status, team_id, include_archived) | "show my tasks", "list items", "what's on my plate", "my to-dos" | — |
| POST | `/items` | Create item (body: name*, type, description, due, status, on_weekly, team_id, parent_id, context) | "add task", "create item", "new to-do", "add action item" | `/items/{id}` |
| GET | `/items/{id}` | Get item detail (includes first-level children) | "show item", "item details", "open task", "what's in item X" | `/items/{id}` |
| PATCH | `/items/{id}` | Update item (body: name, description, due, status, on_weekly, third_party_tracker, source_page_id, roadmap_id). `third_party_tracker`: object to set/replace, `null` to clear, omit to leave unchanged. Setting `status: done` also records the completion timestamp and checks the item off on today's day plan — no follow-up `PATCH /day-plans/today/items/{item_id}` needed. Any other status clears both. `source_page_id`: integer sets/replaces the Pages document this item is linked to, `null` clears it, omit to leave unchanged (requires view access to the named page). `roadmap_id`: optional swimlane-roadmap id that, when present, REPLACES the normal item-edit permission check with "admin of the roadmap's owning team OR a named roadmap editor" — the target item must be a card of that roadmap (its nearest project or itself is in `config.sources` AND within the roadmap's owning organization, else 404 even if listed in `sources` — anti-IDOR); omit for the normal edit-permission check. | "update item", "change status", "rename task", "set due date", "link to HubSpot", "attach ticket", "link item to page", "edit item via roadmap" | `/items/{id}` |
| DELETE | `/items/{id}` | Archive item (soft delete, sets status=archived) | "archive item", "delete task", "remove item", "soft delete" | — |
| GET | `/items/{id}/children` | List child items as nested tree (params: page, per_page, q, depth). `depth` default 2, range 1-20. | "show sub-tasks", "list children", "nested items", "what's under this" | `/items/{id}` |
| PUT | `/items/{id}/move` | Reposition item in tree (body: parent_id, left_id, right_id, position?, group_by?). Optional `position` (0-based integer) places item at a specific slot within the new parent. Optional `group_by: "status"` scopes `position` to the item's status group (use on status-grouped boards); omit for global ordering. Invalid `group_by` value → 400. | "move item", "reparent", "nest under", "reorder" | `/items/{id}` |
| PATCH | `/items/bulk-move` | Move up to 1000 items under a target parent (body: item_ids, parent_id). Items removed from all weekly boards. | "bulk move", "move items", "move these under", "reparent multiple" | — |
| POST | `/items/{id}/reposition` | Move item to a new 0-based position among its siblings (body: position*, group_by?). Optional `group_by: "status"` scopes position to the item's status group (use on status-grouped boards); omit for global ordering. Invalid `group_by` value → 400. Returns updated item. | "reorder item", "move to position", "drag item", "reposition" | — |
| POST | `/items/{id}/indent` | Make item a child of its nearest left sibling (outliner indent). No body. Returns 400 if no left sibling exists. | "indent item", "make subtask", "nest under previous", "demote item" | — |
| POST | `/items/{id}/outdent` | Promote item to sibling of its parent (outliner outdent). No body. Returns 400 if item is already at top level. | "outdent item", "promote task", "move to parent level", "unindent" | — |
| POST | `/items/{id}/duplicate` | Duplicate an item (body: include_children? boolean). Due dates, start dates, and completion status are cleared; assignments are copied. Returns 201 with `{ data: { item, children: [] } }`. | "duplicate item", "copy task", "clone item" | — |
| POST | `/items/{id}/toggle_is_top` | Toggle item must-do (is_top) flag. No body. Each call flips the current value. Turning OFF strips `#must` hashtag from item name. Returns updated item. Errors: 400 (invalid ID), 401, 403, 404. | "mark must-do", "tag as must do", "remove must tag", "toggle priority flag" | `/items/{id}` |
| POST | `/items/context` | Batch context lookup for up to 500 item IDs (body: `{ "item_ids": integer[] }`). Returns 24-field context projection per item (6 chip kinds). Unviewable/non-existent IDs silently dropped. | "get item context", "batch context", "breadcrumbs for items", "item badges", "item chips", "item context chips" | — |
| POST | `/items/{id}/align` | Polymorphic alignment — align an item to a goal, outcome, key result, item, or work session (body: align_to_id*, align_to_type* — one of `Goal`, `Outcome`, `KeyResult`, `Item`, `WorkSession`). Idempotent. Returns `{ data: { aligning_id, aligning_type, align_to_id, align_to_type } }`. | "align item", "link to goal", "connect to outcome", "align to key result", "align to work session" | — |
| PATCH | `/items/remove-next-tag` | Bulk strip `#next` hashtag from item names for the authenticated user (no body required). Returns `{ data: { updated: N } }`. | "remove #next tags", "clear next tags", "strip priority hashtags", "clean up #next" | — |
| PATCH | `/items/move-to-team-idea-list` | Reparent items to a team idea list and optionally clean up day-plan actions (body: item_ids*, target_id* — the destination item ID; dpa_cleanup? boolean). Returns `{ data: { moved: N } }`. | "move to idea list", "send to team backlog", "move to parking lot", "reparent to idea list" | — |
| POST | `/items/{id}/add-to-day-plan` | Add item to today's day plan (no body). Idempotent — already-on-plan still returns `{ data: { item_id, added: true } }`. Caller must be able to edit the item. | "add to today", "put on my plan", "add to day plan" | `/items/{id}` |
| DELETE | `/items/{id}/day-plan` | Remove item from today's day plan (deletes the day-plan action). Item itself untouched, not archived; other contexts (project, team board, meeting) unaffected. Only the caller's own plan. | "take off today's plan", "remove from day plan" | — |
| GET | `/items/{id}/alignment` | Get an item's alignment ladder (top-down: team vision → 1-year goal → rock → milestone → item → children). Returns `{ data: { aligned: boolean, nodes: [{ kind, id, name, meta, aligned_here, you_are_here }] } }`. `aligned: false` (empty `nodes`) is not an error — most items don't roll up to a rock. | "alignment ladder", "what rock is this under", "how does this roll up", "show alignment chain" | `/items/{id}` |
| GET | `/items/{id}/hashtags` | List hashtags on an item — plain lowercase strings, no `#` prefix. Returns `{ data: { hashtags: string[] } }`. | "show hashtags", "list tags on item" | — |
| PUT | `/items/{id}/hashtags` | Replace all hashtags on an item (body: hashtags* — string[], set-replace: absent tags removed, new tags created). Normalized to lowercase, whitespace stripped. Reserved system tags (scheduling, realization, quadrant, etc.) rejected with 422. Returns `{ data: { hashtags, added, removed } }`. | "set hashtags", "replace tags", "retag item" | — |
| POST | `/items/{id}/measures` | Link a scorecard measure to an item (body: measure_id*), so the item shows as work behind that number. Idempotent — re-linking returns 201 again without duplicating. Returns `{ data: { item_id, measure_id } }`. | "link measure to item", "attach KPI to item", "connect item to measure" | — |
| DELETE | `/items/{id}/measures/{measureId}` | Unlink a scorecard measure from an item (both the item and measure survive; only the link is dropped). Idempotent. Returns 204. | "unlink measure from item", "remove KPI link from item" | — |
| POST | `/items/{id}/move-to-long-term-issues` | Move an item to a team's long-term issues (body: team_id*): sets blocked + long-term, strips `#next`/`#parkinglot`/`#blocked` hashtags, and takes the item OFF that team's weekly board (unlike `place-on-weekly`'s `park_for_later`, which keeps it on the board). Cross-org moves drop labels the destination org doesn't own. | "move to long-term issues", "make this a long-term issue" | — |
| POST | `/items/{id}/place-on-weekly` | Place an item on a team's weekly board (body: team_id*, section* — `to_do`\|`issues`\|`park_for_later`), moving it to that team. `to_do` = active on this week's to-dos; `issues` = blocked; `park_for_later` = blocked + long-term, held for a future week (stays on the board, unlike `move-to-long-term-issues`). | "place on weekly board", "add to team board", "file as this week's to-do" | — |

Batch context response: `{ "data": { "<item_id>": { "stored_ancestor_path": string\|null, "on_weekly": boolean, "is_long_term": boolean, "1x1_id": integer\|null, "1x1_name": string\|null, "todolist_id": integer\|null, "todolist_group_id": integer\|null, "todolist_name": string\|null, "day_plan_date": string\|null, "group_id": integer\|null, "group_name": string\|null, "project_meeting_id": integer\|null, "project_meeting_name": string\|null, "parent_item_id": integer\|null, "parent_item_name": string\|null, "measurable_id": integer\|null, "measurable_name": string\|null, "quarterly_planning_id": integer\|null, "quarterly_planning_team_name": string\|null, "parent_rock_id": integer\|null, "parent_rock_name": string\|null, "parent_rock_goal_name": string\|null, "parent_one_year_goal_id": integer\|null, "parent_one_year_goal_name": string\|null } } }`. All 24 keys always present per entry. Fields `1x1_id`, `1x1_name`, and `day_plan_date` are scoped to the requesting user (not item owner). Empty object `{}` when input is empty or all IDs are unviewable. Chip text templates: project_meeting → `project_meeting_name`; parent item → `parent_item_name`; measurable → `measurable_name`; quarterly planning → `"{quarterly_planning_team_name} Quarterly Planning"`; parent rock → `"{parent_rock_goal_name}, {parent_rock_name}"`; parent one-year goal → `parent_one_year_goal_name`.

Item fields: `id`, `name`, `description`, `start_date` (YYYY-MM-DD | null — Gantt-chart scheduling), `due`, `status`, `on_weekly`,
`recur_daily` (boolean — "Everyday" badge in the prioritizer),
`is_long_term` (boolean, defaults to `false`),
`is_top` (boolean — must-do / prioritizer flag; included in all v2 item responses),
`color` (hex string | null),
`comment_count`, `attachment_count` (integers),
`team` (TeamSimple | null), `creator` (UserSimple), `assignees` (UserSimple[]),
`parent_id`, `created_at`, `updated_at`,
`third_party_tracker` (`{ provider: string, external_id: string, name: string } | null` — always present; `null` when no tracker linked; provider is one of `clickup`, `monday`, `hubspot`, `salesforce`, `notion`),
`custom_labels` (`[{id, name, color}]` — always present, `[]` if none; on planner reads carries the requesting user's own personal labels + team labels they're entitled to see; `tags` is a deprecated alias emitting identical content — prefer `custom_labels`),
`links` (ItemLink[] — always present, `[]` if none).

Item `type` values: `Task` (default), `TodoList`, `Outcome`, `KeyResult`.

ItemDetail: Item fields + `children` (Item[]) + two always-present fields: `source_page` (`{id, title}` | null — the Pages document this item was created FROM, read live so a renamed page shows its current title here; `null` is deliberately ambiguous, covering "no origin," "origin page not viewable," and "origin page deleted" identically — set/cleared via `PATCH /items/{id}` (or `/projects/{id}`) with `source_page_id`: an integer sets it, `null` clears it, omit to leave unchanged) and `resolving_todos` (the To-Do items that resolve this Issue, each carrying live status/due; `[]` when none).

ItemTreeNode: Item fields + `children` (ItemTreeNode[]). Returned by `GET /items/{id}/children`. Nested recursively to the requested `depth` (1–20, default 2). Empty array at leaf nodes or max depth.

Move body fields: `parent_id` (integer or null — move under parent or to root), `left_id` (integer — place after sibling), `right_id` (integer — place before sibling). At least one required. If both `left_id` and `right_id` given, `left_id` takes precedence.

Bulk move: `PATCH /items/bulk-move` body: `{ "item_ids": integer[], "parent_id": integer }`. Response: `{ "data": { "moved": integer, "failed": integer, "errors": [{ "id": integer, "reason": string }] } }`. Per-item error reasons: `not_found`, `forbidden`, `self_reference`. Items already under the target parent are silently counted as moved. Duplicate item_ids are deduplicated server-side. Items are removed from all weekly board placements after being moved. Returns 403 if user cannot access the target parent, 404 if target parent not found, 422 for validation errors (empty item_ids, exceeds 1000, missing parent_id).

Smart text: `POST /items` supports `@username` in name to auto-assign, and hashtag date shortcuts (`#tomorrow`, `#nextweek`, `#1month`) to auto-set due date.

### Item Assignees

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/items/{id}/assignees` | List assignees (paginated) | "who's assigned", "show assignees", "assigned to" | `/items/{id}` |
| PUT | `/items/{id}/assignees` | Add assignee (body: user_id*) | "assign to", "add assignee", "give to" | `/items/{id}` |
| DELETE | `/items/{id}/assignees/{user_id}` | Remove assignee | "unassign", "remove assignee", "take off" | `/items/{id}` |

### Item Comments

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/items/{id}/comments` | List comments (chronological, paginated) | "show comments", "show notes", "what's been said" | `/items/{id}` |
| POST | `/items/{id}/comments` | Create comment (body: body*) | "add comment", "leave a note", "comment on" | `/items/{id}` |

**Permission (both routes)**: view access to the item — the same rule as reading the item itself, including the 1-on-1-participant fallback (a participant of a 1:1 the item is shared to may read and post even without ordinary view access). Not edit-gated — any viewer may comment. Errors: 404 if the item doesn't exist; 403 if it exists but isn't viewable (and no 1-on-1 fallback applies); 422 on POST with an empty/whitespace-only `body`; 400 on a non-numeric `{id}` or unparseable JSON body.

**Type scope — verified against the route source, not assumed**: `commentable_type` is hardcoded to `Item`, so this endpoint only ever reads/writes comments on `Item` rows. To-dos, issues, day-plan items, and **milestones** are Items and work here (`createMilestone` persists a Milestone as an Item). **Rocks and Goals (yearly/quarterly) are NOT Items** — they're `Goal` rows, so a rock/goal id 404s here as "Item not found," and there is no `/goals/{id}/comments` or `/rocks/{id}/comments` route anywhere in the v2 API. **Headlines are not Items either** — a headline IS a `Comment` row itself (`is_kudos: true`, no `commentable_id`/`commentable_type` of its own), so it cannot carry a comment through this or any route. Projects get their own alias, `/projects/{id}/comments` (documented under Projects below) — identical shape and `commentable_type: 'Item'`, gated to view access, but with **no** 1-on-1 fallback.

Comment fields: `id`, `body`, `author` (UserSimple), `created_at`, `updated_at` (equal to `created_at` when unedited; later when edited — use to show "edited" badge).

**Example — POST `/items/415/comments`**:
```json
{ "body": "Talked to the vendor — quote is in the shared drive." }
```
Response `201`:
```json
{
  "data": {
    "id": 9001,
    "body": "Talked to the vendor — quote is in the shared drive.",
    "author": { "id": 7, "login": "sarah", "first_name": "Sarah", "last_name": "Lee" },
    "created_at": "2026-09-24T14:02:00.000Z",
    "updated_at": "2026-09-24T14:02:00.000Z"
  }
}
```

**Example — GET `/items/415/comments`** → `200`:
```json
{
  "data": [
    {
      "id": 9001,
      "body": "Talked to the vendor — quote is in the shared drive.",
      "author": { "id": 7, "login": "sarah", "first_name": "Sarah", "last_name": "Lee" },
      "created_at": "2026-09-24T14:02:00.000Z",
      "updated_at": "2026-09-24T14:02:00.000Z"
    }
  ],
  "meta": { "page": 1, "per_page": 100, "total": 1, "total_pages": 1 }
}
```

### Comment Edit / Delete (flat by id)

Flat routes that work for a comment on any commentable surface (Item, Project, Result Feed report, Page, Goal, and others) — one handler branches on the comment's own `commentable_type`.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| PATCH | `/comments/{commentId}` | Edit a comment body (body: body* HTML, ≤ 65,535 bytes). Author-only. Empty body returns 422. | "edit comment", "update comment", "fix my comment" | — |
| DELETE | `/comments/{commentId}` | Remove a comment (hard delete). Author or surface admin. Cleans up activity feed + decrements comment_count. | "delete comment", "remove comment", "remove my note" | — |

- `PATCH` response: `{ data: { id, body, author, created_at, updated_at } }` (200)
- `DELETE` response: `{ data: { id, deleted: true } }` (200)
- **Permission — edit**: comment author only (`comment.user_id === current user`).
- **Permission — delete**: comment author, OR — for an Item/Project comment specifically — a team admin of the item's team (`isTeamAdmin()`: group creator, or an editor/author/contributor on the Group Access List, including ancestor teams). A Result Feed (daily report) comment: the report owner instead. Any other surface: author only.
- **Existence-leak gate**: 404 (never 403) both when the comment doesn't exist and when it exists but its surface isn't viewable to the caller — the two cases read identically so a caller can't probe for what they can't see.
- 403 if a non-author tries to edit, or a non-author/non-admin tries to delete. 422 on an empty or over-length (> 65,535 byte) edit body.
- `comment_count` is decremented on delete only for surfaces that track one — Items and Projects do; a Result Feed report does not, so the decrement is skipped there.
- These two routes accept a `commentId` for **any** `commentable_type`, including `Goal` — but nothing in the v2 API creates or lists a Goal comment (no `/goals/{id}/comments` route exists), so in practice the only comments with an id to edit or delete here are ones reached through `/items/{id}/comments` or `/projects/{id}/comments`.

**Example — PATCH `/comments/9001`**:
```json
{ "body": "Talked to the vendor — quote is in the shared drive, updated with tax." }
```
Response `200`:
```json
{
  "data": {
    "id": 9001,
    "body": "Talked to the vendor — quote is in the shared drive, updated with tax.",
    "author": { "id": 7, "login": "sarah", "first_name": "Sarah", "last_name": "Lee" },
    "created_at": "2026-09-24T14:02:00.000Z",
    "updated_at": "2026-09-24T14:11:00.000Z"
  }
}
```

**Example — DELETE `/comments/9001`** → `200`:
```json
{ "data": { "id": 9001, "deleted": true } }
```

### Item Attachments

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/items/{id}/attachments` | List all attachments (files + links) on an item | "show attachments", "list files", "what's attached", "item files", "show linked URLs" | `/items/{id}` |
| POST | `/items/{id}/attachments` | Upload file attachment (multipart/form-data: file*, name?, description?). Max 4.5 MB. | "upload file", "attach file", "add attachment", "upload to item" | `/items/{id}` |
| POST | `/items/{id}/links` | Add URL link (body: url* HTTPS required, title?, description?, media_type_code?) | "add link", "attach URL", "add resource link", "link to item" | `/items/{id}` |
| PATCH | `/links/{material_id}` | Update a linked URL's fields (body: url?, title?, description?, status_words? — ≤255 chars, the linked ticket's state in its own tracker's vocabulary, e.g. "In Review"; `null`/blank clears a field). At least one field required (400 `no_updatable_fields` otherwise). Same edit permission as POST/DELETE. | "update link", "edit link title", "change link status", "set tracker status on link" | — |
| DELETE | `/attachments/{material_id}` | Delete file attachment. Use `material_id` from list response. | "delete attachment", "remove file", "delete file from item" | — |
| GET | `/attachments/{material_id}/download` | Download file — 302 redirect to pre-signed S3 URL (5-min expiry). Use `material_id`. | "download file", "get file", "download attachment" | — |
| GET | `/attachments/{id}/public/{token}` | Serve a file attachment's bytes at its **permanent**, unauthenticated URL — this is the `permanent_url` an `<img src>` embeds in a saved item/rock description or page body, so unlike the presigned download link above it never expires. The signed token IS the authorization, bound to the attachment id (a swapped id 404s). Covers item attachments (ItemMaterial), rock/goal attachments (GoalMaterial), and page attachments (ObjectMaterial with `associated_type=Page`) — one exception for the last: an unpublished page's attachment also requires a session that can open the page (401 with no session; 403 not a team member; 404 outside the page's audience), served `no-store` instead of the immutable cache used elsewhere. Raster images serve inline; everything else downloads (no inline SVG/HTML execution on this origin). | "open embedded image", "permanent attachment link" | — |
| DELETE | `/links/{material_id}` | Delete URL link. Use `material_id` from list response. | "delete link", "remove link", "remove URL from item" | — |

Attachment list response: `{ "attachments": [AttachmentEntry] }`. Empty list: `{ "attachments": [] }`.

AttachmentEntry (file): `type: "file"`, `id` (Document ID), `material_id` (ItemMaterial ID — **use for delete/download**), `name`, `filename`, `content_type`, `size` (bytes), `url` (pre-signed S3 URL, ~1h expiry), `user_id`, `created_at`.

AttachmentEntry (link): `type: "link"`, `id` (LinkedUrl ID), `material_id` (ItemMaterial ID — **use for delete/update**), `title`, `url`, `description`, `media_type_code` (0=Article, 1=Video, 2=URL default, 3=Audio, 4=PDF, 5=Image, 6=Loom), `user_id`, `created_at`, `status_words` (string | null — the linked ticket's state in its own tracker's vocabulary, e.g. "To Do", "In Review"; free text ≤255 chars, never synced from the provider; set on create or via `PATCH /links/{material_id}`).

Upload errors: `400 { "error": "unsupported_extension" }` — file type not allowed; `400 { "error": "mime_mismatch" }` — MIME doesn't match extension; `413` — file exceeds 4.5 MB. Supported extensions (29): `.pdf .doc .docx .txt .rtf .odt .md .mdx .xls .xlsx .csv .ods .ppt .pptx .odp .png .jpg .jpeg .gif .svg .webp .zip .gz .tar .json .yaml .yml .xml .html`.

Auth: `canEdit` on Item for upload, add-link, and delete. `canView` on Item for list and download.

### Item Recurrence

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/items/{id}/recurrence` | Read current recurrence state | "show recurrence", "item schedule", "how often does this repeat", "recurrence settings" | `/items/{id}` |
| PUT | `/items/{id}/recurrence` | Set or clear recurrence (body: type*, day_within_interval?) | "set recurrence", "make daily", "repeat weekly", "set schedule", "clear recurrence", "remove recurrence" | `/items/{id}` |

Recurrence response: `{ "data": { "type": string|null, "day_within_interval": integer|null, "ends_after": null } }`

`type` values: `"daily"`, `"weekly"`, `"monthly"`, `"quarterly"`, or `null` (clears recurrence). Case-sensitive — `"DAILY"` or `"yearly"` → 422.

`day_within_interval` rules: required for weekly (0–6, Sun=0), monthly (1–31), quarterly (1–91). Ignored for daily. Pass `null` for `type` to clear.

Behavior: Setting any cadence clears the previous recurrence. Every successful write creates an activity feed entry. PUT response returns the updated state — no second GET needed. Returns 404 if item not found or not accessible (uniform, no existence leak).

## Teams

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams` | Authenticated user's teams (params: include_muted, q). Default team first, then alphabetical. | "show my teams", "list teams", "which teams", "my groups" | — |
| POST | `/teams` | Create team (body: name*, description, framework, parent_id?). Optional `parent_id` creates a child team under an existing parent; child inherits parent's account, framework (unless overridden), and team settings (`is_strict`, `assignments_require_review`, `is_cascading_goals`). Returns 403 if caller lacks view access to parent, 422 if parent_id is invalid. | "create team", "new team", "add group", "create child team", "create sub-team", "create team under" | `/teams/{id}` |
| GET | `/teams/{id}` | Get team detail (includes members) | "show team", "team details", "team info", "who's on the team" | `/teams/{id}` |
| PATCH | `/teams/{id}` | Update team (body: name, description, framework) | "update team", "rename team", "change framework" | `/teams/{id}` |
| DELETE | `/teams/{id}` | Delete team (permanent) | "delete team", "remove team" | — |
| PUT | `/teams/{id}/mute` | Mute team for current user (idempotent). Muted teams excluded from `GET /teams` unless `include_muted=true`. | "mute team", "hide team", "silence team" | — |
| DELETE | `/teams/{id}/mute` | Unmute team for current user (idempotent) | "unmute team", "unhide team", "show team again" | — |

`GET /teams` returns the standard data envelope: `{ "data": [...] }`. Response fields per team: `id`, `name`, `description`,
`framework`, `organization_name`, `organization_id`, `parent_name`,
`parent_id`, `is_default`, `is_muted`, `logo_url` (string | null — Filestack CDN URL or null if no logo set), `creator` (UserSimple),
`created_at`, `updated_at`.

Team detail fields: `id`, `name`, `description`, `framework`, `parent_id` (integer | null — ID of parent team, or null for root teams),
`logo_url` (string | null — Filestack CDN URL or null if no logo set), `has_slack_webhook` (boolean — team has a Slack webhook configured), `has_discord_webhook` (boolean — team has a Discord webhook configured), `creator` (UserSimple), `created_at`, `updated_at`, `members` (TeamMember[]).

TeamMember: `id`, `team` (TeamSimple), `user` (UserSimple), `role` ("member" | "admin").

Mute/unmute response: `{ data: { id, name, is_muted } }`.

### Team Members

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/members` | List members (params: page, per_page, q) | "show members", "who's on the team", "team roster" | `/teams/{id}` |
| GET | `/teams/{id}/suggested-members` | All unique members across the full org hierarchy rooted at `{id}`, deduplicated by user ID (params: search — substring filter on login/email/first_name/last_name, activates at ≥2 chars). Excludes muted-team members unless they also belong to a non-muted team. Same response shape as `/teams/{id}/members`. No pagination — all matches returned in one response. `role` is always `"member"`. | "suggested members", "org members", "mention candidates", "who can I mention", "all members across teams", "assignee lookup" | — |
| PUT | `/teams/{id}/members` | Add existing user to team (body: user_id*, role?: "member"\|"admin") | "add member", "make admin" | `/teams/{id}` |
| POST | `/teams/{id}/members/invite` | Add or invite a user to the team by email (body: email*, first_name?, last_name?). Admin only. Returns 201. If the email belongs to an **existing** user (including cross-org), adds them directly and sends a "you were added" notification. If brand-new, creates a passive user and sends a confirmation/setup email (fire-and-forget via SES). | "invite member", "invite to team", "send invite", "invite new user", "add user by email", "add cross-org user" | `/teams/{id}` |
| PATCH | `/teams/{id}/members/{user_id}` | Change member role (body: role* — "admin" or "member"). Admin-only. Cannot demote last admin. | "change role", "make admin", "promote to admin", "demote member", "change member role" | `/teams/{id}` |
| DELETE | `/teams/{id}/members/{user_id}` | Remove member | "remove member", "kick from team" | `/teams/{id}` |
| POST | `/teams/{id}/members/{user_id}/resend-invite` | Re-send confirmation email to a pending (unconfirmed) member. Admin-only. No body. Returns 200 `{ data: { success: true, user_id, team_id } }`. 403 if not admin; 404 if team/user not found or not a member; 422 if member already confirmed. | "resend invite", "resend confirmation", "send invite again", "re-invite pending member" | — |

POST /teams/{id}/members/invite body: `{ "email"*, "first_name"?, "last_name"? }`. `first_name`/`last_name` used only when creating a brand-new user. Response 201: `{ "data": { "id", "team": { "id", "name" }, "user": { "id", "login", "first_name", "last_name" }, "role": "member" } }`. Errors: 401, 403 (not team admin), 404, 422 (email missing; `"has already been invited to this team"` for pending invites; `"is already a member of this team"` for active members). **Behavior**: if email belongs to an existing user not yet on the team (including cross-org users), they are added as an active member (not pending) and receive a "you were added" notification. If email is brand-new, a passive user is created and a confirmation/setup email is sent (fire-and-forget; SES failure does not fail the request). `PUT /teams/{id}/members` (by user_id) remains same-organization only.

PATCH /teams/{id}/members/{user_id} body: `{ "role": "admin" | "member" }`. Response: `{ "data": { "id", "login", "first_name", "last_name", "email", "role" } }`. Errors: 401 (unauthorized), 403 (not a team admin), 404 (team or user not found), 422 (invalid role).

### Team Activity Logs

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/activity-logs` | Paginated list of membership changes (params: page, per_page). Team member auth required. | "activity logs", "team history", "membership changes", "who joined", "who was removed", "team audit log" | — |

ActivityLogEntry fields: `id`, `action` ("member_added" \| "member_removed" \| "role_changed"), `target_user` (UserSimple), `actor` (UserSimple), `details` (string), `created_at`. Wrapped in standard `{ data: [...], meta: { page, per_page, total, total_pages } }` envelope. Errors: 401, 403 (not a team member), 404 (team not found).

### Team Labels

Admin-only for writes. Labels are organizational tags (name + color) used in the web UI.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/labels` | List team labels (params: page, per_page). Team member auth required. | "team labels", "team tags", "show labels" | — |
| POST | `/teams/{id}/labels` | Create label (body: name*, color*). Admin only. | "create label", "add label", "new team tag" | — |
| PATCH | `/teams/{id}/labels/{label_id}` | Update label (body: name?, color?). Admin only. | "update label", "rename label", "change label color" | — |
| DELETE | `/teams/{id}/labels/{label_id}` | Delete label. Admin only. | "delete label", "remove label" | — |
| PATCH | `/teams/{id}/labels/reorder` | Persist a new display order for the team's OWN custom labels (body: label_ids* — integer[], the team's own label IDs only; inherited ancestor labels aren't reorderable here). Re-sorts the Labels tab and Swimlane Roadmap label lanes. Admin only. Returns `{ data: { success: true, count: N } }`. | "reorder labels", "rearrange team labels", "sort labels" | — |
| GET | `/teams/{id}/labels/{label_id}/usage` | Where a SHARED team label is used below its owner team — descendant-team items carrying it and descendant swimlane-roadmap lanes defining it — so the caller can warn before un-sharing/deleting. Read-only. Owner-team admin only. Returns `{ data: { items: [{id, title, team_id}], roadmap_lanes: [{roadmap_id, team_id, name}] } }`. | "label usage", "where is this label used", "check label before deleting" | — |

Label fields: `id`, `name`, `color` (hex string, e.g. "#3b82f6"), `created_at`. Wrapped in standard `{ data: [...], meta }` envelope (list) or `{ data: {...} }` (create/update). Errors: 401, 403 (non-member for GET; non-admin for writes), 404.

### Team Integrations

Admin-only. Webhook configurations (e.g. Slack). Managed via web UI — reference only.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/integrations` | List integrations (params: page, per_page). Admin only. | "team integrations", "slack integration", "team webhook", "team webhook list" | — |
| POST | `/teams/{id}/integrations` | Create/upsert integration by type (body: type*, name*, webhook_url*). Admin only. | "create integration", "add webhook", "set up slack" | — |
| PATCH | `/teams/{id}/integrations/{integration_id}` | Update integration (body: name?, webhook_url?). Admin only. | "update integration", "change webhook url" | — |
| DELETE | `/teams/{id}/integrations/{integration_id}` | Delete integration (disables it). Admin only. | "delete integration", "remove webhook", "disable slack" | — |

Integration fields: `id`, `type` ("slack"; others TBD), `name`, `webhook_url`, `enabled` (boolean), `created_at`, `updated_at`. POST upserts by type — one integration per type per team. Errors: 401, 403 (non-admin), 404.

### Team Logo

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| POST | `/teams/{id}/logo` | Set team logo URL (body: logo_url* — must be `https://cdn.filestackcontent.com/` URL). Admin-only. Upserts (replaces previous). | "upload logo", "team logo", "set team logo" | — |
| DELETE | `/teams/{id}/logo` | Remove team logo. Admin-only. Idempotent (200 even if no logo). | "remove logo", "delete team logo", "clear team logo" | — |

Response: `{ data: { logo_url: "https://cdn.filestackcontent.com/..." | null } }`. Errors: 403 (non-admin), 404 (team not found), 422 (invalid URL — POST only).

### Team Settings

Per-team settings stored in `object_metas` table — no schema changes required.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/settings` | Get all team settings (auth: any team member) | "team settings", "show settings", "is strict mode on", "check team settings" | `/teams/{id}` |
| PATCH | `/teams/{id}/settings` | Update one or more settings (auth: team admin only). Unrecognized keys silently ignored. Returns full settings object after update. | "update settings", "change setting", "enable strict mode", "turn on bhag", "toggle setting", "set parent team", "set inheritance" | `/teams/{id}` |

Settings response shape: `{ "data": { "is_cascading_goals": bool, "is_strict": bool, "bhag_enabled": bool, "assignments_require_review": bool, "skip_show_completion_message": bool, "scorecard_notes_visible": bool, "scorecard_date_order": string, "parent_vision_id": int|null, "parent_scoreboard_id": int|null, "use_parent_goals": bool|null, "pages_creatable_by": string, "can_create_pages": bool } }`.

| Setting Key | Type | Description |
|-------------|------|-------------|
| `is_cascading_goals` | bool | Whether goals cascade to sub-teams |
| `is_strict` | bool | EOS strict meeting accountability mode (EOS teams default `true` when no record exists) |
| `bhag_enabled` | bool | Whether the BHAG section is visible |
| `assignments_require_review` | bool | Whether action assignments require a review step |
| `skip_show_completion_message` | bool | Whether to suppress the item completion message |
| `scorecard_notes_visible` | bool | Whether the notes column is displayed on the team scorecard UI (default `false`; display hint only — the API always returns `notes` on measures regardless) |
| `scorecard_date_order` | string | Order of scorecard date columns: `"newest_first"` or `"oldest_first"` |
| `parent_vision_id` | int\|null | ID of the ancestor team this team inherits its vision/rocks from. `null` = no inheritance set. Three-state: `null` means no ObjectMeta record exists (distinguishable from `false` or `0`). |
| `parent_scoreboard_id` | int\|null | ID of the ancestor team whose scorecard this team inherits. `null` = no inheritance set. Same three-state semantics as `parent_vision_id`. |
| `use_parent_goals` | bool\|null | Whether this team uses its parent team's goals. `null` = not set (distinguishable from `false`). |
| `pages_creatable_by` | string | Who may create Pages on this team: `"all_members"` (default on read) or `"admins_only"`. Writable via PATCH; a value outside the enum returns 422. |
| `can_create_pages` | bool | **Read-only, computed per caller** — whether *this* caller may create a page on this team. Render the "+ Page" / "New sub-page" affordance from it rather than re-deriving team-admin status. |

PATCH body: any subset of the recognized keys. Boolean keys require boolean values; `parent_vision_id` / `parent_scoreboard_id` require integer or `null`; `use_parent_goals` requires boolean or `null`. Sending `null` for the inheritance fields deletes the underlying ObjectMeta record (clears inheritance). Omitting a key leaves its value unchanged. The API does **not** validate that `parent_vision_id` / `parent_scoreboard_id` values are actual ancestor team IDs — client must validate. Errors: 400 (invalid team id), 401 (no auth), 403 (GET: not a team member; PATCH: not a team admin), 404 (team not found), 422 (wrong value type — `{ "error": "Validation failed", "details": { "<key>": ["must be an integer or null"] } }`).

### Team Rhythm Settings

Per-team rhythm meeting time slots stored in `object_metas`. Returns defaults if no custom times saved — GET never returns 404.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/rhythm-settings` | Fetch rhythm meeting time slots (custom or system defaults). Auth: any team member. | "rhythm times", "meeting times", "rhythm settings", "what time is the meeting" | — |
| PATCH | `/teams/{id}/rhythm-settings` | Set all 7 rhythm meeting time slots (full replacement). Auth: team admin only. | "set meeting times", "update rhythm times", "change meeting schedule", "set rhythm settings" | — |

Response shape (both endpoints): `{ "data": { "times": string[] } }` — always exactly 7 time strings in 12-hour format (e.g. `"9:00 AM"`).

PATCH body: `{ "times": ["9:00 AM", "9:15 AM", "9:30 AM", "9:45 AM", "10:00 AM", "10:15 AM", "10:30 AM"] }` — exactly 7 strings required, each must match `/^\d{1,2}:\d{2} (AM|PM)$/i`.

Errors: 400 (invalid JSON), 403 (non-admin on PATCH), 404 (team not found / no access), 422 (wrong count or invalid time format — e.g. `"times must contain exactly 7 entries"` or `"times[2] is not a valid 12-hour time (e.g. 9:00 AM)"`).

### Team Quarterly Rhythm — Next Steps & 3-Step Prep

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/quarterly-items/next-steps` | The team's "next steps" items for the quarterly rhythm — items flagged `is_group_rhythm=true`, excluding archived, sorted by `organizer_position` ascending. Params: page, per_page. Any member who can view the team; non-members/unknown teams get 404. | "quarterly next steps", "team rhythm next steps" | `/team-rhythm-quarterly` |
| GET | `/teams/{id}/weekly-prep-completions` | Has the CALLING member completed their 3-Step Prep for THEIR current week on this team (no params — always self, always current week). Week runs Sunday–Saturday by the member's own local day (**not** the Monday-keyed week Scorecard history uses). Always 200, never 404 — `completed: false` is a normal answer. Readable on an archived team; a viewer who isn't a member gets `completed: false`. | "have I done my prep", "weekly prep status", "3-step prep completed" | — |
| POST | `/teams/{id}/weekly-prep-completions` | Record the caller's 3-Step Prep completion for their current week (body: history_data? — arbitrary JSON, stored verbatim and never interpreted, ≤65535 bytes serialized). **Idempotent per member+team+week** — a repeat submit returns 200 with the ORIGINAL record and writes nothing (never 201 then 200; the first submit's `history_data` is preserved). Also drops a completed personal to-do "Reviewed and updated assignments for the team weekly" onto the member's check-in for that day, once per day regardless of how many teams they prep for. Requires team membership; 403 on an archived team (participation stays readable though). | "record 3-step prep", "complete weekly prep", "log my prep" | — |
| GET | `/teams/{id}/weekly-prep-participation` | Share of the team's people who completed 3-Step Prep in a given week (param: date? — any date in the week, normalized to that week's Sunday; default caller's current local week). `members_total` counts this team **and every team beneath it**; `members_completed` counts records against **this team only** — a sub-team member who prepped for their own sub-team counts in the total but not the completed count (deliberate legacy asymmetry). `percentage` capped at 100, 0 for a team with no members. Readable on an archived team. | "team prep participation", "weekly prep percentage", "3-step prep engagement" | — |

PrepCompletionStatus fields (GET response): `completed` (boolean), `week_start` (date, Sunday), `week_end` (date, Saturday).

PrepCompletion fields (POST response): `id`, `team_id`, `user_id`, `week_start`, `week_end`, `created_at` (on a repeat submit, the ORIGINAL write time, not the repeat's).

PrepParticipation fields: `team_id`, `week_start`, `week_end`, `percentage` (0–100, 2 decimals), `members_completed`, `members_total`.

System defaults (returned when no custom times saved): `["9:00 AM", "9:15 AM", "9:30 AM", "9:45 AM", "10:00 AM", "10:15 AM", "10:30 AM"]`.

### Team Customer-to-Cash Departments

Ordered list of departments a customer passes through from first contact to revenue collection. Stored in `object_metas` (`meta_key = 'customer_to_cash_data'`). GET returns defaults if none saved — never returns 404.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/customer-to-cash` | Get department list (custom or defaults). Auth: any team member. | "customer to cash departments", "c2c departments", "department flow", "c2c flow" | — |
| PUT | `/teams/{id}/customer-to-cash` | Replace entire department list (full replacement). Auth: team admin only. | "set departments", "update c2c departments", "save department flow", "set customer to cash departments" | — |

Response shape (both endpoints): `{ "data": { "departments": string[] } }`.

Default departments (returned when none saved): `["Marketing", "Sales", "Customer Success", "Engineering/Product/Service Delivery", "Finance"]`.

PUT body: `{ "departments": ["Marketing", "Sales", ...] }` — non-empty array, max 50 items, each ≤255 chars.

Errors: 400 (invalid team ID or malformed JSON), 401 (unauthenticated), 403 (GET: not a team member; PUT: not a team admin), 404 (team not found), 422 (validation failure — `{ "error": { "code": "validation_error", "details": { "departments": ["departments must not be empty"] } } }`).

### Team Weekly Board (Items)

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/items` | All team items (params: page, per_page, q, all, include_archived) | "show weekly", "team board", "weekly board", "L10 board" | `/level-10-meeting?team={id}` |
| POST | `/teams/{id}/items` | Create team item (on_weekly=true) | "add to weekly", "new team task", "create on board" | `/items/{item_id}` |
| PUT | `/teams/{id}/items/{item_id}` | Add item to board (sets on_weekly=true) | "put on weekly", "add to board", "show on weekly" | `/items/{item_id}` |
| DELETE | `/teams/{id}/items/{item_id}` | Remove from weekly (sets on_weekly=false, keeps item) | "remove from weekly", "take off board", "hide from weekly" | — |
| GET | `/teams/{id}/items/{section}` | Items by section (params: page, per_page, q, all, include_archived). Section: `done`, `next`, `blocked`, `parked`. | "show next", "show done", "show issues", "show parked", "priorities", "blockers", "parking lot" | `/level-10-meeting?team={id}` |
| PUT | `/teams/{id}/items/{section}/{item_id}` | Move item to section on board. Section: `done`, `next`, `blocked`, `parked`. | "move to next", "mark done", "flag as blocked", "park item", "prioritize" | `/items/{item_id}` |

Section values for `{section}`: `done`, `next`, `blocked`, `parked`.

| Section | GET shows | PUT effect |
|---------|-----------|------------|
| `next` | Items with status=next. Default: due within 7 days. Pass `?all=true` to skip. | Sets status=next, ensures on_weekly=true, auto-sets due date if null |
| `done` | Items with status=done. Default: completed within 7 days. Pass `?all=true` to skip. | Sets status=done, records completion timestamp |
| `blocked` | Items with status=blocked. No time filter. | Sets status=blocked, ensures on_weekly=true |
| `parked` | Items with status=parked. No time filter. Supports `include_archived`. | Sets status=parked, ensures on_weekly=true |

The `all` param (boolean, default false) on team item endpoints shows all team members' items when true; otherwise only current user's. Note: team projects do NOT use `all` — use `followed_only` and `include_muted` instead.

### Team Issues (dedicated endpoint)

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/issues` | List team issues (items with status=blocked, is_wow=true). Supports rich filtering. No pagination — returns all matches. | "show team issues", "list all issues", "filter issues by label", "long-term issues", "IDS items" | `/components?tab=issues` |

Query params: `is_long_term` (boolean — filter long-term vs short-term issues; null treated as false), `search` (string, min 2 chars — case-insensitive name search), `custom_label_ids[]` (integer[] — AND logic, item must have all specified labels), `created_at_from` (YYYY-MM-DD), `created_at_to` (YYYY-MM-DD), `completed_from` (YYYY-MM-DD), `completed_to` (YYYY-MM-DD).

**Notes**: Completion date filters (`completed_from`/`completed_to`) also include `realized` items (not just `blocked`). Response includes `can_edit` (boolean), `comment_count` (integer), `attachment_count` (integer) in addition to standard Item fields.

Due date auto-set: creating an item with `status: "next"` in a team context (or moving an item to the `next` column via `PUT .../items/{section}/{item_id}`) with no explicit `due` date auto-sets `due` to 7 days from now. Explicit `due` values are always preserved.


### Team Projects

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/projects` | List team projects (params: page, per_page, q, status, include_muted, followed_only). Default: active, non-parkinglot, non-muted. Each project includes `default_view` (string\|null) and completion stats: `percent_complete` (number, 0–100), `total_children`, `realized_count`, `blocked_count`, `overdue_count`, `active_count` (all integers). | "show projects", "team projects", "rocks (EOS)", "execution plan", "project completion", "how complete is this project" | `/plugins/projects` |
| POST | `/teams/{id}/projects` | Create project in team (body: name*, description, due, status, on_weekly, team_id, parent_id, context). Note: stat fields are NOT included in create responses. | "create project", "new project on team", "add rock" | `/plugins/projects/{project_id}/overview` |
| GET | `/projects/{id}` | Get single project detail. Includes `default_view` (string\|null) and completion stats: `percent_complete`, `total_children`, `realized_count`, `blocked_count`, `overdue_count`, `active_count`. Also includes `children` array. | "show project", "project detail", "open project" | `/plugins/projects/{project_id}/overview` |
| PUT | `/teams/{id}/projects/{project_id}` | Convert item to team project (sets type=TodoList, assigns to team). Idempotent. | "convert to project", "promote to project", "make it a project" | `/plugins/projects/{project_id}/overview` |
| PATCH | `/teams/{id}/projects/{project_id}` | Update project (body: name, description, due, status, on_weekly) | "update project", "rename project", "change project status" | `/plugins/projects/{project_id}/overview` |
| PATCH | `/projects/{id}/default-view` | Set default view for a project (body: default_view*). Any team member with view access. Shared across all members. | "set default view", "change default view", "default to board view", "set project view" | — |
| DELETE | `/teams/{id}/projects/{project_id}` | Remove project from team (clears group_id, keeps project) | "remove project from team", "unlink project", "take off team board" | — |
| PATCH | `/teams/{id}/projects/reorder` | Persist a new SHARED display order for the team's projects (body: item_ids* — integer[], sets `organizer_position` for each; may be a filtered/displayed subset, every id must be a project belonging to this team). Not per-user — last write wins, visible to every member on next load. Admin only. Returns `{ data: { reordered: N } }`. | "reorder projects", "rearrange team projects", "sort projects" | — |

Default filtering: returns only active, non-parkinglot, non-muted projects. Use `status` to override the active-only filter (e.g. `?status=done`). Use `include_muted=true` to include muted items.

**Project completion stats** (`percent_complete`, `total_children`, `realized_count`, `blocked_count`, `overdue_count`, `active_count`): returned on all GET project responses (list and detail). All fields are always numeric (never null); projects with no children have all zeros. Stats are NOT returned on POST/PATCH responses. Counts exclude archived children.

`default_view` valid values: `"overview"`, `"board"`, `"table"`, `"roadmap"`, `"outline"`, `"mindmap"`, `null` (resets to no preference; treated as `"overview"` by clients). Per-project, shared across all team members. `PATCH /projects/{id}/default-view` body: `{ "default_view": string | null }`. Response 200: `{ "data": { "id": integer, "default_view": string | null } }`. Response 422: `{ "errors": ["default_view is not a valid view"] }`.

### Standalone Projects (`/projects`)

User-owned project CRUD, independent of the team-scoped `/teams/{id}/projects` routes above (same underlying data — `type=TodoList` items — different surface). `GET /projects/{id}` is shared with the team-scoped table above; the rest are documented here.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/projects` | List projects OWNED BY THE CALLER (params: page, per_page, q, status, include_archived). `type` query param is accepted but ignored — always TodoList. | "my projects", "list my projects", "show my project list" | `/plugins/projects` |
| POST | `/projects` | Create a standalone project (body: name*, description?, due?, status? default `not_started`, on_weekly? default false, team_id?, parent_id?, context? — `{type: "team"|"meeting"|"day_plan", id?}`, id required for team/meeting, omitted for day_plan). `type` is always forced to TodoList regardless of body. | "create project", "new project", "add project" | `/plugins/projects/{project_id}/overview` |
| PATCH | `/projects/{id}` | Update a project (body: any `ItemUpdateRequest` field — name, description, due, status, source_page_id, etc.). 404 if the item exists but isn't a TodoList. | "update project", "edit project", "rename project" | `/plugins/projects/{project_id}/overview` |
| DELETE | `/projects/{id}` | Soft-archive a project (V1 status → archived). 404 if not a TodoList. Returns 204. | "archive project", "delete project" | — |
| POST | `/projects/children-batch` | Batch-fetch children trees for up to 100 projects in ONE call (body: project_ids* — integer[], max 100, deduped, non-positive/non-integer ignored; depth? — 0–20, default 2; roadmap_id? — lets a named roadmap editor receive projects they can't view by team membership, limited to that roadmap's own cards). Projects that don't exist, aren't TodoLists, or aren't viewable are silently omitted (never an error for those). Built for surfaces aggregating multiple projects at once (the swimlane roadmap board). Returns `{ data: [{ project_id, project: {id,name,color}\|null, children: ItemTreeNode[] }] }`. | "batch fetch project children", "load multiple projects at once", "roadmap board data" | — |
| GET | `/projects/{id}/assignees` | List project assignees (paginated). | "project assignees", "who's on this project" | — |
| PUT | `/projects/{id}/assignees` | Add an assignee (body: user_id*). Idempotent — 200 if already assigned, 201 if newly added. | "assign to project", "add project assignee" | — |
| DELETE | `/projects/{id}/assignees/{user_id}` | Remove an assignee. Returns 204. | "unassign from project", "remove project assignee" | — |
| GET | `/projects/{id}/children` | Nested child tree (params: page, per_page, q, depth? 1–20 default 2; roadmap_id? — same named-editor exception as children-batch). Pagination applies to top-level children only. In columnar projects, prefer `GET /projects/{id}/columns` (position-ordered, embedded items). 404 if not a TodoList. | "project children", "list project contents" | — |
| GET | `/projects/{id}/attachments` | List file + link attachments (`{ attachments: ItemAttachment[] }`). Requires VIEW only (same as commenting). 404 if not a TodoList. | "project attachments", "files on this project" | — |
| POST | `/projects/{id}/attachments` | Upload a file attachment (multipart: file*, name?, description?) — what an image pasted into the project comment composer/editor uploads through. **Requires VIEW only, deliberately not edit** — a viewer who can comment must be able to attach an image to that comment; the edit-gated `/items/{id}/attachments` route would refuse them. Max 4.5 MB. Returns FileAttachment with `permanent_url`. | "upload project attachment", "attach file to project" | — |
| GET | `/projects/{id}/comments` | List comments, chronological (oldest first), paginated. | "project comments", "show project discussion" | — |
| POST | `/projects/{id}/comments` | Add a comment (body: standard CommentCreateRequest, same as item comments). | "comment on project", "add project comment" | — |

Project fields (`Project` — the list/detail shape, distinct from the plain `Item` shape): `id`, `name`, `description` (string\|null), `due` (date\|null), `status`, `on_weekly`, `team` (TeamSimple\|null), `creator` (UserSimple), `assignees` (UserSimple[]), `parent_id` (integer\|null), `default_view`, plus the six completion-stat fields documented above. `GET /projects/{id}` returns `ItemDetail` (Project/Item fields + `children` + two newer always-present fields: `source_page` — `{id, title}`\|null, the Pages document this item was created from, read live so a renamed page shows its current title; deliberately ambiguous — `null` covers "no origin", "origin page not viewable", and "origin page deleted" identically — and `resolving_todos` — the To-Do items that resolve this Issue, each with live status/due, `[]` when none).

### Project Hierarchy (read this before pulling project contents)

A project is a container for items, and **its contents are usually two levels deep**. Treating a project as a flat list of to-dos will surface column headers as if they were tasks.

**Standard shape (columnar — most projects):**

```
Project
├── Column A    ← direct child #1 (a section header, NOT a to-do)
│   ├── Item   ← grandchild — the actual task
│   └── Item
├── Column B    ← direct child #2
│   └── Item
└── Column C    ← direct child #3
```

Direct children of the project are **columns / section names** (Backlog, Doing, Done, etc.). The actual to-dos are **grandchildren** — children of the columns.

**Flat-checklist shape (minority case):**

```
Project
├── Item       ← direct child IS the to-do (no column layer)
├── Item
└── Item
```

A project with no columns has items as its direct children. Treat the direct-children list as the to-dos.

**How to detect which shape a project uses:**

1. **Fastest** — `GET /api/v2/projects/{id}/columns`. If the response returns columns, the project is columnar. An empty result means flat-checklist.
2. **From a fetched child** — columns carry the `is_project_column` ObjectMeta flag (see Project Columns section). A direct child without that flag is a to-do, meaning the project is flat.
3. **From `default_view`** — `"board"`, `"table"`, `"roadmap"` strongly imply columns are in use. `"outline"`, `"mindmap"`, `"overview"` may be either; do not rely on this alone.

**Recommended fetch patterns:**

- **Get the columns + items in one call (preferred):** `GET /api/v2/projects/{id}/columns` returns columns with embedded `items[]` by default. Use `?include_items=false` for the header row only.
- **Manual two-level walk:** `GET /items/{project_id}/children` for columns, then `GET /items/{column_id}/children` for items in each column. Use this only if you need fields not returned by the columns endpoint.

**Rules for any consumer (skills, MCP servers, integrations):**

- Never present a project's direct children as to-dos without first checking whether they are columns.
- When listing "to-dos in project X," walk to the grandchild level for columnar projects.
- Always handle the flat-checklist case — don't assume columns exist.
- When showing a kanban / board view, columns are the direct children; items are the grandchildren.

### Project Columns

Columns are plain `Item` records with `parent_id = projectId`, distinguished by an `is_project_column` ObjectMeta flag. Color uses the native `Item.color` column.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/api/v2/projects/{id}/columns` | List all columns for a project, ordered by position. Each column includes embedded `items[]` by default. Use `?include_items=false` for columns-only (header row). | "list project columns", "show columns", "project table headers", "view board columns" | — |
| POST | `/api/v2/projects/{id}/columns` | Create a new column (body: name* 1–255 chars, color? hex string). Position auto-assigned to end. Returns 201 with new column. | "add column", "create project column", "new board column" | — |
| PATCH | `/api/v2/projects/{id}/columns/{columnId}` | Update a column's name and/or color (body: name?, color?). | "rename column", "change column color", "update column" | — |
| DELETE | `/api/v2/projects/{id}/columns/{columnId}` | Archive a column; child items are reparented to the project root automatically. | "delete column", "archive column", "remove board column" | — |
| POST | `/api/v2/projects/{id}/columns/{columnId}/reposition` | Move a column to a new 0-based position (body: position*). Clamped to valid range; siblings renumber. | "reorder columns", "move column", "drag column to position" | — |
| POST | `/api/v2/projects/{id}/columns/{columnId}/duplicate` | Duplicate a column with all its child items. | "duplicate column", "copy column", "clone board column" | — |
| PUT | `/api/v2/projects/{id}/columns/{columnId}/move` | Nest one column under another (body: parent_id*). Circular-reference prevention enforced. | "nest column", "move column under", "reparent column" | — |

Column shape: `id`, `name`, `color` (hex or null), `position` (0-based), `parent_id`, `status`, `number_of_children`, `created_at`, `updated_at`, `items[]` (embedded by default).

Item shape within a column: `id`, `name`, `status`, `due` (YYYY-MM-DD or null), `position`, `color`, `assignee_id_cache`, `number_of_children`.

### Process Rules

Automation rules on columns. Fire when an item's `parent_id` changes to a rule-bearing column (via move, indent, or outdent). Failures are logged but do not block the move.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/api/v2/projects/{id}/columns/{columnId}/process-rules` | List automation rules on a column. | "list rules", "show automation rules", "column rules" | — |
| POST | `/api/v2/projects/{id}/columns/{columnId}/process-rules` | Create an automation rule (body: rule_type*, config*). Returns 201. | "add automation rule", "create process rule", "automate column" | — |
| PATCH | `/api/v2/process-rules/{id}` | Update a process rule (body: rule_type?, config?, enabled?). All fields optional. | "update rule", "disable rule", "toggle automation" | — |
| DELETE | `/api/v2/process-rules/{id}` | Delete a process rule permanently. | "delete rule", "remove automation rule" | — |

Process rule `rule_type` values and `config` shapes:
- `assign` — `{ "user_id": integer }` — assigns user to item on entry
- `status` — `{ "status": "completed" }` — sets item status on entry
- `hashtag` — `{ "tag": "urgent" }` — applies label to item on entry
- `due_date` (relative) — `{ "mode": "relative", "days": integer }` — sets due to today + N days
- `due_date` (absolute) — `{ "mode": "absolute", "date": "YYYY-MM-DD" }` — sets specific due date

Process rule fields: `id`, `item_id` (the column's item ID), `rule_type`, `config` (JSON object), `enabled` (boolean), `created_at`, `updated_at`.

### Team Headlines

Only available for teams using the EOS framework.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/headlines` | List active headlines (params: page, per_page). Active = no expiration AND created within 7 days, OR expires_at > today. When expires_at is set, only expiration matters. | "show headlines", "team headlines", "what's new", "announcements" | `/level-10-meeting?team={id}` |
| POST | `/teams/{id}/headlines` | Create headline (body: text*, expires_at?) | "add headline", "new headline", "share update", "post announcement" | `/level-10-meeting?team={id}` |
| PATCH | `/teams/{id}/headlines/{headline_id}` | Update headline (body: text?, expires_at?). Creator or team admin only. | "update headline", "edit headline", "change headline" | `/level-10-meeting?team={id}` |
| DELETE | `/teams/{id}/headlines/{headline_id}` | Archive headline (soft delete — sets expires_at to today, immediately hidden). Creator or team admin only. | "delete headline", "remove headline", "archive headline" | — |
| GET | `/teams/{id}/headlines/history` | The caller's own headlines for this team, INCLUDING expired, newest-created-first, paginated — no expiration/recency filter (unlike the active list) and scoped to the caller. Powers the L10 meeting "history"/rewind panel. | "my headline history", "past headlines", "headline rewind" | `/level-10-meeting?team={id}` |
| POST | `/teams/{id}/headlines/{headline_id}/attachments` | Upload a file to a headline (multipart: file*, name?, description?). Max 4.5 MB. Headline creator or team admin only. Returns FileAttachment — `permanent_url` is **absent** for headline materials (unlike item/rock/page attachments). | "attach file to headline", "upload headline attachment" | — |
| POST | `/teams/{id}/headlines/{headline_id}/links` | Add a link to a headline (body: url* — http(s), bare domain normalized to https://; title?; status_words? — ≤255 chars, tracker state text). Headline creator or team admin only. Returns LinkAttachment. | "add link to headline", "attach URL to headline" | — |
| PATCH | `/teams/{id}/headlines/{headline_id}/materials/{material_id}` | Update a headline LINK in place (body: url?, title?, description?, status_words? — `null`/blank clears; ≥1 updatable key required). **Not** `PATCH /links/{id}` — headline materials use a separate ObjectMaterial id space from item links. Headline creator or team admin only. | "edit headline link", "update headline link status" | — |
| DELETE | `/teams/{id}/headlines/{headline_id}/materials/{material_id}` | Remove a file or link from a headline (deletes the join row and the underlying Document/S3 object or LinkedUrl). Headline creator or team admin only. | "delete headline attachment", "remove file from headline" | — |
| GET | `/teams/{id}/headlines/{headline_id}/materials/{material_id}/download` | 302 redirect to a 5-minute pre-signed S3 URL for a headline FILE material. 400 if the material is a link, not a file. Any team member who can view the headline. | "download headline file" | — |

Headline fields: `id`, `text`, `creator` (UserSimple), `expires_at` (YYYY-MM-DD | null), `created_at`, `updated_at`.

HeadlineCreateRequest: `text` (string, required), `expires_at` (YYYY-MM-DD, optional — if omitted, headline visible for 7 days from creation).

HeadlineUpdateRequest: `text` (string), `expires_at` (YYYY-MM-DD). At least one field required.

### EOS Level 10 (L10)

EOS-friendly URL aliases for the team weekly board. These endpoints return the same data as their generic V2 counterparts but use Level 10 terminology. Only available for EOS teams.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/l10/todos` | List L10 to-dos (alias for `GET /teams/{id}/items/next`; params: page, per_page, q, all) | "show L10 to-dos", "L10 todos", "weekly to-dos" | `/level-10-meeting?team={id}` |
| GET | `/teams/{id}/l10/done` | List completed L10 to-dos (alias for `GET /teams/{id}/items/done`; params: page, per_page, q, all). Default: completed within 7 days. `all=true` for older. | "show L10 done", "completed to-dos", "L10 completed" | `/level-10-meeting?team={id}` |
| GET | `/teams/{id}/l10/issues` | List L10 issues (alias for `GET /teams/{id}/items/blocked`; params: page, per_page, q) | "show L10 issues", "IDS list", "L10 blockers" | `/level-10-meeting?team={id}` |
| GET | `/teams/{id}/l10/parked` | List L10 parking lot (alias for `GET /teams/{id}/items/parked`; params: page, per_page, q) | "show L10 parking lot", "L10 parked", "parked items" | `/level-10-meeting?team={id}` |
| GET | `/teams/{id}/l10/headlines` | List L10 headlines (alias for `GET /teams/{id}/headlines`; params: page, per_page) | "show L10 headlines", "L10 announcements" | `/level-10-meeting?team={id}` |
| POST | `/teams/{id}/l10/todos` | Create L10 to-do (body: name*, description?, due?). Status=next, due defaults to 7 days. | "add L10 to-do", "new to-do", "create L10 todo" | `/items/{item_id}` |
| POST | `/teams/{id}/l10/issues` | Create L10 issue (body: name*, description?, due?). Status=blocked. | "add L10 issue", "raise issue", "new IDS item" | `/items/{item_id}` |
| POST | `/teams/{id}/l10/headlines` | Create L10 headline (alias for `POST /teams/{id}/headlines`; body: text*, expires_at?) | "add L10 headline", "new L10 headline" | `/level-10-meeting?team={id}` |
| POST | `/teams/{id}/l10/done` | Create item directly in the Done column (body: name*, description?). Sets status=done (realized + completed now) and on_weekly=true. | "add L10 done item", "log a done directly", "create completed L10 item" | `/items/{item_id}` |
| POST | `/teams/{id}/l10/parked` | Create item directly in the Parking Lot column (body: name*, description?). Sets status=parked (`#parkinglot`) and on_weekly=true. No due date. | "add L10 parking lot item", "create parked item directly" | `/items/{item_id}` |
| GET | `/teams/{id}/l10/headlines/history` | The caller's own headlines for this team, including expired, newest first, paginated (alias for `GET /teams/{id}/headlines/history` — see Team Headlines). | "L10 headline history", "my past L10 headlines" | `/level-10-meeting?team={id}` |
| PUT | `/teams/{id}/l10/todos/{item_id}` | Move item to L10 to-dos. Sets status=next, auto-sets due to 7 days if null. Alias for `PUT /teams/{id}/items/next/{item_id}`. | "move to L10 to-dos", "make it a to-do", "prioritize in L10" | `/items/{item_id}` |
| PUT | `/teams/{id}/l10/done/{item_id}` | Mark L10 item as done. Sets status=done, records completion. Alias for `PUT /teams/{id}/items/done/{item_id}`. | "mark L10 done", "complete L10 to-do", "L10 done" | `/items/{item_id}` |
| PUT | `/teams/{id}/l10/issues/{item_id}` | Move item to L10 issues. Sets status=blocked. Alias for `PUT /teams/{id}/items/blocked/{item_id}`. | "move to L10 issues", "flag as issue", "IDS this" | `/items/{item_id}` |
| PUT | `/teams/{id}/l10/parked/{item_id}` | Park L10 item. Sets status=parked. Alias for `PUT /teams/{id}/items/parked/{item_id}`. | "park L10 item", "move to parking lot", "shelve in L10" | `/items/{item_id}` |
| DELETE | `/teams/{id}/l10/items/{item_id}` | Remove item from L10 board (sets on_weekly=false, keeps item). Alias for `DELETE /teams/{id}/items/{item_id}`. | "remove from L10", "take off L10 board", "drop from L10" | — |
| GET | `/teams/{id}/l10/quick-wins` | Fetch contextual coaching articles from MasteryMaps based on subscriber persona and team framework. Always returns 200 — empty array if no articles available (persona=1, non-EOS/OKR framework, or external API failure). | "quick wins", "coaching articles", "L10 tips", "team coaching" | — |

#### L10 / Quarterly Meeting Ratings

"Conclude" scores attendees give a meeting (1–10). L10 rates weekly meetings; the parallel **Quarterly Meeting** endpoints (`/teams/{id}/quarterly/meeting-ratings...`) rate the quarterly meeting instead — same shapes, keyed by `{year, quarter}` in place of a week.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/l10/meeting-ratings` | Per-attendee L10 scores for a week (param: date? — any date in the target week, Monday-normalized; default current week). Any team member. Returns `MeetingRatingConclude`. | "L10 meeting score", "conclude ratings", "weekly meeting score" | `/level-10-meeting?team={id}` |
| GET | `/teams/{id}/l10/meeting-ratings/history` | Weekly per-attendee score grid + team averages + stat-tile aggregates over the last N weeks (param: weeks? — 1–52, default 12). Any team member. Returns `MeetingRatingHistory`. | "L10 rating history", "meeting score trend", "weekly rating history" | `/level-10-meeting?team={id}` |
| PUT | `/teams/{id}/l10/meeting-ratings/{userId}` | Record/replace an attendee's 1–10 score for a week (body: stars* — 1–10, date? — defaults current week). One score per attendee per week, latest write wins. Self-recording allowed for any attendee; recording someone else's score is team-admin only. | "rate L10 meeting", "record attendee score", "score this week's meeting" | — |
| GET | `/teams/{id}/l10/rating-changes` | Full append-only audit trail of rating writes across BOTH write paths (admin meeting-ratings and self-service weekly-ratings) — actor, attendee, target week, prior/new value, source, write time; oldest-first, immutable, team-scoped. Team admin only (403 for others). | "rating change history", "meeting score audit log", "who changed this rating" | — |
| GET | `/teams/{id}/quarterly/meeting-ratings` | Per-attendee Quarterly-meeting scores for a quarter (params: year?, quarter? 1–4; default current quarter). Any team member. | "quarterly meeting score", "quarterly conclude ratings" | `/team-rhythm-quarterly` |
| GET | `/teams/{id}/quarterly/meeting-ratings/history` | Per-quarter score grid + averages + aggregates over the last N quarters (param: quarters? — 1–20, default 4). Any team member. | "quarterly rating history", "quarterly meeting score trend" | `/team-rhythm-quarterly` |
| PUT | `/teams/{id}/quarterly/meeting-ratings/{userId}` | Record/replace an attendee's 1–10 score for a quarter (body: stars* — 1–10, year?, quarter?). Same self/admin rule as the L10 version. | "rate quarterly meeting", "score this quarter's meeting" | — |

MeetingRatingConclude fields: `week_of` (date), `goal` (integer — on-goal threshold), `average` (number|null, 1 decimal), `rated_count`, `attendee_count`, `attendees` (MeetingRatingAttendeeScore[]).

MeetingRatingHistory fields: `goal`, `empty` (boolean — no scores in range), `weeks` (MeetingRatingHistoryWeek[], most recent first), `attendees` (`[{ user_id, name }]`), `last_meeting` (`{ week_of, average, rated_count, attendee_count }` | null), `range_average` (number|null), `meetings_at_goal` (integer). Quarterly variant is the same shape keyed by quarter instead of week.

QuickWinsArticle fields: `id` (integer), `headline` (string), `subheadline` (string | null), `thumbnail_url` (string | null), `type` (string, e.g. "Video How To"), `body` (string — HTML), `link_text` (string | null), `video_url` (string | null).

### Team Activity Logs

Team membership change audit trail. Any team member can view.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/activity-logs` | List membership change events (params: page, per_page). Actions: member_added, member_removed, role_changed. | "team activity", "audit log", "membership changes", "who joined" | — |

ActivityLog fields: `id`, `action` ("member_added" | "member_removed" | "role_changed"), `target_user` (UserSimple), `actor` (UserSimple), `details` (string), `created_at`.

### Team Labels

Team-scoped colored labels. Any member can view; admin-only for create/update/delete. A team label is **local to its own team by default** — descendant teams see it only when the owning team turns on `shared_with_descendants`.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/labels` | List team labels (paginated). Includes labels shared down from ancestor teams — each row carries `inherited`, `source_team_id`, and `shared_with_descendants`. | "show labels", "team labels", "list tags" | — |
| POST | `/teams/{id}/labels` | Create label (body: name*, color?). Admin-only. Name max 50 chars; duplicate names are allowed — posting a name the team already uses returns 201 with a new id, not 422. Derive any "you already have a label named X" warning from the existing list, and still allow the create. Color hex `#xxxxxx`. | "create label", "add label", "new tag" | — |
| PATCH | `/teams/{id}/labels/{label_id}` | Update label (body: name?, color?, shared_with_descendants?). Owner-team admin only — an admin of a descendant team gets 403. `shared_with_descendants` applies to team labels only. Setting it to `false` immediately strips the label from every descendant-team item; the owner team's items keep it. | "update label", "rename label", "change label color", "share label with sub-teams", "stop sharing label" | — |
| DELETE | `/teams/{id}/labels/{label_id}` | Delete label (permanent). Admin-only. Removes the label from the owner team's items **and** every descendant team's items, whatever the current sharing state. | "delete label", "remove label", "remove tag" | — |
| GET | `/teams/{id}/labels/{label_id}/usage` | What the label is currently attached to, for an impact warning before un-sharing or deleting. Owner-team admin only. Returns `{ "items": [{ "id", "title", "team_id" }], "roadmap_lanes": [{ "roadmap_id", "team_id", "name" }] }`. | "what uses this label", "label usage", "what will I lose if I delete this label" | — |
| PATCH | `/teams/{id}/labels/reorder` | Persist a new display order for the team's own custom labels (body: label_ids*). Admin only. See main Team Labels section above for details. | "reorder labels", "rearrange team labels" | — |

Label fields: `id`, `name`, `color` (hex string), `shared_with_descendants` (boolean — default `false`; `true` makes the label available to descendant teams), `inherited` (boolean — `true` when the row belongs to an ancestor team rather than this one), `source_team_id` (integer | null — the team that owns the label; `null` when local), `created_at`.

**Sharing model**: descendants only — children, grandchildren, and so on. Sharing never reaches siblings, ancestors, or a team in another organization. Roadmap swimlanes name their labels in `lane_label_ids` inside the `json_content` of a type-17 `custom_contents` record; that is the key the usage endpoint reads.

### Team Integrations

Webhook integrations (Slack/Discord). Admin-only for all operations.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/integrations` | List configured integrations (admin-only, paginated) | "show integrations", "list webhooks", "team integrations" | — |
| POST | `/teams/{id}/integrations` | Create or update integration (body: type*, webhook_url*, name?). Admin-only. Upsert: one per type per team. | "add integration", "connect Slack", "set up webhook" | — |
| PATCH | `/teams/{id}/integrations/{integration_id}` | Update integration (body: name?, webhook_url?). Admin-only. | "update integration", "change webhook", "update Slack" | — |
| DELETE | `/teams/{id}/integrations/{integration_id}` | Delete integration (permanent). Admin-only. | "delete integration", "remove webhook", "disconnect Slack" | — |

Integration fields: `id`, `type` ("slack" | "discord"), `name`, `webhook_url`, `enabled` (boolean), `created_at`, `updated_at`.

### Team Logo

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| POST | `/teams/{id}/logo` | Set team logo URL (body: logo_url* — must be `https://cdn.filestackcontent.com/` URL). Admin-only. Upserts (replaces previous). | "upload logo", "set team logo", "change team image" | — |
| DELETE | `/teams/{id}/logo` | Remove team logo. Admin-only. Idempotent (200 even if no logo). | "remove logo", "delete team logo", "clear team logo" | — |

Response: `{ data: { logo_url: "https://cdn.filestackcontent.com/..." | null } }`. Errors: 403 (non-admin), 404 (team not found), 422 (invalid URL — POST only).

### L10 Meeting Organizer

Endpoints supporting the L10 Meeting Organizer page (Team Weekly). All under `/teams/{id}/l10/`.

#### Weekly Focus (Rally Cry)

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/l10/weekly-focus` | Get current + previous weekly focus entries (params: date — YYYY-MM-DD) | "show rally cry", "weekly focus", "what's the focus", "team rally cry" | `/level-10-meeting?team={id}` |
| POST | `/teams/{id}/l10/weekly-focus` | Set weekly focus for a date (body: focus_name*, date*). Admin only. | "set rally cry", "set weekly focus", "new rally cry" | `/level-10-meeting?team={id}` |

GET response: `{ data: { id, weekly_focus, created_for, previous_weekly_focus: [{ id, created_for, focus_name, average_rating }] } }`.
POST response (201): `{ data: { id, focus_name, created_for } }`.

#### Weekly Notes

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/l10/weekly-notes` | Get current + previous meeting notes | "show meeting notes", "weekly notes", "L10 notes" | `/level-10-meeting?team={id}` |
| POST | `/teams/{id}/l10/weekly-notes` | Create a meeting note (body: title*, body*, json_content*). Admin only. HTML body sanitized server-side. | "add meeting note", "new weekly note", "create L10 note" | `/level-10-meeting?team={id}` |
| PATCH | `/teams/{id}/l10/weekly-notes/{note_id}` | Update a meeting note (body: title?, body?). Admin only. | "update meeting note", "edit weekly note" | `/level-10-meeting?team={id}` |
| DELETE | `/teams/{id}/l10/weekly-notes/{note_id}` | Delete a meeting note. Admin only. | "delete meeting note", "remove weekly note" | `/level-10-meeting?team={id}` |

GET response: `{ data: { current: { id, title, body, json_content, creator_id, created_at, updated_at }, previous: [same shape] } }`.
POST response (201): Created note in `data` envelope. DELETE: 204 No Content.

#### Wins

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/l10/wins` | Get team wins for a date range (params: date — YYYY-MM-DD). | "show wins", "team wins", "what did we win", "victories" | `/level-10-meeting?team={id}` |
| POST | `/teams/{id}/l10/wins` | Create a win (body: name*, win_type* ["personal"\|"professional"], win_date* [YYYY-MM-DD], description?). Member auth. user_id set from auth token. | "add win", "create win", "log a win", "new win" | `/level-10-meeting?team={id}` |
| PATCH | `/teams/{id}/l10/wins/{win_id}` | Update a win (body: name?, win_type?, win_date?, description?). Owner or admin only. | "update win", "edit win", "change win" | `/level-10-meeting?team={id}` |
| DELETE | `/teams/{id}/l10/wins/{win_id}` | Delete a win. Owner or admin only. Returns 204. | "delete win", "remove win" | `/level-10-meeting?team={id}` |

Response (GET): `{ data: { wins: [{ id, name, description, win_type, win_date, user: { id, full_name }, created_at }] } }`. `win_type`: "professional" or "personal".

Response (POST 201, PATCH 200): `{ data: { win: { id, name, description, win_type, win_date, user: { id, full_name }, created_at } } }`.

Response (DELETE): 204 No Content. Errors: 403 if not owner and not admin.

#### Documents

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/l10/documents` | List team documents (paginated). Returns `material_category_id` per document. | "show documents", "team docs", "team files", "list documents" | `/level-10-meeting?team={id}` |
| POST | `/teams/{id}/l10/documents` | Upload a document (multipart form data: file*, name*, material_category_id?, description?). Member auth. | "upload document", "add team file", "new document" | `/level-10-meeting?team={id}` |
| PATCH | `/teams/{id}/l10/documents/{doc_id}` | Update document metadata (body: name?, material_category_id?, description?). Admin/owner only. | "update document", "rename document" | `/level-10-meeting?team={id}` |
| DELETE | `/teams/{id}/l10/documents/{doc_id}` | Delete a document. Admin/owner only. | "delete document", "remove file" | `/level-10-meeting?team={id}` |

Document fields: `id`, `name`, `filename`, `content_type`, `size`, `description`, `material_category_id`, `user_id`, `created_at`. Paginated with `meta`. POST uses multipart form data (not JSON). DELETE: 204.

#### Linked URLs

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/l10/linked-urls` | List linked URLs (paginated) | "show linked urls", "team links", "list urls" | `/level-10-meeting?team={id}` |
| POST | `/teams/{id}/l10/linked-urls` | Create a linked URL (body: title*, full_path*, description?, media_type_code?, material_category_id?). Member auth. | "add linked url", "new team link", "link a url" | `/level-10-meeting?team={id}` |
| PATCH | `/teams/{id}/l10/linked-urls/{url_id}` | Update a linked URL (body: title?, full_path?, description?, media_type_code?, material_category_id?). Member auth. | "update linked url", "edit team link" | `/level-10-meeting?team={id}` |
| DELETE | `/teams/{id}/l10/linked-urls/{url_id}` | Delete a linked URL. Member auth. | "delete linked url", "remove team link" | `/level-10-meeting?team={id}` |

LinkedURL fields: `id`, `title`, `full_path`, `description`, `media_type_code`, `material_category_id`, `user_id`, `created_at`. Paginated with `meta`. DELETE: 204.

#### Shared Links

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/l10/shared-links` | List shared links | "show shared links", "team shared links" | `/level-10-meeting?team={id}` |
| POST | `/teams/{id}/l10/shared-links` | Create a shared link (body: title*, link_string*). **Admin role required** (403 for non-admin). | "add shared link", "share a link", "new shared link" | `/level-10-meeting?team={id}` |
| PATCH | `/teams/{id}/l10/shared-links/{link_id}` | Update shared link title (body: title*). Member auth (non-viewer). | "update shared link", "rename shared link", "edit link title" | `/level-10-meeting?team={id}` |
| DELETE | `/teams/{id}/l10/shared-links/{link_id}` | Delete a shared link. Member auth. | "delete shared link", "remove shared link" | `/level-10-meeting?team={id}` |

SharedLink fields: `id`, `title`, `full_path`, `link_string`, `user_id`, `created_at`. Response in `data` envelope. DELETE: 204.

#### Material Categories

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/l10/material-categories` | List material categories. Any team member. | "show material categories", "document categories", "list categories" | `/level-10-meeting?team={id}` |
| POST | `/teams/{id}/l10/material-categories` | Create material category (body: name*). Member auth (non-viewer). 409 if name already exists. | "create category", "new document category", "add category" | `/level-10-meeting?team={id}` |
| PATCH | `/teams/{id}/l10/material-categories/{cat_id}` | Rename material category (body: name*). Member auth (non-viewer). | "rename category", "update category name" | `/level-10-meeting?team={id}` |
| DELETE | `/teams/{id}/l10/material-categories/{cat_id}` | Delete material category. Creator only (403 for others). Sets material_category_id=null on associated documents and linked URLs. | "delete category", "remove category" | `/level-10-meeting?team={id}` |

MaterialCategory fields: `id`, `name`, `user_id`, `created_at`, `updated_at`. Response in `data` envelope.

#### Weekly Ratings

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/l10/weekly-ratings` | Get all-time average rating, total count, and per-week history (param: weeks — int 1–52, default 12) | "show weekly rating", "team rating", "meeting rating", "how are meetings rated", "rating trend", "meeting rating history" | `/level-10-meeting?team={id}` |
| POST | `/teams/{id}/l10/weekly-ratings` | Submit or update weekly rating (body: rating*, date*). One rating per user per week — upserts. Member auth. | "rate meeting", "submit rating", "rate the week", "rate weekly" | `/level-10-meeting?team={id}` |

GET response: `{ data: { average_rating, total_ratings, weekly_history: [{ week_of, average_rating, count }] } }`. `weekly_history` is ordered most-recent-first; weeks with no ratings appear with `average_rating: null` and `count: 0`. `week_of` is the Monday of the week (YYYY-MM-DD). Use `?weeks=N` to control the number of slots (default 12, max 52).
POST response (201 new, 200 updated): `{ data: { id, stars, created_at } }`.

#### Braindump

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| POST | `/teams/{id}/l10/braindump` | Bulk create items on the board (body: items* — string[], section*). Admin only. Max 50 items per request. | "braindump", "bulk add items", "dump items to board", "brain dump" | `/level-10-meeting?team={id}` |

`section` values: `next`, `blocked`, `parked`.
Response (201): `{ data: { items: [{ id, name }], count } }`.

#### Item Reorder

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| PATCH | `/teams/{id}/l10/reorder` | Reorder organizer items (body: item_ids* — integer[]). Admin only. All IDs must belong to the team and be on the organizer board (is_wow=true). | "reorder items", "rearrange board", "sort items" | `/level-10-meeting?team={id}` |

Response (200): `{ data: { success: true, count } }`.

#### Meeting Settings

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/l10/meeting-settings` | Get meeting day, start time, and section durations | "show meeting settings", "meeting schedule", "L10 settings", "meeting time" | `/level-10-meeting?team={id}` |
| PATCH | `/teams/{id}/l10/meeting-settings` | Update meeting settings (body: meeting_day?, start_time?, section_durations?). Admin only. | "update meeting settings", "change meeting day", "set meeting time", "adjust section times" | `/level-10-meeting?team={id}` |

Response: `{ data: { meeting_day, start_time, section_durations: { transition, scorecard, goals, headlines, done, next, blocked } } }`.
`meeting_day`: 0-6 (Sunday=0). `start_time`: formatted string e.g. `"01:30 PM"`. `section_durations`: values are integers (minutes).

#### Meeting Summary Email

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| POST | `/teams/{id}/l10/meeting-summary` | Send summary email to all team members. Admin only. Fire-and-forget. | "send meeting summary", "email meeting notes", "send L10 summary" | `/level-10-meeting?team={id}` |

Response (200): `{ data: { sent_to, message } }`. Example: `{ "sent_to": 8, "message": "Meeting summary sent to 8 team members" }`.

#### L10 Meeting Organizer Error Responses

All L10 Meeting Organizer endpoints share these error shapes:
```json
{ "error": { "code": "bad_request", "message": "Invalid team ID" } }
{ "error": { "code": "forbidden", "message": "Admin access required" } }
{ "error": { "code": "not_found", "message": "Team not found" } }
{ "error": { "code": "validation_error", "message": "Validation failed", "details": { "<field>": "Required" } } }
```

### Team Lifecycle & Sharing

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| POST | `/teams/{id}/archive` | Archive a team — removes it from every list/selector for everyone. Team lifecycle, not team administration: a Team Admin cannot call it, only a Global Admin or the Org Owner. Works on private teams too. **No unarchive endpoint.** | "archive team", "delete team permanently", "remove team from all lists" | — |
| GET | `/teams/{id}/attachments` | List the team's inline rich-text image attachments, newest first (`{ attachments: FileAttachment[] }`). NOT the team's filed documents (see `GET /teams/{id}/l10/documents`) — these are images pasted mid-sentence into team-owned rich text. 404 (not 403) if the caller can't see the team. | "team attachments", "team inline images" | — |
| POST | `/teams/{id}/attachments` | Upload a file owned by the team (multipart: file*, name?, description?). The upload target for every team-owned rich-text field — L10 notes, seat notes/accountabilities, vision draft fields, core values, EOS fields, review prompts. Response's `permanent_url` is expiry-free (no Authorization header needed) for embedding in saved rich text — `url` is a 1-hour pre-signed link. Max 4.5 MB (413 otherwise). 404 if caller can't see the team. | "upload team attachment", "attach image to team content" | — |
| POST | `/teams/{id}/break-glass` | Grant one person membership of a **private** team from outside it (body: user_id*). Org Owner only (not Global Admin, not Team Admin). Plain membership row — no email sent, in-app notification only, to every team member including the grantee. Target must share an account/org with the caller. 422 if the team isn't private or the target is already a member. | "break glass access", "grant access to private team", "add outsider to private team" | — |
| GET | `/teams/{id}/children` | Direct child teams of this team (the parent's Internal Teams tab data source — the flat `/teams` list is only the viewer's own memberships). Same access as the parent's own detail page (404 on refusal). A private child the viewer doesn't belong to is a **locked** row (Global Admin/Org Owner only — name, member count, team owners; no content) for those roles, absent entirely for anyone else. Archived children absent for everyone. Sorted by name. | "child teams", "sub-teams", "team's children", "internal teams tab" | — |
| POST | `/teams/{id}/make-private` | Convert a standard team to private (body: owner_ids* — integer[], at least 2 distinct current members). Global Admin / Org Owner only, not Team Admin. Response adds `is_private`, `team_owners` to the Team shape. | "make team private", "convert to private team" | — |
| POST | `/teams/{id}/make-standard` | Convert a private team back to standard, restoring its row on the parent's Internal Teams tab. Global Admin / Org Owner only — not Team Admin, not the team's own team owners. Changes discoverability only. 422 if already standard. | "make team standard", "unprivate a team", "convert to standard team" | — |

FileAttachment fields: `type: "file"`, `id` (Document ID), `material_id` (join-row ID — ItemMaterial/GoalMaterial/ObjectMaterial depending on parent; independent id spaces), `name`, `filename`, `content_type`, `size`, `url` (pre-signed, 1h expiry), `permanent_url` (expiry-free, embeddable; present for item/rock/page attachments, absent for headline materials), `user_id`, `created_at`.

### Team Ownership

Team owners are a **private-team-only** concept (a private team must always have owners; a standard team has none). All endpoints below are Org Owner-only unless noted.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/owner-candidates` | This team's members as team-ownership candidates, each flagged `is_team_owner`. A team owner is always a member, so candidates = members. Org Owner only (a Global Admin's locked-row view has no ownership control). Names only, no emails. | "who can be team owner", "team owner candidates" | — |
| POST | `/teams/{id}/owners` | Name a second team owner (body: user_id* — must already be a member) to repair a private team that has fallen to exactly one owner. 422 if the team doesn't have exactly one owner already. Returns `{ data: { team_owners: UserSimple[] } }`. | "add second team owner", "name a team owner" | — |
| POST | `/teams/{id}/owners/transfer` | Transfer team ownership (body: from_user_id*, to_user_id* — must already be a member). Two callers reach this: a team owner (may only name themselves as `from_user_id`) and the Org Owner (may move any named owner). Membership is unaffected — the former owner stays on the team. Returns `{ data: { team_owners: UserSimple[] } }`. | "transfer team ownership", "change team owner" | — |
| POST | `/teams/{id}/leadership-team` | Designate this team as the account's leadership team (one per account; clears any prior designation, enables EOS add-on if applicable, updates Visionary/Integrator seat associations). Requires account admin. Returns `{ data: { team_id, is_leadership_team: true } }`. Team-scoped alternative to `PUT /accounts/{id}/leadership-team` (account-scoped, account-owner-only, both still live). | "designate leadership team", "make this the leadership team" | — |
| DELETE | `/teams/{id}/leadership-team` | Remove the leadership team designation (disables EOS add-on if applicable). Requires account admin. Returns `{ data: { team_id, is_leadership_team: false } }`. | "remove leadership team designation", "undesignate leadership team" | — |

### Team Standing Invitation Notes

A note that pre-fills the personal-note field on invitations. **Precedence: the team's own note › its organization's standing note › nothing.** Absence is always `data: null` — never an empty-bodied note — because a *cleared* note falls through to the organization note while an *empty* one would not (there is no empty note; whitespace-only `body` on write is treated as a clear).

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/standing-invitation-note` | Read this team's standing note, with author + `updated_at`. `data: null` if none. Gate: team admin. | "team's standing invitation note", "show invitation note" | — |
| PUT | `/teams/{id}/standing-invitation-note` | Create-or-replace this team's note (body: body* — ≤500 chars, counted so an emoji is 1 char; line breaks preserved). Empty/whitespace-only clears it (same outcome as DELETE). Author is always the caller. Gate: team admin. | "set team invitation note", "write standing note" | — |
| DELETE | `/teams/{id}/standing-invitation-note` | Clear this team's note (falls through to the org note). Idempotent. Gate: team admin. | "clear team invitation note", "remove standing note" | — |
| GET | `/teams/{id}/organization-standing-invitation-note` | Read the ORG's standing note — `{id}` must be the organization's root team; a non-root team gets the same 403 a non-admin gets (shape not disclosed). Applies to every team in the org that has no note of its own. Gate: admin of the root team. | "organization standing invitation note", "org-wide invitation note" | — |
| PUT | `/teams/{id}/organization-standing-invitation-note` | Create-or-replace the org's note (body: body* — ≤500 chars). Same clear-on-empty semantics. Does not touch any team's own note. Gate: admin of the root team. | "set org invitation note", "write organization standing note" | — |
| DELETE | `/teams/{id}/organization-standing-invitation-note` | Clear the org's note. Idempotent. Leaves every team's own note untouched. Gate: admin of the root team. | "clear org invitation note" | — |
| GET | `/teams/{id}/organization-standing-invitation-note/summary` | Counts behind "N of M teams fall through to the org note" (`{ total_teams, teams_using_organization_note, teams_with_own_note: [{id,name}] }`, sorted by name). One read regardless of org size; archived teams excluded. Gate: admin of the root team. | "invitation note summary", "how many teams use the org note" | — |
| GET | `/teams/{id}/invitation-note-prefill` | Resolves the pre-fill chain for one team → one body + `source` (`{ kind: "team"\|"organization"\|"none", id, name }`). **Call with the OWNING team** of whatever is being shared (project/roadmap), not the inviter's currently-selected team. Gate: anyone who can see the team (not admin-only) — carries no author/timestamp, unlike the admin-only GET above. | "what invitation note applies", "resolve invitation note prefill" | — |
| DELETE | `/teams/{id}/members/{user_id}/invite` | Cancel a pending (unconfirmed) invitation — invalidates the confirmation token, removes the billable account-user row and the acting-team membership. Admin-only, same as inviting. **Only for unconfirmed invitations** — a confirmed member returns 422 (use `DELETE /teams/{id}/members/{user_id}` instead). Idempotent: repeat cancel returns 200 `{ data: { canceled: false, user_id, team_id } }`. | "cancel invitation", "revoke pending invite", "un-invite" | — |

### Team Vision Builder & 3-Year Vision Canvas

AI-assisted vision/mission drafting plus the 3-Year Vision Canvas (a 20-prompt, 5-section grid: Financials, Employees, Customers, Products + Services, Press). The canvas and the Vision Builder wizard present the **same prompts under different field names** — don't conflate the two shapes.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/vision-builder/ai-draft` | The team's most recent raw AI-generated vision/mission draft, stored independently of the saved official vision (`PATCH /teams/{id}/vision` never touches this). Non-admin caller or a vision-inheriting team gets `exists: false` (not an error), same as "never generated". Team admin only for a real draft. | "AI vision draft", "get vision builder draft" | — |
| POST | `/teams/{id}/vision-builder/draft` | Generate a fresh AI draft (body: type* — `draft_vision`\|`draft_mission`; previous_suggestions? — string[], drafts already rejected, replayed so the model doesn't repeat them). `draft_vision` drafts WHAT+WHY from the saved 3-Year Vision Canvas answers; `draft_mission` drafts a one-liner from the saved draft vision. Requires team membership, not admin. Best-effort persists to the ai-draft store. Does NOT save the official vision/mission — that's the `/save` endpoint. 502 if the LLM fails, 503 if not configured. | "generate vision draft", "draft our vision with AI", "AI-generate mission" | — |
| GET | `/teams/{id}/vision-builder/flow` | The static 20-prompt catalog (5 sections × 4 prompts) that drives the wizard, in wizard order. Team ID only scopes to someone who can see the team. | "vision builder prompts", "vision builder flow", "3-year vision canvas questions" | — |
| POST | `/teams/{id}/vision-builder/save` | Commit an edited draft as the official vision or mission (body: type* — `draft_vision`\|`draft_mission`; blob* — `{description, purpose}` for vision, `{name}` for mission). On an EOS team, `draft_mission` writes to the EOS core focus purpose instead of the plain mission (blank name leaves it alone). Team admin only; 403 if the team inherits its vision from a parent (edit the parent instead). | "save vision draft", "save AI vision as official", "commit vision builder draft" | — |
| GET | `/teams/{id}/vision-builder/status` | Per-step completion flags (`canvas_done`, `draft_vision_done`, `draft_mission_done` — true once a step's blob holds anything) plus the team's `framework` (lowercased, defaults `okr`), so the wizard can resume and label steps per-framework. Requires team membership. | "vision builder progress", "vision builder status" | — |
| GET | `/teams/{id}/vision-canvas` | The full 5-row × 4-prompt grid merged with saved answers, plus `canEdit` (computed by the same rule PUT enforces). A vision-inheriting team reads the OWNING team's canvas — `visionTeamId` names it, and writes must target that team; `canEdit` is always false in an inheriting context. `exists: false` until a non-empty canvas is saved. Requires team membership. | "show vision canvas", "3-year vision canvas", "get vision canvas answers" | — |
| PUT | `/teams/{id}/vision-canvas` | Full-replacement save of canvas answers (body: answers* — object keyed by prompt id `"371"`–`"390"`, string values). Every save marks the canvas complete and mirrors prompts 371 (revenue) and 372 (profit) into the team's EOS 3-Year Picture. Edit rule: Visionary seat holder, Integrator seat holder, or team admin — **all evaluated on THIS team**, so a subteam admin is refused. 403 if the team inherits its vision (save to `visionTeamId` instead). | "save vision canvas", "fill in 3-year vision canvas", "update vision canvas answers" | — |

VisionCanvas fields: `teamId` (the requested team), `visionTeamId` (the team that actually owns the canvas after inheritance resolution — target writes here), `isInheritingParentVision`, `parentTeamId` (integer | null), `exists` (boolean), `title`, `rows` (5 × `{ id, label, prompts: [{ id, label, hint, answer: string|null }] }`).

Standing-invitation-note fields (`StandingInvitationNote`): `body` (≤500 chars, line breaks preserved), `author` (StandingInvitationNoteAuthor | null — null when the last author no longer resolves), `updated_at` (ISO datetime | null).

InvitationNotePrefill fields: `body` (string | null), `source` (`{ kind: "team"|"organization"|"none", id: integer|null, name: string|null }`).

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/users/me` | Authenticated user (includes api_token, default_team, current_team). Response wrapped in `{ data: { ... } }`. `current_team` reflects the team last set via `PATCH /users/me/team-context` (was always null before 2026-03-13 API fix). Optional param: `?include=access` enriches `default_team` and `current_team` with `access_level` object (`is_admin`, `designation`, `seats_owned`) plus `is_leadership_team` and `framework` — use for LLM/AI context needing role awareness. | "who am I", "my profile", "my token", "my API key", "my role", "my access level", "am I admin" | `/customize` |
| GET | `/users/search` | Search users (params: q* — min 2 chars, page, per_page). Searches login, email, first_name, last_name. Returns active users visible to current user. | "find user", "search people", "look up user" | — |
| GET | `/users/{id}` | User profile (no api_token). Returns UserPublic. | "show user", "user profile", "who is this" | `/users/{id}` |
| GET | `/users/{id}/items` | User's items (requires same-team membership; params: page, per_page, q, status) | "show their tasks", "user's items", "what's assigned to them" | `/users/{id}` |
| GET | `/users/{user_id}/stats` | User profile stats (supports `me` as ID; requires shared team membership) | "show stats", "user stats", "profile stats", "how am I doing" | `/users/{user_id}` |
| GET | `/users/{user_id}/measurables` | User scorecard metrics with periodic data (params: period?, year?, active_only?; requires shared team membership) | "show measurables", "scorecard", "metrics", "KPIs" | `/users/{user_id}` |
| GET | `/users/{user_id}/rocks` | Quarterly rocks this person OWNS across every team — rocks they're ASSIGNED to (authorship alone doesn't count) plus their own personal team-less rocks. 1-Year Goals never appear here. Params: year?, quarter? (1–4, narrows year), page, per_page; requires shared team membership — a "Just me" personal rock is withheld from everyone but its owner. Accepts `me`. See UserRock fields below. | "show rocks", "my rocks", "goals", "quarterly priorities" | `/users/{user_id}` |
| GET | `/users/me/rocks` | Same as `GET /users/{user_id}/rocks` with the caller's own id — `me` is a static path segment, routed ahead of the dynamic `{user_id}` one. | "my rocks", "show my rocks" | — |
| POST | `/users/me/rocks` | Create a personal rock owned by the caller (body: name*, description?, year?, quarter? (1–4), achieve_by? — explicit date, overrides year/quarter). Private ("Just you") from creation — audience is not a create-time choice, open it later via `PUT /rocks/{id}/audience`. Due at end of year/quarter unless `achieve_by` given. | "create personal rock", "add my own rock", "new personal goal" | — |
| POST | `/users/{user_id}/rocks` | Assign a personal rock to a direct or indirect report — `{user_id}` names the rock's new OWNER, the caller is recorded as its ASSIGNER (reversed from every other `/users/{user_id}/...` route). `me` is refused with 403 — use `POST /users/me/rocks` for your own. Body: name*, description?, achieve_by? (wins over year/quarter), year?, quarter? (1–4), milestones? (array of `{name*, due?}`, created in order, owned by the OWNER not the assigner, all-or-nothing validated before any write), one_on_one_id? (integer\|null — tracks the rock in a 1:1 from creation; all three checks — real 1:1, caller can edit it, OWNER is a participant — fail as **404, never 403**, so the response can't be used to enumerate someone else's sessions). Caller must sit above `{user_id}` on the Accountability Chart (any depth, same org) — checked before the body, so a caller with no standing learns nothing. Rock is private from creation (no audience). Assigner gets `can_set_status: true` but `can_edit: false` — status-flip only; the owner keeps every edit right and all ongoing 1:1-align rights. Returns 201 with the same `UserRock` shape the rocks feed uses. | "assign rock to report", "give a rock to someone", "hand a rock to a direct report", "delegate a rock" | — |
| GET | `/users/{user_id}/goals` | 1-Year Goals this person OWNS across every team — their own personal annual goals plus company 1-Year Goals ASSIGNED to them (authorship/team membership alone doesn't count). Quarterly rocks never appear here. Param: year? (filters by due date), page, per_page. Accepts `me`. Requires shared team membership; a personal goal is withheld from everyone but its owner, no manager/admin escalation. | "show user goals", "their yearly goals", "1-year goals for person" | `/users/{user_id}` |
| GET | `/users/{user_id}/feedback` | User feedback/High5s (params: direction* — "given" or "received", page, per_page; requires shared team membership) | "show feedback", "High5s", "kudos", "recognition" | `/users/{user_id}` |
| GET | `/users/check-login` | Check if login/handle is available (params: login* — 3-40 chars) | "check login", "is handle available", "username taken" | — |
| GET | `/users/me/direct-reports` | People reporting to the caller on the Accountability Chart — read from seats (owner of a non-archived seat whose parent is one of the caller's own seats), not team membership. Params: team_id* (any team in the org; resolved to that org's root), scope? — literal `downline` returns the caller's WHOLE downline at any depth (traversing vacant seats, excluding the caller) instead of one level. No standing in that org → empty list, not an error. | "my direct reports", "who reports to me", "my downline", "my team on the org chart" | — |
| GET | `/users/me/upcoming-deadlines` | Timeline view: items due in a date window, plus day-plan items when the window includes today+. Combines three sources (assigned to caller, authored by caller, on caller's day plan) with the same priority-tag and `#parkinglot` filters as `GET /day-plans/today` (day-plan-sourced items only). Params: start_date? (default today), end_date? (default start_date+30d), include_done? — literal string `"true"` includes past-realized items from the due-date sources only (day-plan items unaffected); any other value = excluded. Each item carries `custom_labels` (requester's personal labels + team labels they're entitled to see; no deprecated `tags` twin here). | "upcoming deadlines", "timeline view", "what's due across sources", "my deadlines this month" | `/prioritizer/timeline` |
| PATCH | `/users/{id}/preferences` | Set a user's subscriber persona (body: persona* — one of `visionary`, `integrator`, `manager`, `delegate`, `doer`, `partner`, `undecided`). Account admins can update any user in their account; a user can update their own. Returns `{ data: { preferences: { subscriber_persona } } }`. | "set persona", "change subscriber persona", "update user persona" | — |
| GET | `/users/me/preferences` | Get full preferences (profile, notifications, timezone, startup view, API token, subscriber_persona, day-plan sorting/view preferences) | "my preferences", "settings", "notification settings" | `/customize` |
| PATCH | `/users/me/preferences` | Update preferences (body: login?, first_name?, last_name?, time_zone?, notifications?, startup_view_code?, preferred_team_id?, secondary_email?, update_frequency?, unsubscribe_all?, slack_username?, day_plan_sorting? — int 0–4: 0=priority, 1=result, 2=due, 3=creator, 4=quadrant; day_plan_show_settings? — `everything`/`must`/`not deferred and completed`; today_index_view? — `#list_view`/`#quadrant_view`). Partial update — only sent fields change. Notification booleans represent the logical ON/OFF value (true=on); the API inverts from the raw DB `should_suppress` field. Returns full preferences envelope including all day-plan fields. | "update preferences", "change settings", "change timezone", "toggle notifications", "turn off digest", "turn on notifications", "change day plan sorting", "switch to quadrant view", "set planner view" | `/customize` |
| GET | `/users/me/progress` | Personal progress — strategy metrics, practice scorecard, streak totals (params: period? — week/month/quarter) | "my progress", "practice streak", "how am I doing", "scorecard" | — |
| GET | `/users/me/integrations` | Get third-party integration selections (task_management, sales_revops, team_communication) | "my integrations", "connected apps", "integration settings" | `/customize` |
| PATCH | `/users/me/integrations` | Update integration selections (body: task_management?, sales_revops?, team_communication?). Set to null to disconnect. | "update integrations", "connect app", "disconnect integration" | `/customize` |
| POST | `/users/me/password` | Change password (body: current_password?, password*, password_confirmation*). current_password required unless OAuth-only user. | "change password", "update password", "new password" | `/customize` |
| PATCH | `/users/me/team-context` | Set the authenticated user's active team (body: team_id*). Returns `{ data: { id, name } }` of the newly active team. Idempotent. Errors: 400 (malformed body), 401 (unauthorized), 422 (team_id missing/invalid/not a member). | "switch team", "use team", "set active team", "change my team" | — |
| GET | `/users/me/context` | Full organizational context snapshot — user profile, all orgs/teams, strategic data (vision, plans, rocks, measures, projects, todos, issues), and today's day_plan in one call. **For full schema and disambiguation patterns, read `references/user-context-schema.md`.** Use this endpoint when the user references a team by name, asks about data across multiple teams, or needs organizational grounding. | "my context", "full context", "organizational context", "load my context", "everything about my teams", "all my rocks and issues", "my orgs and teams", "session context" | — |
| GET | `/users/me/notifications` | Paginated list of notifications for the authenticated user. Query params: `is_read` (boolean), `is_archived` (boolean, defaults false — archived excluded by default), `subscribeable_type` (string), `since` (ISO timestamp), `page`, `per_page`. | "my notifications", "what's new", "unread notifications", "notification inbox" | — |
| GET | `/users/me/notifications/unread-count` | Fast count of unread, non-archived notifications. Returns `{ "data": { "count": N } }`. | "unread count", "notification badge", "how many notifications", "do I have notifications" | — |
| POST | `/users/me/notifications/mark-all-read` | Mark all notifications as read. Body: `{ "subscribeable_type"?: string, "subscribeable_id"?: number }` — both optional. Omit both to mark all read. Scoped by type marks only that type's notifications. | "mark all read", "clear notifications", "dismiss notifications" | — |
| PATCH | `/users/me/notifications/:id` | Update a single notification. Body: `{ "is_read"?: boolean, "is_archived"?: boolean }`. Returns updated notification. 404 for another user's notification (no data leakage). | "mark notification read", "archive notification", "dismiss notification" | — |
| DELETE | `/users/me/notifications/:id` | Soft-archive a notification (sets `is_archived=true`, never hard-deletes). Returns 204. 404 for another user's notification. | "delete notification", "remove notification", "archive notification" | — |
| GET | `/users/me/activity-feed` | Paginated activity feed events for objects the user subscribes to. Query params: `page`, `per_page`, `since` (ISO timestamp). | "activity feed", "recent activity", "what happened", "feed" | — |
| GET | `/users/me/muted-items` | Paginated list of muted items (items with suppressed notifications) for the authenticated user. | "muted items", "what I've muted", "notification mutes" | — |
| POST | `/users/me/muted-items` | Mute an item (suppress notifications for it). Body: `{ "subscribeable_type": string, "subscribeable_id": number }`. | "mute item", "silence notifications for item", "stop notifications" | — |
| DELETE | `/users/me/muted-items/:id` | Unmute an item. `:id` is the `subscribeable_id` (the item ID), not a row ID. Muted items stored as JSON blob in `object_metas`. | "unmute item", "restore notifications for item" | — |
| GET | `/api/v2/users/me/upcoming-tasks` | Upcoming tasks for the current user across three sources: items assigned to caller (not authored), items authored by caller, and today's day-plan items. Params: `start_date` (YYYY-MM-DD, default today), `end_date` (YYYY-MM-DD, default start_date+30d), `include_done` (string, optional — pass literal `"true"` to include past-realized items from sources 1 and 2; any other value or absent = exclude). Returns `{ items: [...] }`. Sort: day-plan items first, then due ASC (nulls last), then created_at ASC. Excludes #parkinglot items and deferred day-plan actions. `day_plan_date` is non-null only for day-plan source items. Priority-tag filter applied to day-plan-sourced items (source 3): non-active priority-tagged items are excluded. Due-date sources (1 and 2) are unaffected. | "upcoming tasks", "my tasks", "tasks this week", "timeline tasks", "what's due soon", "my upcoming items", "tasks due next week", "show done tasks", "include completed tasks" | `/prioritizer/timeline` |
| POST | `/api/v2/users/me/history` | Record a visited entity. Body: `{ "entity_type": string, "entity_id": integer }`. Upserts `visited_at` if same tuple exists; prunes oldest entries beyond 100. Returns `{ ok: true }`. Valid entity_type values: `Item`, `Rock`, `Measure`, `Project`, `Person`, `Meeting`, `Page`, `Review`. Returns 422 for invalid entity_type. | "record visit", "track visit", "add to history", "mark visited" | — |
| GET | `/api/v2/users/me/history` | Retrieve recent visit history for the authenticated user. Returns up to 50 entries ordered newest-first. Names resolved at read time from entity tables; deleted entities are omitted. Returns `{ history: [{ id, entity_type, entity_id, name, team_name, visited_at }] }`. | "my history", "recently visited", "visit history", "recent items", "what I visited" | — |
| GET | `/api/v2/users/me/onboarding-state` | Returns the authenticated user's onboarding state. Fields: `onboarding_role` ("visionary"\|"integrator"\|"manager"\|null), `total_steps` (int), `completed_steps` (int), `completed_step_names` (string[]), `is_complete` (boolean), `should_show_onboarding` (boolean — true only when flag is set, valid account+team context exists, onboarding not complete, and user qualifies). Wrapped in `{ data: { ... } }`. | "onboarding status", "onboarding progress", "should I show onboarding", "is onboarding complete", "my onboarding role" | — |
| POST | `/api/v2/users/me/onboarding-state/skip` | Permanently dismisses the onboarding banner for the authenticated user. No request body. Returns `{ data: { success: true } }`. Idempotent. After this call, `GET /api/v2/users/me/onboarding-state` returns `should_show_onboarding: false`. | "skip onboarding", "dismiss onboarding banner", "hide onboarding", "don't show onboarding" | — |
| GET | `/api/v2/users/me/inbox` | Items the authenticated user has been assigned by other users (`assignment.user_id = me AND assignment.creator_id != me`). Self-assigned items excluded. Params: `status` (comma-separated V2 statuses, default `not_started,next`), `group_id` (comma-separated team IDs), `page`, `per_page` (default 100). Response envelope: `{ data: [...items], meta: { page, per_page, total, total_pages } }`. Same item shape as `GET /users/{id}/items`. `archived` excluded by default. | "my inbox", "items assigned to me", "what teammates asked me to do", "delegated items", "assigned by others", "inbox" | — |
| GET | `/api/v2/users/me/outbox` | Items the authenticated user has delegated to others (`assignment.creator_id = me AND assignment.user_id != me, active=true`). Params: `status` (comma-separated V2 statuses, default `active,archived,blocked,realized,review`), `group_id` (comma-separated team IDs), `show_all` (boolean — include realized items beyond 30-day window), `start_date`/`end_date` (ISO date range for realized items), `order` (`most_recently_assigned` sorts by assignment `created_at` DESC; `most_recently_updated` sorts by item `feed_updated_at` DESC; default sorts by hashtag priority tier then `assignment.position` ASC), `page`, `per_page` (default 100). Response envelope: `{ data: { ids_of_assignments_without_group_ids: integer[], items: [...OutboxItems] } }`. Each OutboxItem includes `id`, `name`, `status`, `type`, `group_id`, `is_wow`, `stored_ancestor_path`, `feed_updated_at`, `parent`, `assignments[]` (each with `id`, `user_id`, `creator_id`, `position`, `workflow_status_id`, `created_at`, `user`), `last_3_feeds[]`. `ids_of_assignments_without_group_ids` holds assignment IDs where `item.group_id IS NULL` (powers "Track All Under A Team" popup). Priority sort tier: #next → #toppriority/#priority → #1–#4 → #must → unlabeled → realized. | "my outbox", "items I delegated", "items assigned by me to others", "what I asked teammates to do", "delegated tasks", "outbox", "delegated to others" | — |
| POST | `/api/v2/users/me/outbox/reorder` | Reorder outbox items by setting assignment positions. Body: `{ "item_ids": integer[] }` (full ordered list). Returns `{ data: { ok: true } }`. | "reorder outbox", "drag outbox item", "reposition delegated item", "sort outbox" | — |
| POST | `/api/v2/users/me/outbox/filter-by-person` | Outbox narrowed to items delegated to a specific assignee. Body: `{ "user_id": integer }`. Returns same envelope as `GET /api/v2/users/me/outbox`. | "filter outbox by person", "show items assigned to person", "outbox for user", "delegated to person", "outbox filtered by assignee" | — |
| GET | `/users/me/assigned-to-me` | The Personal Planner's **Assigned to Me** tab: everything other people have put on the caller, each row carrying both the work and its assignment. Distinct from `GET /users/me/inbox`, which reads the same assignments under different rules. Self-only (keyed to `me`). Param: `scope` — `visible` (rows with no team, or a non-muted team), `muted` (rows whose team the caller has muted), `all` (default; everything). Not paginated — the **whole** list returns in one response; nothing ages off it; `page`/`per_page` and any other param are silently ignored. Rows are newest-ask-first. **Excludes**: anything the caller assigned to themselves, `TodoList` work, any `KeyResult`/Milestone, no-longer-live asks, completed/archived work, and anything currently sitting in a parking lot (either the L10 Kanban's Park For Later column or the Compass dock's Park for later tab — same state, either surface). **Never excludes** blocked work or work on a team's Issues list. See AssignedToMeRow below. | "assigned to me", "what's been assigned to me", "my asks", "who assigned me this", "assigned to me tab" | `/prioritizer` |
| GET | `/users/me/assigned-to-me/count` | Open-ask count for the Assigned to Me badge (same `scope` param and predicate as the list — can never disagree with `meta.total` on that same scope). Its own endpoint so a client can refresh the badge after an accept/decline without refetching every row. Returns `{ data: { count: integer } }`. | "assigned to me count", "how many things assigned to me", "assigned to me badge" | — |
| PATCH | `/users/me/assigned-to-me/{item_id}` | Accept an ask (body: `{ "accept_state": "accepted" }` — the only value accepted; there is no "un-accept"). `item_id` is the **item's** id, not an assignment id — one piece of work yields at most one row. Only the assignee may accept (403 for the assigner, a manager, or a system admin — not 404, because the assigner knows the ask exists). Idempotent. Returns the updated `AssignedToMeRow`. 404 if there's no live ask on that item for the caller. | "accept assignment", "accept this ask", "say yes to assigned item" | — |
| DELETE | `/users/me/assigned-to-me/{item_id}` | Decline an ask — retires the caller's assignment only; the item itself, its team, board position, other assignees and history are untouched ("not mine", not "gone"). Leaves the list entirely (204, no body). Only the assignee may decline (403 otherwise, same reasoning as accept). Declining an already-declined ask returns 404 (no longer on the list). | "decline assignment", "decline this ask", "say no to assigned item", "not mine" | — |
| GET | `/teams/{id}/open-work` | The My Work **Team** tab (BDD page 974): everything open on the team, whoever it's on, plus the team's roster with each person's open count — `rows`, `roster` and `total` together in one response, so the tab's count line, list and Owner menu can never disagree in one frame. `total` always equals `rows.length` and the sum of every `roster[].open_count`. **No filter params and no paging** — Labels/Owner/Type are render-time predicates in the client; the tab renders one flat list. "Open on this team" is three arms: work whose own `group_id` is the team; work in the team's projects (project → column → item, since a column carries no `group_id`); and work on a 1:1 where **both** participants are team members. A team with nothing open still returns 200 with empty `rows`, `total: 0`, and a full roster of zeros — never 404. See TeamOpenWorkRow/TeamRosterEntry below. | "what's open on this team", "team's open work", "my work team tab", "who has what open on this team" | — |
| POST | `/api/v2/items` | **Extended** create item with optional outbox-friendly fields. All existing `/items` create params supported. New optional params: `assignees` (integer[] — user IDs to assign on create), `with_assignments` (boolean — include created assignments in response), `with_last_3_updates` (boolean — include last 3 activity feeds in response). When neither flag is set, returns legacy bare-item `{ data: <Item> }`. When flags are set, returns `{ data: { item, assignments[], assignees[], last_3_updates[] } }`. Fully backward compatible — callers omitting the new fields see unchanged behavior. | "create item with assignees", "create delegated item", "add task with assignment", "create outbox item" | `/items/{id}` |
| GET | `/items/:id/activity-feed` | Item-scoped activity feed events. Paginated; params: `page`, `per_page`, `since`. Returns 403 (not 404) when user lacks read access. | "item activity", "what happened on this item", "item history", "item feed" | — |
| GET | `/subscriptions` | Lists authenticated user's subscriptions. Query param: `subscribeable_type` (filter). | "my subscriptions", "what I'm subscribed to", "subscriptions" | — |
| POST | `/subscriptions` | Subscribe to an object. Body: `{ "subscribeable_type": string, "subscribeable_id": number }`. Idempotent: returns 200 with existing record if already subscribed, 201 if newly created. | "subscribe", "follow item", "watch item", "get notifications for" | — |
| DELETE | `/subscriptions/:id` | Unsubscribe. Returns 404 for another user's subscription. | "unsubscribe", "unfollow item", "stop following", "stop watching" | — |
| GET | `/communication-trackers` | Returns all 8 scheduled email tracker records for the authenticated user. Not paginated — always exactly 8 records; missing records created on demand. | "email trackers", "communication preferences", "email schedule", "digest settings" | — |
| PATCH | `/communication-trackers/:id` | Toggle email suppression for a tracker. Body: `{ "should_supress": boolean }` (intentional legacy typo — matches DB column name). Recomputes `next_send` after update. | "suppress emails", "turn off digest", "enable digest", "toggle email notifications" | — |

AssignedToMeRow fields: `id` (the item's id — also the accept/decline key), `name` (string | null), `kind` (`"To-Do"` | `"Issue"` — tab vocabulary, not the underlying item type; **`"Milestone"` was removed from this enum on 2026-09-01** — Milestones now belong to a different view and never appear on this list), `source` (`"one_on_one"` | `"project"` | `"level_10"` | `null` — always present, value may be null; what the tab's Type filter groups by; `level_10` is reported for an Issue exactly as for a To-Do since it names *where the work came from*, not what kind of thing it is; `null` = personal work with no board/project/1:1 behind it; when more than one source could apply, precedence is `one_on_one` > `project` > `level_10`), `due` (YYYY-MM-DD | null), `parent` (`{ id, name }` | null — for project work this is the **column**, not the project; see `project` below), `assigner` (`{ id, first_name, last_name, profile_photo_thumb_path }` | null — who made the ask, not who authored the work; null only when unidentifiable, row still returned), `assigned_at` (ISO datetime | null — age is the client's arithmetic; API returns no age value and does no age filtering), `accept_state` (`"new"` | `"accepted"` — declining removes the row, so no third value), `blocked` (boolean — the **assignee** flagged it; distinct from `on_issues_list`), `on_issues_list` (boolean — sits in a team's Issues column, whoever put it there), `issues_list_team` (`{ id, name, path }` | null, populated only when `on_issues_list` — `path` is `"{org root name} / {team name}"`, composed server-side, collapsing to the team name alone when the team is its own org's root), `project` (`{ id, name, path }` | null — `path` is `"{project name} / {column name}"`, composed server-side, collapsing to the project name alone when there's no column or the column is named for its own project; draw the project chip from `path` alone, never concatenate `project.name` + `parent.name` yourself).

TeamOpenWorkRow fields: this is `AssignedToMeRow` with **`owner` added** and the four ask-fields (`assigner`, `assigned_at`, `accept_state`, `blocked`) **dropped** — a team-wide list has no single asker and no accept/decline state. `owner` (`{ id, first_name, last_name, name, profile_photo_thumb_path?, is_viewer }` — the person the row's work is ON; **never null**: where an item names nobody, this is its creator, since the creator owns what they create until they hand it off; `is_viewer` marks the caller's own rows). Otherwise shares `id`, `name`, `kind` (`"To-Do"`\|`"Issue"` — carried for parity but not drawn as a label on this tab; the Issues chip is the only place a row's kind shows), `due`, `source`, `parent`, `project`, `on_issues_list`, `issues_list_team`, and `custom_labels` (`[{id, name, color}]`, always present, `[]` if none — what the tab's Labels filter narrows by) with `AssignedToMeRow` above.

TeamRosterEntry fields: `id`, `first_name`, `last_name`, `name` (composed server-side), `profile_photo_thumb_path`, `open_count` (that person's open count on this team — sums to the feed's `total`), `is_viewer` (true on exactly one entry). Every team member appears, alphabetically, even at `open_count: 0` — there is no "Everyone" entry; that state is the client clearing its selection, not a roster row.

User fields (`/users/me`): `id`, `login`, `email`, `first_name`, `last_name`,
`api_token`, `default_team` (TeamSimple | null), `current_team` (TeamSimple | null — reflects the team last set via `PATCH /users/me/team-context`. Non-null after at least one team-context set call).

With `?include=access`, `default_team` and `current_team` gain: `is_leadership_team` (boolean), `framework` (string), `access_level` (`{ is_admin: boolean, designation: "visionary"|"integrator"|"leadership_team"|"front_line", seats_owned: [{ id, name }] }`). `designation` is derived from seat ownership — not a stored field.

UserPublic fields: `id`, `login`, `email`, `first_name`, `last_name`.

UserSimple fields: `id`, `login`, `first_name`, `last_name`. In 1-on-1 person objects (`persons.person1`, `persons.person2`), also includes `title` (string | null — organizational role from participant's most recently updated non-archived Seat; null if no active Seat).

TeamSimple: `{ id: integer, name: string }`.

UserStats fields: `wins_given`, `wins_received`, `goals_aspired`, `goals_realized`, `actions_done`.

UserMeasurable fields: `id`, `name`, `target_value`, `target_unit`, `owner` (UserSimple), `is_archived`, `values` ([{ date, value, on_track, percent_change }]).

Measurables params: `period` ("week" | "month", default "week"), `year` (default current), `active_only` (default true).

UserRock fields: `id`, `name`, `description` (string | null), `status` (`"active"` | `"on_track"` | `"off_track"` | `"realized"` | `"completed"` | `"dropped"` — derived: `completed` when the rock carries an `actual_achievement`, else `current_state`, falling back to `on_track` for a legacy null row; `active` from creation until first judged; never null), `due_date`, `team` (`{ id, name }` | null — null for a personal/team-less rock), `is_personal` (boolean — true only for a personal rock, the only kind with an audience), `owner` (GoalAssignee | null — null on a team rock; read `team` instead), `viewer_access` (string | null — why the caller can see a personal rock: `owner`\|`person_grant`\|`team_grant`\|`organization_grant`\|`assigner`\|`one_on_one`\|null; always null on a team rock), `can_set_status` (boolean | null — owner or assigner only; NOT derivable from `viewer_access`, e.g. an assigner who also holds a team grant reports `team_grant` there yet still `true` here), `can_edit` (boolean | null — personal-rock field edits, owner only; independent of `can_set_status` — an assigner gets `false` here), `progress_color` (string | null — weekly on/off-track judgement), `milestones_total`, `milestones_completed`, `milestones` (MilestoneResponse[] — the same set `milestones_total` counts; empty array, never placeholder rows), `created_at`.

FeedbackEntry fields: `id`, `message`, `from_user` (UserSimple + profile_photo_thumb_path), `to_user` (UserSimple + profile_photo_thumb_path), `created_at`.

UserPreferences fields: `id`, `profile_photo_thumb_path`, `login`, `first_name`, `last_name`, `email`, `secondary_email`, `time_zone`, `notifications` ({ morning_day_ahead, week_ahead_sunday, end_of_day_digest, weekly_digest_friday, weekly_status_request, daily_status_request, daily_status_request_to_slack, confirmation_link } — all boolean, true=on, false=off; API inverts the raw DB `should_suppress` field so clients read/write logical on/off values directly), `update_frequency` ("once_daily" | "every_change"), `unsubscribe_all`, `startup_view_code`, `startup_view_label`, `preferred_team_id`, `slack_username`, `api_token`, `is_coach`, `subscriber_persona` (integer 1-7, read-only, default 3 = Leadership Team Member).

Notification fields: `id`, `subscription_id`, `subscribeable_type`, `subscribeable_id`, `subscribeable_title`, `body` (HTML string), `is_read` (boolean), `is_archived` (boolean), `sent_at`, `created_at`, `actor` ({ user_id, user_name, user_avatar_url } — all null if no actor can be determined).

Subscription fields: `id`, `subscribeable_type`, `subscribeable_id`, `created_at`.

CommunicationTracker fields: `id`, `email_type_id` (1=end_of_week_digest, 2=end_of_day_digest, 3=mentions, 4=weekly_status_request, 5=item_assigned, 6=daily_status_request, 7=daily_status_request_to_slack, 8=confirmation_link), `email_type_key`, `should_supress` (boolean — intentional legacy typo matching DB column; true=suppressed/off), `next_send`, `last_sent` (nullable).

ActivityFeedEntry fields: `id`, `trackable_type`, `trackable_id`, `verb_clause`, `user_friendly_detail`, `comment_text` (nullable), `comment_id` (nullable), `document_id` (nullable), `progress_id` (nullable), `created_at`, `user` ({ id, name, avatar_url }).

MutedItem fields: `id`, `subscribeable_type`, `subscribeable_id`.

PersonalProgress fields: `targets` ({ rocks_realized_all_time, milestones_realized_all_time, milestones_realized_this_quarter }), `practice_scorecard` ({ days: [{ date, day_name, completed }] }), `practice_totals` ({ all_time, current_streak, longest_streak }).

UserIntegrations fields: `task_management` ({ selected, options }), `sales_revops` ({ selected, options }), `team_communication` ({ selected, options }).

## Third-Party Integrations (Nango)

User-scoped HubSpot / OAuth connection management. All routes require auth. Provider whitelist: `clickup`, `monday`, `hubspot`, `salesforce`, `notion`, `google-sheet`. **The Google slug is `google-sheet` — singular.** Nango's provider registry has no `google-sheets` key, and a wrong slug fails at OAuth time, not at request time. Only HubSpot has a dedicated tickets reader; the others use connect/status/disconnect only — `google-sheet` additionally backs the Measurable sheet binding (see **Team Scorecard Measures**).

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| POST | `/api/v2/nango/connect` | Persist a Nango connection_id after OAuth popup. Body: `provider`*, `connection_id`*. Idempotent — re-connecting returns 201 + `connected: true`. | "connect HubSpot", "link HubSpot account", "save nango connection" | — |
| GET | `/api/v2/nango/status?provider={provider}` | Check if user is connected. Always 200 for authed callers — read `data.connected` and `data.error`. Safe to poll. | "is HubSpot connected", "check integration status", "HubSpot connection status" | — |
| DELETE | `/api/v2/nango/disconnect?provider={provider}` | Disconnect the (user, provider) pair, and make it stick — the disconnect is recorded and honored until that same user reconnects, so every later `GET /nango/status` reports `connected: false`. The remote Nango grant is deliberately **not** revoked, which is why reconnecting needs no fresh OAuth popup. Idempotent; succeeds even when Nango is unreachable. | "disconnect HubSpot", "unlink integration", "remove HubSpot connection" | — |
| GET | `/api/v2/nango/hubspot/tickets?limit&after` | Page the user's HubSpot CRM tickets. Returns `{ id, subject }` per ticket. Last page: `paging: null`. 401 = not connected; 502 = HubSpot unreachable. Lazy-evicts cached token on HubSpot 401/403. | "show HubSpot tickets", "list tickets", "HubSpot CRM tickets", "pick a ticket" | — |

Connection envelope: `{ "data": { "provider": string, "connected": boolean, "error": string|null } }`. Tickets envelope: `{ "data": { "results": [{ "id": string, "subject": string }], "paging": { "next": { "after": string } } | null } }`. Status is always 200 — never 401/5xx for missing token; use `connected` + `error` fields. `POST /connect` validates `connection_id` contains the authenticated user's ID (mismatches → 400). No token ever appears in any response.

**Disconnect is durable.** While a user has an explicit disconnect on record, `GET /nango/status` returns `connected: false` with **`error: null`** — a disconnect is a normal state, not a failure, so don't render it as one — and the provider data endpoints behave exactly as they do for someone who never connected (`GET /nango/hubspot/tickets` → `401 { "error": "HubSpot integration not connected" }`). `POST /nango/connect` is the only thing that clears the record. **An expired credential is not a disconnect**: with no disconnect on record, a cache miss still falls back to Nango, so a stale token recovers with no user action. One exception — `google-sheet` holds its grant at the account level, so disconnect is still a silent no-op for it (200, `connected: false`, nothing changes).

**Linking an Item to a HubSpot ticket**: PATCH `/items/{id}` with `{ "third_party_tracker": { "provider": "hubspot", "external_id": "12345", "name": "Ticket subject" } }`. Clear with `{ "third_party_tracker": null }`. Read back from `GET /items/{id}` — field always present (object or `null`).

## Account Management

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| POST | `/accounts` | Create account / signup (unauthenticated). Body: `login`*, `email`*, `password`*, `password_confirmation`*, `name`?, `framework`? (`eos`,`okr`,`v2mom`,`srt`,`default`; defaults to `okr`). Returns 201 with user+account+team+api_token on success, 422 with field-level `details` on validation failure. Transactional — rolls back entirely on failure. Sends welcome email fire-and-forget. | "create account", "sign up", "new account", "register", "onboard new user" | — |
| PATCH | `/accounts/{id}` | Rename the account AND its Leadership Team together, in one act (body: name* — required, blank/whitespace-only is 422 with no fallback). Renames the caller's OWN account only, never creates a second one — keyed by account id. An organization is not an account (organization-expert). Account admin only. Returns `{ data: { account: {id, name}, team: {id, name} | null } }`. Currently accepts `name` only. | "rename organization", "rename account", "change organization name" | — |
| PUT | `/accounts/{id}/framework` | Set management framework for an account. Body: `framework`* (`eos`,`okr`,`v2mom`,`srt`,`default`). Account owner only. Returns 200 with `{ account_id, framework }`. | "set framework", "change framework", "select management framework" | — |
| POST | `/accounts/{id}/org-owner` | Transfer the Org Owner role (an organization/root-team-level role, addressed by account since the account resolves to exactly one root team — 422 otherwise) to another person (body: user_id*). An organization is not an account (organization-expert). **Caller must be the CURRENT holder of the role, and nobody else** — not even the account owner; once moved, the former holder is no longer offered it either. New holder must be on the account or share an org with the caller. Returns `{ data: { org_owner: UserSimple } }`. | "transfer org owner", "change org owner", "give org owner role to" | — |
| PUT | `/accounts/{id}/leadership-team` | Designate a team as the leadership team for an account. Body: `team_id`* (must belong to account). Account owner only. Returns 200 with `{ account_id, leadership_team_id, previous_leadership_team_id }`. One leadership team per account — designating a new one removes the previous. An organization is not an account (organization-expert). | "set leadership team", "designate leadership team", "change leadership team" | — |
| GET | `/users/me/accounts` | List accounts the user belongs to (includes is_owner flag) | "my accounts", "list accounts", "which accounts" | — |
| GET | `/accounts/{account_id}/members` | List account members (params: page, per_page). Any account member can view. | "account members", "who's in account", "list users in account" | — |
| DELETE | `/accounts/{account_id}/members/{user_id}` | Remove member from account. Account owner only. Cannot remove owner. | "remove from account", "kick from account", "remove account member" | — |

UserAccount fields: `id`, `name`, `is_owner` (boolean).

AccountMember fields: `id`, `login`, `first_name`, `last_name`, `email`, `profile_photo_thumb_path`, `is_owner` (boolean).

Signup response (201): `{ data: { user: { id, login, email, api_token }, account: { id, name }, team: { id, name } } }`. Validation error (422): `{ error: { code: "validation_error", message, details: { field: [messages] } } }`.

### Account Data Connections

Account-level external data sources that feed scorecard measures (see `POST /measures/{id}/data-source` under Team Scorecard Measures). Any account member may read; create/sync/test/disconnect are account-admin only. **Google Sheets is the only supported named provider today** — any other `provider` value is 422.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/accounts/{id}/connections` | List every connection in the account. `credential_masked` is a fixed presence indicator (`••••••••`, not real characters — the credential is encrypted at rest), visible to admins only (null for a non-admin member, and always null for a `google-sheet` connection, which stores no credential). The raw `credential` is never present on any read. | "list data connections", "account integrations", "show connections" | — |
| POST | `/accounts/{id}/connections` | Create a connection (body: name*, connection_type* — `custom_endpoint`\|`named`; provider? — only `google-sheet` valid; credential? — required unless provider is `google-sheet` (whose credential Nango brokers and never stores); endpoint_url? — HTTPS, required for `custom_endpoint`; auth_method?; auth_header? — custom header name, `^[A-Za-z0-9-]{1,64}$`, default sends `Authorization: Bearer <credential>`). Account admin only. **`credential` is returned in full exactly once, in this 201 response** — never again on any read. | "create data connection", "connect a spreadsheet", "add custom endpoint connection", "connect Google Sheets" | — |
| GET | `/accounts/{id}/connections/{cid}` | One connection. Same `credential_masked` visibility rule as the list. | "get connection", "show connection details" | — |
| DELETE | `/accounts/{id}/connections/{cid}` | Disconnect — deletes the connection and detaches every measurable it feeds (each reverts to manual entry, gains a `connection`-category change-log entry naming what went away; already-pulled values are left intact). Account admin only. Existence is checked before the admin check, so a non-admin gets 404 for a nonexistent connection and 403 for a real one. Returns the detached measurables (same shape as the measurables-preview GET below). | "disconnect data connection", "remove connection", "delete integration" | — |
| GET | `/accounts/{id}/connections/{cid}/measurables` | Preview which measurables this connection feeds, WITHOUT detaching anything (same payload the DELETE returns). Any account member. | "preview connection impact", "what does this connection feed", "measurables using this connection" | — |
| POST | `/accounts/{account_id}/connections/{connection_id}/sync` | Run the same pull the daily cron runs, on demand, for this one connection (no body). Overwrites each attached measure's CURRENT week only — prior weeks untouched. Account admin only. A `custom_endpoint` pull is a real SSRF-guarded HTTPS GET (extracts `value_field`, a dotted path with one optional `[]` wildcard, e.g. `series[].count`; applies `aggregation` — `latest`\|`sum`\|`count`\|`average`). On any measure failure the connection flips to `status: needs_attention` with `attention_reason` set to a closed-set failure code (`auth_rejected`, `endpoint_unreachable`, `bad_response`, `field_not_found`, `value_not_numeric`, `aggregation_required`, `egress_unavailable` — a blocked SSRF destination reports `endpoint_unreachable`, indistinguishable from a genuinely down endpoint); otherwise `last_synced_at` is stamped and `attention_reason` cleared. Returns `{ data: { connection_id, status, results: [{measure_id, ok, value, week}] } }`. | "sync connection now", "pull data connection", "force sync measure source" | — |
| POST | `/accounts/{account_id}/connections/{connection_id}/test` | Live-preview a pull WITHOUT writing anything — no history row, no status change (body: value_field?, aggregation?, measure_id? — required to pick which Measurable's Google Sheets binding to preview when the connection is shared across measurables; omitted for Sheets previews with no target). Account admin only. Same closed-set failure codes as sync. Returns `{ data: { ok, value, date, week, status, error? } }`. | "test data connection", "preview connection pull", "dry-run connection sync" | — |

Connection fields: `id`, `account_id`, `name`, `connection_type` (`custom_endpoint`\|`named`), `endpoint_url` (string\|null), `status` (`connected`\|`needs_attention`), `provider` (`"google-sheet"`\|null), `auth_method` (string\|null — `oauth` for google-sheet), `authorized_as` (string\|null), `expired_at` (datetime\|null), `attention_reason` (closed-set string\|null, see sync above), `credential_masked` (string\|null, admin-only), `credential_note`, `credential` (create-response only), `last_synced_at` (datetime\|null), `created_by`/`created_by_name`, `created_at`, `updated_at`, `used_by_count` (integer — how many measures currently pull from this connection), `created_from_measure_id` (integer\|null — set when the connection was created inline from a Measurable's Data Source tab rather than the account Integrations page).

ConnectionMeasurablesImpact fields: `connection_id`, `affected_measurables` (`[{id, name, owner_id}]`, empty when none attached).

## Search

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/api/v2/search` | Full-text search across 8 entity types. Params: `q`* (min 2 chars), `types` (comma-separated: `items,rocks,measures,projects,people,meetings,pages,reviews`; default: all), `limit` (per type; default 20). Returns `{ groups: { items: [...], rocks: [...], measures: [...], projects: [...], people: [...], meetings: [...], pages: [...], reviews: [...] }, total: N }`. Each result: `{ id, entity_type, name, status, assignee, due_date, team_id, team_name, url_hint }`. Returns 400 if q < 2 chars. | "search", "find", "look up", "search for item", "search everything", "full-text search", "find across teams" | — |

## Day Plans

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/day-plans/today` | Today's plan (auto-creates if none exists). Priority-tag filter applied: items whose name contains a priority hashtag (`#next`, `#priority`, `#toppriority`, `#must`, `#1`–`#4`) are excluded when their status is not `active`. Item responses include `day_plan_action_id` (required when calling DPA-centric endpoints). Optional `?show=` query param for server-side filtering: `everything` (default — returns all items), `must` (only items where `is_top=true` OR name contains `#must`), `not deferred and completed` (excludes completed, deferred, or realized/done items). Invalid value → 400. | "show today", "my plan", "daily plan", "prioritizer" | `/prioritizer` |
| GET | `/day-plans/today/prioritized` | Today's plan, additive read-only sibling of `GET /day-plans/today`, re-ordered into the exact sequence the `/prioritizer` front end renders (priority-tag tier, then position within tier) — for non-browser callers that need the UI's computed order. Same underlying pipeline/filters (params: show? — same enum as `/today`; limit? — optional top-N slice applied AFTER ordering/dedup; non-integer/zero/negative ignored). | "today's plan in prioritizer order", "my plan in priority order", "top N priorities today" | `/prioritizer` |
| GET | `/day-plans/today/items` | Today's items (params: page, per_page, q, include_archived). Item responses include `day_plan_action_id` (required when calling DPA-centric endpoints such as defer, move-to-week, move-to-day). | "today's tasks", "what's on today", "my plan items" | `/prioritizer` |
| POST | `/day-plans/today/items` | Create item in today's plan (auto-creates plan). Hashtag side-effects processed on create: `#must` → `is_top=true`, `#daily` → `recur_daily=true`, `#next` or `#1` → `quadrant_position=1`, `#2`/`#3`/`#4` → respective quadrant. Hashtags remain in stored name. | "add to today", "new task for today", "put on my plan" | `/items/{item_id}` |
| PUT | `/day-plans/today/items/{item_id}` | Attach existing item to today (auto-creates plan, body: position?) | "attach to today", "add to plan", "link to today" | `/prioritizer` |
| PATCH | `/day-plans/today/items/{item_id}` | Toggle completion (body: completed*) | "check off", "mark done for today", "complete for today", "undo" | `/prioritizer` |
| DELETE | `/day-plans/today/items/{item_id}` | Remove from plan (keeps item) | "remove from today", "take off plan", "drop from today" | — |
| POST | `/day-plans/today/items/{item_id}/defer` | Defer an item to a future date (body: defer_to* — YYYY-MM-DD). Sets `deferred_to_date` on the day-plan action. Returns `{ data: { item_id, day_plan_action_id, deferred_to_date } }`. | "defer item", "snooze task", "push to later", "postpone item", "defer to date" | — |
| DELETE | `/day-plans/today/items/{item_id}/defer` | Clear deferral — remove the deferred_to_date from a day-plan action. Returns the updated day-plan action. | "clear deferral", "undefer item", "bring back to today", "stop deferring" | — |
| DELETE | `/day-plans/today/items` | Bulk remove items from today's plan (body: item_ids*, delete_items? boolean — if true, also archives items). Returns `{ data: { removed: N, deleted: N, skipped: [{ item_id, reason }] } }`. Skip reason `has_children` means item was not archived. OpenAPI path: `/day-plans/today/items/bulk-delete`. | "bulk remove from plan", "remove multiple items", "clear items from today", "bulk delete plan items" | — |
| POST | `/day-plan-actions/{id}/move-back-to-today` | Clear deferral and reassign a day-plan action back to today's plan. No body. | "move back to today", "bring deferred item back", "un-defer to today" | — |
| POST | `/day-plan-actions/{id}/move-to-day` | Reassign a day-plan action to a specific date (body: date* — YYYY-MM-DD). | "move to a different day", "reschedule to date", "move item to Wednesday" | — |
| POST | `/day-plan-actions/{id}/move-to-week` | Move item to current week plan and remove the day-plan action from today. No body. | "move to week", "add to weekly board", "send to this week" | — |
| POST | `/day-plans/today/set-positions` | Reorder today's plan items (body: item_ids* — complete ordered array of item IDs; assigns position=1-based index to each). Empty array is valid. Subset allowed — only provided items get updated positions. Auto-creates today's plan if needed. Returns `{ "data": { "success": true } }`. | "reorder today", "sort plan", "drag to reorder", "set item order", "change order of today's items" | — |
| POST | `/day-plans/today/items/{item_id}/set-quadrant-position` | Assign an Eisenhower quadrant to an item on today's plan, keyed by item_id (body: quadrant* — one of: urgent_important, not_urgent_important, urgent_not_important, not_urgent_not_important, unassigned). Returns `{ data: { action, quadrant_position } }` where quadrant_position is 1–4 (or 0 for unassigned). 404 if item not on today's plan. | "put in quadrant", "assign to Q1", "set quadrant", "prioritize to urgent", "Eisenhower quadrant", "move to do first", "unassign quadrant" | `/prioritizer/quadrants` |
| GET | `/day-plans/upcoming-actions` | Flat list of every action on the caller's day plans dated today or later (no upper bound). Runs the idempotent prep gate first (auto-creates today's plan, inserts daily-recurring items, rolls over prior-day actions — at most once per day). Returns non-deferred actions (`deferred_to_date IS NULL`) whose item status is active/blocked/realized/review. Excludes #parkinglot items and non-active priority-tagged items. Each row includes `day_plan_date` (YYYY-MM-DD) for client-side bucketing — Today / This Week / Next Week / Later. No query parameters. Response: `{ data: [...] }` with the same V2_ITEM_SELECT item projection as `/day-plans/today`. Use for the day/week column view; use `upcoming-tasks` for the Timeline view. | "upcoming day plan actions", "what's on my schedule next few weeks", "day/week column view", "my future plans", "upcoming planned tasks", "what have I planned" | — |
| GET | `/day-plans/{date}` | Plan by date (YYYY-MM-DD). Priority-tag filter applied (same rule as `/day-plans/today`): non-active priority-tagged items are excluded. Supports the same `?show=` query param as `/day-plans/today` (`everything`, `must`, `not deferred and completed`). | "show plan for Monday", "last Friday's plan" | `/prioritizer` |
| GET | `/day-plans/{date}/items` | Items by date (params: page, per_page, q, include_archived) | "items for that day", "what was on Monday" | `/prioritizer` |
| POST | `/day-plans/{date}/items` | Create item in date's plan (plan must already exist) | "add to that day's plan" | `/items/{item_id}` |
| PUT | `/day-plans/{date}/items/{item_id}` | Attach existing item to date (plan must already exist, body: position?) | "attach to that plan" | `/prioritizer` |
| PATCH | `/day-plans/{date}/items/{item_id}` | Toggle completion (body: completed*) | "check off for that day" | `/prioritizer` |
| DELETE | `/day-plans/{date}/items/{item_id}` | Remove from plan (keeps item) | "remove from that day" | — |
| POST | `/day-plans/{date}/items/{item_id}/set-quadrant-position` | Assign an Eisenhower quadrant to an item on a specific date's plan, keyed by item_id (body: quadrant* — one of: urgent_important, not_urgent_important, urgent_not_important, not_urgent_not_important, unassigned). Returns `{ data: { action, quadrant_position } }`. 400 if date invalid. 404 if no plan for date or item not on that plan. | "set quadrant for past day", "assign quadrant for date" | — |
| POST | `/day-plan-actions/{id}/set-quadrant-position` | Assign an Eisenhower quadrant to a day-plan action, keyed by action id (body: quadrant* — same enum as above). Returns `{ data: { action, quadrant_position } }`. Legacy endpoint — prefer item-keyed variants when you have item_id. | "set action quadrant" | — |
| POST | `/day-plans/{date}/set-positions` | Reorder a specific date's plan items — date-parameterized counterpart of `/day-plans/today/set-positions` (body: item_ids* — complete ordered array; position = 1-based index). Auto-creates the date's plan if needed. Used by the Day/Week prioritizer for This Week / Next Week columns. | "reorder items for that day", "sort a future day's plan" | `/prioritizer` |
| GET | `/day-plan-completions` | The caller's own historical day-plan completions, most recent first — the historical counterpart to the current-day-only reads above (params: months? — window in calendar months back, default last 30 days; column? — filter by the item's CURRENT column name, case-insensitive; column_id? — same filter by id, takes precedence over `column`). One row per completion — an item finished on two different days yields two rows. `column` reports where the item sits NOW, not necessarily where it sat when completed; null if it's in no active column. Non-positive-integer `months`/`column_id` are treated as omitted. | "day plan completion history", "what have I completed over time", "completions last 3 months", "completions in this column" | — |

DayPlan fields: `id`, `date`, `creator` (UserSimple), `items` (DayPlanItem[]).

DayPlanItem fields: Item fields + `completed` (boolean), `position` (integer), `quadrant_position` (integer 0–4; 0 = unassigned, 1 = urgent+important, 2 = not urgent+important, 3 = urgent+not important, 4 = not urgent+not important), `day_plan_action_id` (integer — required when calling DPA-centric endpoints: defer, move-back-to-today, move-to-day, move-to-week), `deferred_to_date` (YYYY-MM-DD or null).

Eisenhower quadrant values: `urgent_important` (Q1), `not_urgent_important` (Q2), `urgent_not_important` (Q3), `not_urgent_not_important` (Q4), `unassigned` (0).

Day plan completion: regular items also get status=done. Recurring/daily items only toggle `completed` for that day — item stays active for tomorrow. The reverse holds too: setting `status: done` via `PATCH /items/{id}` also checks the item off on today's day plan. Either route leaves the same state.

### Day Plan Columns (Custom Columns / Personal Planner Buckets)

Personal Planner custom column lanes. All endpoints require auth. Items embedded in column responses are automatically scoped to the caller's today DayPlan — no filter param needed.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/day-plan-columns` | List all active (non-archived) columns owned by the caller, with embedded items scoped to today's plan. Priority-tag filter applied to embedded items (same rule as `/day-plans/today`): non-active priority-tagged items are excluded. Response includes `color: string \| null` on each column (6-digit hex e.g. `#2563EB`, or null). | "list my columns", "show custom columns", "what are my planner buckets", "show planner columns" | `/prioritizer/custom-columns` |
| POST | `/day-plan-columns` | Create a new column (body: name* — 1–255 chars, color? — 6-digit hex e.g. `#2563EB` or omit for no color). Position auto-assigned to end. Returns 201 with new column including `color`. | "add a column", "create a planner bucket", "new column called X", "create column with color" | `/prioritizer/custom-columns` |
| PATCH | `/day-plan-columns/{id}` | Update a column (body: name? — 1–255 chars; color? — 6-digit hex to set, `null` to clear, omit to leave unchanged). Both fields are now optional — send either or both. Returns 404 if not owned or archived. | "rename column", "change column name", "set column color", "change column color", "clear column color" | `/prioritizer/custom-columns` |
| DELETE | `/day-plan-columns/{id}` | Soft-archive a column (sets is_archived=true, removes all action rows). Returns 200 with archived column. Items in the column are unlinked but not deleted. | "delete column", "archive column", "remove planner bucket" | `/prioritizer/custom-columns` |
| POST | `/day-plan-columns/{id}/reposition` | Move column to new 0-indexed position (body: position* — non-negative integer, clamped to end). Siblings re-numbered. Returns `{ data: { success: true } }`. | "reorder columns", "move column", "drag column" | `/prioritizer/custom-columns` |
| POST | `/day-plan-columns/drop-action` | Place an item into a column at a position (body: item_id*, new_column_id* (number or null), position?). One-column-per-item enforced globally — removes item from all other columns first. Pass new_column_id: null to unlink from all columns. Returns 200 `{ data: { success: true } }`. 403 if item not viewable; 404 for missing/archived/unowned column. | "put item in column", "move item to column", "drop into bucket", "unlink item from columns", "remove item from planner" | `/prioritizer/custom-columns` |

DayPlanColumn fields: `id`, `name`, `position` (0-indexed), `is_archived` (boolean), `created_at`, `updated_at`, `items` (DayPlanColumnItem[]).

DayPlanColumnItem fields: `id`, `name`, `completed` (boolean), `due` (YYYY-MM-DD or null), `recur_daily` (boolean), `position` (0-indexed within column), `is_top` (boolean), `assignees` (UserSimple[]), `custom_labels` (`[{ id, name, color }]` — always present, `[]` when nothing qualifies, ordered by label id ascending; carries the caller's own personal labels **plus** the team labels they are entitled to see, i.e. labels owned by a team they belong to, or shared down to them by an ancestor team. Never a sibling team's label, an unshared ancestor's label, another organization's, another user's personal label, a project label, or a quadrant label. No `tags` twin on this endpoint).

## Result Feed

The "90-second practice" — a daily check-in report where users record what they got done, what's next, and what's blocked. **Auto-DONE**: when a user marks any item done through any V2 surface (`PATCH /items/:id`, day-plan completion, L10 section move, etc.), it is automatically recorded into the completing user's check-in `done` section for their local today — no manual add needed. Credited to the actor (completer), not the item owner. Does not fire for `recur_daily` items or on uncomplete. Best-effort; a check-in write failure never fails the completion.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/result-feed/{date}` | Get check-in for date (auto-creates empty report). `{date}` accepts `YYYY-MM-DD` or literal `today`. Returns `{ data: ResultFeed }` with 4 sections: `done`, `review`, `next`, `blocked` — each a structured object `{ items, notes, attachments }`. | "show my check-in", "90 seconds", "result feed", "daily report", "what did I do", "show check-in for {date}" | — |
| POST | `/result-feed/{date}/{section}` | Create new item in section (body: name*) | "add done", "add next", "add blocked", "new done item", "got something done" | — |
| PUT | `/result-feed/{date}/{section}/{item_id}` | Add existing item to section (idempotent; applies the section's status change immediately). Body is **optional** and also carries section metadata: `notes?` (string\|null, HTML stripped server-side; `null` clears), `attachment_ids?` (integer[] — Document IDs to attach). There is no separate endpoint for section metadata — set it here, on any item you're adding (or re-adding, since adding is idempotent). | "add item {id} to done", "put {id} in next", "attach {id} to blocked", "add notes to done", "set notes on done/next/blocked/review", "attach files to section" | — |
| DELETE | `/result-feed/{date}/{section}/{item_id}` | Remove item from section (keeps item, does not revert status) | "remove {id} from done", "take {id} off next", "drop {id} from blocked" | — |
| POST | `/result-feed/{date}/submit` | Submit + share check-in (body: optional team_id; `item_ids` is deprecated, accepted and ignored). A share always covers the **whole** check-in. `team_id` is validated before anything is written, so a 404 (team not viewable) or 400 (team_id not a positive integer) means nothing was submitted and the call is safe to retry. Requires ≥1 item in both done and next. Idempotent. | "submit", "finalize", "done for the day", "submit check-in" | — |
| DELETE | `/result-feed/{date}/share` | Retract a share — returns your own check-in for that date to shared-with-nobody (removes both `shared_team_id` and `team_shared_item_ids`). **Idempotent and always 204**: shared, never shared, or no check-in for that date at all are the same success. Does NOT un-submit — status, sections and contents are unchanged, only the audience is removed; can be re-shared afterwards. Acts only on the caller's own check-in. Cannot recall a Slack/Discord push already delivered. | "unshare check-in", "retract share", "stop sharing check-in", "take back check-in from team" | — |
| GET | `/teams/{id}/result-feed` | List team's shared check-ins (params: page, per_page). Reverse chronological. Requires team membership. | "team check-ins", "team feed", "team result feed", "show team check-ins" | — |
| POST | `/result-feed/{date}/push-to-slack` | Push check-in to team's Slack webhook (body: group_context_id*, exclude_item_ids[]). 422 if no webhook configured, 502 if webhook fails, 403 if not a team member. | "share to slack", "push to slack", "send check-in to slack" | — |
| POST | `/result-feed/{date}/push-to-discord` | Push check-in to team's Discord webhook (body: group_context_id*, exclude_item_ids[]). Same error codes as push-to-slack. | "share to discord", "push to discord", "send check-in to discord" | — |
| POST | `/result-feed/{date}/reactions` | Toggle high-five reaction on a report (body: user_id — whose report to react to). Returns `{ data: { reacted: boolean, count: integer } }`. | "high-five", "react", "give kudos", "high five check-in" | — |
| GET | `/result-feed/{date}/reactions` | Get current reaction state for a report (query: user_id*). Returns `{ data: { reacted: boolean, count: integer } }`. | "show reactions", "reaction count", "did I react", "high-five count" | — |
| POST | `/result-feed/{date}/attachments` | Upload a file attachment to a check-in (multipart/form-data: file*). Max 4.5 MB. Returns `{ data: { id, filename, content_type, filesize, parent_object_type } }`. Use returned `id` as `attachment_id` in PUT section metadata. | "upload file to check-in", "attach file", "upload attachment" | — |
| GET | `/result-feed/{date}/comments` | List comments on a report (query: user_id* — whose report). Returns `{ data: [{ id, comment, user_id, created_at }] }`. | "show comments", "read comments", "comments on check-in" | — |
| POST | `/result-feed/{date}/comments` | Add comment to a report (body: body*, user_id* — whose report). body required, non-empty, ≤ 10,000 chars. Returns 201 with created comment `{ id, comment, user_id, created_at }`. | "comment on check-in", "add comment", "reply to check-in" | — |
| GET | `/teams/{id}/result-feed/{date}/{user_id}` | View a specific user's report for a date. Returns `{ data: { report: ResultFeed, is_quiet: boolean } }`. `is_quiet: true` when shared to a different team context. 403 if not a member, 404 if no report. | "show user's check-in", "view teammate's report", "team member report" | — |

ResultFeed fields: `id`, `date`, `is_completed`, `done` (ResultFeedSection), `review` (ResultFeedSection), `next` (ResultFeedSection), `blocked` (ResultFeedSection).

ResultFeedSection fields: `items` (Item[]), `notes` (string | null), `attachments` (Attachment[]).

Attachment fields: `id`, `filename`, `content_type` (MIME type, e.g. "image/png"), `size` (integer — bytes).

UploadedDocument fields (returned by POST attachments): `id`, `filename`, `content_type`, `filesize`, `parent_object_type` (always "CustomContent"). Use `id` as `attachment_id` in PUT section metadata.

TeamResultFeed fields: ResultFeed fields + `user` (UserSimple).

Comment fields: `id`, `comment` (text body), `user_id`, `created_at`.

Reaction response fields: `reacted` (boolean — whether the requesting user has reacted), `count` (integer — total reaction count).

Submit request body (all optional): `team_id` (integer — the team to share with; must be a positive integer, anything else is 400. `null` or omitted = submit without sharing), `item_ids` (integer[] — **deprecated: accepted and ignored**. A share records every item in the check-in across all four sections; it cannot be narrowed. For per-item control use `exclude_item_ids` on push-to-slack / push-to-discord).

Section path parameter: `done`, `review`, `next`, `blocked`.

Date path parameter: `YYYY-MM-DD` or literal `today` (resolved server-side via user timezone).

Push-to-slack/discord request body: `group_context_id` (integer — required, the team/group context ID), `exclude_item_ids` (integer[] — optional items to omit from the push).

Behavioral notes:
- GET auto-creates an empty report if none exists for the date.
- GET result-feed sections are objects (`{ items, notes, attachments }`), NOT flat arrays.
- Section metadata (`notes`, `attachment_ids`) is set via `PUT /result-feed/{date}/{section}/{item_id}`'s optional body — there is no dedicated section-metadata endpoint. `notes: null` clears notes; `attachment_ids` replaces the full list (filtered to IDs the caller owns).
- PUT (add item) is idempotent — adding an already-present item returns 200.
- DELETE (remove item) returns 404 if item is not in that section. Does NOT delete the item or revert its status.
- Submit is idempotent — re-submitting a completed report returns 200.
- Submit validation: requires ≥1 item in both `done` and `next` (422 otherwise). `team_id` is authorized before any write — a refused share submits nothing.
- Submit share scope: the share records every item in the check-in, across all four sections. `item_ids` cannot narrow it and there is no narrowed state to be stuck in.
- Submit side-effects (server-side, no skill action required): upserts ObjectMeta `last_status_provided` timestamp for the user, triggers daily recurrence item rollover (recurrent items due today roll to tomorrow), and — when `team_id` is given — records the share as `shared_team_id` + `team_shared_item_ids` (every item in the check-in, not a selectable subset).
- Retracting a share (`DELETE /result-feed/{date}/share`) does not un-submit; it only clears the audience and is safe to call unconditionally (idempotent, always 204).
- Adding items triggers status side-effects: done→done, next→next, blocked→blocked.
- Removing items does NOT revert status side-effects.
- React (high-five) is a toggle — calling again removes the reaction.
- Comments: body is required, non-empty, max 10,000 characters.
- Push-to-slack/discord: 422 if team has no webhook configured, 502 if webhook returns non-2xx, 403 if caller is not a team member.
- Team-feed detail: `is_quiet: true` when the report was shared to a different team than the requester's active group context.

## One-on-Ones (1-on-1)

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/1-on-1` | List one-on-ones (params: group_id — team scope; organization_id — organization scope, the org's root-team id; scope=`all` — every organization the caller belongs to, overrides both; page, per_page, archived — `true`/`false`/`all`; default `false` = active only). Scope tiers: `group_id` = this team; `organization_id` = this org subtree; `scope=all` = everywhere; neither = all orgs the user participates in. `group_id` wins over `organization_id` when both are sent; `scope=all` overrides both. Non-integer `organization_id` → 400. Every row carries a `teams` array (see below). | "show 1:1s", "my one-on-ones", "list 1:1s", "one-on-one meetings", "show archived 1:1s", "1:1s in my org", "organization 1:1s", "1:1s across all my orgs" | — |
| GET | `/1-on-1/{id}` | Meeting detail — `Meeting` = `MeetingSimple` + top-level `next`, `done`, `blocked` arrays (Item[] each; NOT nested under an `items` key). Also carries `measures`, `goals`, `notes`, `can_edit_notes`, `attachments`, `assistants`. Non-participants receive 403 (not 500). | "show meeting", "meeting details", "open 1:1" | `/1-on-1/{id}` |
| GET | `/1-on-1/{id}/items` | All meeting items (params: page, per_page, q, status — `active`\|`realized`\|`blocked`; omit status for all). No `creator_id` or `include_archived` param. | "meeting items", "what's on the agenda", "meeting blockers" | `/1-on-1/{id}` |
| GET | `/1-on-1/{id}/done` | Done items (params: start_date? YYYY-MM-DD, end_date? YYYY-MM-DD, show_all? boolean default false — skip the date filter, page, per_page) | "meeting done items", "completed items", "done since date" | `/1-on-1/{id}` |
| POST | `/1-on-1/{id}/items` | Create item in meeting (body: name*, column? — `next`/`blocked`/`done`, default `next`; description? — HTML body) | "add to meeting", "new meeting item", "add to 1:1" | `/items/{item_id}` |
| POST | `/1-on-1/{id}/align` | Align a measure, goal, or item to the session (body: alignable_type* — `Measure`, `Goal`, or `Item`; alignable_id*). Idempotent. Use `alignable_type: "Item"` to attach an existing item to the meeting — there is NO `PUT /1-on-1/{id}/items/{item_id}` endpoint. A **personal** rock may be aligned only by its owner, and only when the owner is a participant (creator or sessionable user) — refused with 404 (not 403) whether it's someone else's rock or doesn't exist, so the two never disclose which. Aligning it makes it visible to both participants (`viewer_access: one_on_one` on the rocks feed). An **item** may be aligned only by someone who can already edit it independently of the 1:1; same 404-for-both refusal. Team goals and measures are unaffected by these rules. | "attach to meeting", "link item to 1:1", "add existing item to meeting", "align to 1:1", "track goal in 1:1", "add measure to meeting" | `/1-on-1/{id}` |
| POST | `/1-on-1/{id}/unalign` | Remove an alignment from the session (body: alignable_type*, alignable_id*). For Goals, cascades to remove their KeyResults. A **personal** rock can be unaligned only by its owner, acting as a participant — same 404 refusal as align. Unaligning ends the 1:1-derived view for both participants but leaves the owner's own audience grants (`GET /rocks/{id}/audience`) standing. Team goals, measures and items are unaffected. | "unalign from 1:1", "stop tracking in meeting", "remove goal from 1:1" | `/1-on-1/{id}` |
| DELETE | `/1-on-1/{id}/items/{item_id}` | Remove an item from the meeting by URL param (keeps the item). Equivalent to unalign with `alignable_type: "Item"`. Returns 204. | "remove from meeting", "detach from 1:1" | — |
| PUT | `/1-on-1/{id}/notes` | Save meeting notes (body: `{ "text": "<HTML>" }`, sanitized server-side). Overwrites existing notes. | "save notes", "add notes to 1:1", "write meeting notes" | `/1-on-1/{id}` |
| PUT | `/1-on-1/{id}` | Schedule (or clear) next meeting. Body: `{"next_meeting_at":"<ISO 8601 datetime>"}` or `{"next_meeting_at":null}`. Returns updated MeetingSimple. | "schedule next meeting", "set next 1:1", "clear next meeting date" | `/1-on-1/{id}` |
| GET | `/1-on-1/fetch` | Find-or-create a 1-on-1 session between two users (params: `user1_id`, `user2_id` — both required). Checks both directions (A→B and B→A). Returns existing session (200) or creates one (implementation returns `MeetingSimple` either way). | "find 1:1 with", "get meeting between", "open 1:1 between users" | — |
| POST | `/1-on-1` | Find-or-create a 1-on-1 session (body: `{ user1_id*, user2_id* }`). 200 if an existing session is found, 201 if a new one is created. Returns `MeetingSimple` with `can_edit`. | "create 1:1", "start new one-on-one", "new meeting between" | — |
| POST | `/1-on-1/{id}/archive` | Archive a session (participants only — creator or other participant; 403 if not participant; 404 for project sessions). Idempotent. | "archive 1:1", "archive meeting", "hide one-on-one" | — |
| POST | `/1-on-1/{id}/unarchive` | Restore an archived session. Idempotent. | "unarchive 1:1", "restore meeting", "unarchive one-on-one" | — |
| POST | `/1-on-1/{id}/assistants` | Set the session's assistant editors (body: user_ids* — integer[], full replace). Creator or sessionable user only. | "set 1:1 assistants", "add assistant to meeting", "who can edit this 1:1" | — |
| GET | `/1-on-1/{id}/attachments` | List session link attachments (`{ data: [{ id, url, title }] }`). | "meeting attachments", "1:1 links", "show session attachments" | `/1-on-1/{id}` |
| POST | `/1-on-1/{id}/attachments` | Add a link attachment (body: url*, title*). | "add attachment to meeting", "attach link to 1:1" | `/1-on-1/{id}` |
| DELETE | `/1-on-1/{id}/attachments/{attachmentId}` | Remove a link attachment. | "remove meeting attachment", "delete 1:1 link" | — |
| GET | `/1-on-1/{id}/goals` | 1-year goals and rocks aligned to the session, milestones nested under each node's `children`, in `TargetNode` shape (see Strategy Tree) and alignment order. `owner`/`assigned_by`/`is_personal` carry personal-rock provenance — read `assigned_by` for who assigned it, **never `creator`** (which names the owner, not the assigner, on an assigned personal rock). `can_edit` is always `false` on this read; `is_visible_to_team` is always `true`. | "goals tracked in meeting", "1:1 rocks", "meeting goals and milestones" | `/1-on-1/{id}` |
| GET | `/1-on-1/{id}/measures` | Measures aligned to the session, each with a pre-calculated `trend` (`{ percentage, display, value_rising }` vs. the prior ISO week; all null when no prior-week data — displays "N/C") and `can_edit`/`can_record_value` computed against the measure's **owning** team (see OneOnOneMeasure below). | "meeting measures", "1:1 KPIs", "aligned measures with trend" | `/1-on-1/{id}` |
| PUT | `/1-on-1/{id}/notes-lock` | Lock or unlock meeting notes for editing (body: locked*). Creator or sessionable user only. | "lock meeting notes", "unlock notes", "toggle notes lock" | — |
| POST | `/1-on-1/{id}/set-positions` | Reorder session items (body: item_ids* — integer[], full ordered list). | "reorder meeting items", "sort 1:1 items" | — |

OneOnOneSimple (`MeetingSimple`) fields: `id`, `type` (`"one_on_one"` | `"project"`), `date` (YYYY-MM-DD | null), `human_name` (pre-formatted display string),
`person1` (UserSimple+title), `person2` (UserSimple+title) — **top-level fields, not nested under a `persons` key**,
`project` (`{ id, name }` | null — set only for `type: "project"` sessions),
`cadence` (string | null — e.g. `"weekly"`, `"biweekly"`, `"monthly"`; null if no cadence configured),
`cadence_interval` (integer | null — multiplier, e.g. 1 = every period, 2 = every 2 periods; null if no cadence),
`next_meeting_at` (string | null — UTC ISO 8601 datetime of next scheduled meeting; null if not scheduled),
`archived` (boolean — `true` if archived by a participant; archived sessions excluded from default list),
`can_edit` (boolean — always present, never null; `true` if the current user is person1, person2, or a listed assistant; `false` for viewers and non-participants; fail-closed),
`assisted` (boolean, default `false` — `true` only when the caller reached this session as a listed assistant who is neither person1 nor person2; drives the "assisted" marker on the meeting tile).

MeetingListItem (the shape `GET /1-on-1` returns) = MeetingSimple + `teams` (MeetingTeam[] — every team **both** participants belong to, ascending by id; scoped by `group_id`/`organization_id` when sent; only teams the caller can see; always present, empty array when none visible. Render a row unlabeled when the current team is among these, labeled with a team name otherwise). MeetingTeam: `{ id, name, organization_id, organization_name }` — `organization_id` is the org's root-team id (a `groups.id`), never an `accounts.id`. Same shape as `SwimlaneRoadmapTeam`.

OneOnOne (detail) fields (`Meeting` schema) = MeetingSimple + top-level `next` (Item[]), `done` (Item[]), `blocked` (Item[]) — **not** nested under an `items` key, and the blocked-column array is named `blocked`, not `issues`. Also carries `notes` (string | null), `can_edit_notes` (boolean), `measures`, `goals`, `attachments`, `assistants` per the endpoint description (each has its own dedicated GET too — see rows above).

OneOnOneMeasure fields (`GET /1-on-1/{id}/measures`): `id`, `name`, `description` (string | null), `current_value` (string | null), `target_value` (string | null), `unit`, `direction` (`"higher"` | `"lower"`), `is_archived`, `notes` (string | null), `owner` (UserSimple+profile_photo_thumb_path | null), `trend` (`{ percentage: integer|null, display: string, value_rising: boolean|null }` | null — `display` reads `"+7%"`, `"-3%"`, or `"N/C"` when no prior-ISO-week data), `can_edit` (boolean — computed against the measure's OWNING team, agrees with `PATCH /measures/{id}`), `can_record_value` (boolean — broader than `can_edit`, agrees with `POST /measures/{id}/history`).

> **Terminology**: The blocked-column array in the API is named `blocked` (not `issues`) — it is the "Blocked/Issues" column in the UI. The `group_id` param filters by team.

## Sessions

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| POST | `/sessions` | Login via credentials or Google OAuth. No auth required. Returns API token. | "login", "authenticate", "get token" | — |
| DELETE | `/sessions` | Logout / destroy current session | "logout", "sign out", "end session" | — |

SessionResponse: `api_token` (string), user fields.

## Passwords

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| POST | `/passwords/reset` | Trigger password reset email for a user (admin auth required, body: user_id*) | "reset password", "send password reset", "password reset for user" | — |
| PUT | `/passwords` | Complete password reset (unauthenticated, body: token*, password*). Uses reset token from email link. | "set new password", "complete password reset" | — |
| POST | `/passwords/recovery-codes` | Self-serve password recovery — unauthenticated (body: identifier* — a login name or an email address). **Always answers `202` with the identical body**, for a never-confirmed account, an ordinary account, or an identifier nobody uses — callers must not branch on the response; there is deliberately no 403 and no 404. The server decides and acts after the response is sent, so nothing about the decision is observable. Only refusals: 400 malformed request, 429 rate limit. | "forgot password", "recover my password", "reset my password", "I lost my password" | — |

POST /passwords/reset: Admin-only. Sends a password reset email to the specified user. Body: `{ "user_id": integer }`. Response: `{ "data": { "message": "Password reset email sent" } }`. Returns 403 if caller is not admin, 422 if user_id is invalid, user not in account, or user has no email.

PUT /passwords: Unauthenticated — the reset token serves as authentication. Body: `{ "token": string, "password": string }`. Response: `{ "data": { "message": "Password updated successfully" } }`. Returns 422 if token is invalid/expired or fields are missing. This endpoint is used by the browser-based reset flow, not by the CLI skill.

POST /passwords/recovery-codes: the self-serve counterpart to admin-triggered `/passwords/reset` — for a user with no admin to ask. Accepts either a login or an email (the login is the account's identity; the email is an attached alias). Rate-limited and identifier-blind by design: response status, body, and timing never reveal whether the identifier matched an account.

## Invite Confirmation

Endpoints for the teammate-invite accept flow (unauthenticated). **Legacy** — this is the API behind the older `/user/confirmation` page. The current invite-accept screen (`/invite/{token}`) uses the `POST /invitations/{token}/accept` endpoint in the Invitations section below instead; that endpoint takes one free-text `name` field and splits it server-side, where this one takes separate `first_name`/`last_name`. Both remain live in the spec.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/api/v2/users/confirmation` | Validate an invite token (params: token*). Always 200. Returns `{ data: { status, valid, login? } }`. **Tri-state status**: `valid` — live, unconfirmed invite (show signup form, `login` is present); `used` — link already consumed, route to sign in; `invalid` — no pending invite, offer a fresh invite. `valid` boolean is retained for backward compatibility (`true` only when `status === 'valid'`). | "validate invite token", "check invite link" | — |
| POST | `/api/v2/users/confirmation` | Activate account by accepting an invite (unauthenticated, body: token*, login*, password*, first_name?, last_name?). Password must be 6–20 characters. A token belonging to an already-confirmed account is rejected and never overwrites existing credentials. Returns 422 if token already used or password out of range. | "accept invite", "confirm account", "activate account" | — |
| POST | `/api/v2/users/confirmation/resend` | Self-serve resend of invite email by invitee (unauthenticated, body: email*). Always 200. Status: `sent` — email sent; `throttled` — within rate-limit window (default 5 min), no email; `already_active` — account confirmed, sign in instead; `no_invite` — no pending invite, ask admin. No account is created on any path. | "resend invite email", "resend confirmation email", "send invite again" | — |

## Invitations

The API behind the **current** `/invite/{token}` accept screen — a separate, newer system from Invite Confirmation above, keyed by an invitation token rather than a user id. **Three of these four endpoints require no authentication** — they run before the invited person has any account or session. Invitations last 14 days from when they were last sent (resending restarts the clock). **Every refusal is one uniform `404`** — an unknown token, a malformed token, a cancelled invitation, and an already-accepted one are indistinguishable, on purpose, so an anonymous caller can't use this to enumerate invitations.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/invitations/{token}` | Read an invitation — no authentication. Returns `{ data: { invited_email, inviter: {name, seat, email}, organization: {id, name}, team: {id, name}, member_count, member_initials, sent_at, expires_at, expired, invitee_has_account } }`. `organization` is **the account**, not a root team (a deliberate, documented exception). `member_initials` carries at most 5 initials, never a name/email/login/photo/id; `member_count` is the true total behind the "+N" chip. `invitee_has_account` tells the accept screen which of the two `accept` body shapes to send. Safe to call repeatedly — reads create and consume nothing. | "read invitation", "what team is this invite for", "check my invite" | — |
| POST | `/invitations/{token}/accept` | Accept an invitation — no authentication. Two body shapes, selected by `invitee_has_account` from the read above: `{ name*, password* }` (no existing account — completes the invited row, no new account created, returns 201) or `{ password* }` (existing account — signs in, returns 200). `name` is one free-text field split server-side on the **last** whitespace (`first_name`/`last_name`); an `email` in the body is ignored — the address always comes from the invitation. Password minimum 8. Both shapes return a session. An invitation can be accepted **at most once** — the token is cleared on accept, so a second attempt gets the same 404 as an unknown token. 410 when expired (distinct from 422). 429 after 10 failed password attempts on one invitation within an hour. To accept with a federated identity instead of a password, use `POST /sessions` with `provider: cognito` and `invitation_token` (see Sessions). | "accept invite", "join the team", "set my password and join" | — |
| POST | `/invitations/{token}/resend` | Ask for a fresh invitation link, at the invitee's own request — no authentication, no body. Emails the **same** token with its expiry clock restarted (the original email's link keeps working too), and notifies the original inviter that a new link was requested. Creates no account and signs nobody in. Honored whether or not the invitation is currently expired. 429 after 3 requests per invitation per hour, without sending mail. Unknown token answers with the same 404 as the read. | "resend invite", "send me a new invite link", "my invite link expired" | — |

## Status Values

`not_started`, `next`, `parked`, `blocked`, `done`, `archived`, `draft`

`draft` is read-only — cannot be set via POST or PATCH (422 if attempted). Only allowed transition: `draft` → `not_started`.

## Core Values

**Note**: `GET /api/v2/core-values` has been removed. Core values are now managed via EOS Vision: `GET /teams/{id}/core-values` (see EOS Vision section below). The `core_value_id` in ratings requests now references a label ID from the EOS Vision core values list.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/core-values-ratings` | List ratings for a subject (params: subject_id*, page, per_page) | "show ratings", "core value ratings", "ratings for user" | — |
| POST | `/core-values-ratings` | Create standalone core value ratings (body: subject_id*, ratings[{core_value_id*, score*}]) — `core_value_id` is a label ID from EOS Vision core values | "rate core values", "submit ratings", "score values" | — |

CoreValuesRating fields: `id`, `core_value` ({ id, name }), `score` (integer), `justification` (string | null), `rater` (UserSimple), `review_id` (integer | null), `created_at`.

## Reviews

Performance reviews with self-assessment and reviewer assessment workflow.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/reviews` | List reviews (params: page, per_page, status, q, team_id). `team_id` filters by organization — resolves the team's root ancestor and returns only reviews where the reviewee is a member of any team in that org. 400 if team_id invalid, 404 if not found. Omitting team_id returns all reviews. Excludes archived. Response includes `user_id` (creator ID, nullable). | "show reviews", "list reviews", "my reviews", "performance reviews" | — |
| POST | `/reviews` | Create review (body: reviewee_id*, reviewer_id*, template_id*, review_type?, start_date?, end_date?). Admin/people-ops only. reviewee_id and reviewer_id must be members of at least one team in the account (400 "is not a member of any team in this account" if not). | "create review", "start review", "new performance review" | — |
| GET | `/reviews/{id}` | Review detail. Assessment visibility depends on requesting user's role. Response includes `user_id` (creator ID, nullable), `can_delete` (boolean — whether the authenticated user may delete this review), and `gwc_evaluations` (GwcEvaluationEntry[] — 0-2 entries, one per respondent_type). Reviewer GWC entries hidden from reviewee until `signed_off` status. | "show review", "review details", "open review" | — |
| PATCH | `/reviews/{id}` | Update review (body: review_type?, start_date?, end_date?) | "update review", "change review dates", "edit review" | — |
| DELETE | `/reviews/{id}` | Archive review (soft delete). Allowed for admins/people-ops and for the review creator (unless the reviewee has saved assessment data — 403 "Cannot delete: the reviewee has already saved assessment data"). Use `can_delete` from the detail response to determine visibility. | "archive review", "delete review", "remove review" | — |
| PUT | `/reviews/{id}/draft-assessment` | Save draft assessment (WIP, does not advance state). Body: AssessmentSubmitRequest (includes optional `gwc_evaluation`). | "save draft", "draft assessment", "save progress" | — |
| POST | `/reviews/{id}/submit-assessment` | Submit final assessment. Transitions to assessed when both parties submit. Body: AssessmentSubmitRequest (includes optional `gwc_evaluation`). | "submit assessment", "finalize assessment", "submit review" | — |
| POST | `/reviews/{id}/sign-off` | Sign off review (body: initials*). Must be in assessed state. Reviewer only. | "sign off", "approve review", "finalize review" | — |
| PUT | `/reviews/{id}/void` | Void review (body: reason*). Admin/people-ops only. Rejects all further actions. | "void review", "cancel review", "invalidate review" | — |
| PUT | `/reviews/{id}/notes` | Update review notes (body: notes*). Reviewer or people-ops. | "update review notes", "add notes", "edit review notes" | — |
| POST | `/reviews/{id}/action-items` | Create action item (body: title*, assignee_id*). **Server-gated** — see write-authorization note below. | "add action item", "create follow-up", "review action item" | — |
| DELETE | `/reviews/{id}/action-items/{aid}` | Delete an action item. **Server-gated** — see write-authorization note below. Returns 204. | "delete action item", "remove follow-up", "remove review action item" | — |
| POST | `/reviews/{id}/attachments` | Upload attachment (multipart/form-data: file*). Beta — metadata stored, file storage deferred. **Server-gated** — see write-authorization note below. | "attach file", "upload to review", "add attachment" | — |
| DELETE | `/reviews/{id}/attachments/{aid}` | Delete attachment. **Server-gated** — see write-authorization note below. | "remove attachment", "delete file from review" | — |
| POST | `/reviews/{id}/self-assessment-invitation` | Ask the review's reviewee to complete their self-assessment (body: note? — string, ≤500 chars, markup stripped; absent/null/blank = no note block in the email). Reviewer-only: refused for the reviewee, the review's creator, a Review Administrator, and the reviewee's manager — same flat 403 as every other review write. **Also has a state gate** (added after initial ship): refused with the same 403 when the review is not `in_progress`/`assessed` (i.e. signed off, voided, archived) **or** the reviewee has already submitted their self-assessment — a *draft* self-assessment does NOT count as submitted, so the invitation still works for a reviewee who started and stopped. The 403 has two indistinguishable causes (not-the-reviewer vs. wrong state) — never tell a user "you are not the reviewer" from this response alone. A caller who cannot view the review at all gets 404, not 403. Resending is just calling again — every send is recorded separately, no de-dup, no limit. 422 if the note is too long or the reviewee has no email on file. 502 (nothing recorded) if delivery fails. Reads back via `GET /reviews/{id}/audit-log`, filtered to `action: "self_assessment_invited"` (newest first); a note-less send records the fixed string `Self-assessment invitation sent without a note.` — match it exactly, don't paraphrase. | "invite self-assessment", "ask them to complete their self-assessment", "send self-assessment reminder", "resend self-assessment invite" | — |
| GET | `/reviews/{id}/audit-log` | Audit log entries for review | "review history", "audit log", "review changes" | — |
| GET | `/teams/{id}/review-admins` | List the organization's review administrators (the grant lives on the org's root team; any team in the org resolves the same list). Returns `{ data: { organization_id, admins: [{ user_id, first_name, last_name, email, login, profile_photo_thumb_path, status: "active"\|"pending" }], viewer: { is_review_admin, can_manage } } }`. Only explicit grants are listed — the root team's founder and the account owner always have review-admin standing without appearing here; `viewer.is_review_admin` reports standing by any route, `viewer.can_manage` says whether the caller may grant/revoke. | "list review admins", "who are the review administrators", "review admin standing" | — |
| POST | `/teams/{id}/review-admins` | Grant review-admin standing (body: user_id*). Only the org root team's founder or the account owner may grant. Target must belong to the org's account (422 otherwise). Idempotent — re-granting returns 200 `{ data: { granted: true } }` instead of 201. | "grant review admin", "make someone a review administrator" | — |
| DELETE | `/teams/{id}/review-admins/{userId}` | Revoke a review-admin grant. Same granter-only permission as POST. **Not idempotent** — revoking someone who holds no grant is 404, not a silent no-op. Returns `{ data: { revoked: true } }`. | "revoke review admin", "remove review administrator" | — |
| GET | `/reviews/{id}/seat-accountability-comments` | List all seat accountability comments for a review. Response: array of { id, review_id, seat_id, comment (HTML string), respondent_type ("self"\|"reviewer"), created_at, updated_at }. Auth: reviewer, reviewee, or review admin. | "seat accountability comments", "list accountability comments" | — |
| PUT | `/reviews/{id}/seat-accountability-comments/{seatId}` | Create or update (upsert) a seat accountability comment (body: comment* (HTML), respondent_type* ("self"\|"reviewer")). respondent_type "self" — reviewee only; "reviewer" — reviewer only. 200 on update, 201 on create. 400 invalid input, 403 unauthorized for respondent_type, 404 review/seat not found. | "save accountability comment", "upsert seat comment", "update seat accountability" | — |

**Review attachment / action-item write authorization** (applies to `POST`/`DELETE /reviews/{id}/attachments`, `POST`/`DELETE /reviews/{id}/action-items`): allowed only for the review's **reviewee**, its **assigned reviewer**, or a **Review Administrator** of the review's organization, and only while the review's status is `in_progress` or `assessed`. Refused for the review's creator (with no other role), the reviewee's direct manager, and anyone outside the organization — always with the flat `403 { "error": { "code": "forbidden", "message": "You do not have access to this review." } }`, which does not say *why* (status vs. standing are indistinguishable from the response). The creator and direct manager can still *read* the review — the write gate is narrower than the view gate. A hidden button in a UI was never the enforcement; a stale client that still renders these controls gets refused server-side regardless.

Review status values: `in_progress`, `assessed`, `signed_off`, `voided`.

ReviewListItem fields: `id`, `user_id` (integer | null — creator ID), `reviewee` (UserSimple), `reviewer` (UserSimple), `status`, `review_type` (integer | null), `template` ({ id, name } | null), `start_date`, `end_date`, `created_at`.

ReviewDetail fields: ReviewListItem + `can_delete` (boolean — whether the current user can delete), `notes`, `void_reason`, `signed_off_at`, `signed_off_initials`, `self_assessment` (Assessment | null), `reviewer_assessment` (Assessment | null), `core_values_ratings` (CoreValuesRatingEntry[]), `gwc_evaluations` (GwcEvaluationEntry[] — defaults to `[]`), `attachments` (Attachment[]), `action_items` (ActionItem[]), `updated_at`.

Assessment fields: `respondent_type` ("self" | "reviewer"), `respondent` (UserSimple), `is_draft` (boolean), `responses` ([{ prompt_id, description, response_value, score }]).

AssessmentSubmitRequest: `respondent_type` ("self" | "reviewer"), `assessment_responses` ([{ prompt_id*, response_value?, score? }]), `core_values_ratings?` ([{ core_value_id*, score*, justification? (string, max 5000 chars, HTML stripped, empty string → null) }]), `gwc_evaluation?` (GwcEvaluationInput — optional, upserts GWC data keyed by respondent_type).

GwcEvaluationEntry fields: `respondent_type` ("self" | "reviewer"), `gets_it_1..3` (boolean | null), `gets_it_verdict` (boolean | null), `wants_it_1..5` (boolean | null), `wants_it_verdict` (boolean | null), `capacity_1..4` (integer | null), `capacity_total` (integer | null — server-computed, sum of capacity_1–4, null if any capacity field null). Reviewer entries hidden from reviewee until review reaches `signed_off` status.

GwcEvaluationInput: same fields as GwcEvaluationEntry except `capacity_total` (read-only, do not send). All fields nullable — partial saves allowed.

ActionItem fields: `id`, `title`, `assignee` (UserSimple), `status`, `created_at`.

Attachment fields: `id`, `file_name`, `file_type`, `file_size`, `url`, `created_at`.

AuditLogEntry fields: `id`, `change_type`, `user` (UserSimple), `description`, `created_at`.

### Review Templates

Templates that define the prompts used in reviews. Access is role-based (`canView`/`canEdit`/`canDelete`): viewers, editors, authors, and contributors can access templates through direct or group-inherited roles. Account admins and team admins retain full access. Permissions can be managed via the standard permissions service with `object_type='ReviewTemplate'`.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/review-templates` | List review templates (params: page, per_page). Returns templates visible to the user through direct or group-inherited roles (viewer, editor, author, contributor) plus team-shared templates. Account admins see all. **Excludes archived templates.** | "show templates", "list review templates", "review forms", "list templates" | — |
| POST | `/review-templates` | Create template (body: name*, target_role?, reviewer_instructions?, owning_organization_id?, shared_with_organization_ids?). Admin on owning organization (team admin or account admin). Organization IDs must be root teams. | "create template", "new review template", "add review form" | — |
| PATCH | `/review-templates/{id}` | Update template (body: name?, target_role?, reviewer_instructions?, shared_with_organization_ids? — replace-all, archived? — boolean to archive/unarchive). owning_organization_id is rejected (400). Requires `canEdit`. Organization IDs must be root teams (422 if sub-team IDs sent). `archived` must be boolean (400 otherwise); idempotent. | "update template", "edit review template", "rename template", "share template", "manage template sharing", "archive template", "unarchive template", "restore template" | — |
| GET | `/review-templates/{id}` | Fetch single template by ID. Returns archived templates (includes `archived` boolean field). | "get template", "fetch template", "view template" | — |
| DELETE | `/review-templates/{id}` | Delete template (permanent). Requires `canDelete` (delegates to `canEdit`) — editor, author, contributor, or org admin. | "delete template", "remove review template" | — |
| POST | `/review-templates/{id}/prompts` | Create assessment prompt (body: description*, answer_type*, hint?, answer_meta_data?). Requires `canEdit` on parent template. | "add prompt", "new question", "add review question" | — |
| PATCH | `/review-templates/{id}/prompts/{pid}` | Update prompt (body: description?, hint?, answer_type?, answer_meta_data?). Requires `canEdit` on parent template. | "update prompt", "edit question", "change prompt" | — |
| DELETE | `/review-templates/{id}/prompts/{pid}` | Delete prompt. Requires `canEdit` on parent template. | "delete prompt", "remove question" | — |
| PUT | `/review-templates/{id}/prompts/positions` | Reorder prompts (body: positions[{id*, position*}]). All prompts must be included. Requires `canEdit` on parent template. | "reorder prompts", "rearrange questions", "sort prompts" | — |
| GET | `/review-templates/{id}/permissions` | List individual user permissions on a template. Returns `{ data: { object_type, object_id, viewers: [{user_id, login, first_name, last_name, profile_photo_thumb_path, role_name}], collaborators: [...] } }`. Requires `canEdit`. | "who has access to template", "list template permissions", "view template roles" | — |
| POST | `/review-templates/{id}/permissions` | Grant a role to a user on a template (body: user_id*, permission_type* — viewer/editor/author/admin). Returns 204. Requires `canEdit`. | "grant template access", "add template permission", "give user access to template" | — |
| DELETE | `/review-templates/{id}/permissions` | Revoke a role from a user on a template (body: user_id*, permission_type? — omit to revoke all roles). Returns 204. Requires `canEdit`. | "revoke template access", "remove template permission", "remove user from template" | — |
| POST | `/review-templates/{id}/copy` | Copy a review template (no request body). Accessible to any user with view access (creator, account admin, owning team member, shared team member). Returns 201 with the new template. Copy name = original + " (Copy)". All prompts duplicated with new IDs. Copy owned by requesting user, starts unshared, never archived. `can_edit` is always true on response. | "copy template", "duplicate review template", "clone template", "make a copy of template" | — |

ReviewTemplateListItem fields: `id`, `name`, `target_role` (string | null), `prompt_count` (integer), `created_at`, `owning_organization` (`{ id, name }` | null), `organization_id` (integer | null — root team ID).

ReviewTemplateDetail fields: `id`, `name`, `target_role`, `reviewer_instructions`, `archived` (boolean — true if archived), `prompts` (AssessmentPrompt[]), `created_at`, `updated_at`, `owning_organization` (`{ id, name }` | null), `shared_with_organizations` (`[{ id, name }]`), `organization_id` (integer | null — root team ID).

422 on POST/PATCH when any organization ID is not a root team: `{ "error": "Organization ID(s) {ids} are not root teams" }`.

AssessmentPrompt fields: `id`, `description`, `hint` (string | null), `answer_type` ("range" | "text" | "textarea" | "boolean" | "multiple"), `answer_meta_data` (object | null), `position` (integer).

## Seats (Accountability Chart)

Seats represent positions on a team's accountability chart. Each seat can have an owner, aligned measures, aligned goals, and URL links. Seats form a hierarchy (parent/child) within a team.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/seats` | Get team accountability chart — full hierarchical tree (params: `include_archived`, `context`). Pass `?context=organization` to resolve the org root from the team ID and return the full org-level seat tree (for accountability charts visible to subteam members); omit for team-scoped results (default). Each node includes `roles` (string[] | null) and `seat_level` ("leadership_team"\|"department"\|"individual_contributor"\|null). | "show org chart", "accountability chart", "team seats", "who does what", "org-level seat tree", "full organization chart" | `/plugins/accountability-chart` |
| GET | `/users/{id}/seats` | Flat list of seats owned by user `id`, scoped to teams the requester can access (teams where requester is a member or admin; others are silently excluded). Returns same `SeatTreeNode` shape as `/teams/{id}/seats` but `children` is always `[]`. Param: `include_archived` (boolean, default false — when true each node has `archived: true`). Errors: 400 (invalid id), 401 (no auth), 404 (user not found). | "seats for user", "what seats does this person own", "user's positions on org chart" | — |
| POST | `/seats` | Create seat (body: name*, team_id or parent_id, accountabilities?, notes?, seat_owner_id?, associated_team_id?). Root requires team_id; child requires parent_id. One root per team. | "create seat", "add position", "new role on chart" | — |
| GET | `/seats/{id}` | Get seat detail (children as SeatSimple, one level deep). Includes `roles`, `seat_level`, and `has_direct_reports` (boolean, computed). | "show seat", "seat details", "position details" | — |
| PATCH | `/seats/{id}` | Update seat (body: name?, accountabilities?, notes?, seat_owner_id?, associated_team_id?, roles?, seat_level?). Owner changes cascade to aligned measures/goals. `roles`: string[] | null, max 5 items, 500 chars each. `seat_level`: "leadership_team"\|"department"\|"individual_contributor"\|null. | "update seat", "rename seat", "change seat owner", "assign seat", "set seat roles", "set seat level" | — |
| DELETE | `/seats/{id}` | Archive seat and all descendants (soft delete). Cannot archive root seat. | "archive seat", "delete seat", "remove position" | — |
| PUT | `/seats/{id}/restore` | Restore archived seat (children remain archived, restore individually) | "restore seat", "unarchive seat", "bring back seat" | — |
| PUT | `/seats/{id}/move` | Re-parent seat (body: parent_id*). Validates no circular refs, same group. Cannot move root. | "move seat", "reparent seat", "reorganize chart" | — |
| POST | `/teams/{id}/seats/scaffold` | Scaffold default accountability chart for a team (empty body). Idempotent — returns 200 with `seats_created: 0` if team already has seats, 201 with seat count and root seat details if created. Seat names depend on framework: EOS uses Visionary/Integrator, all others use CEO/COO-President. | "scaffold seats", "create default org chart", "set up accountability chart", "initialize seats" | — |
| GET | `/seats/{id}/documents` | The seat's uploaded documents (process/playbook materials) — `FileAttachment[]`, empty array if none. Same read access as viewing the seat. Also available in bulk via the `documents` array on each node of `GET /teams/{id}/seats`. | "seat documents", "seat playbook files", "process documents for seat" | — |
| GET | `/seats/{id}/valid-parents` | Valid re-parent targets for this seat — every seat in the team except itself and its own descendants. Requires team admin or seat owner. | "valid parent seats", "where can this seat move", "reparent targets" | — |

Seat fields: `id`, `name`, `accountabilities` (string | null, HTML sanitized), `notes` (string | null, HTML sanitized), `parent` (SeatSimple | null — `{ id, name }` object), `creator` (UserSimple), `seat_owner` (UserSimple | null), `team` (TeamSimple + framework), `associated_team` (TeamSimple | null), `measures` ([{ id, name, description }]), `goals` ([{ id, name, description }]), `links` ([{ id, title, url }]), `children` (Seat[] in tree, SeatSimple[] in detail), `roles` (string[] | null — max 5, 500 chars each; Seat Builder accountability roles), `seat_level` ("leadership_team" | "department" | "individual_contributor" | null), `has_direct_reports` (boolean, computed, only on GET /seats/{id}), `created_at`, `updated_at`.

SeatSimple: `{ id: integer, name: string }`.

### Seat Measures

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/seats/{id}/measures` | List measures aligned to seat. Response includes `chart_type` (string | null), `current_value` (string | null), and `target_value` (string | null) on each measure object. | "seat measures", "show KPIs for seat", "aligned measures" | — |
| PUT | `/seats/{id}/measures` | Align measure to seat (body: measure_id*). Moves alignment if already aligned elsewhere. | "align measure", "add KPI to seat", "link measure" | — |
| DELETE | `/seats/{id}/measures/{measure_id}` | Remove measure alignment | "remove measure", "unlink KPI", "detach measure" | — |

### Seat Goals

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/seats/{id}/goals` | List goals aligned to seat. Response includes `status` (string | null — mapped from `current_state`: `active`, `at_risk`, `off_track`, `complete`, `archived`) and `due_date` (string | null, YYYY-MM-DD) on each goal object. | "seat goals", "show rocks for seat", "aligned goals" | — |
| PUT | `/seats/{id}/goals` | Align goal to seat (body: goal_id*). Moves alignment if already aligned elsewhere. | "align goal", "add rock to seat", "link goal" | — |
| DELETE | `/seats/{id}/goals/{goal_id}` | Remove goal alignment | "remove goal", "unlink rock", "detach goal" | — |

### Seat Links

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/seats/{id}/links` | List URL links on seat | "seat links", "show links", "resources for seat" | — |
| POST | `/seats/{id}/links` | Create link (body: url*, title?). URL must be http/https. Title defaults to URL. | "add link", "attach URL", "add resource" | — |
| PATCH | `/seats/{id}/links/{link_id}` | Update link (body: url?, title?). Set title to null to reset to URL. | "update link", "rename link", "change URL" | — |
| DELETE | `/seats/{id}/links/{link_id}` | Delete link (permanent) | "delete link", "remove link", "remove URL" | — |

SeatLink fields: `id`, `title`, `url`.

### Seat Snapshots

Team admins can save, list, view, update, delete, and revert snapshots of their team's seat hierarchy. Seat edits (PATCH, move, archive, restore) automatically create a pre-change snapshot (non-blocking — seat ops always succeed even if snapshot fails).

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| POST | `/teams/{id}/snapshots` | Create a named snapshot (body: title*, description?) | "save snapshot", "create checkpoint", "save chart state", "backup accountability chart" | — |
| GET | `/teams/{id}/snapshots` | List snapshots for team (newest first) | "list snapshots", "show chart history", "view saved charts", "snapshot history" | — |
| GET | `/teams/{id}/snapshots/{snapshotId}` | Get snapshot detail with full seat data | "show snapshot", "view saved chart", "get checkpoint" | — |
| PATCH | `/teams/{id}/snapshots/{snapshotId}` | Update snapshot title/description | "rename snapshot", "update snapshot", "edit checkpoint" | — |
| DELETE | `/teams/{id}/snapshots/{snapshotId}` | Delete a snapshot | "delete snapshot", "remove checkpoint" | — |
| PUT | `/teams/{id}/snapshots/{snapshotId}/revert` | Revert chart to snapshot (body: create_backup? boolean, **default false**). Archive-and-recreate: archives all current seats and creates new ones from the snapshot data. | "revert chart", "restore snapshot", "undo chart changes", "roll back chart" | — |
| GET | `/snapshots/{id}` | **Flat alias** for `GET /teams/{id}/snapshots/{snapshotId}` — no team id in the path. Same team-admin gate, same `SnapshotDetail` shape. | "show snapshot", "view saved chart" | — |
| PATCH | `/snapshots/{id}` | Flat alias for updating snapshot title/description. **Difference from the team-scoped PATCH: `title` is required here** (the team-scoped version allows either field alone). | "rename snapshot", "update snapshot" | — |
| DELETE | `/snapshots/{id}` | Flat alias for permanently deleting a snapshot. | "delete snapshot", "remove checkpoint" | — |
| POST | `/snapshots/{id}/revert` | Flat alias for reverting — **note the method is POST here, not PUT** as on the team-scoped route. Body: create_backup? boolean, default false. Response: `{ data: { message, backup_snapshot_id } }`. | "revert chart", "restore snapshot" | — |

All snapshot endpoints require team admin. Non-admins receive 403.

Snapshot list fields: `id`, `title`, `description`, `creator_name`, `created_at`.

Snapshot detail adds: `seats` (array of seat objects with `id`, `name`, `description`, `parent_id`, `user_id`, `accountability_owner_id`, `notes`).

Revert response: `{ message, backup_snapshot_id }` — `backup_snapshot_id` present only when `create_backup: true`.

## Team Scorecard Measures

Team scorecard measures are KPIs tracked weekly on a team's scorecard. Each measure can have a target, unit, direction (higher/lower is better), target period, aggregation type, and an optional owner. Weekly history values are recorded against Monday dates.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/measures` | List all measures for a team with weekly history (params: year?, include_archived?, owner_id?). Results sorted ascending by `position`. Resolves inherited scorecards: ask with the team's **own** id and, when that team is configured with a `parent_scoreboard_id`, the ancestor's measures come back (asking with the ancestor's id instead still requires direct membership of the ancestor and 403s for a child-team-only member). Every measure carries `can_edit` and `can_record_value` for the requesting user. | "show scorecard", "list measures", "team KPIs", "team measurables", "scorecard measures", "weekly metrics", "what are our KPIs" | `/components?tab=data` |
| POST | `/teams/{id}/measures` | Create a new measure (body: measure wrapper with name*, unit?, direction?, target_value?, target_period? ("week"\|"month"\|"quarter"\|"year"; default "week"), aggregation_type? ("sum"\|"last"\|"average"; default "sum"), owner_id?, data_source_type? (default 0), roll_up_type? ("sum"\|"average"), roll_up_measure_ids? (integer[]), chart_type? (string — one of: `pie`, `progress_circle`, `progress_bar`, `trend`, `bar_chart`; omit or null for no preference)). Server auto-assigns `position = max(existing) + 1` (or 1 if first). | "add measure", "create KPI", "new measurable", "add scorecard item", "create metric", "set monthly target", "quarterly measure" | — |
| PATCH | `/teams/{id}/measures/reorder` | Persist a new ordering for the team's active scorecard measures. Admin-only. Body: `{ "measure_ids": [int, ...] }` — must be the **complete** ordered list of every active (non-archived) measure ID for the team. Returns `{ "data": { "success": true, "count": N } }`. Statuses: 200 success, 403 non-admin, 422 incomplete/invalid list (missing IDs, duplicates, archived IDs, cross-team IDs, empty array). | "reorder measures", "reorder scorecard", "drag and drop measures", "change measure order", "rearrange KPIs", "sort scorecard measures" | — |
| PATCH | `/measures/{id}` | Update measure fields (body: measure wrapper with name?, unit?, direction?, target_value?, target_period? ("week"\|"month"\|"quarter"\|"year"; omit to preserve, null rejected), aggregation_type? ("sum"\|"last"\|"average"; omit to preserve, null rejected), archived?, notes? (string\|null — sanitized HTML; omit to preserve, send null to clear), data_source_type?, roll_up_type? ("sum"\|"average"), roll_up_measure_ids? (integer[]), chart_type? (string — one of: `pie`, `progress_circle`, `progress_bar`, `trend`, `bar_chart`; omit key to preserve, send null to clear)). Use `archived: true` to soft-archive, `archived: false` to restore. | "update measure", "rename KPI", "change target", "edit measurable", "restore measure", "add measure notes", "set measure description notes", "clear measure notes", "set monthly target", "change measure period", "set aggregation", "make this a last-value measure" | — |
| DELETE | `/measures/{id}` | Archive a measure (soft-delete, idempotent). Sets is_archived=true. | "archive measure", "delete KPI", "remove measurable", "hide measure" | — |
| POST | `/measures/{id}/history` | Record a weekly or monthly value for a measure (body: date*, value*, period?). `period` is optional: `"week"` (default, date must be a Monday) or `"month"` (date as `YYYY-MM` or `YYYY-MM-01`, response normalises to `YYYY-MM-01`). Omitting `period` defaults to weekly — fully backward-compatible. Upserts by (measure_id, date). | "record value", "log KPI", "enter score", "record measurable", "update scorecard value", "fill in weekly number", "record monthly value", "log monthly score", "enter monthly measure", "monthly scorecard entry" | — |
| POST | `/measures/{id}/history/note` | Record or clear a per-week text note on a history slot (body: date*, note — string ≤255 chars or null/empty to clear). Upserts; clearing a slot with no note is a no-op. | "add note", "record note", "annotate week", "note this week", "clear note", "remove note", "weekly note" | — |
| POST | `/teams/{id}/measures/shared` | Add a measure that is **defined on another team** onto this team's scorecard (body: measure_id*) — the "Re-use Existing" action. Not a copy: same measure, same weekly values on every board that shows it; recording a value on any board changes it everywhere. Source team can be any other team (parent, ancestor, child, or sibling — not restricted to ancestors). If this team inherits its scorecard (`parent_scoreboard_id`), the row is added to that ancestor's board instead — send this team's own id regardless. Requires edit rights on the team whose board changes AND view rights on the measure being added (stricter than the legacy endpoint). 201 when a new row was created, 200 when the board already showed it (repeat call or already-owned) — both are success with an identical body. Returns the measure in the same shape as a `GET /teams/{id}/measures` element. | "share measure with team", "reuse existing measure", "add measure from another team", "put another team's KPI on this scorecard" | — |
| DELETE | `/teams/{id}/measures/shared/{measure_id}` | Remove a shared measure from **this team's scorecard only** (detaches the inclusion — the measure, its owner, its values, and its place on the owning team's board are untouched). Requires edit rights on the team whose board changes; view rights on the measure are NOT required. 404 if this scorecard has no such shared measure. **Gate offering this action on the row's `can_unshare` field — never on `is_shared`** (see below). Returns `{ "data": { "removed": true } }`. | "remove shared measure", "unshare measure", "take measure off this scorecard", "detach shared KPI" | — |
| GET | `/measures/{id}/change-log` | Full change-log feed for one measure, newest first, not paginated (param: category? — `value`\|`settings`\|`connection`, unrecognized value ignored). `meta.counts` (`{ all, value, settings, connection }`) is always computed over the FULL feed regardless of the category filter. Visibility follows the measure's owner (its team or its goal). | "measure history", "change log for KPI", "who changed this measure", "value change history" | — |
| POST | `/measures/{id}/data-source` | Attach a measure to an account Connection, or detach it back to manual entry (body: connection_id? — required unless detaching; data_source_type? — send `0` alone to detach; spreadsheet_id?/sheet_tab?/cell_ref? — Google Sheets only; value_field?/aggregation? — custom-endpoint only; schedule? — default `weekly`). Gated by the normal measure-edit rule, not the account-connection-admin gate. No backfill on attach — history starts at the next scheduled pull. `data_source_type` on the response follows the connection's provider: `1` (google_sheets) for a `google-sheet` connection, `2` (other_api) for any other, `0` when detaching — the caller does not choose this. `cell_ref` must be a single A1 cell (`B2`); a range (`B2:B10`, `B:B`) is rejected with 422. A Sheets cell showing `47%` is stored/returned already scaled to `47` — do not scale again. | "connect measure to spreadsheet", "attach measure to data source", "sync KPI from Google Sheets", "detach measure from connection", "switch measure back to manual" | — |

Measure fields: `id`, `name`, `description` (string | null), `notes` (string | null — sanitized HTML, present on all measure responses; null if not set), `unit` (string, e.g. `"#"`, `"$"`, `"%"`), `direction` (`"higher"` | `"lower"`), `target_value` (numeric string | null), `target_period` (`"week"` | `"month"` | `"quarter"` | `"year"` — the time period that `target_value` applies to; default `"week"`), `aggregation_type` (`"sum"` | `"last"` | `"average"` — how weekly values combine when rolled up for display; `"sum"` adds, `"last"` takes the most recent, `"average"` takes the mean; default `"sum"`), `position` (integer — display order, ascending; use reorder endpoint to change), `owner` (UserSimple | null), `is_archived` (boolean), `chart_type` (string | null — one of: `pie`, `progress_circle`, `progress_bar`, `trend`, `bar_chart`; null = no preference), `histories` (MeasureHistory[]), `data_source_type` (integer, always present: 0=manual, 1=google_sheets, 2=other_api, 3=roll_up — type 2 is stored but unimplemented, so don't offer it as a working source), `can_edit` (boolean), `can_record_value` (boolean).

**Rights fields** (`can_edit`, `can_record_value`) are on every measure returned by `GET /teams/{id}/measures` and `POST /teams/{id}/measures`. Both are always present, never null, and fail closed to `false`. They are computed per measurable **and per requesting user**, against the team that **owns** the measurable — so on an inherited scorecard the owner reads `true` while an admin of the merely inheriting team reads `false` (admin rights cascade downward, not upward). `can_edit` answers "would `PATCH /measures/{id}` be accepted" — the definition: name, goal, unit. `can_record_value` answers "would `POST /measures/{id}/history` be accepted". `can_edit` implies `can_record_value`, never the reverse; the gap between them is exactly one population — plain members of the owning team, who may enter values on their own scorecard but may not rename or re-goal a measurable. Gate value entry on `can_record_value`, never on `can_edit`.

| Requester | `can_edit` | `can_record_value` |
|---|---|---|
| Owner / creator / admin of the owning team | `true` | `true` |
| Plain member of the **owning** team | `false` | **`true`** |
| Plain member of a **child** team that inherits the scorecard | `false` | `false` |
| Team admin of the **child** team, not the owner | `false` | `false` |

**Inclusion / sharing fields** (on every `GET /teams/{id}/measures` and `POST .../measures` / `POST .../measures/shared` element — i.e. `ScorecardMeasure`; **absent from the `PATCH`/`DELETE /measures/{id}` response**, which uses the separate `ScorecardMeasureNoHistory` shape that does not carry them): `is_shared` (boolean — this row reaches THIS board through an inclusion; display only), `owning_team` (`{ id, name }` | null — the team the measurable is DEFINED on, not necessarily the team in the path; null when not team-scoped or unresolvable), `can_unshare` (boolean — whether "Remove from this scorecard" applies to this row for the requesting user). All three always present on `ScorecardMeasure`, fail closed (`false`/`false`/`null`).

**Gate removal on `can_unshare`. Never on `is_shared`.** A measurable can be BOTH owned by a board and included on it (production has such rows, from before an `alreadyOwned` guard existed) — `is_shared` is `true` for them, but removing the inclusion is then a silent no-op because ownership still puts the row on the board. `can_unshare` already accounts for this (true only when the row is an inclusion, the board doesn't also own the measurable, and the caller passes the team-admin gate `DELETE /teams/{id}/measures/shared/{measure_id}` enforces) — that's the field that separates the two verbs in a row menu: `can_unshare` → `DELETE /teams/{id}/measures/shared/{measure_id}` (detaches another team's measurable from this board only); `can_edit` → `DELETE /measures/{id}` (archives a measurable this team OWNS, on every board showing it).

Roll-up fields (present in responses only when `data_source_type=3`): `roll_up_type` (`"sum"` | `"average"`), `roll_up_measure_ids` (integer[] — IDs of source measures; create/update requires same-team IDs, 422 cross-team), `roll_up_measures` (array, read-only — each source enriched with `id`, `name`, `team_id`, `team_name`, `is_archived`, so the "what rolls up" list renders from this response alone even when a source is archived).

**Data-connection fields** (present when the measure is attached to a Connection): `source_name` (string | null — name of the Connection this measure pulls from), `connection_status` (`"connected"` | `"needs_attention"` | null — `needs_attention` means the last pull failed), `last_synced_at` (ISO 8601 datetime | null), `google_sheet` (`{ spreadsheet_id, tab, cell }` | present only when `data_source_type=1` — note the stored/returned keys are `tab`/`cell`, not the request body's `sheet_tab`/`cell_ref`). No credential is ever stored or returned on the measure.

Google Sheets fields (present in responses only when `data_source_type=1`): `google_sheet` (`{ spreadsheet_id, tab, cell, connected_user_id }` — `connected_user_id` is an internal user id, **not a credential**; no Google token is ever returned by any endpoint), `sync_state` (`{ last_sync_at, last_sync_status: "success" | "error", last_sync_error, last_sync_error_message }` — absent until a first pull has been attempted; the two error fields are absent on success). Flag a measure whose `sync_state.last_sync_status` is `"error"` and show `last_sync_error_message`. Two traps worth stating: the Google connection is **per-user** — the sync reads with the credentials of whoever bound the measure, so if that person leaves or revokes access the team's measure stops updating and reports `connection_lost`; and a cell displaying `47%` is stored by Google as `0.47` but returned and recorded here as **47** with `is_percent: true` — already scaled, do not scale again. A failed pull leaves the week empty — no fabricated value, no carry-forward. Manual entry on a type-1 measure is still rejected (422).

MeasureHistory fields: `id` (integer | null — null if no value recorded), `date` (YYYY-MM-DD, always a Monday), `value` (numeric string | null), `target_value` (numeric string | null), `note` (string | null — null if no note recorded for this slot).

**Response envelopes**:
- `GET /teams/{id}/measures` → `{ "data": Measure[], "meta": { "year": int, "date_range": { "start": string, "end": string } } }` — returns 52 weekly history slots per year per measure
- `POST /teams/{id}/measures` → `{ "data": Measure }` (201, histories is empty array, includes `position`)
- `PATCH /teams/{id}/measures/reorder` → `{ "data": { "success": true, "count": N } }` (200)
- `PATCH /measures/{id}` → `{ "data": Measure }` (200, no histories field, no is_shared/can_unshare/owning_team)
- `DELETE /measures/{id}` → `{ "data": Measure }` (200, is_archived: true, no histories field, no is_shared/can_unshare/owning_team)
- `POST /measures/{id}/history` → `{ "data": { "id": int, "measure_id": int, "date": string, "value": string, "target_value": string | null, "period": "week" | "month" } }` (200, upsert; for monthly entries `date` is always normalised to `YYYY-MM-01`)
- `POST /measures/{id}/history/note` → `{ "data": { "id": int|null, "measure_id": int, "date": string, "note": string|null } }` (200, upsert; id is null when note is cleared)
- `POST /teams/{id}/measures/shared` → `{ "data": Measure }` (201 created / 200 already on board)
- `DELETE /teams/{id}/measures/shared/{measure_id}` → `{ "data": { "removed": true } }` (200)
- `GET /measures/{id}/change-log` → `{ "data": MeasureChangeLogEntry[], "meta": { "counts": { "all", "value", "settings", "connection" } } }`. Entry fields: `id`, `category` (`value`\|`settings`\|`connection`), `action` (string), `actor_user_id` (integer | null — null for a sync, not a person), `source_name` (string | null), `week_interval` (string | null), `old_value`/`new_value` (string | null), `is_override` (boolean — a person overwrote a connection-pulled value), `created_at`.
- `POST /measures/{id}/data-source` → `{ "data": { "measure_id", "connection_id" (absent when detaching), "data_source_type": 0\|1\|2 } }` (200)

**Validation**: `name` must not be blank (422). `value` must be a numeric string (422). `date` must be a valid ISO date (Monday preferred). `direction` must be `"higher"` or `"lower"`. `target_period` must be one of `"week"`, `"month"`, `"quarter"`, `"year"` (422 for any other value, including null); omitting on PATCH preserves the stored value. `aggregation_type` must be one of `"sum"`, `"last"`, `"average"` (422 for any other value, including null); omitting on PATCH preserves the stored value. `data_source_type` must be 0–3 (422 otherwise). `chart_type` must be one of `pie`, `progress_circle`, `progress_bar`, `trend`, `bar_chart` or null if provided (422 otherwise); omitting the key on PATCH preserves the existing value. For roll-up measures (`data_source_type=3`): `roll_up_type` must be `"sum"` or `"average"` (422); `roll_up_measure_ids` must all belong to the same team (422 cross-team); a measure may not include itself in `roll_up_measure_ids` (422 self-reference); circular references (A→B→A) return 422. For `POST /measures/{id}/data-source`: 422 when `connection_id` is missing/not in the measure's account; `spreadsheet_id` is neither a bare ID nor a Google Sheets URL; `sheet_tab` is missing alongside `spreadsheet_id`; or `cell_ref` is missing or not a single cell.

## Strategy & Targets

### Strategy Tree (read-only, all frameworks)

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/targets` | Get team strategy tree (params: year?, quarter? — default current; use `"All"` or `0` for all) | "show strategy", "strategy tree", "goals and rocks", "team objectives", "OKRs", "V2MOM", "show rocks", "annual goals", "quarterly priorities", "show targets" | `/components?tab=traction` |

TargetResponse: `{ "data": { "framework": string, "targets": TargetNode[], "unaligned": TargetNode[] } }`

TargetNode fields: `id`, `name` (string | null), `description` (string | null), `status` (active | complete | archived | deferred | review | draft | cancelled | at_risk | off_track), `object_type` (yearly_goal | rock | focus_area | objective | key_result | milestone | action), `type` (integer for Goals: 0=objective/WIG, 1=rock, 2=yearly; string for Items: KeyResult, ResultArea), `color` (string | null), `assignees` (TargetAssignee[]), `creator` (TargetAssignee | null), `due` (YYYY-MM-DD | null), `children` (TargetNode[]), `inherited` (boolean), `inherited_from` ({ team_id, team_name } | null), `can_edit` (boolean — server-computed edit permission for the current user reflecting cascade rules: rocks include parent-goal cascade, milestones include parent-rock cascade; always present on every node at every depth; inherited nodes always `false`).

TargetAssignee fields: `id`, `first_name` (string | null), `last_name` (string | null).

**Supported frameworks**: EOS, OKR, 4DX. SRT and V2MOM are **not yet supported** (returns 400 error).

**GET filtering rules**: EOS: yearly goals by `year`, rocks by `quarter` (persistent active rocks always included, realized persistent excluded). OKR: focus areas included if they have qualifying children, objectives "pulled up" if any child key result is in range. 4DX: same as OKR for L1-L3, actions filtered by year/quarter.

**Inherited nodes**: Nodes with `inherited: true` come from a parent team and are read-only. `inherited_from` contains the source `team_id` and `team_name`.

### Goals — Yearly

**EOS restriction**: POST endpoints return `422 Unprocessable Entity` with message "This endpoint is only available for EOS teams" when called against a non-EOS team. **GET is available for all team types** (EOS restriction removed as of 2026-04-16).

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/goals` | List yearly goals (params: year?) — available for all team types | "list goals", "show yearly goals", "annual goals", "1-year goals" | `/components?tab=traction` |
| POST | `/teams/{id}/goals` | Create a yearly goal (body: name*, achieve_by?, assignee_ids?) — EOS teams only | "create goal", "add yearly goal", "new annual goal" | `/components?tab=traction` |
| PATCH | `/goals/{id}` | Update a yearly goal (body: name?, description?, status?, achieve_by?, assignee_ids?) | "update goal", "rename goal", "mark goal complete", "change goal status" | — |
| DELETE | `/goals/{id}` | Archive a yearly goal | "archive goal", "delete goal", "remove goal" | — |

**Goal response shape** (verified via curl 2026-03-18):
```json
{
  "data": {
    "id": 3645,
    "name": "Hit $10M ARR",
    "description": null,
    "status": "active",
    "type": "yearly_goal",
    "achieve_by": "2026-12-31",
    "color": null,
    "is_visible_to_team": true,
    "assignees": [{"id": 5, "login": "", "first_name": "Alice", "last_name": "Smith", "profile_photo_thumb_path": null}],
    "creator": {"id": 5, "login": "", "first_name": "Alice", "last_name": "Smith", "profile_photo_thumb_path": null},
    "created_at": "2026-01-15T10:00:00.000Z",
    "updated_at": "2026-01-15T10:00:00.000Z"
  }
}
```

**Response envelopes**:
- `GET /teams/{id}/goals` → `{ "data": [Goal], "meta": { page, per_page, total, total_pages } }` (200)
- `POST /teams/{id}/goals` → `{ "data": Goal }` (201)
- `PATCH /goals/{id}` → `{ "data": Goal }` (200)
- `DELETE /goals/{id}` → `{ "data": Goal }` (200, status: "archived")

### Rocks — Quarterly (EOS only)

All rock endpoints return `422 Unprocessable Entity` for non-EOS teams.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/rocks` | List quarterly rocks (params: year?, quarter?, parent_id?). Each rock includes `aligned_measurables` array (may be empty). | "list rocks", "show rocks", "quarterly rocks", "90-day priorities" | `/components?tab=traction` |
| POST | `/teams/{id}/rocks` | Create a rock (body: name*, parent_id?, assignee_ids?). **Permissions**: team admin, OR any member who can edit the parent 1-yr goal (when `parent_id` is set). No `parent_id` → admin-only. | "create rock", "add rock", "new quarterly rock" | `/components?tab=traction` |
| PUT | `/rocks/{id}` | Align rock to a yearly goal (body: parent_id*). **Permissions**: creator, assignee, team admin, or member who can edit the parent 1-yr goal. | "align rock to goal", "link rock", "move rock under goal" | — |
| PATCH | `/rocks/{id}` | Update a rock (body: name?, description?, status?, assignee_ids?). **Permissions**: creator, assignee, team admin, or member who can edit the parent 1-yr goal. | "update rock", "rename rock", "mark rock complete", "change rock status" | — |
| DELETE | `/rocks/{id}` | Archive a rock. **Permissions**: creator, assignee, team admin, or member who can edit the parent 1-yr goal. | "archive rock", "delete rock", "remove rock" | — |
| GET | `/rocks/{id}/alignments` | List scorecard measurables aligned to a rock, ordered by position | "rock alignments", "rock measurables", "linked measurables for rock" | — |
| POST | `/rocks/{id}/alignments` | Link a rock to a scorecard measurable (body: measurable_id*). Returns 409 if already linked, 422 if measurable archived | "link rock to measurable", "align rock to scorecard", "connect rock to measurable" | — |
| DELETE | `/rocks/{id}/alignments/{alignment_id}` | Remove a rock–measurable alignment. Returns 204 No Content. Requires edit access to the rock. | "remove rock alignment", "unlink rock from measurable", "detach rock measurable" | — |
| GET | `/rocks/{id}/attachments` | List a rock's file attachments, newest first (`{ attachments: FileAttachment[] }`). Requires view permission. | "rock attachments", "files on this rock" | — |
| POST | `/rocks/{id}/attachments` | Upload a file attachment to a rock (multipart: file*, name?, description?) — what an image pasted into the rock's description is uploaded through. Max 4.5 MB. Requires edit permission. Returns FileAttachment (`material_id` here is a GoalMaterial id — rocks are goals). | "upload rock attachment", "attach file to rock" | — |
| DELETE | `/rocks/{id}/attachments/{materialId}` | Delete a rock's file attachment (`materialId` = the FileAttachment's `material_id`). Scoped to rocks — do not reuse `DELETE /attachments/{id}`, which takes an ItemMaterial id from a separate id space. Requires edit permission. | "delete rock attachment", "remove file from rock" | — |
| GET | `/rocks/{id}/audience` | Read who can see a **personal** rock: owner-set `people`/`teams`/`organizations` grants (additive, independent — "just you" when all three are empty) plus `derived_viewers` the owner cannot revoke (whoever assigned the rock; the other participant of a 1:1 while aligned into it). **Owner only** — a non-owner, a team rock (no audience concept), and a nonexistent rock all return the same 404, never 403, so a personal rock's existence is never disclosed to anyone but its owner. | "who can see this rock", "rock audience", "personal rock visibility" | — |
| PUT | `/rocks/{id}/audience` | Set a personal rock's audience (body: people?/teams?/organizations? — integer[] each; a list this body **omits** is left unchanged, only lists it names are replaced; send all three as `[]` to clear to "just you"). `organizations` accepts any team id in the org, normalized to the org's root team before storage. Owner cannot name themselves in `people` (422). Owner only — same 404-for-everyone-else as GET. | "set rock audience", "share personal rock", "open up my rock", "make rock private" | — |
| GET | `/teams/{id}/personal-rocks` | The Traction "Personal Rocks" sub-tab (distinct from `GET /teams/{id}/rocks`, the team-rocks sub-tab): this team's people's PERSONAL rocks, grouped one entry per person — the caller's own group first, flagged `is_viewer`. Which rocks show is governed per-rock by the owner's audience/derived access (same rules as `GET /rocks/{id}/audience`); team membership alone grants nothing, and team admin grants nothing extra. A teammate the caller can see nothing of produces no entry at all. Params: year? (default current), quarter? (1–4, default current). | "personal rocks", "team's personal rocks tab", "everyone's personal rocks" | `/components?tab=traction` |
| POST | `/teams/{id}/rocks/carry-forward` | Batch-copy incomplete rocks (and their incomplete child milestones) from a closing quarter into the next quarter as brand-new active rocks (body: rock_ids* — integer[], non-empty; from* — `{year, quarter}`; to? — `{year, quarter}`, defaults to the quarter after `from`, Q4→Q1 next year). Originals untouched. Atomic — any ineligible rock (complete/archived/wrong team/wrong quarter) 422s the whole batch, nothing created. Copies preserve name/description/owners, start with no health/color/completion history, `achieve_by` = end of target quarter. Carrying the same rock+from-quarter into the same target quarter twice is refused (422, names the conflict) — but a different target quarter, or a never-carried rock, still succeeds. Team admin only. Returns `{ data: { carried: [{ source_rock_id, new_rock_id, milestone_count }] } }` (201). | "carry rocks forward", "roll incomplete rocks to next quarter", "carry forward rocks" | `/components?tab=traction` |

**Rock response shape** (verified via curl 2026-03-18):
```json
{
  "data": {
    "id": 3646,
    "name": "Launch enterprise tier",
    "description": null,
    "status": "active",
    "type": "rock",
    "achieve_by": "2026-03-31",
    "color": null,
    "is_visible_to_team": true,
    "assignees": [],
    "creator": {"id": 5, "login": "", "first_name": "Alice", "last_name": "Smith", "profile_photo_thumb_path": null},
    "created_at": "2026-01-15T10:00:00.000Z",
    "updated_at": "2026-01-15T10:00:00.000Z",
    "parent_id": 3645,
    "persist_until_cleared": false
  }
}
```

**Rock list includes `aligned_measurables`** on every rock (added 2026-04-24):
```json
"aligned_measurables": [
  {
    "alignment_id": 7,
    "measurable_id": 42,
    "name": "Monthly Recurring Revenue",
    "current_value": "85000",
    "target_value": "100000",
    "unit_measure_id": 3
  }
]
```
Field is always present (empty array `[]` when no alignments exist). Applies to `GET /teams/{id}/rocks` and `GET /users/{id}/rocks`.

**Rock alignment response shape** (POST /rocks/{id}/alignments → 201):
```json
{
  "id": 7,
  "rock_id": 5,
  "measure_id": 42,
  "position": 1,
  "measurable": {
    "id": 42,
    "name": "Monthly Recurring Revenue",
    "current_value": "85000",
    "target_value": "100000",
    "unit_measure_id": 3
  },
  "created_at": "2026-04-23T12:00:00.000Z",
  "updated_at": "2026-04-23T12:00:00.000Z"
}
```

**Response envelopes**:
- `GET /teams/{id}/rocks` → `{ "data": [Rock], "meta": { page, per_page, total, total_pages } }` (200)
- `POST /teams/{id}/rocks` → `{ "data": Rock }` (201)
- `PUT /rocks/{id}` → `{ "data": Rock }` (200)
- `PATCH /rocks/{id}` → `{ "data": Rock }` (200)
- `DELETE /rocks/{id}` → `{ "data": Rock }` (200, status: "archived")
- `GET /rocks/{id}/alignments` → array of alignment records (200)
- `POST /rocks/{id}/alignments` → alignment record (201); 409 already linked; 422 archived measurable
- `DELETE /rocks/{id}/alignments/{alignment_id}` → 204 No Content

### Milestones (EOS only)

All milestone endpoints return `422 Unprocessable Entity` for non-EOS teams.

**Known bug**: `GET /teams/{id}/milestones?year=&quarter=` returns incorrect results. Use `?parent_id=ROCK_ID` instead for accurate filtering.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/milestones` | List milestones (params: parent_id? — **recommended**; year?, quarter? — **avoid, known bug**) | "list milestones", "show milestones", "deliverables" | `/components?tab=traction` |
| POST | `/teams/{id}/milestones` | Create a milestone (body: name*, parent_id?, due?). **Permissions**: team admin, OR any member who can edit the parent rock (when `parent_id` is set). No `parent_id` → admin-only. | "create milestone", "add milestone", "new deliverable" | `/components?tab=traction` |
| PUT | `/milestones/{id}` | Align milestone to a rock (body: parent_id*). **Permissions**: creator, assignee, team admin, or member who can edit the parent rock. | "align milestone to rock", "link milestone", "move milestone under rock" | — |
| PATCH | `/milestones/{id}` | Update a milestone (body: name?, description?, status?, due?). **Permissions**: creator, assignee, team admin, or member who can edit the parent rock. | "update milestone", "rename milestone", "mark milestone complete" | — |
| DELETE | `/milestones/{id}` | Archive a milestone. **Permissions**: creator, assignee, team admin, or member who can edit the parent rock. | "archive milestone", "delete milestone", "remove milestone" | — |
| POST | `/milestones/{id}/reorder` | Reorder a milestone within its parent rock (body: position*). **Permissions**: keyed off the **parent rock** — requires ability to edit the rock (not just the milestone). 403 if caller cannot edit the parent rock. | "reorder milestone", "move milestone", "change milestone order" | — |

**Milestone response shape** (verified via curl 2026-03-18):
```json
{
  "data": {
    "id": 79874,
    "name": "Sign 3 enterprise customers",
    "description": null,
    "status": "active",
    "type": "milestone",
    "due": "2026-03-31",
    "color": null,
    "parent_id": 3646,
    "assignees": [],
    "creator": {"id": 5, "login": "", "first_name": "Alice", "last_name": "Smith", "profile_photo_thumb_path": null},
    "created_at": "2026-03-17T10:00:00.000Z"
  }
}
```

Note: Milestone responses do NOT include `updated_at`.

**Response envelopes**:
- `GET /teams/{id}/milestones` → `{ "data": [Milestone], "meta": { page, per_page, total, total_pages } }` (200)
- `POST /teams/{id}/milestones` → `{ "data": Milestone }` (201)
- `PUT /milestones/{id}` → `{ "data": Milestone }` (200)
- `PATCH /milestones/{id}` → `{ "data": Milestone }` (200)
- `DELETE /milestones/{id}` → `{ "data": Milestone }` (200, status: "archived")

### EOS Hierarchy

- **Goals** are root-level (no parent)
- **Rocks** align to goals via `parent_id`
- **Milestones** align to rocks via `parent_id`

**Authorization**: Root-level creation requires team admin. Child creation requires team admin or node-level assignment on the parent (assignee of the parent or any ancestor).

### Team Vision (cross-framework)

Universal vision endpoint that returns framework-appropriate vision data for any team. Use this instead of `/eos-vision` when the team's framework is unknown or when building framework-agnostic views (e.g. TBR report).

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/vision` | Get framework-appropriate vision data (works for EOS, OKR, 4DX, and others). Response: `{ data: { framework, framework_supported, vision, mission, core_values, eos_vision } }`. `framework_supported` is `true` for EOS/OKR/4DX, `false` for V2MOM/SRT/Pinnacle/unknown. `vision`/`mission`/`core_values` present when supported. `eos_vision` non-null for EOS only (full V/TO composite). `core_values` ordered by position. Errors: 400 non-numeric ID, 403 not a team member, 404 team not found. | "team vision", "show vision", "vision and mission", "core values", "strategic direction", "what's our vision", "team mission" | — |
| PATCH | `/teams/{id}/vision` | Create or update vision and mission (merge semantics — omitted fields unchanged). Body: `{ vision?: { purpose?, description? }, mission?: { name?, description? } }` — at least one of `vision` or `mission` required. Response: `{ success: true, data: { vision: { id, purpose, description }, mission: { id, name, description } } }`. Creates records if absent; all strings HTML-sanitized. Errors: 400 empty body/empty sub-object, 403 not team admin or team inherits parent vision, 404 team not found. | "update vision", "set mission", "save vision", "write vision", "update mission", "set our vision", "edit vision description", "update vision purpose" | — |
| GET | `/teams/{id}/vision-builder/answers` | Retrieve saved Vision Builder questionnaire answers. Response: `{ success: true, data: { answers: { prompt_key: "answer", ... } } }`. Returns `answers: null` when no answers saved yet. Auth: team member. | "get vision builder answers", "vision questionnaire answers", "saved vision answers", "vision builder progress" | — |
| PUT | `/teams/{id}/vision-builder/answers` | Save Vision Builder questionnaire answers (full replacement — previous blob is completely replaced). Body: `{ answers: { prompt_key: "answer", ... } }` — `answers` required, must be an object; use `{}` to clear all. Response: `{ success: true, data: { answers: { ... } } }`. All strings HTML-sanitized. Auth: team admin. Errors: 400 missing/non-object answers, 403 not admin or parent vision block. | "save vision builder answers", "store vision answers", "update vision questionnaire", "save vision builder progress", "clear vision answers" | — |

**Framework behaviour**:

| Framework | `framework_supported` | `vision` | `mission` | `core_values` | `eos_vision` |
|-----------|----------------------|----------|-----------|---------------|--------------| 
| `eos` | `true` | from DB | from DB | from labels | full composite |
| `okr` | `true` | from DB | from DB | from labels | `null` |
| `4dx` | `true` | from DB | from DB | from labels | `null` |
| `v2mom` / `srt` / other | `false` | `null` | `null` | `[]` | `null` |

### EOS Vision (V/TO)

The Vision/Traction Organizer (V/TO) covers six EOS components: core values, core focus (purpose/niche), BHAG (10-year target), marketing strategy, three-year picture, and year/quarter plans.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/eos-vision` | Get complete V/TO (all 6 sections in one call) | "show vision", "show V/TO", "vision traction organizer", "EOS vision", "show the VTO" | `/vision` |
| GET | `/teams/{id}/core-values` | List core values | "show core values", "list core values", "our values" | `/vision` |
| POST | `/teams/{id}/core-values` | Create core value (body: name*, description?) | "add core value", "create core value", "new value" | `/vision` |
| PATCH | `/core-values/{valueId}` | Update core value (body: name?, description?) — standalone, no team prefix | "update core value", "edit value", "rename value" | — |
| DELETE | `/core-values/{valueId}` | Delete core value — standalone, no team prefix | "delete core value", "remove value" | — |
| GET | `/teams/{id}/eos-core-values` | **Deprecated** (`deprecated: true` in the spec) — framework-neutral duplicate sharing the same handler as `GET /teams/{id}/core-values` above. Use the non-`eos-` path. | "show core values" | `/vision` |
| POST | `/teams/{id}/eos-core-values` | **Deprecated** — duplicate of `POST /teams/{id}/core-values` above, same handler. Use the non-`eos-` path. | "add core value" | `/vision` |
| PATCH | `/eos-core-values/{valueId}` | **Deprecated** — duplicate of `PATCH /core-values/{valueId}` above, same handler, no team prefix. Use the non-`eos-` path. | "update core value" | — |
| DELETE | `/eos-core-values/{valueId}` | **Deprecated** — duplicate of `DELETE /core-values/{valueId}` above, same handler, no team prefix. Use the non-`eos-` path. | "delete core value" | — |
| GET | `/teams/{id}/eos-core-focus` | Get core focus (purpose + niche) | "show core focus", "what's our purpose", "our niche" | `/vision` |
| PATCH | `/teams/{id}/eos-core-focus` | Update core focus (body: purpose?, niche?) | "update core focus", "set purpose", "change niche" | `/vision` |
| GET | `/teams/{id}/eos-bhag` | Get BHAG (10-year target) | "show BHAG", "10-year target", "big hairy audacious goal" | `/vision` |
| PATCH | `/teams/{id}/eos-bhag` | Update BHAG (body: text*) | "update BHAG", "set 10-year target", "change BHAG" | `/vision` |
| GET | `/teams/{id}/eos-marketing-strategy` | Get marketing strategy | "show marketing strategy", "target market", "our uniques", "proven process", "guarantee" | `/vision` |
| PATCH | `/teams/{id}/eos-marketing-strategy` | Update marketing strategy (body: targetMarket?, uniques?, provenProcess?, guarantee?) | "update marketing strategy", "set target market", "change uniques" | `/vision` |
| GET | `/teams/{id}/eos-three-year-picture` | Get three-year picture | "show three-year picture", "3-year picture", "where we'll be in 3 years" | `/vision` |
| PATCH | `/teams/{id}/eos-three-year-picture` | Update three-year picture (body: description?, futureDate?, revenue?, profit?, measurables?) | "update three-year picture", "set 3-year picture" | `/vision` |
| GET | `/teams/{id}/eos-plans` | Get all year/quarter plans | "show plans", "annual plan", "quarterly plan", "year plans" | `/team-rhythm-quarterly` |
| GET | `/teams/{id}/eos-plans/{year}` | Get plans for a specific year | "show 2026 plans", "plans for this year" | `/team-rhythm-quarterly` |
| GET | `/teams/{id}/eos-plans/{year}/{quarter}` | Get specific quarter plan (quarter: 0=annual, 1-4=Q1-Q4) | "show Q1 plan", "annual plan for 2026" | `/team-rhythm-quarterly` |
| PATCH | `/teams/{id}/eos-plans/{year}/{quarter}` | Update year/quarter plan (body: text, date, revenue, profit, measures — all string or null) | "update Q1 plan", "set annual plan", "change quarterly plan" | `/team-rhythm-quarterly` |
| GET | `/teams/{id}/eos-plans/{year}/{quarter}/history` | Full write-log for this quarter's plan, newest first — one entry per field a save actually changed (a two-field save = two entries sharing author+timestamp; a no-op save appears not at all). Readable by anyone who can READ the plan (not edit-gated). Inheriting team reads the parent's history. Not paginated. Returns `{ data: PlanHistoryEntry[], meta: { count } }`. | "plan version history", "quarter plan history", "who changed the plan" | `/team-rhythm-quarterly` |
| POST | `/teams/{id}/eos-plans/{year}/{quarter}/history/{entryId}/restore` | Roll the quarter's plan back to a captured history entry, appending a new "restore" history entry (deletes nothing — later writes stay in history, so a restore can itself be undone). Restoring the current entry is a harmless no-op. No body. Same edit right as PATCHing the plan. Returns the plan's resulting fields (`EosPlanEntry`). | "restore plan version", "revert quarter plan", "undo plan change" | `/team-rhythm-quarterly` |
| POST | `/teams/{id}/eos-plans/{year}/{quarter}/suggestions` | Run one read-only AI suggestion pass over a **draft** quarter plan (quarter 1–4 only — quarter 0/annual is rejected with 400). Reads the immediately-prior closing quarter's Scorecard, Rocks, Issues list and previous-session notes (`sources`, always 4 rows, honestly reported even when empty) and returns an `insight` line plus zero or more `suggestions` (each anchored to a plan field). **Writes nothing** — no history entry, not persisted, private to the caller. Accepting a suggestion is an ordinary `PATCH` of the plan with `via_ai: true` in the body (tags the resulting history entry); dismissing sends nothing. Same edit right as PATCHing the plan. 502/503 (with a `telemetry` sibling of `error`, for the caller's own analytics — this API emits none itself) on generation failure/misconfiguration, distinct from a 200 that legitimately found nothing. | "AI suggestions for quarter plan", "suggest quarter plan edits", "AI-assist the quarterly plan" | `/team-rhythm-quarterly` |

**Composite GET `/eos-vision` response shape**:
```json
{
  "data": {
    "teamId": 456,
    "isInheritingParentVision": false,
    "parentTeamId": null,
    "canEdit": true,
    "coreValues": [{ "id": 1, "name": "Integrity", "description": "<p>Do the right thing</p>", "groupId": 456 }],
    "coreFocus": { "purpose": "<p>Our mission</p>", "niche": "<p>Our niche</p>" },
    "bhag": { "text": "<p>Be the best</p>" },
    "marketingStrategy": { "targetMarket": "<p>SMBs</p>", "uniques": ["Speed", "Quality"], "provenProcess": "<p>Our process</p>", "guarantee": "<p>100% satisfaction</p>" },
    "threeYearPicture": { "description": "<p>Where we'll be</p>", "futureDate": "2029-01-01", "revenue": "5000000", "profit": "1000000", "measurables": "Key metrics" },
    "plans": { "2026_0": { "text": "Annual goals", "date": "2026-12-31", "revenue": "1000000", "profit": "200000", "measures": "Key measurables" } }
  }
}
```

**Behavior notes**:
- **PATCH merge semantics**: Marketing strategy and three-year picture only update provided fields — omitted fields retain existing values.
- **Parent vision inheritance**: If a team uses parent vision, reads return parent data with `isInheritingParentVision: true`. All writes return 403.
- **Case convention**: Marketing strategy and three-year picture use camelCase in API (targetMarket, provenProcess, futureDate).
- **Plan keys**: `{year}_{quarter}` format. Quarter 0 = annual, 1-4 = Q1-Q4. Values outside 0-4 return 400.
- **HTML sanitization**: All string inputs sanitized before storage.
- **Standalone core value routes**: PATCH/DELETE at `/core-values/{valueId}` — no team ID in URL. Team inferred from value's `group_id`.
- **Deprecated aliases — do not use**: `GET`/`POST /teams/{id}/eos-core-values` and `PATCH`/`DELETE /eos-core-values/{valueId}` are `deprecated: true` in the spec, framework-neutral duplicates sharing the same handler as `/teams/{id}/core-values` and `/core-values/{valueId}` above. Use the non-`eos-` paths.
- **Auth**: All GET endpoints require Member role. Writes are open to a **team admin** of that team **or** the accountability owner of that team's own unarchived **Visionary** or **Integrator** seat — that is: `PATCH /teams/{id}/eos-core-focus`, `/eos-bhag`, `/eos-marketing-strategy`, `/eos-three-year-picture`, `/eos-plans/{year}/{quarter}`, and `POST /teams/{id}/core-values` (and its `/teams/{id}/eos-core-values` alias). The seat must sit on the chart of the **team being edited** — a qualifying seat on another team's chart grants nothing, and no ancestor walk applies to seats (team-admin rights keep theirs). Only those two seat names qualify. `PATCH` / `DELETE /core-values/{valueId}` remain **team admin only**, so a seat holder who is not an admin can add a core value but not rename or delete it.
- **Read `canEdit`, don't re-derive it**: `canEdit` on `GET /teams/{id}/eos-vision` already folds in the seat grant, the admin paths, and inheritance. Inheritance still wins — a team that inherits its vision reports `canEdit: false` and refuses every write, to seat holders exactly as to admins.
- **Plan write history & AI suggestions**: see the three `eos-plans/{year}/{quarter}/...` rows above (`history`, `history/{entryId}/restore`, `suggestions`).

## EOS Tools Checklist

Tracks which EOS practice tools a team has adopted. State is stored as a JSON blob keyed by tool slug. Only available for EOS-framework teams.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/eos-tools-checklist` | Get saved EOS Tools checklist state | "show EOS tools checklist", "which EOS tools do we use", "EOS tools adoption", "show tools checklist" | — |
| PATCH | `/teams/{id}/eos-tools-checklist` | Partial update — merge tool states (body: `tools*` — object of slug→boolean) | "update EOS tools checklist", "toggle EOS tool", "mark EOS tool adopted", "check off EOS tool" | — |

**Request body (PATCH)**:
```json
{ "tools": { "the-eos-model": true, "the-five-leadership-abilities": false } }
```

**Response shape (GET 200 / PATCH 200)**:
```json
{ "data": { "tools": { "the-eos-model": true, "the-five-leadership-abilities": false } } }
```

**Behavior notes**:
- **GET 404 = no checklist saved yet** — treat as all tools unchecked. Do not show an error; render a blank checklist.
- **PATCH is a partial merge** — only supplied keys are updated; unspecified keys retain their existing values.
- **Boolean values only** — all values in `tools` must be booleans. Non-boolean values yield 422.
- **EOS teams only** — both endpoints return 403 if the team's `team_management_framework` is not `'EOS'`.
- **Auth**: GET requires team Member; PATCH requires team Admin.
- **Unknown keys are silently ignored** by the API (not stored).

## Quarterly Review

Per-team HTML blob storage for quarterly review summaries. Data is persisted in `object_metas` keyed by team, year, and quarter. Writes are admin-only; reads require team membership.

| Method | Path | Description | User Phrases | Auth |
|--------|------|-------------|--------------|------|
| GET | `/api/v2/teams/{id}/quarterly-review` | Fetch saved quarterly review blobs (params: `year`*, `quarter`* 1–4). Returns 404 if no data saved yet for this period. | "show quarterly review", "get quarterly review", "quarterly review data", "what's in our quarterly review" | Team member |
| PATCH | `/api/v2/teams/{id}/quarterly-review` | Partially update quarterly review fields (params: `year`*, `quarter`* 1–4; body: `wins`?, `went_well`?, `focus`?). Creates record if none exists. | "save quarterly review", "update quarterly review", "set quarterly wins", "update went well", "update focus" | Team admin |
| GET | `/api/v2/teams/{id}/quarterly-review/linked-urls` | List file/URL attachments for a quarterly review (params: `year`*, `quarter`* 1–4). Auto-creates the review record if none exists. Returns `{ linked_urls: [...] }`. | "quarterly review attachments", "quarterly review links", "quarterly review files", "list quarterly review urls" | Team member |
| POST | `/api/v2/teams/{id}/quarterly-review/linked-urls` | Add a URL attachment to a quarterly review (params: `year`*, `quarter`* 1–4; body: `url`*, `name`?). Returns 201 with `{ linked_url: { id, url, name, created_at } }`. | "attach url to quarterly review", "add link to quarterly review", "upload quarterly review file", "add quarterly review attachment" | Team admin |
| DELETE | `/api/v2/teams/{id}/quarterly-review/linked-urls/{url_id}` | Remove a URL attachment from a quarterly review (params: `year`*, `quarter`* 1–4). Returns 204 No Content. Returns 404 if url_id doesn't belong to the requested review. | "remove quarterly review attachment", "delete quarterly review link", "remove attachment from quarterly review" | Team admin |

**Request body (PATCH)** — all fields optional; omit to preserve, send `""` to clear:
```json
{ "wins": "<p>...</p>", "went_well": "<p>...</p>", "focus": "<p>...</p>" }
```

**Response shape** (both endpoints):
```json
{ "data": { "id": 42, "year": 2026, "quarter": 1, "wins": "", "went_well": "", "focus": "" } }
```

Response fields: `id` (team ID), `year`, `quarter`, `wins`, `went_well`, `focus` (all sanitized HTML strings; empty string if never set).

**Linked-URL response shape** (GET returns array, POST returns single object):
```json
{
  "linked_urls": [
    { "id": 301, "url": "https://docs.google.com/...", "name": "Q2 Review Notes", "created_at": "2026-04-10T14:22:00.000Z" }
  ]
}
```

**Behavior notes**:
- **404 on GET**: No data saved yet — treat as empty editor, not an error.
- **Partial PATCH**: Only provided fields are updated; omitted fields retain existing values.
- **HTML sanitization**: All fields sanitized server-side on write.
- **50 KB per field**: Each of `wins`, `went_well`, `focus` capped at 51,200 bytes (400 if exceeded).
- **Admin gate**: PATCH requires `isTeamAdmin`; GET requires `canViewGroup`. Non-members/non-admins receive 403.
- **Missing/invalid params**: Both endpoints return 400 if `year` or `quarter` is missing, non-integer, or `quarter` is outside 1–4.
- **Linked-URL scoping**: Attachments are scoped to the specific quarterly review (team + year + quarter). Not the same as L10 meeting linked URLs. GET auto-creates the review record if missing.
- **Linked-URL DELETE 404**: Returned if `url_id` doesn't belong to the requested quarterly review (cross-review deletion prevented).

## Favorites

User-private bookmarks to any relative app URL. Ordered by position. All endpoints require Bearer auth.

| Method | Path | Description | User Phrases |
|--------|------|-------------|--------------|
| GET | `/favorites` | List authenticated user's favorites ordered by position | "show my favorites", "list bookmarks", "my saved pages" |
| POST | `/favorites` | Create a favorite (body: url*, title?, folder_id? — integer\|null, must be one of the caller's own folders, verified before creation; omit/null for a loose favorite) | "add favorite", "bookmark this", "save this page", "add to favorites", "add favorite to folder" |
| PATCH | `/favorites/{id}` | Update a favorite (body: title?, folder_id? — integer\|null). **Field presence is the instruction, not its value**: omit a field to leave it unchanged; `{"folder_id": null}` takes it out of its folder (still a favorite); `{"title": null}` is 400 (a favorite always has a title, unlike `folder_id`); `{}` is a 200 no-op. 404 (folder not found) is the same response whether the folder doesn't exist or belongs to someone else. | "rename favorite", "update bookmark title", "move favorite to folder", "take favorite out of folder" |
| DELETE | `/favorites/{id}` | Remove a favorite | "remove favorite", "delete bookmark", "unfavorite" |
| PUT | `/favorites/reorder` | Reorder all favorites (body: favorite_ids[]) | "reorder favorites", "move bookmark", "reorganize favorites" |
| GET | `/favorites/folders` | List the caller's favorite folders, ordered by position. Empty array, not 404, when none exist. | "show favorite folders", "list bookmark folders" |
| POST | `/favorites/folders` | Create a folder (body: name* — ≤255 chars, trimmed non-empty). Appended after existing folders. Duplicate names allowed. | "create favorite folder", "add bookmark folder", "new folder for favorites" |
| PATCH | `/favorites/folders/{id}` | Rename a folder (body: name*). Does not touch which favorites it holds or its position. 404 (indistinguishable: doesn't exist vs. belongs to another user) if not the caller's own. | "rename favorite folder", "rename bookmark folder" |
| DELETE | `/favorites/folders/{id}` | Delete a folder. **The favorites it held survive** — they become loose (`folder_id: null`), never unfavorited. Deleting a non-empty folder is normal, not an error. No undo. Same indistinguishable 404 as PATCH. | "delete favorite folder", "remove bookmark folder" |
| PUT | `/favorites/folders/reorder` | Replace the caller's folder order (body: folder_ids* — must be EXACTLY the caller's folder IDs, all of them, no extras/duplicates; positions rewritten 1..n). All-or-nothing — a request naming the wrong set is refused whole. | "reorder favorite folders", "rearrange bookmark folders" |

Favorite fields: `id`, `url`, `title`, `position` (one sequence spanning ALL the user's favorites regardless of folder — folder order and loose order are both read off it by filtering), `folder_id` (integer | null — always present; null = loose), `created_at`, `updated_at`.

FavoriteFolder fields: `id`, `name` (duplicates allowed), `position` (a separate sequence from `Favorite.position`; folders always sort above loose favorites), `created_at`, `updated_at`. Folders are owner-only (no team dimension, no admin override) and **not nestable** — a folder holds favorites only, never another folder.

- `url`: relative path starting with `/`, max 2048 chars. Unique per user — duplicate returns 409.
- `title`: max 255 chars. Auto-generated from URL path if omitted on create.
- `position`: auto-assigned on create (appended to end). Renumbered only via explicit reorder.
- Ownership violations return 403.
- `PUT /favorites/reorder` body: `{ "favorite_ids": [3, 1, 2] }` — must include ALL user's favorite IDs in desired order. Response: `{ "data": [...] }` with updated positions.

## Custom Labels

Labels that can be attached to Items, Goals, and **Pages** — a Page draws on the same pool, there is no parallel "page label" system (see Page labels under Pages). Labels support three scopes: **personal** (user-owned), **team** (shared across team members), and **project** (shared within a project) — a Page can carry personal and team labels only, never project. All endpoints require Bearer / Token auth.

### Custom Label Endpoints

| Method | Path | Description | User Phrases |
|--------|------|-------------|--------------|
| GET | `/api/v2/custom-labels` | List accessible custom labels (params: page, per_page, scope, team_id, project_id — omit scope for union of all accessible). Ancestor-team labels appear **only** when the owning team has shared them down (`shared_with_descendants: true`, default `false`); an unshared ancestor label is simply absent. Each label includes `inherited` (bool), `source_team_id` (int\|null), and `source_team_name` (string\|null). The `shared_with_descendants` flag itself is **not** on these rows — read it from `GET /teams/{id}/labels`. **Access control**: `scope=team&team_id=N` returns 403 unless caller can view team N or an ancestor team; `scope=project&project_id=N` returns 404 if project doesn't exist or 403 if caller can't view it. | "list my labels", "show custom labels", "my tags", "my labels", "team labels", "project labels" |
| POST | `/api/v2/custom-labels` | Create a custom label (body: name*, color?, scope?, scope_id? — scope defaults to personal; team/project scope requires admin) | "create label", "add label", "new label", "create tag" |
| PATCH | `/api/v2/custom-labels/{id}` | Update label name and/or color — scope-aware auth (admin required for team/project labels); returns 403 if caller is a descendant-team admin but not admin of the label's owning team (body: name?, color?). Descendant sharing is toggled on the team route instead: `PATCH /teams/{id}/labels/{label_id}`. | "rename label", "update label", "change label color" |
| DELETE | `/api/v2/custom-labels/{id}` | Delete label — scope-aware auth; returns 422 `reserved_label` for reserved labels; returns 403 if caller is a descendant-team admin but not admin of the label's owning team | "delete label", "remove label", "delete tag" |
| POST | `/api/v2/custom-labels/manage` | Bulk sync labels on an Item, Goal, or **Page** — accepts label IDs from ancestor teams that share with descendants (body: labeled_type*, labeled_id*, custom_label_ids* — array of label IDs). `labeled_type` must be one of `Item`, `Goal`, `Page`; any other value is 422 `"must be one of: Item, Goal, Page"`. Personal labels need only view access on the target; adding a team or project label needs **edit** permission on it (403 otherwise). On a **Page** target: a project-scope label ID is 422 `"Project labels do not apply to pages"` (a page is not an item); the caller not being able to open the page is 403, and adding a team label without edit rights on the page is 403 `"Edit permission required to manage team labels on this page"`; an unknown or soft-deleted page is 404. See Page labels under Pages for the full per-label authorization table. | "set labels on item", "tag item", "apply labels", "sync labels", "label this item", "attach labels", "label this page", "tag the page", "remove label from page" |
| GET | `/api/v2/custom-labels/content` | Get attached + creator labels for an Item, Goal, or **Page** — includes ancestor-team labels the owning team shares with descendants; each label has `inherited` and `source_team_id` fields (params: labeled_type* — one of `Item`, `Goal`, `Page`, else 422 `"must be one of: Item, Goal, Page"`; labeled_id*). On a **Page** target this needs only the right to open the page (403 if the caller can't; 404 if the page doesn't exist or is soft-deleted) — no project labels ever appear for a Page. | "labels on this item", "show item labels", "label picker", "which labels are attached", "what labels are on this page" |

**BREAKING CHANGE**: `POST /api/v2/custom-labels/manage` body field changed from `custom_labels: string[]` (names) to `custom_label_ids: number[]` (IDs). Sending old `custom_labels` field returns 422 with migration guidance.

### Team Admin Endpoints

| Method | Path | Description | User Phrases |
|--------|------|-------------|--------------|
| GET | `/api/v2/teams/{id}/admins` | List team admins | "list team admins", "who are team admins" |
| POST | `/api/v2/teams/{id}/admins` | Grant team admin (body: user_id*) | "make team admin", "grant team admin" |
| DELETE | `/api/v2/teams/{id}/admins/{user_id}` | Revoke team admin | "remove team admin", "revoke team admin" |

### Project Admin Endpoints

| Method | Path | Description | User Phrases |
|--------|------|-------------|--------------|
| GET | `/api/v2/projects/{id}/admins` | List project admins | "list project admins", "who are project admins" |
| POST | `/api/v2/projects/{id}/admins` | Grant project admin (body: user_id*) | "make project admin", "grant project admin" |
| DELETE | `/api/v2/projects/{id}/admins/{user_id}` | Revoke project admin | "remove project admin", "revoke project admin" |

### Project Permissions Endpoints

Manage individual role grants on a project. Requires **edit permission** on the project. Valid roles: `viewer`, `editor`, `author`, `contributor`.

| Method | Path | Description | User Phrases |
|--------|------|-------------|--------------|
| GET | `/api/v2/projects/{id}/permissions` | List all individual role grants on a project. Response: `{ data: [{ id, role, user_id, user: { id, login, first_name, last_name } }] }`. Errors: 400 (non-numeric id), 401, 403, 404. | "list project permissions", "who has access to project", "project roles", "project access" |
| POST | `/api/v2/projects/{id}/permissions` | Grant a role to a user on a project (body: role*, user_id*). Returns 201 (empty body). Errors: 400 (missing field), 401, 403, 404, 422 (invalid role, duplicate grant, non-existent user_id). | "grant project access", "give user project role", "add project permission", "share project with user" |
| DELETE | `/api/v2/projects/{id}/permissions` | Revoke a role from a user (body: role*, user_id*); omit `role` to revoke all roles for that user. Returns 204 (idempotent — no-op if grant absent). Errors: 400 (missing user_id), 401, 403, 404. | "revoke project access", "remove user from project", "remove project permission", "remove all project roles for user" |

Custom Label object fields: `id`, `name`, `color` (hex string or null), `scope` (personal/team/project), `scope_id` (null for personal), `label_type`, `template_code` (null for user-created), `user_id`, `group_id`, `item_id`, `is_inverted`, `inherited` (boolean — `true` when the label belongs to an ancestor team), `source_team_id` (integer | null — the owning team; `null` when local), `source_team_name` (string | null), `is_locked` (boolean, always present — locked against rename/recolor/delete, for team admins too; applying and removing are never affected by it; turned only via `PATCH /teams/{id}/labels/{label_id}` for a team label, `PATCH /custom-labels/{id}` by its owner for a personal one, or at an inherited label's source team). The `shared_with_descendants` flag lives on the team-label rows (`GET /teams/{id}/labels`), not here.

Admin object fields: `user_id`, `login`, `email`, `role`, `is_owner`.

- **Color**: hex string (`#fff` or `#ff00aa`) or null. Optional on create/update.
- **Name**: required, max 255 chars, trimmed. Duplicate name per user returns `422 { name: ["already exists"] }`.
- **Cascade delete**: `DELETE` removes all `custom_labelings` associations first, then the label.
- **Scope-aware auth**: Personal labels — owner only. Team/project labels — team/project admin required for PATCH/DELETE; only an admin of the label's **owning** team, never a descendant team's admin.
- **Team-label inheritance is opt-in**: a team label reaches descendant teams only while its owner sets `shared_with_descendants: true` (default `false`). Sharing covers descendants only — never siblings, ancestors, or another organization. Turning sharing off strips the label from descendant-team items; the owner team's items keep it. Check `GET /teams/{id}/labels/{label_id}/usage` before un-sharing or deleting so you can tell the user what will lose the label.
- **`/manage` semantics**: Diff-based sync by ID. `labeled_type` must be `"Item"`, `"Goal"`, or `"Page"` (other values → `422 "must be one of: Item, Goal, Page"`); a genuinely inaccessible label ID → `422`. Permission splits by scope: applying or removing a **personal** label needs only view access to the target, while adding a **team or project** label needs item edit permission — a non-editor gets `403 { "code": "forbidden" }` and the whole request is refused, nothing applied and nothing removed. A team or project label already on the item that the caller cannot edit is **preserved** across a full sync: omitting it neither removes it nor fails the request, and it is not listed in `removed`. Sending `[]` clears everything the caller is entitled to remove. **On a `Page` target** the gate is evaluated per label, not per request (a page's picker routinely syncs a personal and a team label in one call) — see Page labels under Pages for the full case table, and Page labels get their own 422 (`"Project labels do not apply to pages"`) for any project-scope ID.
- **`/content` response**: `{ data: { attached_labels: [...], creator_labels: [...] } }` — `creator_labels` entries additionally carry `label_context` (boolean — whether that label is attached to the object). Returns scope metadata (`scope`, `scope_id`) and `is_locked` on each label. Multi-scope visibility. On a `Page` target, `attached_labels` includes the page's team labels for any viewer who can open the page but a personal label only to its owner; `creator_labels` offers the caller's own personal labels plus the page team's labels (inherited included); no project label ever appears for a Page.
- **Item response**: `GET /api/v2/items/{id}` now includes `custom_labels` array with scope-aware visibility. All item responses now emit **both** `tags` (deprecated) and `custom_labels` with identical content and order. Prefer `custom_labels` — `tags` will be removed in a future phase. `tags` removal will not happen until all consumers confirm migration.

## Pages

Team-scoped hierarchical document pages. Pages form a tree via `parent_id`; the list endpoint returns a **flat array** — build the tree client-side. All endpoints require Bearer / Token auth. **The list and detail reads are audience-filtered, not just team-membership-gated** — a page outside the caller's audience is absent from the list (not a stub) and 404 on direct read, even for a team admin (see Page Audience below).

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/api/v2/teams/{team_id}/pages` | List pages the CALLER CAN SEE on a team, as a flat array. Includes computed `can_edit`, `can_delete`, `can_manage_permissions` per page. | "list pages", "show team pages", "team wiki", "team docs", "team notes" | — |
| POST | `/api/v2/teams/{team_id}/pages` | Create a page. Body is **one of two mutually exclusive shapes**: `{ title*, body?, parent_id? }` for a blank/authored page, OR `{ template_id*, parent_id? }` to create from a page template (built-in or team's own) — sending `title`/`body` alongside `template_id` is 400. Query param `?format=markdown` interprets `body` as markdown (converted to sanitized HTML for rendering; markdown source kept for byte-perfect reads); omit or `html` for plain sanitized HTML. Gated by the team's `pages_creatable_by` setting (`all_members` default, or `admins_only` — read `can_create_pages` from `GET /teams/{id}/settings`), not a flat admin-only rule. **With `parent_id`, the new page copies its parent's audience at that moment** (a one-time copy, not a live link) — a page made under a private parent starts private. Response is a thin `PageWriteConfirmation` (identity only — id, title, position, etc. — **never the body you just sent**); read the page to get content back. | "create page", "add page", "new page", "new doc", "new wiki page", "create page from template" | — |
| GET | `/api/v2/teams/{team_id}/pages/{page_id}` | Get a single page (`PageResponse` = `PageWriteConfirmation` + `body`). Query param `?format=markdown` returns `body` as markdown (stored source, or converted from HTML). 404 for a caller outside the page's audience — existence not disclosed. | "show page", "get page", "view page", "open page" | — |
| GET | `/pages/{id}` | Get a page from its ID alone, without knowing the owning team first — for bare deep links like `/pages/90200`. Owning team is resolved from the page; caller must be a member. **Status ordering differs from the team-scoped read**: the page is resolved before any team-membership check, so a page in a team the caller isn't on is 403 (not 404), while an unknown id is 404. Same response shape (including `can_edit`, `can_delete`, `locked`, `unlocked_for_me`, `team_id` — used to switch the caller into the owning team) and same `?format=markdown` param as the team-scoped read. Archived pages are returned (archived ≠ hidden); soft-deleted pages 404. | "open page by id", "page deep link", "resolve page id" | — |
| GET | `/pages/{id}/attachments` | List a page's file attachments, newest first (`{ attachments: FileAttachment[] }`). Requires view permission. Resolves a bare page id the same 403-before-404 way as `GET /pages/{id}`. | "page attachments", "files on this page" | — |
| POST | `/pages/{id}/attachments` | Upload a file attachment to a page (multipart: file*, name?, description?) — what an image dropped/pasted into the page body uploads through. Max 4.5 MB. Requires edit permission. Returns FileAttachment with `permanent_url`. | "upload page attachment", "attach file to page", "add image to page" | — |
| PATCH | `/api/v2/teams/{team_id}/pages/{page_id}` | Update a page (body: title?, body?, parent_id?, position? — 0-based sibling slot, a MOVE not an insert, clamped to last; expected_updated_at? — optimistic-concurrency guard, see below). `?format=markdown` interprets `body` as markdown; an HTML-mode update clears any stored markdown source. Requires editor/author role. **Refusal order**: page exists (404) → caller may edit (403 `forbidden`) → not locked (403 `page_locked`) → declared copy matches (409 `conflict`) → validation (422/400). Response is the thin `PageWriteConfirmation` (no body) — read the page for saved content. | "edit page", "update page", "rename page", "move page", "reorder page" | — |
| DELETE | `/api/v2/teams/{team_id}/pages/{page_id}` | **Soft**-deletes the page and every descendant (sets `deleted_at`; row and comments retained, restorable via the `/restore` endpoint below). Requires author role. | "delete page", "remove page" | — |
| GET | `/api/v2/pages/{page_id}/permissions` | List page role assignments. Each row is a User grantee (`member_type: "User"`) or Group grantee (`member_type: "Group"`) — the other kind's fields are null. `status: "pending"` rows carry `email`; confirmed rows don't. Gate: the page's author, **or a team admin of the page's team** (was author-only). | "list page permissions", "who can edit page", "page roles" | — |
| POST | `/api/v2/pages/{page_id}/permissions` | Grant a role (body: role* — `author`\|`editor`\|`contributor`\|`viewer`; exactly one of user_id or group_id). **Groups (teams) can now be granted a role, not just users.** Gate: author or team admin. A team admin outside a private page's audience must break the glass first (404 until then). | "grant page access", "add page editor", "share page", "give page permission", "grant team role on page" | — |
| DELETE | `/api/v2/pages/{page_id}/permissions` | Revoke a role (body: **role\* is now required** — the old `{user_id}`-only body is stale; exactly one of user_id or group_id). Gate: author or team admin. | "revoke page access", "remove page editor", "remove page permission" | — |

**Page object shape** (`PageResponse` — a read):
```json
{
  "id": 1,
  "title": "Getting Started",
  "body": "<p>HTML content, sanitized server-side</p>",
  "parent_id": null,
  "position": 0,
  "team_id": 10,
  "user_id": 42,
  "can_edit": true,
  "can_delete": false,
  "can_manage_permissions": true,
  "has_markdown_source": false,
  "locked": false,
  "unlocked_for_me": false,
  "is_archived": false,
  "archived_at": null,
  "archived_by": null,
  "is_published": false,
  "created_at": "2026-04-18T12:00:00.000Z",
  "updated_at": "2026-04-18T12:00:00.000Z"
}
```
A CREATE or UPDATE response (`PageWriteConfirmation`) is this same shape **minus `body`** — deliberately absent (not null) so a write's confirmation costs the same to read regardless of page size. `parent_id` also reads `null` when the caller can see this page but not its parent (the stored value is unchanged; only what's reported is). `has_markdown_source: true` means per-block writes (see Page Blocks) are refused with 422 — use the whole-body PATCH instead. `is_published` is a read-only state bit visible to any reader (not just the author/admin) — for the live address, gate and audit trail, see Page Publishing.

**Write confirmation shape** — a create (`201`) and an update (`200`) answer with the page's identity and **no `body` field at all**: not `null`, not an empty string, **absent**. Every other field above is unchanged and still present, `updated_at` included (still the copy of record for a subsequent conditional write). `?format=markdown` does not change a write's answer.

> Confirm a write by the **`id`** the answer names — never by comparing an echoed body to what you sent. To show the saved page afterwards, `GET` it: that read is the supported way to get saved content back, and a save and a fresh read never disagree about what the page says.

**Markdown**: `?format=markdown` on page create, update, and read makes the existing `body` field markdown in that direction — a write's `body` is interpreted as markdown (converted to sanitized HTML for rendering, with the markdown source stored), and a read returns `body` as markdown. A markdown-authored page round-trips **byte-perfect**; an HTML-authored page is converted to markdown on read. An HTML update clears the stored markdown source. Default (no `format`, or `?format=html`) is HTML in both directions, exactly as before. The **list** endpoint ignores `format` — read a single page to get markdown. Safety is identical either way: script tags and other disallowed raw HTML are stripped from both the rendered HTML and the stored markdown source. There is no new response field — markdown always arrives in `body`. Rendering follows GitHub comment conventions: GFM tables, `- [ ]` / `- [x]` task lists become the Pages checklist (real checkboxes with their checked state), images are kept, and a single newline inside a paragraph is a line break while a blank line starts a new paragraph.

**Optimistic concurrency (stale-copy protection)**: `PATCH` accepts an optional `expected_updated_at` — the page's `updated_at` as the caller last read it, echoed back. A mismatch is refused with `409 { error: { code: "conflict", message: "Page has changed since you opened it" } }` and nothing is written. Omit it and no staleness check runs (permanent backward compatibility, not a migration window). A malformed value is 400.

**Page permission object shape**:
```json
{
  "id": 101,
  "role": "editor",
  "user_id": 55,
  "user": { "id": 55, "login": "jsmith", "first_name": "Jane", "last_name": "Smith" }
}
```

**Permission model**:
- **View** (`GET`): team membership **and** the page's audience. A page carries its own audience — a whole-team grant plus named people, additive and independent — and every read path consults it. Outside the audience a page is simply **absent** from a list, or a `404` on a direct read: no stub, no redacted title, no count.
- **Create** (`POST`): governed per team by the `pages_creatable_by` setting (`all_members` by default, so a plain member can create; `admins_only` restricts it). Read `can_create_pages` off `GET /teams/{id}/settings` rather than re-deriving admin status. Creator automatically receives `author` role on the new page; a sub-page copies its parent's audience at creation, with no cascade afterwards in either direction.
- **Edit** (`PATCH`): team admin OR user with `author`, `editor`, or `contributor` role on the page
- **Delete** (`DELETE`): team admin OR user with `author` role. Soft delete — restorable via `POST .../restore`.
- **Manage permissions** (`/permissions`, `/audience`): page `author` **OR** team admin. Gate the affordance on `can_manage_permissions` on the page object.

A page can be hidden from a team admin, and sight is a precondition for every page operation — `POST /pages/{id}/break-glass` is the audited, author-notifying route back. Note also that `parent_id` may be `null` on a page whose real parent exists but is hidden from the caller: render it top-level, it is not corruption.

**Page locking**: while a page's global lock is set, a `PATCH` carrying `title` or `body` is refused with `403 { error: { code: "page_locked", ... } }` for everyone except a caller holding a **personal unlock** (see `PATCH .../lock/me` below) — a request carrying only `parent_id`/`position` is unaffected (the lock makes content read-only, not the page's place in the tree). See Page Lifecycle below for the lock endpoints themselves.

Role hierarchy on pages: `author` > `editor` > `contributor` > `viewer`. Group (team) grants share this same enum.

**Create request** (body: `title`*, `body`, `parent_id`):
```json
{ "title": "Onboarding", "body": "<p>Welcome!</p>", "parent_id": null }
```
Response: `201` with `{ "data": { ...page } }` — the write confirmation shape above, **without `body`**.

**Error codes**: `400` missing/empty title, title > 255 chars, body > 100KB, parent_id from a different team, cycle detected (moving a page under its own descendant), invalid role. `401` missing/invalid token. `403` insufficient permission, or `page_locked`. `404` team, page, or template not found (or outside the caller's audience — same response); every read of a soft-deleted page is also 404. `409` stale copy. `422` validation.

**Update request** — all fields optional; send `parent_id` to move, `position` to reorder among siblings:
```json
{ "title": "New Title", "body": "<p>...</p>", "parent_id": 3, "position": 1 }
```
Response: `200` with `{ "data": { ...page } }` — again **without `body`**. Cycle detection prevents moving a page to one of its own descendants (returns `400`).

Use `can_edit` / `can_delete` / `can_manage_permissions` flags on each page object to gate write suggestions. The list endpoint returns a flat array — build the tree client-side from `parent_id`. Position is 0-based ordering among siblings, auto-maintained on create/move/delete.

### Page labels

A page's labels are the **same custom-labels system** Items and Goals use (see Custom Labels above) — there is no separate page-label endpoint. Pass `labeled_type: "Page"` with the page's id to the two unified endpoints below. Neither list nor detail page reads carry a labels field: `GET /teams/{team_id}/pages`, `GET /teams/{team_id}/pages/{page_id}`, and `GET /pages/{id}` never return labels (confirmed against the Page object shape above) — a page's labels have to be read separately, **per page**.

- **Read**: `GET /custom-labels/content?labeled_type=Page&labeled_id={pageId}` → `{ data: { attached_labels: [...], creator_labels: [...] } }` (field names confirmed by a live call).
- **Write**: `POST /custom-labels/manage` with `{ "labeled_type": "Page", "labeled_id": <id>, "custom_label_ids": [<full desired set>] }` → `{ data: { applied: [<ids>], removed: [<ids>] } }`. This is a full-set sync, exactly like an item — not additive.

**Which scopes a page takes**:

| Scope | On a page? |
|---|---|
| Personal | Yes — returned only to its owner, never to another viewer of the same page |
| Team | Yes — inherited (ancestor-shared) team labels included |
| Project | **No** — 422 `"Project labels do not apply to pages"`; a project label is scoped to one item, and a page is not an item |

**Authorization is per label, not per request.** A page's label picker syncs the whole desired set in one call, so a single request routinely carries a personal label and a team label together — each label in the diff is gated on its own:

| Case | Requires | Outcome |
|---|---|---|
| Keep — a label already on the page, sent back unchanged | nothing | never reaches the gate |
| Add — a new **personal** label | right to **open** the page | 200 — a view-only reader can put her own label on a page she can't edit |
| Add — a new **team** label | right to **edit** the page | refused outright: 403 `"Edit permission required to manage team labels on this page"` — nothing at all is written |
| Remove — a **personal** label | right to **open** the page | 200 |
| Remove — a **team** label the caller cannot edit | right to **edit** the page | **preserved**: left attached, left off `removed`, response is still 200 |
| Target page unknown or soft-deleted | — | 404 |
| Caller cannot open the target page | — | 403 |

The label's lock (`is_locked` — see Custom Labels above) never gates any of this: a locked label goes on and comes off a page exactly like an unlocked one; only rename, recolor, and delete are stopped by it.

### Page Content Blocks

Alternative to whole-body PATCH: page content is also addressable as an ordered list of blocks (`pages.body` remains the source of truth; blocks are a derived index that materializes on first read). Concatenating `content` in order reproduces `body` byte-for-byte. **Refused entirely on a markdown-authored page** (`has_markdown_source: true`) — use the whole-body `PATCH /pages/{id}` there instead.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/pages/{id}/blocks` | List a page's blocks in order (`{ data: { blocks: PageBlock[] } }`). Works on every page, including markdown-authored ones (only the writes are refused there). | "list page blocks", "show page content blocks" | — |
| POST | `/pages/{id}/blocks` | Insert one block (body: content* — HTML, sanitized; block_type? — default/only `html`; after_block_id?/before_block_id? — omit both to append to an empty page, omit `after` to prepend, omit `before` to append; expected_updated_at?). Position derives from neighbors — no sibling renumbered, so two concurrent inserts at the same spot both survive. Per-write ceiling: 500KB. **A page VIEWER (not just an editor) may insert exactly one block containing a single embedded item-row** (`<div class="rm-item-row">...</div>`, ≤8KB, exactly one `data-type="itemRow"` span with numeric `data-id"`, at most one anchor, no other content) — refused 403 for anything else from a viewer, and refused entirely if the page is locked, published, or markdown-authored. Returns `{ data: PageBlock, meta: { page_updated_at } }` — chain `page_updated_at` into your next `expected_updated_at` when issuing several block writes, and issue them SEQUENTIALLY (parallel writes against one stale value self-conflict). | "add page block", "insert content block", "add item row to page" | — |
| PATCH | `/pages/{id}/blocks/{blockId}` | Replace one block's content (body: content*, expected_updated_at?). Other blocks' content/order/identity untouched; page `body` updated in the same transaction. Same 500KB ceiling, same viewer-item-row exception, same lock/stale-copy rules as POST. Returns `{ data: PageBlock, meta: { page_updated_at } }`. | "edit page block", "update content block" | — |
| DELETE | `/pages/{id}/blocks/{blockId}` | Remove one block (no sibling renumbered). `expected_updated_at` travels as a QUERY param here (no body). Returns `{ data: { deleted: true }, meta: { page_updated_at } }`. | "delete page block", "remove content block" | — |

PageBlock fields: `id` (stable across writes), `rank` (string, lexicographic order key — compare as a string, never parse as a number), `block_type` (only `"html"` today), `content` (HTML).

### Page Publishing

Publishes a page to a public, unguessable address outside the app. Distinct from Page Audience (in-app visibility) — a page can be team-private in-app and still publicly published, or vice versa in terms of control surface.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/pages/{id}/publish` | Read the page's live public address, or `null` if unpublished (`PagePublication` \| null). Gate: page author or team admin. | "is this page published", "get public page link", "page publish state" | — |
| POST | `/pages/{id}/publish` | Publish, or change visibility class of an already-published page (body: visibility_class* — `link` [anyone with the address] \| `resultkit_login` [any signed-in ResultKit account, any org]; confirmation* — must equal literally `"I understand"`, no trimming/case-folding, or nothing is written). **Publishing an already-published page returns the SAME url** and only changes visibility — republishing never mints a new address; only DELETE kills one. Refused (400) for archived, soft-deleted, or archived-subtree pages. Gate: page author or team admin only — an `editor`/`contributor` grant does NOT carry publish rights, and org-level administration outside the page's own team doesn't reach it either. | "publish page", "make page public", "share page publicly", "change page public visibility" | — |
| DELETE | `/pages/{id}/publish` | Unpublish — revokes the address immediately (every embedded image URL for that publication stops serving in the same instant). Page content/comments/audience untouched. Republishing later mints a NEW address; the old one never works again. Idempotent. Gate: page author or team admin. | "unpublish page", "revoke public page link", "kill page public link" | — |
| GET | `/teams/{id}/pages/published` | The team-admin registry: every published page on this team, whoever published it, newest first (params: limit? ≤50 default 50, offset?). Gate: **team admin** (inherited from ancestor teams). No search/filter yet. | "team published pages", "published pages registry", "list all published pages" | — |
| DELETE | `/teams/{id}/pages/published` | Kill switch — unpublish EVERY live publication on this team in one action (one audit row per revocation). Gate: team admin. Returns `{ data: { revoked: N } }`. | "unpublish all pages", "revoke all published pages", "kill all public page links" | — |
| GET | `/public/pages/{token}` | **The actual public read** — unauthenticated, and the only endpoint in the v2 API that serves account data with no credential (`GET /health` is also uncredentialed but reports on the deployment only). Body carries only the title, body blocks, and a "Made with ResultKit" footer flag — no id, author, team, timestamps, audience, or archive state, ever. Every refusal (unpublished, altered, or never-issued token) is a **uniform 404**, byte-identical to a live token that never existed — a `/p/` address can never confirm a page once lived there. Over-rate-limit requests get the same 404, never a 429. Never cached, never indexed. See the response-states table below. | — | `/p/{token}` |
| GET | `/public/pages/{token}/attachments/{materialId}/{signature}` | Serve one image embedded in a published page's body — unauthenticated. The signature is bound to the **publication**, not just the attachment, so unpublishing kills the image URL with the page (republishing does not resurrect it). Every failure (forged signature, swapped id, wrong page, unpublished) is the same 404. Never cached. Members' in-app access to the same attachment is unaffected. | — | — |
| GET | `/pages/resolve-public/{token}` | Resolve a public page's token to its in-app page id, for a caller who may already open it in-app — powers the public page view's "Open in app" button. **Not the public read** (`GET /public/pages/{token}` is unchanged and remains the content source for anyone, signed in or out). Gated on the page's own audience decision (not team membership) — a `200` guarantees `GET /pages/{page_id}` succeeds for this caller. Every refusal (never-issued token, altered token, revoked publication, page gone, no rights, over rate limit) is a **uniform 404** — no 403 exists here, so no case discloses more than another. Rate-limited per caller per hour, separately from the public read's budget. Never cached. | "open published page in app", "resolve public page link" | — |

PagePublication fields: `url` (the live public address, e.g. `https://resultkit.ai/p/{token}`), `visibility_class` (`link`\|`resultkit_login`), `published_at`, `published_by` (`{id, name}`).

**`GET /public/pages/{token}` response states**:

| Publication | Caller | Response |
|---|---|---|
| Live, `link` | anyone | `200` with the page |
| Live, `resultkit_login` | any live ResultKit credential, any account | `200` with the page |
| Live, `resultkit_login` | no credential, or a deactivated account | `200` `{"gated": true}` — no page content |
| Unpublished, altered, or never issued | anyone | `404`, uniform — including a gated token: an unpublished gated token returns the 404, never the gate |

Links inside the body to pages that are not themselves published are stripped to plain text; images are re-pointed at addresses bound to this publication (see the attachments row above).

### Page Audience & Access

Who can see a page in-app — independent of Page Publishing above. Every page created before this feature reads `whole_team: true` (unrestricted, the pre-existing default).

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/pages/{id}/audience` | Who can see this page — the UNION of a whole-team grant and named people, plus read-only `derived_viewers` the author didn't choose and can't revoke. Gate: page author or team admin. Same 404 for "can't see it" and "can see it but can't manage audience" — never discloses that a private page exists. | "page audience", "who can see this page", "page visibility settings" | — |
| PUT | `/pages/{id}/audience` | Replace the audience dimensions this body NAMES (body: whole_team? boolean, people? — `[{user_id}]`). **Both optional; an omitted field is left untouched** — the two grants are independent. `{"whole_team": false, "people": []}` is the one call that clears both ("Just you"). Re-enabling starts from nobody (no shadow state). A named person must be a team member (422 otherwise). Gate: page author or team admin. | "set page audience", "share page with team", "make page private", "restrict page to people" | — |
| POST | `/pages/{id}/break-glass` | Restore a **team admin's own** access to a private page they're outside the audience of (Decision 4 — privacy from your own team admin is deliberately soft and visible). No body. Gate: team admin of the page's team ONLY (differs from `POST /teams/{id}/break-glass`, which is org-owner-only for team MEMBERSHIP, not this page-level admin restore — same product gesture, different gate). Writes an audit entry, notifies the page's AUTHOR only (nobody in the audience gains/loses anything), and does NOT change the audience itself — grants access to this one page, not team membership. Idempotent. Returns the page (201, full `PageResponse`). | "break glass on page", "restore my access to private page", "team admin view private page" | — |

PageAudience fields: `page_id`, `whole_team` (boolean), `people` (PageAudiencePerson[]), `derived_viewers` (PageAudienceDerivedViewer[] — always present, empty array if none; read-only, PUT neither accepts nor affects it).

### Page Templates

A cataloged snapshot of one page's title + body (NOT the same system as `/api/v2/templates`, which captures project/item trees — a page template captures a Pages document). Editing a template never touches the page it was captured from or any page created from it, in either direction.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/page-templates` | A team's whole template gallery in one read: `{ data: { built_in: PageTemplateResponse[], team: PageTemplateResponse[] } }` — the 8 ResultKit-authored built-ins (same for every team) plus this team's own saved templates (`[]` if none, never another team's). Requires team membership. | "page template gallery", "list page templates", "show template catalog" | — |
| POST | `/teams/{id}/page-templates` | Save a page as a team template (body: page_id* — must be on this team and visible to caller; name*, ≤255 chars; category* — `Process`\|`Meetings`\|`Planning`; description? — null/blank both store null). Copies title+body only — position/parent/audience/author/archived/publish state and `updated_at` are NOT captured. Only these 4 fields accepted; anything else (including `icon`, any audience key) is refused, not ignored. Every saved template is team-visible — no private option. Gate: caller must be able to READ the page (else 404) and hold the team's `pages_creatable_by` standing. | "save page as template", "create page template", "add to template gallery" | — |
| GET | `/page-templates/{templateId}` | Read one template. A built-in is readable by anyone authenticated; a team template by any member of its team (reading is broader than managing). No existence leak — a template on a team the caller isn't on is 404, byte-identical to an unknown id. | "get page template", "view template details" | — |
| PATCH | `/page-templates/{templateId}` | Edit a TEAM template's **name, description, category only** — the captured snapshot, icon, and saved-by identity are never writable (a request naming them is refused, not ignored). Gate: team admin or the person who saved it. **Built-ins refuse with 403, not 404** (readable but not manageable). | "rename page template", "edit template category" | — |
| DELETE | `/page-templates/{templateId}` | Delete a TEAM template's catalog entry only — the source page and every page ever created from it survive untouched (no cascade; templates hold no back-reference). Gate: team admin or the person who saved it. Built-ins refuse with 403. | "delete page template", "remove template from catalog" | — |

PageTemplateResponse fields: `id`, `slug` (string\|null — a built-in's stable name, null on team templates), `is_built_in` (boolean — **switch on this, never on `id`**), `icon` (emoji), `owner_label` (string\|null — role byline like "Note taker"/"Keeper", built-ins only, never accepted from a caller), `name`, `description`, `category` (`Process`\|`Meetings`\|`Planning`), `captured_title` (frozen at save, independent of `name` after a rename), `captured_body` (HTML, present on both list and detail reads), `has_markdown_source`, `team_id` (integer\|null — null on built-ins), `saved_by` (person or the ResultKit brand persona on built-ins — **now non-null on BOTH populations; use `is_built_in` to distinguish, never `saved_by == null`**), `can_edit`, `can_delete` (always false on built-ins), `created_at`, `updated_at`.

### Page Lifecycle — Archive, Lock, Move, Restore

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| PATCH | `/teams/{id}/pages/{pageId}/archive` | Archive/unarchive (body: archived* boolean). **Cascades in one request** — archiving reaches the page and every descendant at every depth (one archiver/timestamp recorded for all); a descendant already archived on its own is left as it was. Unarchiving restores the named page, the descendants archived by the SAME action (not ones archived separately beforehand), and every archived ANCESTOR up to root (so the page comes back reachable) — **not** a blanket subtree operation, unlike `/restore`. Archived pages are comment-read-only (new comments/replies/resolution changes refused 403). Gate checked once, on the named page: team admin or page author. | "archive page", "unarchive page", "archive page and sub-pages" | — |
| PATCH | `/teams/{id}/pages/{pageId}/lock` | Set the GLOBAL lock for everyone (body: locked* boolean). Same edit gate as updating the page. When locked, content writes (title/body — including block writes) are refused for everyone except a holder of a personal unlock. Returns `{ data: { locked } }`. | "lock page", "unlock page", "lock page for everyone" | — |
| PATCH | `/teams/{id}/pages/{pageId}/lock/me` | "Unlock for me" / "Re-lock" — a PERSONAL unlock for the caller only (body: unlocked* boolean). Never touches the global lock; the page stays locked for everyone else. Same edit gate as the global lock. Idempotent. Returns `{ data: { unlocked_for_me } }`. | "unlock page for me", "personal page unlock", "re-lock for myself" | — |
| POST | `/teams/{id}/pages/{pageId}/move` | Move a page to another team (body: destination_team_id*; include_comments? default true — re-scopes comments to the destination, false removes them; preview? default false — returns the affected `comment_count` without moving anything). Returns `{ data: { comment_count, moved } }`. | "move page to another team", "preview page move", "transfer page to team" | — |
| POST | `/teams/{id}/pages/{pageId}/restore` | Restore a **soft-DELETED** page (clears `deleted_at`) and its WHOLE subtree unconditionally, comments intact. **This is NOT unarchive** — deleted and archived are separate states with separate reversals (delete↔restore, archive↔unarchive with `{"archived":false}`), and restore's reach (whole subtree, always) differs from unarchive's (only what the matching archive action touched). 404 if no soft-deleted page with that id. | "restore deleted page", "undelete page", "recover deleted page and sub-pages" | — |

### Page Comments

Comment threads on a page — open to any team member who can view the page; no author/admin tier for basic read/write, though resolution follows the Google Docs model (anyone who can view may resolve/reopen ANY thread).

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/pages/{pageId}/comments` | Every thread on the page, open and resolved, each with nested replies. Each thread carries API-derived `orphaned` (true when its `anchor_excerpt` no longer matches the page body exactly once). Returns `{ data: { team_id, page_id, threads: PageCommentThread[] } }`. | "show page comments", "list comment threads", "page discussion" | — |
| POST | `/teams/{id}/pages/{pageId}/comments` | Create a top-level thread or a reply (body: body* — HTML sanitized, 1–65535 bytes; anchor_excerpt? — a quoted passage to anchor to, omit/null for a page-level thread, ignored on replies; parent_comment_id? — set to reply to an existing top-level thread on this page). Refused 403 while the page is archived. 422 on empty/over-ceiling body or invalid parent. | "comment on page", "reply to page comment", "add anchored comment" | — |
| PATCH | `/comments/{commentId}/resolution` | Resolve or reopen a **top-level** thread (body: resolved* boolean). Any viewer of the page may act on any thread — no author/admin restriction. Targeting a reply is 422. A stale transition (resolving an already-resolved thread, or reopening an already-open one) is 409 so the client can refresh. Refused 403 while the page is archived. | "resolve page comment", "reopen comment thread" | — |

PageCommentThread fields: `id`, `body`, `author` (UserSimple), `created_at`, `updated_at`, `resolved` (boolean), `resolved_by` (UserSimple\|null), `resolved_at` (datetime\|null), `anchor_excerpt` (string\|null), `orphaned` (boolean, always false for page-level threads), `replies` (PageCommentReply[]).

## Framework Articles

Proxy endpoint that returns Cmd+K command palette help articles sourced from MasteryMaps, scoped to a management framework. The server fetches upstream, transforms, and caches for 1 hour — clients always receive a clean `{ "data": [] }` on any failure (never a 5xx). Authenticated users only.

| Method | Path | Description | User Phrases |
|--------|------|-------------|--------------|
| GET | `/api/v2/framework-articles?framework=<value>` | Fetch Cmd+K help articles for a framework (`eos`, `okr`, `4dx`; case-insensitive). Unknown or missing framework → `200 { "data": [] }`. OKR and 4DX map to the same upstream chapter. Any upstream failure (timeout, non-200, bad JSON) also returns empty array with 200. | "framework articles", "help articles", "get help for framework", "Cmd+K articles", "framework shortcuts" |

FrameworkArticle fields: `type` (always `"command"`), `title` (string), `description` (string), `key` (string | null), `isAlt` (boolean), `isShift` (boolean), `isCtrl` (boolean), `isMeta` (boolean), `onclick` (string | null).

- **Auth**: `requireAuth` — unauthenticated requests return 401.
- **Caching**: 1 hour per chapter via Next.js Data Cache. Cache hits complete in well under 300 ms.
- **Scope**: UI-helper endpoint for the Cmd+K palette; content is the same for all users (no per-team filtering).

## Project Templates

Reusable project blueprints created from existing items. Templates are backed by archived items and can be shared across teams, launched as new projects, or applied to existing items.

Template object fields: `id`, `name`, `description` (string | null), `template_type` (string — e.g. `"project_or_process"`), `templateable_id` (integer — backing item ID), `templateable_type` (string — e.g. `"Item"`), `shared_with_teams` ([{ id, name }]), `default_view` (`"show"` | `"board"` | `"outline"` | `"roadmap"` | null), `can_edit` (boolean), `can_delete` (boolean), `created_at`, `updated_at`.

| Method | Path | Description | User Phrases |
|--------|------|-------------|--------------|
| GET | `/api/v2/templates` | List templates visible to the user (params: `page?`, `per_page?` (default 100, max 100), `team_id?` for optional filter). Returns paginated list with `meta.page`, `meta.per_page`, `meta.total`, `meta.total_pages`. | "list templates", "show templates", "browse templates", "available templates", "project templates" |
| POST | `/api/v2/templates` | Create template from an existing item (body: `name`*, `source_item_id`*, `description?`, `include_attachments?` (bool), `keep_alignments?` (bool)). Requires edit access on source item. Returns 201 with template object. | "create template", "save as template", "make template from project", "turn project into template" |
| GET | `/api/v2/templates/{id}` | Get template detail. Includes `backing_item` ({ id, name, type, descendant_count }) and `can_edit`/`can_delete` flags. | "get template", "show template detail", "view template" |
| PATCH | `/api/v2/templates/{id}` | Update template name and/or description (body: `name?`, `description?`). Requires edit access. Returns full template object. | "rename template", "update template", "edit template description" |
| DELETE | `/api/v2/templates/{id}` | Delete template and its backing item tree. Requires team admin or account admin. Returns 204. | "delete template", "remove template" |
| POST | `/api/v2/templates/{id}/launch` | Launch template as a new active project (body: `name`*, `due?`, `assignee_id?`, `parent_id?`, `group_id?`). Returns 201 with new item (`id`, `name`, `type`, `status`, `due`, `group_id`, `parent_id`, `descendant_count`, `created_at`). | "launch template", "use template", "create project from template", "start project from template", "apply template as new project" |
| POST | `/api/v2/templates/{id}/apply` | Apply template's child items to an existing item (body: `target_item_id`*, `assign_to_object_assignees?` (bool)). Inserts template descendants under the target without creating a root item. Returns 201 with `{ target_item_id, items_created, items: [{id, name, parent_id}] }`. | "apply template", "add template to project", "inject template checklist", "apply template items" |
| POST | `/api/v2/templates/{id}/share` | Share template with a team (body: `team_id`*). Returns updated `shared_with_teams` list. | "share template", "share template with team", "add team to template" |
| DELETE | `/api/v2/templates/{id}/share` | Remove team from template sharing (body: `team_id`*). Returns updated `shared_with_teams` list. | "unshare template", "remove team from template", "stop sharing template" |
| PATCH | `/api/v2/templates/{id}/default-view` | Set default launch view (body: `default_view`* — one of: `"show"`, `"board"`, `"outline"`, `"roadmap"`). Returns `{ data: { id, default_view } }`. | "set template view", "default view for template", "set template default" |

**Response envelopes**:
- `GET /api/v2/templates` → `{ "data": Template[], "meta": { "page": int, "per_page": int, "total": int, "total_pages": int } }`
- `POST /api/v2/templates` → `{ "data": Template }` (201)
- `GET /api/v2/templates/{id}` → `{ "data": Template }` (includes `backing_item`)
- `PATCH /api/v2/templates/{id}` → `{ "data": Template }` (200)
- `DELETE /api/v2/templates/{id}` → 204 No Content
- `POST /api/v2/templates/{id}/launch` → `{ "data": { id, name, type, status, due, group_id, parent_id, descendant_count, created_at } }` (201)
- `POST /api/v2/templates/{id}/apply` → `{ "data": { target_item_id, items_created, items: [{id, name, parent_id}] } }` (201)
- `POST /api/v2/templates/{id}/share` / `DELETE /api/v2/templates/{id}/share` → `{ "data": { id, shared_with_teams } }` (200)
- `PATCH /api/v2/templates/{id}/default-view` → `{ "data": { id, default_view } }` (200)

**Validation**: `name` required, max 255 chars (422). `source_item_id` must be viewable and editable (403/404). `default_view` must be one of the four valid values (422). Template delete requires team admin or account admin (403). Launch/apply require view access to template and edit access to parent/target (403).

## Swimlane Roadmaps

Saved, versioned roadmap configs that render a set of projects' columns as swimlanes. A roadmap belongs to one team but can be listed across teams/organizations, and non-team-member "named editors" can be granted access to it directly.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/swimlane-roadmaps` | Every roadmap the caller can view within a scope (params: scope* — `team`\|`organization`\|`all`; team_id — required for `team`/`organization`, ignored for `all`). `organization` = the org (root team + all descendants) `team_id` belongs to; `all` = every org the caller belongs to a team in. Each row carries its owning `team` (with that team's org) and `can_manage` (edit gate precomputed). | "swimlane roadmaps across teams", "roadmaps in my organization", "all my roadmaps" | — |
| GET | `/swimlane-roadmaps/{id}` | Resolve a roadmap by id alone, without knowing its team — for deep links and drilling in from a wider scope. Returns the roadmap's full config plus the team to switch context to. A roadmap the caller can't view is a quiet 404 (no roadmap/team fields at all). A named editor may read it even without being a member of the owning team. | "open roadmap by id", "roadmap deep link" | — |
| GET | `/teams/{id}/swimlane-roadmaps` | Roadmap summaries for a team, most recently updated first. Open to any team member. | "list team roadmaps", "team's swimlane roadmaps" | — |
| POST | `/teams/{id}/swimlane-roadmaps` | Create a roadmap (body: title*, config* — `{v: 1, sources: [{project_id, column_ids: "all" | integer[]}], lane_mode?, hidden_lanes?, label_filter?, view?}`; only `v` and `sources` are server-validated, the rest is client-owned). Open to any team member. | "create swimlane roadmap", "save new roadmap" | — |
| GET | `/teams/{id}/swimlane-roadmaps/{roadmapId}` | Full roadmap detail with config. Open to any team member; a named editor may also read it without team membership. | "show roadmap", "get roadmap config" | — |
| PATCH | `/teams/{id}/swimlane-roadmaps/{roadmapId}` | Update title and/or config (≥1 field required). Restricted to a team admin of the owning team OR a named editor of the roadmap. | "update roadmap", "rename roadmap", "edit roadmap config" | — |
| DELETE | `/teams/{id}/swimlane-roadmaps/{roadmapId}` | Permanently delete. Same gate as PATCH (team admin or named editor). | "delete roadmap" | — |
| GET | `/teams/{id}/swimlane-roadmaps/{roadmapId}/editors` | List named editors. Open to any team member who can view the roadmap. | "list roadmap editors", "who can edit this roadmap" | — |
| POST | `/teams/{id}/swimlane-roadmaps/{roadmapId}/editors` | Grant editor role (body: exactly one of user_id or email — never both, never neither, else 400; note? — ≤500 chars, never stored, never writes back to a standing invitation note). **Cross-team allowed** — the grantee need not be a member of the owning team. Idempotent (re-adding returns the existing row). **Sends mail**: an existing-account `user_id`/known `email` gets a "you were added to this roadmap" email (need not join the team); a brand-new `email` gets the ordinary invitation email AND is joined to the roadmap's owning team (not a second message). A failed send never fails the grant. Gate: team admin of owning team OR a named editor. Returns 201 with either a `RoadmapEditor` (user_id path) or `InvitedPerson` (email path). | "add roadmap editor", "grant roadmap access", "invite person to roadmap" | — |
| DELETE | `/teams/{id}/swimlane-roadmaps/{roadmapId}/editors/{user_id}` | Revoke an editor grant. Idempotent — 204 even if they weren't an editor. Same gate as adding. | "remove roadmap editor", "revoke roadmap access" | — |

SwimlaneRoadmapSimple fields: `id`, `title` (string\|null), `creator_id` (integer\|null), `creator_name`, `created_at`, `updated_at`, `lane_mode` (string\|null), `view` (string\|null), `project_count`.

SwimlaneRoadmapScoped (the `GET /swimlane-roadmaps` shape) = SwimlaneRoadmapSimple + `team` (`SwimlaneRoadmapTeam`: `{id, name, organization_id, organization_name}` — `organization_id` is a `groups.id`, never an `accounts.id`) + `can_manage` (boolean — team admin of the owning team, admin rights inherit from ancestors, OR a named editor; no creator special-case, the creator is seeded onto the editor list at create).

RoadmapEditor fields: `user_id`, `login`, `first_name`, `last_name`, `seat` (string\|null — primary accountability-chart seat name), `team` (`{id, name}` \| null — that seat's owning team).

## Process Workflows

A team's named, custom set of stages (e.g. a sales pipeline or intake process) — distinct from an item's `workflow_status_id` acceptance state. Never shared/inherited across teams, but a **named editor of a swimlane roadmap owned by the team** can read (and, for placements, sometimes write) without team membership, via an optional `roadmap_id` param — see "Roadmap-editor access" below.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/teams/{id}/process-workflows` | List the team's workflows, ordered by name (params: page, per_page, roadmap_id? — see below). Any team member. | "list process workflows", "show workflows" | — |
| POST | `/teams/{id}/process-workflows` | Create a workflow (body: name*, description?). Admin-only. Duplicate names allowed. Starts with no stages. | "create process workflow", "new workflow" | — |
| GET | `/teams/{id}/process-workflows/{workflow_id}` | Get a workflow with its stages, ordered by category (`not_started`→`in_progress`→`done`→`archived`) then `sort_order` (param: roadmap_id?). Any team member. | "show workflow", "get workflow stages" | — |
| PATCH | `/teams/{id}/process-workflows/{workflow_id}` | Update name and/or description. Admin-only. Empty/whitespace name rejected. Duplicate names still allowed. | "rename workflow", "update process workflow" | — |
| POST | `/teams/{id}/process-workflows/{workflow_id}/stages` | Add a stage (body: name*, category* — `not_started`\|`in_progress`\|`done`\|`archived`; color?). Admin-only. Name must be unique among the workflow's non-archived stages. `sort_order` auto-assigned (end of its category). | "add workflow stage", "create process stage" | — |
| PATCH | `/teams/{id}/process-workflows/{workflow_id}/stages/{stage_id}` | Update OR archive a stage. `{"archived": true|false}` archives/unarchives — **when `archived` is present, every other field is ignored**; otherwise updates name/color/category/sort_order (rename requires uniqueness among non-archived stages). Archiving is the only retire path; placements are left untouched. Admin-only. | "update workflow stage", "archive process stage", "unarchive stage", "reorder stage" | — |
| GET | `/teams/{id}/process-workflows/{workflow_id}/placements` | List item placements — which stage each item sits in, ordered by stage then sort_order (params: page, per_page, roadmap_id?, item_ids? — comma-separated, scopes the result). Any team member sees everything; a roadmap-editor caller (via `roadmap_id`, no team membership) sees ONLY placements for that roadmap's own cards. | "list workflow placements", "show items in workflow" | — |
| PUT | `/teams/{id}/process-workflows/{workflow_id}/placements/{item_id}` | Upsert the item's placement (body: stage_id* — must belong to this workflow; sort_order? — defaults 0 on create, only written on update if supplied so a plain stage move preserves order; roadmap_id? — see below). Admin-only **by default**. | "place item in workflow stage", "move item to stage" | — |
| DELETE | `/teams/{id}/process-workflows/{workflow_id}/placements/{item_id}` | Clear the item's placement (falls back to "no stage yet"). Idempotent. Admin-only **by default** (query param roadmap_id? widens it — see below). | "remove item from workflow", "clear workflow placement" | — |

**Roadmap-editor access (rule 7).** An optional `roadmap_id` (query on GETs and the placement DELETE; body or query on the placement PUT) authorizes a **named editor of that roadmap who is not a team member** — it only ever turns a refusal into a success, consulted only when the caller fails the ordinary team-membership/admin check. The roadmap must be owned by the team in the path (400 otherwise). For the two placement writes specifically, supplying `roadmap_id` **widens the admin-only gate to "team admin OR named roadmap editor"** — but only for a placement whose item is actually a card of that roadmap (its nearest project is in the roadmap's `config.sources`, AND that project's team is within the roadmap-owning team's organization — root + descendants; this org-boundary check defeats a forged `sources` entry). An unknown roadmap, or an item that isn't one of its cards, is 404. A non-positive/non-integer `roadmap_id` is 400. Omit `roadmap_id` and placement writes stay admin-only as before.

ProcessWorkflow fields: `id`, `name`, `description` (string\|null), `created_at`, `active_stage_count`, `archived_stage_count`. Detail adds `stages` (ProcessStage[]).

ProcessStage fields: `id`, `name`, `color` (string\|null), `category` (`not_started`\|`in_progress`\|`done`\|`archived` — a fixed 4-value rollup every stage belongs to), `sort_order`, `archived` (boolean), `item_count`.

ProcessItemPlacement fields: `item_id`, `custom_process_stage_id`, `sort_order`.

## MCP

Model Context Protocol endpoint (`mcp-handler` streamable-HTTP transport) — **not part of the v2 REST surface these skills call.** Distinct server/base path from the rest of this document (the spec marks it with a per-path `servers` override) and a different wire protocol: JSON-RPC 2.0 / the MCP spec, not this API's `{ data: ... }` envelope. Authenticated with an **OAuth Bearer access token** validated against ResultMaps' OAuth service (protected-resource metadata published at `/.well-known/oauth-protected-resource`) — not the `api_token` `scripts/api.sh` sends, so it is not reachable through `scripts/api.sh` or any rkit skill.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/mcp` | Open the server→client event stream for an MCP session. | — | — |
| POST | `/mcp` | Send client→server JSON-RPC 2.0 messages (initialize, tool calls, etc.). | — | — |
| DELETE | `/mcp` | Terminate the current MCP session. | — | — |

## Health & Service

Operational endpoints for infrastructure — **not for skills or end users.** None accept a user `api_token`; most use a separate shared secret or no auth at all. User Phrases are `—` throughout: nothing here answers a user request.

| Method | Path | Description | User Phrases | Web URL |
|--------|------|-------------|--------------|---------|
| GET | `/health` | Liveness probe — is this deployment serving requests. Unauthenticated by design (an `Authorization` header, if sent, is ignored rather than checked); no database read — liveness, not readiness. Body carries only `status` and `timestamp`. Never cached. | — | — |
| GET | `/cron/connections-sync` | **INTERNAL, scheduled** — the daily (05:00 UTC) pull of every account's data Connections (see Account Data Connections). Auth: `Authorization: Bearer <CRON_SECRET>`, the only check; 401s if unset. Not reachable with a user token. | — | — |
| POST | `/internal/identity-lookup` | **INTERNAL** — resolves a login or email to a canonical login+email, for the Cognito "forgot password" migration Lambda (which has no password and no session to prove identity any other way). Auth: `Authorization: Bearer <COGNITO_LAMBDA_SHARED_SECRET>`. 404 (uniform) for zero matches or 2+ matches alike — never guesses toward a shared mailbox. | — | — |
| POST | `/internal/send-invite-email` | **INTERNAL** — sends the standard teammate-invitation email on behalf of an internal caller (Lambda/job). Auth: `Authorization: Bearer <INTERNAL_EMAIL_SHARED_SECRET>`. Templated only — a caller-supplied subject/body/html/from is ignored, so it can only ever produce the standard invitation email. `200 {email_sent:true}` only when the transport actually accepted the message; `502 send_failed` otherwise. | — | — |
| POST | `/realtime/subscription` | Declares the contexts (`{entity_type, entity_id}`) the caller's session is currently viewing and returns the opaque subject keys (plus a short-lived token) to listen on. Normal user auth, but not something a skill has a use for — it backs the web app's live-update socket, not a request/response read. An unreadable context comes back under `refused` with no key rather than failing the call; every context is re-authorized from scratch on every call. | — | — |
| POST | `/contact` | Sends a message from the marketing site's public contact form (body: name*, email*, message*). Unauthenticated by design — the visitor has no account or session. Creates nothing (no account, team, invitation, or session). `200` confirms delivery; a client must not treat any non-200 as sent. `502` if delivery fails, `429` (rate-limited) says nothing about what was submitted. | — | — |

## Error Responses

All errors return: `{ "error": { "code": "<error_code>", "message": "<human-readable>", "details": { ... } } }`

| Status | Code | Meaning |
|--------|------|---------|
| 400 | `bad_request` | Missing or invalid query parameter |
| 401 | `unauthorized` | Invalid/missing token |
| 403 | `forbidden` | Not authorized for resource |
| 404 | `not_found` | Resource not found |
| 422 | `validation_error` | Validation error (per-field details in `details`) |
| 500 | `internal_error` | Internal server error |

## Pagination

Most list endpoints return: `{ data: [...], meta: { page, per_page, total, total_pages } }`

Delete responses vary by resource: strategy objects (goals, rocks, milestones) return `200` with the archived object in `{ "data": ... }`. Other resources may return `204 No Content` with empty body.

---

## Glossary

### User Language → API Concept

| User Says | API Concept | Endpoint |
|-----------|-------------|----------|
| item, task, action item, to-do, priority | Item (type=Task) | `/items` |
| project, todo list, TodoList | Item (type=TodoList) | `/items` (type: "TodoList"), `/teams/{id}/projects` |
| outcome, objective (as item type) | Item (type=Outcome) | `/items` (type: "Outcome") |
| key result, KR, measure (as item type) | Item (type=KeyResult) | `/items` (type: "KeyResult") |
| team, group | Team | `/teams` |
| meeting, weekly meeting, weekly sync, L10, team meeting | Team Weekly Board (L10) | `/teams/{id}/items` |
| 1:1, 1x1, one-on-one | One-on-One | `/1-on-1` |
| project meeting | (separate skill — out of scope) | — |
| day plan, daily plan, prioritizer, tasks for today, my plan | Day Plan | `/day-plans/today`, `/day-plans/{date}` |
| check-in, 90-second practice, result feed, daily report | Result Feed (daily check-in report) | `/result-feed/today`, `/result-feed/{date}` |
| team check-ins, team feed, team result feed | Team Result Feeds (shared check-ins) | `/teams/{id}/result-feed` |
| teammate's check-in, user's report, team member report | Team Result Feed Detail (single user's report) | `/teams/{id}/result-feed/{date}/{user_id}` |
| high-five, react, kudos, toggle reaction | Result Feed Reaction (toggle) | `POST /result-feed/{date}/reactions` |
| show reactions, reaction count, did I react, high-five count | Result Feed Reaction (read) | `GET /result-feed/{date}/reactions` |
| comments on check-in, check-in comments | Result Feed Comments | `/result-feed/{date}/comments` |
| unshare check-in, retract share, stop sharing check-in | Retract Result Feed Share | `DELETE /result-feed/{date}/share` |
| share to slack, push to slack | Push Result Feed to Slack | `/result-feed/{date}/push-to-slack` |
| share to discord, push to discord | Push Result Feed to Discord | `/result-feed/{date}/push-to-discord` |
| section notes, done notes, add notes, review notes | Result Feed Section Metadata | `PUT /result-feed/{date}/{section}` |
| upload file to check-in, attach file, upload attachment | Result Feed File Upload | `POST /result-feed/{date}/attachments` |
| weekly, team weekly, weekly board, Level 10, L10 (EOS) | Team Items (weekly board; called "Level 10" for EOS teams) | `/teams/{id}/items` |
| issue, blocker, blocked item, challenge | Item with status=blocked | `/teams/{id}/items/blocked` |
| next, to-do (column), priority for the week | Item with status=next | `/teams/{id}/items/next` |
| parked, parking lot, park for later | Item with status=parked | `/teams/{id}/items/parked` |
| done, completed, finished | Item with status=done | `/teams/{id}/items/done` |
| L10 to-do, weekly to-do | Item with status=next (EOS alias) | `/teams/{id}/l10/todos` |
| L10 issue, IDS item | Item with status=blocked (EOS alias) | `/teams/{id}/l10/issues` |
| team issues, filter issues, long-term issues, IDS board | Team issues with filter support | `GET /teams/{id}/issues` |
| L10 headline | Headline (EOS alias) | `/teams/{id}/l10/headlines` |
| L10 done, L10 completed | Item with status=done (EOS alias) | `/teams/{id}/l10/done` |
| L10 parking lot, L10 parked | Item with status=parked (EOS alias) | `/teams/{id}/l10/parked` |
| move to L10 to-dos, prioritize in L10 | Move item to to-dos section | `PUT /teams/{id}/l10/todos/{item_id}` |
| mark L10 done, complete L10 to-do | Mark item done on L10 board | `PUT /teams/{id}/l10/done/{item_id}` |
| move to L10 issues, IDS this | Move item to issues section | `PUT /teams/{id}/l10/issues/{item_id}` |
| park in L10, move to parking lot | Park item on L10 board | `PUT /teams/{id}/l10/parked/{item_id}` |
| remove from L10, take off L10 board | Remove from L10 board | `DELETE /teams/{id}/l10/items/{item_id}` |
| assignee, assigned to, responsible | Assignee | `/items/{id}/assignees` |
| creator, item creator, who created this | Creator (`creator` field) | `/items`, `/teams`, `/day-plans` |
| accountability owner, accountable | Assignee (if any), else Creator | `/items/{id}/assignees`, `creator` field |
| muted, hidden team, show muted | Muted Team | `GET /teams?include_muted=true` |
| mute team, hide team, silence team | Mute Team | `PUT /teams/{id}/mute` |
| unmute team, unhide team, show team again | Unmute Team | `DELETE /teams/{id}/mute` |
| headline, announcement, team update, news | Headline (EOS only) | `/teams/{id}/headlines` |
| review, performance review, quarterly review | Review | `/reviews` |
| review template, review form | Review Template | `/review-templates` |
| assessment, self-assessment, reviewer assessment | Assessment (within Review) | `/reviews/{id}/submit-assessment`, `/reviews/{id}/draft-assessment` |
| sign off, approve review, finalize review | Review Sign-off | `POST /reviews/{id}/sign-off` |
| void review, cancel review | Void Review | `PUT /reviews/{id}/void` |
| core value, company value | Core Value | `/core-values` |
| core value rating, value score | Core Values Rating | `/core-values-ratings` |
| review prompt, review question | Assessment Prompt | `/review-templates/{id}/prompts` |
| project template, template, blueprint, reusable project | Project Template | `/api/v2/templates` |
| swimlane roadmap, roadmap, roadmap editors | Swimlane Roadmap | `/swimlane-roadmaps`, `/teams/{id}/swimlane-roadmaps` |
| process workflow, pipeline, workflow stages, intake process | Process Workflow | `/teams/{id}/process-workflows` |
| workflow placement, place item in stage, move to stage | Process Item Placement | `/teams/{id}/process-workflows/{workflow_id}/placements/{item_id}` |
| launch template, use template, create from template | Template Launch | `POST /api/v2/templates/{id}/launch` |
| apply template, add template to project, inject template | Template Apply | `POST /api/v2/templates/{id}/apply` |
| action item (review), follow-up | Review Action Item | `POST /reviews/{id}/action-items`, `DELETE /reviews/{id}/action-items/{aid}` |
| invite self-assessment, ask them to complete their self-assessment, self-assessment reminder | Self-Assessment Invitation | `POST /reviews/{id}/self-assessment-invitation` |
| review admin, review administrator, who can manage reviews | Review Admin | `GET /teams/{id}/review-admins`, `POST /teams/{id}/review-admins`, `DELETE /teams/{id}/review-admins/{userId}` |
| show archived, include archived | Archived filter | `?include_archived=true` on list endpoints |
| comment, note | Comment | `/items/{id}/comments` |
| member, team member | Team Member | `/teams/{id}/members` |
| child, sub-task, sub-item, nested item | Child Item (parent_id) | `/items/{id}/children` |
| move, reorder, reparent, nest under | Move Item | `PUT /items/{id}/move` |
| bulk move, move items, move these under, reparent multiple, move all to | Bulk Move Items | `PATCH /items/bulk-move` |
| convert to project, promote to project | Convert Item to Project | `PUT /teams/{id}/projects/{item_id}` |
| my projects, list my projects | Standalone Projects List | `GET /projects` |
| batch fetch project children, multiple projects at once | Project Children Batch | `POST /projects/children-batch` |
| project assignees, assign to project | Project Assignees | `GET`/`PUT /projects/{id}/assignees`, `DELETE /projects/{id}/assignees/{user_id}` |
| project attachments, project comments | Project Attachments/Comments | `/projects/{id}/attachments`, `/projects/{id}/comments` |
| put on weekly, add to board, show on weekly | Set on_weekly=true | `PUT /teams/{id}/items/{item_id}` |
| remove from weekly, take off board | Set on_weekly=false | `DELETE /teams/{id}/items/{item_id}` |
| attach, link to meeting, link item to 1:1 | Attach Item to One-on-One | `POST /1-on-1/{id}/align` (body: `{"alignable_type":"Item","alignable_id":<id>}`) |
| add to plan, add to today, put on my plan | Attach to Day Plan | `PUT /day-plans/today/items/{item_id}` |
| check off, mark done for today, complete for today | Day Plan Completion | `PATCH /day-plans/today/items/{item_id}` |
| reorder today, sort my plan, change order of today, drag to reorder, set item order | Reorder Day Plan | `POST /day-plans/today/set-positions` |
| archive, soft delete, remove item | Archive Item (status→archived) | `DELETE /items/{id}` |
| search, find, look up, search everything, search across teams, full-text search | Search (full-text) | `GET /api/v2/search` |
| my history, recently visited, visit history, recent items, what I visited | Visit History | `GET /api/v2/users/me/history` |
| record visit, track visit, mark visited | Record Visit | `POST /api/v2/users/me/history` |
| onboarding status, onboarding progress, should I show onboarding, is onboarding complete, my onboarding role | Onboarding State | `GET /api/v2/users/me/onboarding-state` |
| skip onboarding, dismiss onboarding banner, hide onboarding, don't show onboarding | Skip Onboarding | `POST /api/v2/users/me/onboarding-state/skip` |
| search, find, look up | Search (q param) | `GET /items?q=...`, `GET /users/search?q=...` |
| my token, API key, api token | API Token | `GET /users/me` |
| admin, team admin, make admin | Team Member Role | `PUT /teams/{id}/members` (role: "admin") |
| activity logs, team history, membership changes, who joined, who was removed, team audit log | Team Activity Logs | `GET /teams/{id}/activity-logs` |
| team labels, team tags, label, tag | Team Labels | `GET /teams/{id}/labels` |
| create label, add label, new team tag | Create Team Label | `POST /teams/{id}/labels` |
| slack integration, team webhook, team integration, webhook | Team Integrations | `GET /teams/{id}/integrations` |
| change role, change member role, promote to admin, demote member, demote to member | Member Role Change | `PATCH /teams/{id}/members/{user_id}` |
| upload logo, team logo, set team logo, remove logo, delete logo | Team Logo | `POST /teams/{id}/logo`, `DELETE /teams/{id}/logo` |
| recurring, daily item, repeating task | Recurring Item | Day plan completion doesn't change item status |
| set recurrence, repeat item, recurrence schedule, make daily, repeat weekly, item cadence | Item Recurrence | `GET /items/{id}/recurrence`, `PUT /items/{id}/recurrence` |
| reset password, send password reset, password reset for user | Password Reset (admin) | `POST /passwords/reset` |
| set new password, complete password reset | Password Update (unauthenticated) | `PUT /passwords` |
| change password, update my password, new password, set password | Change Password (authenticated) | `POST /users/me/password` |
| seat, position, role on chart, accountability chart | Seat | `/teams/{id}/seats`, `/seats/{id}` |
| seats for user, user's seats, person's positions, what seats does someone own | User Seats | `GET /users/{id}/seats` |
| org chart, accountability chart, who does what | Team Seats (chart) | `GET /teams/{id}/seats` |
| seat owner, who owns the seat, assigned to seat | Seat Owner | `PATCH /seats/{id}` (seat_owner_id) |
| seat measure, KPI for seat, aligned measure | Seat Measure | `/seats/{id}/measures` |
| seat goal, rock for seat, aligned goal | Seat Goal | `/seats/{id}/goals` |
| seat link, URL on seat, resource link | Seat Link | `/seats/{id}/links` |
| move seat, reparent seat, reorganize chart | Move Seat | `PUT /seats/{id}/move` |
| archive seat, delete seat, remove position | Archive Seat | `DELETE /seats/{id}` |
| restore seat, unarchive seat | Restore Seat | `PUT /seats/{id}/restore` |
| seat roles, accountability roles, LMA roles, seat responsibilities | Seat Roles | `PATCH /seats/{id}` (roles[]) |
| seat level, org level, leadership team, department, individual contributor | Seat Level | `PATCH /seats/{id}` (seat_level) |
| has direct reports, seat with reports, seat builder | Seat Builder | `GET /seats/{id}` (has_direct_reports) |
| seat snapshot, chart snapshot, accountability chart history, save chart, checkpoint | Seat Snapshot | `/teams/{id}/snapshots` |
| revert chart, restore snapshot, undo chart changes, roll back accountability chart | Snapshot Revert | `PUT /teams/{id}/snapshots/{snapshotId}/revert` |
| strategy, strategy tree, goals and rocks, OKRs, annual goals, team objectives, targets, show targets | Strategy Tree | `GET /teams/{id}/targets` |
| team vision, vision and mission, strategic direction, what's our vision, team mission (any framework) | Team Vision (cross-framework) | `GET /teams/{id}/vision` |
| update vision, set mission, save vision, edit vision, write vision, update mission, edit vision purpose, set vision description | Update Vision/Mission | `PATCH /teams/{id}/vision` |
| vision builder answers, vision questionnaire, saved vision answers, vision builder progress | Vision Builder Answers | `GET /teams/{id}/vision-builder/answers`, `PUT /teams/{id}/vision-builder/answers` |
| vision, V/TO, vision traction organizer, EOS vision, show VTO | EOS Vision (composite) | `GET /teams/{id}/eos-vision` |
| core values, our values, company values (EOS V/TO) | EOS Core Values | `GET /teams/{id}/core-values` |
| core focus, purpose, niche, why we exist (EOS V/TO) | EOS Core Focus | `GET /teams/{id}/eos-core-focus` |
| BHAG, 10-year target, big hairy audacious goal (EOS V/TO) | EOS BHAG | `GET /teams/{id}/eos-bhag` |
| marketing strategy, target market, uniques, proven process, guarantee (EOS V/TO) | EOS Marketing Strategy | `GET /teams/{id}/eos-marketing-strategy` |
| three-year picture, 3-year picture, where we'll be (EOS V/TO) | EOS Three-Year Picture | `GET /teams/{id}/eos-three-year-picture` |
| annual plan, quarterly plan, year plan, Q1 plan (EOS V/TO) | EOS Plans | `GET /teams/{id}/eos-plans` |
| EOS tools checklist, which EOS tools, tools adoption, EOS practice tools, tools we use, check off EOS tool, toggle EOS tool | EOS Tools Checklist | `GET /teams/{id}/eos-tools-checklist`, `PATCH /teams/{id}/eos-tools-checklist` |
| yearly goal, annual goal, 1-year goal, create goal, add goal, new goal | Goal (yearly) | `POST /teams/{id}/goals`, `GET /teams/{id}/goals` |
| rock, quarterly rock, 90-day priority, create rock, add rock, new rock | Rock (quarterly) | `POST /teams/{id}/rocks`, `GET /teams/{id}/rocks` |
| milestone, deliverable, create milestone, add milestone, new milestone | Milestone | `POST /teams/{id}/milestones`, `GET /teams/{id}/milestones` |
| update goal, rename goal, change goal status, mark goal complete | Update Goal | `PATCH /goals/{id}` |
| update rock, rename rock, change rock status, mark rock complete | Update Rock | `PATCH /rocks/{id}` |
| update milestone, rename milestone, mark milestone complete | Update Milestone | `PATCH /milestones/{id}` |
| align rock to goal, link rock, move rock under goal | Align Rock | `PUT /rocks/{id}` |
| align milestone to rock, link milestone, move milestone under rock | Align Milestone | `PUT /milestones/{id}` |
| rock measurable alignment, link rock to measurable, aligned measurables for rock, rock KPI link | Rock–Measurable Alignment | `GET /rocks/{id}/alignments`, `POST /rocks/{id}/alignments`, `DELETE /rocks/{id}/alignments/{alignment_id}` |
| detach goal, unlink goal, archive goal, delete goal | Archive/Unlink Goal | `PATCH /goals/{id}` (unlink), `DELETE /goals/{id}` (archive) |
| detach rock, unlink rock, archive rock, remove rock from goal | Archive/Unlink Rock | `PATCH /rocks/{id}` (unlink), `DELETE /rocks/{id}` (archive) |
| detach milestone, unlink milestone, archive milestone, remove milestone | Archive/Unlink Milestone | `PATCH /milestones/{id}` (unlink), `DELETE /milestones/{id}` (archive) |
| label, tag, team label | Team Label | `/teams/{id}/labels` |
| integration, webhook, Slack integration, Discord integration | Team Integration | `/teams/{id}/integrations` |
| team logo, upload logo, remove logo, delete logo | Team Logo | `POST /teams/{id}/logo`, `DELETE /teams/{id}/logo` |
| activity log, team activity, membership changes | Team Activity Log | `GET /teams/{id}/activity-logs` |
| quarterly review, team quarterly review, q1 review, q2 review, wins, went well, focus | Quarterly Review | `GET /teams/{id}/quarterly-review`, `PATCH /teams/{id}/quarterly-review` |
| quarterly review attachments, quarterly review links, quarterly review files, attach url to quarterly review | Quarterly Review Linked URLs | `GET /teams/{id}/quarterly-review/linked-urls`, `POST /teams/{id}/quarterly-review/linked-urls`, `DELETE /teams/{id}/quarterly-review/linked-urls/{url_id}` |
| change role, promote to admin, demote, make admin | Change Member Role | `PATCH /teams/{id}/members/{user_id}` |
| create account, sign up, new account, register, onboard new user | Create Account (Signup) | `POST /accounts` |
| set framework, change framework, select management framework | Set Account Framework | `PUT /accounts/{id}/framework` |
| set leadership team, designate leadership team, change leadership team | Set Leadership Team | `PUT /accounts/{id}/leadership-team` |
| scaffold seats, create default org chart, set up accountability chart, initialize seats | Scaffold Seats | `POST /teams/{id}/seats/scaffold` |
| account, my accounts, account list, account membership | Account | `GET /users/me/accounts` |
| account members, who's in account, who's in my account | Account Members | `GET /accounts/{id}/members` |
| remove from account, kick from account, remove account member | Remove Account Member | `DELETE /accounts/{id}/members/{user_id}` |
| my preferences, my settings, my profile, settings, notification settings | User Preferences | `GET /users/me/preferences` |
| update preferences, change timezone, change settings, toggle notifications, turn off digest, turn on notifications | Update Preferences | `PATCH /users/me/preferences` |
| my progress, practice streak, how am I doing | Personal Progress | `GET /users/me/progress` |
| my integrations, connected apps | User Integrations | `GET /users/me/integrations` |
| stats, profile stats, my stats, my wins, wins given, wins received, my score, goals realized, actions done | User Stats | `GET /users/{user_id}/stats` |
| measurables, scorecard, KPIs, metrics | User Measurables | `GET /users/{user_id}/measurables` |
| rocks, goals, quarterly priorities | User Rocks | `GET /users/{user_id}/rocks`, `GET /users/me/rocks` |
| create personal rock, my own rock | Create Personal Rock | `POST /users/me/rocks` |
| assign rock to report, give a rock to someone, delegate a rock | Assign Personal Rock | `POST /users/{user_id}/rocks` |
| user goals, their 1-year goals | User Goals | `GET /users/{user_id}/goals` |
| direct reports, who reports to me, my downline | Direct Reports | `GET /users/me/direct-reports` |
| upcoming deadlines, timeline view, what's due | Upcoming Deadlines | `GET /users/me/upcoming-deadlines` |
| set persona, subscriber persona | Set User Persona | `PATCH /users/{id}/preferences` |
| feedback, High5s, kudos, recognition | User Feedback | `GET /users/{user_id}/feedback` |
| check login, login available, check username, is handle available, username taken | Check Login | `GET /users/check-login` |
| switch team, use team, set active team, change my team, team context | Set Active Team | `PATCH /users/me/team-context` |
| my context, full context, organizational context, load my context, everything about my teams, all my rocks and issues, my orgs and teams, session context | User Context Snapshot | `GET /users/me/context` |
| upcoming tasks, my tasks, tasks this week, timeline tasks, what's due soon, tasks due next week, my upcoming items | Upcoming Tasks | `GET /api/v2/users/me/upcoming-tasks` |
| upcoming day plan actions, what's on my schedule, day/week column view, my future plans, upcoming planned tasks, what have I planned | Upcoming Day Plan Actions | `GET /api/v2/day-plans/upcoming-actions` |
| my inbox, items assigned to me, what teammates asked me to do, delegated items, assigned by others, inbox | My Inbox | `GET /api/v2/users/me/inbox` |
| my outbox, items I delegated, items assigned by me to others, what I asked teammates to do, delegated tasks, outbox, delegated to others | My Outbox | `GET /api/v2/users/me/outbox` |
| reorder outbox, drag outbox item, reposition delegated item, sort outbox | Reorder Outbox | `POST /api/v2/users/me/outbox/reorder` |
| filter outbox by person, show items assigned to person, outbox for user, delegated to person, outbox filtered by assignee | Filter Outbox by Person | `POST /api/v2/users/me/outbox/filter-by-person` |
| assigned to me, my asks, what's been assigned to me, assigned to me tab | Assigned to Me | `GET /users/me/assigned-to-me`, `GET /users/me/assigned-to-me/count` |
| accept assignment, decline assignment, say yes/no to an ask | Assigned to Me Accept/Decline | `PATCH /users/me/assigned-to-me/{item_id}`, `DELETE /users/me/assigned-to-me/{item_id}` |
| custom label, personal label, team label, project label, tag, my label | Custom Label | `GET /api/v2/custom-labels` |
| create label, add label, new label, create tag, create team label, create project label | Create Label | `POST /api/v2/custom-labels` |
| rename label, update label, change label color | Update Label | `PATCH /api/v2/custom-labels/{id}` |
| delete label, remove label, delete tag | Delete Label | `DELETE /api/v2/custom-labels/{id}` |
| set labels on item, tag item, apply labels, sync labels, label this, attach labels, update item labels | Manage Labels on Content | `POST /api/v2/custom-labels/manage` |
| labels on this item, show item labels, label picker, which labels are attached | Labels for Content | `GET /api/v2/custom-labels/content` |
| team admin, who is team admin, list team admins | Team Admin | `GET /api/v2/teams/{id}/admins` |
| make team admin, grant team admin, add team admin | Grant Team Admin | `POST /api/v2/teams/{id}/admins` |
| remove team admin, revoke team admin | Revoke Team Admin | `DELETE /api/v2/teams/{id}/admins/{user_id}` |
| project admin, who is project admin, list project admins | Project Admin | `GET /api/v2/projects/{id}/admins` |
| make project admin, grant project admin, add project admin | Grant Project Admin | `POST /api/v2/projects/{id}/admins` |
| remove project admin, revoke project admin | Revoke Project Admin | `DELETE /api/v2/projects/{id}/admins/{user_id}` |
| project permissions, who has access to project, list project roles, project access | List Project Permissions | `GET /api/v2/projects/{id}/permissions` |
| grant project access, give user project role, add project permission, share project with user | Grant Project Permission | `POST /api/v2/projects/{id}/permissions` |
| revoke project access, remove user from project, remove project permission, remove all project roles | Revoke Project Permission | `DELETE /api/v2/projects/{id}/permissions` |
| page, doc, wiki, team doc, team wiki, team note, team knowledge base | Page | `/teams/{team_id}/pages`, `/teams/{team_id}/pages/{page_id}` |
| list pages, show team pages, team docs, team wiki | List Pages | `GET /teams/{team_id}/pages` |
| create page, new page, new doc, new wiki page | Create Page | `POST /teams/{team_id}/pages` |
| edit page, update page, rename page | Update Page | `PATCH /teams/{team_id}/pages/{page_id}` |
| move page, nest page under, reparent page, reorder page | Move/Reorder Page | `PATCH /teams/{team_id}/pages/{page_id}` (parent_id / position) |
| delete page, remove page | Delete Page | `DELETE /teams/{team_id}/pages/{page_id}` |
| page permissions, who can edit page, page roles, share page | Page Permissions | `/pages/{page_id}/permissions` |
| grant page access, add page editor, share page with | Grant Page Permission | `POST /pages/{page_id}/permissions` |
| page blocks, insert content block, edit block, page block writes | Page Content Blocks | `GET`/`POST /pages/{id}/blocks`, `PATCH`/`DELETE /pages/{id}/blocks/{blockId}` |
| publish page, make page public, public page link | Page Publishing | `GET`/`POST`/`DELETE /pages/{id}/publish` |
| published pages registry, unpublish all pages | Team Published Pages Registry | `GET`/`DELETE /teams/{id}/pages/published` |
| page audience, who can see this page, private page, restrict page | Page Audience | `GET`/`PUT /pages/{id}/audience` |
| break glass on page, restore admin access to page | Page Break-Glass | `POST /pages/{id}/break-glass` |
| page template, template gallery, save page as template | Page Templates | `GET`/`POST /teams/{id}/page-templates`, `/page-templates/{templateId}` |
| lock page, unlock page, unlock for me | Page Lock | `PATCH /teams/{id}/pages/{pageId}/lock`, `PATCH .../lock/me` |
| archive page, unarchive page | Archive Page | `PATCH /teams/{id}/pages/{pageId}/archive` |
| move page to another team | Move Page (cross-team) | `POST /teams/{id}/pages/{pageId}/move` |
| restore deleted page, undelete page | Restore Page | `POST /teams/{id}/pages/{pageId}/restore` |
| page comments, comment thread, resolve comment, reopen comment | Page Comments | `GET`/`POST /teams/{id}/pages/{pageId}/comments`, `PATCH /comments/{commentId}/resolution` |
| revoke page access, remove page editor | Revoke Page Permission | `DELETE /pages/{page_id}/permissions` |

### Item Types

| User Language | DB type | POST body |
|---------------|---------|-----------|
| task, to-do, action item | Task (default) | `{ "name": "..." }` |
| project, todo list | TodoList | `{ "name": "...", "type": "TodoList" }` |
| outcome, objective | Outcome | `{ "name": "...", "type": "Outcome" }` |
| key result, KR | KeyResult | `{ "name": "...", "type": "KeyResult" }` |

### Context (Where to Create)

| User Says | Context Body | Effect |
|-----------|-------------|--------|
| create in team, add to team 42 | `{ "type": "team", "id": 42 }` | Creates in team, sets on_weekly=true |
| create for meeting, add to meeting 99 | `{ "type": "meeting", "id": 99 }` | Creates and links to meeting |
| create for today, add to my plan | `{ "type": "day_plan" }` | Creates and adds to today's day plan |
| _(nothing)_ | _(omit context)_ | Creates as standalone item |

### Smart Text Features

| User Says | Feature | Example | Effect |
|-----------|---------|---------|--------|
| assign @john, @username | @-mention auto-assign | `"Fix bug @jdoe"` | Auto-assigns mentioned user |
| due tomorrow, #tomorrow | Hashtag date shortcut | `"Fix bug #tomorrow"` | Sets due to tomorrow |
| due next week, #nextweek | Hashtag date shortcut | `"Fix bug #nextweek"` | Sets due to next week |
| due in a month, #1month | Hashtag date shortcut | `"Fix bug #1month"` | Sets due to 1 month from now |

### Status Aliases

| User Says | API Status | Notes |
|-----------|-----------|-------|
| not started, new, fresh | `not_started` | Default for new items |
| next, to-do, priority, up next | `next` | Prioritized for this period |
| parked, on hold, deprioritized, later | `parked` | Temporarily shelved |
| blocked, stuck, issue, waiting | `blocked` | Has a dependency/blocker |
| done, complete, finished, resolved | `done` | Completed (sets complete date) |
| archived, deleted, removed | `archived` | Soft-deleted |
| draft | `draft` | Read-only — cannot be set via API |
| in progress (review) | `in_progress` | Review: awaiting assessments |
| assessed (review) | `assessed` | Review: both assessments submitted |
| signed off (review) | `signed_off` | Review: reviewer approved |
| voided (review) | `voided` | Review: cancelled with reason |

### Framework Column Names

| API Column | Default | EOS | OKR | 4DX | V2MOM | SRT | SVEP |
|-----------|---------|-----|-----|-----|-------|-----|------|
| next | Next | To-Do | Priorities | WIG Actions | Next | Next | Next |
| done | Done | Done | Done | Done | Done | Done | Done |
| blocked | Issues | Issues | Issues + Challenges | Blockers | Obstacles | Issues | Issues |
| parked | Parked | Parked | Park for Later | Parked | Parked | Parked | Parked |

### Key Distinctions

| Concept A | Concept B | Difference |
|-----------|-----------|------------|
| Creator (`creator` field) | Assignee (`assignees` array) | Creator = who created the item. Assignees = who's responsible for it. One creator, many assignees. Accountability ownership = assignees if any, otherwise creator. |
| Archive (`DELETE /items/{id}`) | Delete (`DELETE /teams/{id}`) | Items are soft-deleted (status→archived). Teams are permanently deleted. |
| Completed (day plan) | Done (item status) | Both routes now produce the same state — `completed: true` on the day plan and `status: done` on the item each set the other. The distinction that remains is recurring items: for those, only the day plan toggles and the item stays active for tomorrow. |
| on_weekly (item field) | status (item field) | `on_weekly` controls board visibility. `status` controls the column. An item can be `status: next` but `on_weekly: false`. |
| One-on-one meeting | Project meeting | One-on-ones use `/1-on-1` endpoints; persons nested under `persons.person1`/`persons.person2`. Project meetings are out of scope for rkit:1on1 and will get a separate skill. |
| Team projects (`/teams/{id}/projects`) | Standalone projects (`/projects`) | Team projects are scoped to a team. Standalone are user-level. Same underlying data (type=TodoList). |
| `DELETE /teams/{id}/projects/{pid}` | `DELETE /projects/{id}` | Team version removes from team (clears group_id). Standalone version archives the project. |
| Headline (`/teams/{id}/headlines`) | Comment (`/items/{id}/comments`) | Headlines are team-level announcements (EOS only, auto-expire after 7 days). Comments are item-level notes. |
| Draft assessment | Submitted assessment | Draft saves WIP without advancing state. Submit finalizes and transitions review when both parties submit. |
| Review archive (`DELETE /reviews/{id}`) | Review void (`PUT /reviews/{id}/void`) | Archive soft-deletes. Void records a reason and blocks all further lifecycle actions. |
| Core values ratings (standalone) | Core values ratings (in review) | Standalone via `POST /core-values-ratings`. In-review via `core_values_ratings` in AssessmentSubmitRequest. |
