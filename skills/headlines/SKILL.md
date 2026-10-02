---
name: rkit:headlines
description: View and manage EOS headlines (People & Customer Headlines) for a team. List active headlines, add new ones, archive (soft-delete), and update text or expiration. Uses L10-specific API routes for EOS teams. Use this skill when users mention headlines, people headlines, customer headlines, team announcements, or want to add, remove, or update headlines for their team.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Read, Glob, Grep, AskUserQuestion
---

# rkit:headlines

Drives the ResultKit connector's MCP tools; `scripts/api.sh` is used only for the jobs under **Fallback (api.sh)**. Tools are named by base name below; the callable name is `mcp__<server>__<tool>` and the `<server>` alias varies by install, so match on the base name.

## Current State

- Config status: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING"; fi`
- api.sh (Fallback only): !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/headlines/scripts/api.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/headlines/scripts/api.sh "$HOME/.claude/skills/rkit:headlines/scripts/api.sh" "$HOME/.agents/skills/headlines/scripts/api.sh" "$HOME/.gemini/skills/headlines/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

## Rules

- **Confirm writes**: Before any create, update or archive, summarize all planned changes in a single prompt and ask for confirmation. If the command implies multiple related mutations, batch them under one confirmation. Reads execute immediately.
- **Show IDs**: Include headline IDs wherever the source carries them, so users can reference them. `list_headlines` carries none: IDs come from a `create_headline` or `update_headline` answer, or from the Fallback read. This overrides the connector's general "never print ids" note.
- **Concise output**: Tables and short summaries. No verbose prose.
- **Direct execution**: Call the connector tools directly. Never use Task agents or subagents, never curl or hand-build a URL, and skip the connector's `guide` tool — the flows below are complete for this skill.

## Argument Parsing

Parse the user input to determine which flow to follow:

| Input | Flow |
|-------|------|
| *(no args)* | View Headlines |
| `add "text"` | Add Headline |
| `remove {headline_id}` | Archive Headline |
| `update {headline_id} ...` | Update Headline |
| `--team {id}` *(anywhere in args)* | Override team ID for any flow |

If the input doesn't match any pattern, show this usage summary and ask what they'd like to do.

## Team ID Resolution

1. **`--team {id}` flag** in args → use that team ID
2. **`default_team_id` in config** → use that
3. **Neither** → "No default team configured. Run `/rkit:setup` first."

## Tools

| Job | Tool and arguments |
|---|---|
| Team name | `get_team`: `team_id` (answers text; line 1 is `# {team_name}`) |
| List active headlines | `list_headlines`: `team_id` |
| Create | `create_headline`: `team_id`, `text`, `expires_at?` |
| Update | `update_headline`: `team_id`, `headline_id`, `text?`, `expires_at?` |
| Archive (soft-delete) | `archive_headline`: `team_id`, `headline_id` |

Headlines exist only for EOS teams; the tools refuse any other team. Create and update answer the headline as JSON (`id`, `text`, `expires_at`); archive answers one sentence.

## Flow: View Headlines

**Trigger**: No args (or only `--team {id}`)

Resolve the team ID, then call `get_team` and `list_headlines` together. `list_headlines` answers prose: a header `{N} headlines:` (or `{shown} of {total} headlines:`), then one line per headline, `- "text" — Creator (YYYY-MM-DD) [category: …; expires: YYYY-MM-DD; N attachments]`. With none: "No active headlines for {team_name}."

```
Headlines: {team_name} (ID: {team_id})

| Text | Creator | Expires | Created |
|------|---------|---------|---------|
| New client signed | John Smith | 2026-03-03 | 2026-02-24 |
| Office lease renewed | Jane Doe | 2026-03-04 | 2026-02-25 |

{N} headlines shown
```

**Display rules**:
- No ID column: `list_headlines` carries no IDs. When the user asks for IDs, or wants to change a headline by its text, run the Fallback read and show its table instead.
- Creator is the name as given (`first_name last_name`, else `login`). Created is the date in parentheses. Expires is the `expires:` value, "—" when absent.
- If the header reads `{shown} of {total} headlines`, show "(showing {shown} of {total})" after the table.

## Flow: Add Headline

**Trigger**: `add "text"` or `add "text" --expires {YYYY-MM-DD}`

1. Extract the headline text — everything after `add` that is not a flag (`--expires`, `--team`). Empty or whitespace-only → "Headline text cannot be empty." Date = `--expires`, else 7 days from today in YYYY-MM-DD.
2. Resolve the team ID and `get_team` for the name. Confirm:
   > Create headline "**{text}**" for **{team_name}** (expires {date})?
3. Call `create_headline` (`team_id`, `text`, `expires_at`). It answers the new headline: "Created headline **{id}**: \"{text}\" (expires {date})."

## Flow: Archive Headline

**Trigger**: `remove {headline_id}`

Resolve the team ID and `get_team` for the name. If the user named the headline instead of giving an ID, find the ID with the Fallback read first. Confirm:
> Archive headline **{headline_id}** from **{team_name}**?

Then `archive_headline` (`team_id`, `headline_id`): "Archived headline **{headline_id}**."

## Flow: Update Headline

**Trigger**: `update {headline_id} --text "new text"` and/or `--expires {YYYY-MM-DD}`

1. Extract `headline_id` (first argument after `update`; a headline named by its text → find the ID with the Fallback read), `--text` and `--expires`. Neither flag → "Provide at least one of --text or --expires to update."
2. Resolve the team ID and `get_team` for the name. Describe what changes — `text → "{new_text}"`, `expires → {new_date}`, or both. Confirm:
   > Update headline **{headline_id}** on **{team_name}**: {changes}?
3. Call `update_headline` (`team_id`, `headline_id`, plus only the fields provided: `text`, `expires_at`). It answers the headline: "Updated headline **{id}**: \"{text}\" (expires {date})."

## Fallback (api.sh)

The connector has no tool for this job, so it runs as before: `RESPONSE=$("<api.sh path>" METHOD PATH)` returns `{status, body}`. Reads need no confirmation.

| Job | Call |
|---|---|
| Headlines with IDs (to show IDs, or to find the ID of a headline the user named by its text) | `GET /teams/TEAM_ID/l10/headlines?per_page=100`, or `GET /teams/TEAM_ID/headlines?per_page=100` when `get_team`'s `**Framework**` line is not `eos`. Headlines in `body.data`, total in `body.meta.total`. Table columns `ID`, `Text`, `Creator`, `Expires`, `Created`: Creator `first_name last_name` (else `login`); dates YYYY-MM-DD (date part of ISO `created_at`); `expires_at` null → "—"; if `meta.total` > 100, "(showing 100 of {total})". |

api.sh errors: `NO_CONFIG` or `NO_TOKEN` "Config not found. Run `/rkit:setup` first."; `CURL_FAILED` "Network error. Check your connection."; 401 "Unauthorized (401). Run `/rkit:setup` to update your token."; 422 mentioning "EOS framework" "Headlines are only available for teams using the EOS framework."; path `NOT_FOUND` "api.sh not found. Install via: `/plugin marketplace add ResultKit-ai/resultkit-skills` then `/plugin install rkit@resultkit`"

## Errors

| The tool answers | Say |
|---|---|
| tools missing, or an authorization error | "The ResultKit connector isn't connected. Connect it (https://mcp.resultkit.ai) and try again." |
| "Team not found or you don't have access to it." / "You don't have access to this team." | "Team {id} not found, or you don't have access to it." |
| "Headlines are only available for teams using the EOS framework" | "Headlines are only available for teams using the EOS framework." |
| "Headline not found or you don't have access to it." | "Headline {id} not found, or you can't change it (only its creator or a team admin can)." |
| "Validation failed: expires_at …" | "Expiration date must be in YYYY-MM-DD format." |
| any other `Error: …` | Show it as returned. |

No default team and no `--team` → "No default team configured. Run `/rkit:setup` first."

## References

- [ResultMaps V2 API Reference](references/api-reference.md)
