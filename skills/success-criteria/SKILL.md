---
name: rkit:success-criteria
description: Review, grade, write, and rewrite the Success Criteria of any process document — stack-model docs, ResultKit pages, SOPs, playbooks, runbooks. Use this skill whenever someone asks about success criteria, says "are these good criteria", "grade these", "tighten this success section", "what does done look like for this process", "how do we know it's done", "results look like", or pastes or links a process doc and wants its success section reviewed, scored, or rewritten. Also use when someone shares a ResultKit page URL alongside criteria talk, when writing a new process doc's success section from scratch, and when coaching someone on how to write criteria. Grades every criterion against seven rules — end state not activity, stranger-verifiable, binary, countable scope, handoff included, 3-6 max, grounded examples — and hands back a rewritten set in the author's own vocabulary.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Bash(pandoc *), Bash(npx *), Bash(date *), Read, Glob, Grep, AskUserQuestion
---

# rkit:success-criteria

Grade and rewrite the Success Criteria of a process document. Criteria describe the world *after* the work; the checklist describes the work. Most weak criteria are checklist steps that drifted upstairs.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- api.sh: !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/success-criteria/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/success-criteria/scripts/api.sh "$HOME/.claude/skills/rkit:success-criteria/scripts/api.sh" "$HOME/.agents/skills/success-criteria/scripts/api.sh" "$HOME/.gemini/skills/success-criteria/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`
- Today: !`date +%F`

## Rules

- **Grade before you rewrite.** Show the verdict table first, then the rewritten set. The author needs to see *why* a line failed, not just a better line.
- **Confirm writes.** Before any POST/PATCH/DELETE, summarize all planned changes in a single prompt and ask for confirmation. Batch related mutations under one confirmation. GET requests execute immediately.
- **Archive before overwriting.** Never PATCH a page body without first creating a dated archive copy — see Flow: Apply to a ResultKit Page.
- **The author's words win.** Preserve intent and domain vocabulary. If they say "sublot", "Razor", "settlement", the rewrite says it too. You are tightening their criteria, not substituting yours.
- **Concise output.** Table, then the rewritten set. No preamble, no reciting the rules back at them.
- **Direct execution.** Use Bash with api.sh for all API calls. Never use Task agents.

## The Seven Rules

Grade every criterion against all seven. Full rubric with examples: `references/rules.md`.

1. **End state, not activity** — describe the world after the work ("Results Look Like…"). An item that opens with a doing-verb is a checklist step that snuck upstairs.
2. **Stranger test** — someone outside the team can verify yes/no by looking. Name the artifact and where it lives: "entered in Razor", "on the calendar".
3. **Binary** — done or not done. No quality adverb without a measure attached; "properly", "timely", "accurately" are bans.
4. **Countable scope** — "all pallets", "every sublot", and a number wherever one exists.
5. **Handoff included** — done means the next seat has what it needs, stated as a condition of the criterion.
6. **3–6 criteria** — more than six usually means the process is really two processes.
7. **Grounded pairs** — coach with a good/bad pair drawn from their doc, not from this file.

## Argument Parsing

| Input | Behavior |
|-------|----------|
| *(pasted criteria)* | Grade and rewrite in the reply |
| `{page_id}` or a `resultkit.ai/pages/{id}` URL | Read the page, grade its Success section, propose a rewrite |
| `{path/to/doc.md}` | Read the local doc, grade its Success section |
| `write {page_id}` / "apply it" after a review | Archive the page, then PATCH the rewritten section |
| `new "{process name}"` | Interview for the end state, draft 3–6 criteria |
| *(no args)* | Ask which criteria — page ID, file path, or paste |

---

## Flow: Obtain the Criteria

Pasted text and local files need no API call — read them as-is. For a ResultKit page, resolve the team from args or `default_team_id` (neither → "No team specified and no default configured. Run `/rkit:setup`."):

```bash
API_SH="<api.sh path>"
RESPONSE=$("$API_SH" GET "/teams/TEAM_ID/pages/PAGE_ID?format=markdown")   # unknown ID → GET /teams/TEAM_ID/pages first
echo "$RESPONSE"
```

`?format=markdown` returns `body.data.body` as markdown — the stored source for a markdown-authored page, converted from HTML otherwise. Take the Success section — the heading matching "Success", "Results Look Like", or "Definition of Done", plus the list beneath it — and note `can_edit` before offering to apply anything. No Success section anywhere → say so and offer to draft one from the checklist.

## Flow: Grade

One row per criterion, in the author's original order:

```
## Success Criteria — {page or doc title}

| # | Criterion | Verdict | Fails | Why |
|---|-----------|---------|-------|-----|
| 1 | Material processed efficiently | Rewrite | 3 Binary, 2 Stranger | "efficiently" has no measure |
| 2 | All pallets weighed, tagged, entered in Razor | Keep | — | — |

{n} criteria · {k} keep · {m} rewrite
```

- **Fails** names the rule number and short name — every rule the line breaks, worst first. **Why** is one clause, not a sentence; quote the offending word when there is one.
- More than six criteria → add one line under the table proposing the split, naming the two processes.

## Flow: Rewrite

Rewrite the whole set, not only the failures — a half-rewritten set reads inconsistently. Keep the author's nouns, systems, and role names verbatim; land at 3–6 by merging overlapping lines rather than dropping content; end with the handoff criterion when the process feeds another seat. Hand it back as the checkbox list the doc already uses, ready to paste:

```
## Success: Results Look Like…

- [ ] All pallets weighed, tagged, photographed, and entered in Razor
- [ ] Every resale-bound unit shows Data Erasure = Passed with the tester recorded
- [ ] Settlement can review the order without sending anything back for grade or notes correction
```

Close with one line naming what changed and why — not a rule-by-rule replay.

## Flow: Apply to a ResultKit Page

Only on explicit request. Two writes, one confirmation.

**Step 1 — Confirm.** State the exact change: page title and ID, the section being replaced, and the archive that will be created first.

> Replace the Success section of **{title}** ({page_id})? A dated copy is archived first as **{title} — {YYYY-MM-DD}** under **Archive** ({archive_page_id}). {n} criteria in, {m} out. Nothing else on the page changes.

**Step 2 — Archive.** Find the team's archive page in the tree (top-level, titled "Archive" or similar); if there isn't one, ask before creating it rather than inventing tree structure.

```bash
DATE=$(date +%F)
PAYLOAD=$(jq -n --arg t "TITLE — $DATE" --arg b "CURRENT_MARKDOWN_BODY" --argjson p ARCHIVE_PAGE_ID \
  '{title: $t, body: $b, parent_id: $p}')
"$API_SH" POST "/teams/TEAM_ID/pages?format=markdown" "$PAYLOAD"
```

A 201 is required before Step 3 — if the archive write fails, stop and report; never PATCH an unarchived page.

**Step 3 — Patch.** Send markdown as-is with `?format=markdown` — no local conversion — and splice the new section into the existing body rather than replacing the page.

```bash
BODY=$(cat "REWRITTEN_FULL_PAGE.md")
PAYLOAD=$(jq -n --arg body "$BODY" '{body: $body}')
"$API_SH" PATCH "/teams/TEAM_ID/pages/PAGE_ID?format=markdown" "$PAYLOAD"
```

Read the current body back with `GET "/teams/TEAM_ID/pages/PAGE_ID?format=markdown"` so you are splicing into markdown, not HTML. A write's response carries no `body` — confirm by the `id` it names.

Report: "Updated **{title}** ({page_id}). Archived as {archive_id}."

## Error Handling

api.sh wraps every response as `{"status": N, "body": {...}}` — always read fields via `.body.…`.

- `"error": "NO_CONFIG"` / `"NO_TOKEN"` → "Config not found. Run `/rkit:setup` first."
- `"error": "CURL_FAILED"` → "Network error. Check your connection."
- `status: 400` → show the validation message (empty title, title > 255, body > 100KB).
- `status: 401` → "Unauthorized (401). Run `/rkit:setup` to update your token."
- `status: 403` → "You don't have permission — editing needs an author/editor/contributor role on the page."
- `status: 404` → "Team or page not found (404)."

## Edge Cases

- **api.sh not found**: "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"
- **No Success section**: offer to draft one from the checklist — criteria are usually the last step of each checklist phase, restated as a state.
- **One criterion**: not a failure on its own, but ask what the next seat receives; rule 5 almost always surfaces a second.
- **Policy dressed as a criterion** ("we always double-check"): ask what artifact proves it, then rewrite around that artifact.
- **`can_edit: false`**: grade and hand back the rewrite as text; don't offer to apply it.
- **No converter installed**: irrelevant — markdown goes to the API as-is. Never hand the rewrite back and refuse the write for a missing pandoc or npx.

## References

- [The Seven Rules — full rubric](references/rules.md) — why each rule matters, good/bad pairs, and a worked before/after of a whole criteria set. Read it when the user wants the reasoning, is training someone, or pushes back on a verdict.
- [Stack-model process docs](references/stack-model.md) — the section order these criteria sit in, and how Success relates to the checklist and to handoffs. Read it when working in a stack-model doc and a structure question comes up.
- [ResultMaps V2 API Reference](references/api-reference.md) — see the **Pages** section for full payloads and the permission model (author > editor > contributor > viewer).
