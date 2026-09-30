---
name: rkit:braindump
description: Parse unstructured text (meeting notes, emails, dictation, voice memos, chat, pasted text) into organized action items using the team's management framework. Outputs a structured table with item names, types, status, context, owners, and dates. Use this skill when users paste unstructured text, meeting notes, emails, or voice memo transcripts and want them organized into actionable items.
user-invocable: true
allowed-tools: Bash(scripts/api.sh *), Bash(jq *), Bash(date *), Read, Glob, Grep, AskUserQuestion
---

# rkit:braindump

Parse unstructured input into organized action items using the team's management framework.

## Current State

- Config: !`if [ -f "$HOME/.config/resultkit/config.json" ] && jq empty "$HOME/.config/resultkit/config.json" 2>/dev/null; then echo "EXISTS"; jq '{token_masked: (.api_token[:3] + "..." + .api_token[-4:]), default_team_id, api_base}' "$HOME/.config/resultkit/config.json"; else echo "MISSING — run /rkit:setup"; fi`
- Today: !`date +%Y-%m-%d`

## Rules

- **Interpret first, act second.** Read the user's pasted text. Parse it. Present the table. Ask only when truly ambiguous.
- **Confirm writes.** GET requests execute immediately. POST/PUT/PATCH/DELETE: summarize all planned changes in a single prompt and ask for confirmation. Batch related mutations under one confirmation.
- **Show IDs.** Always include entity IDs in output.
- **Concise output.** Tables and short summaries. No filler.
- **Direct execution.** Use Bash with api.sh for all API calls. Never use Task agents.
- **Framework-aware.** Use the team's framework terminology (EOS, OKR, 4DX, V2MOM, SRT) when labeling items.

---

## Core Principles

1. **Handle partial information gracefully** — Full context is ideal but not required. Infer what you can, ask only when truly ambiguous.

2. **Minimize interactions while remaining intelligent** — Default to sensible assumptions. The goal is an experience that feels magical, not one that interrogates the user.

3. **The line between "magical" and "stupid"** — Smart inference without wrong assumptions. When uncertain, ask; when reasonably confident, proceed.

## Object Model

See `references/eos-object-model.md` for full definitions. Summary:

| Type | Definition | Default Destination |
|------|------------|---------------------|
| Action Item | General task | Personal Planner |
| To-do | Action item on L10 or 1:1 (7-day due) | L10/1:1 + others |
| Issue | Blocked/stuck item or identified problem | Same as above |
| Project | Collection of action items | (container) |
| Rock | 90-day target | (reference only) |
| Milestone | Sub-component of rock/project | (reference only) |

## Output Format

Always output a markdown table with these columns:

| Column | Content |
|--------|---------|
| Item | Descriptive name (may include ticket IDs like SUP-XXX, RSW-XXXXX) |
| Description | Verbatim source text in quotes, prefaced with source type (e.g., "from pasted email:", "from dictation:") |
| Organize as a | To-do, Action Item, Issue, Project |
| Status | Done, Not Done |
| Context | Destination(s): Personal Planner, L10, 1:1, Project name |
| Owner | Person responsible |
| Created at | Date (YYYY-MM-DD) |
| Due by | Date (YYYY-MM-DD) |

## Issue Handling

When an Issue is identified:

1. Create the Issue row with description appended: "— to-do logged for {person} to {resolve | investigate and provide a timeline}"

2. Create a corresponding To-do row:
   - Item: "{ticket ID if exists} {investigate | resolve} {issue summary}"
   - Description: "To resolve the issue '{issue name}' by {owner} on {created date}"
   - Owner: Same as Issue owner unless explicitly stated otherwise

## Default Behaviors

Apply these defaults to minimize questions:

| Situation | Default |
|-----------|---------|
| L10 or 1:1 context | 7-day due date |
| Owner not stated | Person who surfaced the item |
| Created at not clear | Today's date |
| Issues | Auto-generate corresponding To-do |
| No context specified | Personal Planner |
| "Me" as owner | Acceptable; use as-is |

## When to Ask

Only ask when:

- **Owner** is genuinely unclear (e.g., "your Robert" in someone else's email)
- **Context** cannot be reasonably inferred and would affect due dates
- **Completed items** appear — confirm include or filter out
- **Potential duplicates** — confirm if items are same or distinct
- **Dates** not derivable from source and due date matters

## Parsing Guidelines

1. **Item names**: Create descriptive names, not just ticket IDs. Example: "SUP-946 fix incorrect last login date" not just "SUP-946"

2. **Split compound items**: "Update OIT and Mender scorecards" → two separate rows

3. **Preserve verbatim text**: Put original text in Description column in quotes

4. **Infer action verbs**: Add appropriate verbs when missing. "Accuracy data from MAHA" → "Get accuracy data from MAHA"

5. **Source attribution**: Always prefix Description with source type:
   - "from pasted email:"
   - "from dictation:"
   - "from meeting notes:"
   - "from chat:"

## Example Interaction Flow

**User pastes unstructured text** → Parse into table → Ask minimal clarifying questions → Update table with answers → Done

Batch questions together. Allow user to answer multiple questions in one response.

Example questions:
- "Owner: These appear to be Gus's items—confirm? Exception: item X mentions 'Robert'—is Robert the owner?"
- "Completed items: Include SUP-909 and SUP-347 as Done, or filter out?"
- "Context: Do any of these belong to an L10 or 1:1, or all Personal Planner?"

## References

- [EOS Object Model](references/eos-object-model.md)
