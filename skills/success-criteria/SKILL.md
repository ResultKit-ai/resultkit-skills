---
name: rkit:success-criteria
description: Review, grade, write, and rewrite the Success Criteria of any process document — stack-model docs, ResultKit pages, SOPs, playbooks, runbooks. Use this skill whenever someone asks about success criteria, says "are these good criteria", "grade these", "tighten this success section", "what does done look like for this process", "how do we know it's done", "results look like", or pastes or links a process doc and wants its success section reviewed, scored, or rewritten. Also use when someone shares a ResultKit page URL alongside criteria talk, when writing a new process doc's success section from scratch, and when coaching someone on how to write criteria. Grades every criterion against seven rules — end state not activity, stranger-verifiable, binary, countable scope, handoff included, 3-6 max, grounded examples — and hands back a rewritten set in the author's own vocabulary.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Bash(pandoc *), Bash(npx *), Bash(date *), Read, Glob, Grep, AskUserQuestion
---

# rkit:success-criteria

Grade and rewrite the Success Criteria of a process document. Criteria describe the world *after* the work; the checklist describes the work. Most weak criteria are checklist steps that drifted upstairs.

ResultKit pages go through the ResultKit connector's MCP tools, named below by base name: the full tool name is `mcp__<server>__<tool>` and the server alias varies by install, so match on the base name. Every page job has a live connector tool, so `scripts/api.sh` is not used.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- Today: !`date +%F`

## Rules

- **Grade before you rewrite.** Show the verdict table first, then the rewritten set. The author needs to see *why* a line failed, not just a better line.
- **Confirm writes.** Before any page write (create or update), summarize all planned changes in a single prompt and ask for confirmation. Batch related mutations under one confirmation. Reads execute immediately.
- **Archive before overwriting.** Never update a page body without first creating a dated archive copy — see Flow: Apply to a ResultKit Page.
- **The author's words win.** Preserve intent and domain vocabulary. If they say "sublot", "Razor", "settlement", the rewrite says it too. You are tightening their criteria, not substituting yours.
- **Concise output.** Table, then the rewritten set. No preamble, no reciting the rules back at them.
- **Direct execution.** Call the connector tools directly. Never use Task agents, never curl or hand-build a URL, and skip the connector's `guide` tool.

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
| `write {page_id}` / "apply it" after a review | Archive the page, then update the rewritten section |
| `new "{process name}"` | Interview for the end state, draft 3–6 criteria |
| *(no args)* | Ask which criteria — page ID, file path, or paste |

## Tools

| Job | Tool and arguments |
|---|---|
| Find a page (unknown ID, or the team's Archive page) | `list_pages`: `team_id`. Answers the team's pages as a flat list: `id`, `title`, `parent_id`, `position`, `can_edit`. |
| Read a page as markdown | `get_page`: `team_id`, `page_id`, `markdown: true`. Answers `title`, `body`, `can_edit`. |
| Create the archive copy | `create_page`: `team_id`, `title`, `body`, `parent_id`, `markdown: true`. Answers the new page's `id`, not its body. |
| Update the page | `update_page`: `page_id`, `team_id`, `body`, `markdown: true`. Answers the saved page's `id`, not its body. |

---

## Flow: Obtain the Criteria

Pasted text and local files need no tool call — read them as-is. For a ResultKit page, resolve the team from args or `default_team_id` (neither → "No team specified and no default configured. Run `/rkit:setup`."), then call `get_page` with `markdown: true` (unknown ID → `list_pages` for the team first, and pick the page from the list).

`markdown: true` returns `body` as markdown — the stored source for a markdown-authored page, converted from HTML otherwise. Take the Success section — the heading matching "Success", "Results Look Like", or "Definition of Done", plus the list beneath it — and note `can_edit` before offering to apply anything. No Success section anywhere → say so and offer to draft one from the checklist.

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

**Step 2 — Archive.** Find the team's archive page in the tree (top-level, titled "Archive" or similar) with `list_pages`; if there isn't one, ask before creating it rather than inventing tree structure. Then `create_page` with `title` = `"{title} — {Today}"`, `body` = the current markdown body, `parent_id` = the archive page's ID, `markdown: true`. The answer must name the new page's `id` before Step 3 — if the archive write fails, stop and report; never update an unarchived page.

**Step 3 — Update.** Send markdown as-is with `markdown: true` — no local conversion — and splice the new section into the existing body rather than replacing the page. Read the current body back with `get_page` (`markdown: true`) so you are splicing into markdown, not HTML, then `update_page` with the full spliced markdown as `body`. A write's answer carries no body — confirm by the `id` it names.

Report: "Updated **{title}** ({page_id}). Archived as {archive_id}."

## Errors

| The tool answers | Say |
|---|---|
| tools missing, or an authorization error | "The ResultKit connector isn't connected. Connect it (https://mcp.resultkit.ai) and try again." |
| "Title cannot be empty", "Title cannot exceed 255 characters", "Body cannot exceed 2MB" | Show the validation message. |
| "You do not have permission to …" a page | "You don't have permission — editing needs an author/editor/contributor role on the page." |
| "Page not found", "Team not found or you don't have access to it." | "Team or page not found (404)." |
| "This page is locked", any other `Error: …` | Show it as returned. |

## Edge Cases

- **No Success section**: offer to draft one from the checklist — criteria are usually the last step of each checklist phase, restated as a state.
- **One criterion**: not a failure on its own, but ask what the next seat receives; rule 5 almost always surfaces a second.
- **Policy dressed as a criterion** ("we always double-check"): ask what artifact proves it, then rewrite around that artifact.
- **`can_edit: false`**: grade and hand back the rewrite as text; don't offer to apply it.
- **No converter installed**: irrelevant — markdown goes to the page tool as-is. Never hand the rewrite back and refuse the write for a missing pandoc or npx.

## References

- [The Seven Rules — full rubric](references/rules.md) — why each rule matters, good/bad pairs, and a worked before/after of a whole criteria set. Read it when the user wants the reasoning, is training someone, or pushes back on a verdict.
- [Stack-model process docs](references/stack-model.md) — the section order these criteria sit in, and how Success relates to the checklist and to handoffs. Read it when working in a stack-model doc and a structure question comes up.
- [ResultMaps V2 API Reference](references/api-reference.md) — see the **Pages** section for the permission model (author > editor > contributor > viewer).
