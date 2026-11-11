---
name: rkit:my-setup
description: The expert on your own ResultKit setup — every company, team, project and 1:1 you belong to — so you can ask anything about them by a loose name and never say which team or sub-team a thing lives in. Use this skill whenever the user asks about "my" projects, teams, clients, companies, 1:1s or meetings without giving an ID or the exact team, for example "what percent of the cards are done in my Acme stability project", "which project is the product roadmap", "who do I have 1:1s with at Acme", "what's set up for Examp.ly", "where should this to-do go", "what do I belong to", "which of my companies are clients". Also use it first whenever another rkit skill needs a team, project or 1:1 ID the user described in words. It finds the thing, reads the answer, and remembers the user's own nicknames and where-things-go rules in a private notes file. Read-only in ResultKit. Not for login, token or default team — that is rkit:setup.
user-invocable: true
allowed-tools: Bash(scripts/find.sh *), Bash(scripts/api.sh GET *), Bash(jq *), Bash(mkdir -p *), Read, Write, Edit, AskUserQuestion
---

# rkit:my-setup

Knows where everything in the user's ResultKit lives. The user says a loose name; this skill finds the exact company, team, project or 1:1, then reads the answer. It never changes anything in ResultKit.

Two sources, and they do different jobs:

- **Live ResultKit** says what exists: companies, teams, projects, columns, 1:1s. `scripts/find.sh` reads it fresh every time, so there is no saved ID list to go stale.
- **The notes file** holds only what ResultKit cannot know: which companies matter and what each one is, the user's nicknames, and their where-things-go rules.

## Current State

- Notes: !`N="${RESULTKIT_CONFIG_DIR:-$HOME/.config/resultkit}/my-setup.md"; if [ -f "$N" ]; then echo "$N"; cat "$N"; else echo "NONE at $N — see First run"; fi`
- find.sh: !`echo "${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/my-setup/scripts/find.sh}" | xargs -I{} sh -c '[ -f "{}" ] && echo "{}" && exit 0; for p in "$HOME/.claude/plugins/cache/"*/rkit/*/skills/my-setup/scripts/find.sh "$HOME/.claude/skills/rkit:my-setup/scripts/find.sh" "$HOME/.agents/skills/my-setup/scripts/find.sh" "$HOME/.gemini/skills/my-setup/scripts/find.sh" "scripts/find.sh"; do [ -f "$p" ] && echo "$p" && exit 0; done; echo "NOT_FOUND"'`

`api.sh` sits beside `find.sh` in the same folder.

## Answering a question

1. **Translate.** Swap any nickname from the notes for the real thing. Apply any where-things-go rule that fits the question.

2. **Find.** Run `find.sh` with the two or three words that carry the meaning; drop filler such as "my", "project", "team".

   ```
   find.sh acme stability
   project 5610 | Acme Supply (2001) / Engineering (2004) / Platform Stability Backlog | columns: In Dev 5611; In QA 5612; ...
   ```

   Each line is one `team`, `project` or `1on1` with its ID and where it lives. A line matches only when every word appears somewhere in it, so a company name alone returns that company's whole setup, and adding `team`, `project` or `1on1` narrows it to that kind. A 1:1 that reads `no company on this 1:1` is not attached to any team in ResultKit: list it separately and say so rather than guessing where it belongs.

   - One match: use it.
   - Several: prefer the companies listed in the notes. Still several: ask, showing at most five, likeliest first.
   - None: drop a word and try again. Still none: say it was not found and what you searched for.

3. **Read the answer.** Read-only, always.

   | The question needs | Use |
   |---|---|
   | Which team, project or 1:1, or what a company has | The `find.sh` lines themselves |
   | How many cards, or what percent are done, in a project | `find.sh count PROJECT_ID` |
   | Anything else (items, rocks, scorecard, a 1:1's contents, pages) | The ResultKit connector's read tools, or `api.sh GET <path>` from [`references/api-reference.md`](references/api-reference.md), with the ID you found |

   `find.sh count` reads every card, which can take half a minute on a big project. Never estimate from a first page: on real boards the first hundred cards in a column do not look like the rest.

4. **Reply.** Lead with the answer. Then one line naming exactly what you used, with its path and ID, so the user can see you found the right thing:

   > 46 of 310 cards are marked done (14.8%).
   > Platform Stability Backlog (5610) — Acme Supply / Engineering (2004)

   When the answer is a list (people, projects, teams), put each one's ID beside it so the user can act on it.

   When "done" could mean two things — a card's status, or the column it sits in — show both numbers and say which is which. Pick neither for the user.

## The notes file

One markdown file, three sections. Example:

```markdown
# My ResultKit setup notes

## Companies that matter
- Examp.ly (1241): my company
- Acme Supply (2001): client

## Nicknames
- "the roadmap" = project 5501, 2026 Product Roadmap, in Examp.ly (1241)

## Where things go
- Personal to-dos go to team My Personal (3001), never Examp.ly (1241)
```

- **First run** (Notes shows NONE). Answer the question first; a missing notes file never blocks an answer. If answering needed a question of your own, ask only that and bring up notes once it is settled. Then run `find.sh` with no words: it lists every company, busiest first. Recommend the few that look active, ask which ones matter and what each is (my company, client, demo, ignore), show the finished notes, and save them only on a yes.
- **Learn as you go.** Whenever you had to ask — two things matched, or a nickname was new — offer to save the answer as one line. Show the exact line. Save only on a yes.
- **Live wins.** If a name or ID in the notes no longer shows up in `find.sh`, say so, use what is live, and offer to fix the note.
- The notes are private to this machine. Nothing about the user's companies is ever written anywhere else.

## Not this skill

- Login, token, default team, a second account: `/rkit:setup`.
- Changing anything (add, move, mark done, edit): hand over the ID you found and name the skill that does it — `/rkit:projects`, `/rkit:1on1`, `/rkit:level10`, `/rkit:today`, `/rkit:pages`.

## Errors

`find.sh` prints a line starting `ERROR` and stops. `NO_CONFIG` or `NO_TOKEN`: "ResultKit isn't set up here. Run `/rkit:setup`." Status 401: "Your token is no longer accepted. Run `/rkit:setup`." Anything else: show the line as it is. Never answer from the notes alone when the live read failed.
