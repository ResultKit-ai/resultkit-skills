# ResultKit Skills

AI coding agent skills for the [ResultMaps](https://resultmaps.com) V2 API. Manage your day plans, team boards, weekly meetings, and action items directly from the command line.

Works with **Claude Code**, **OpenAI Codex CLI**, and **Google Gemini CLI**.

## What's Included

| Skill | Description |
|-------|-------------|
| `rkit:1on1` | View and manage one-on-one meetings, with items grouped by column. |
| `rkit:board` | View any item's children as a kanban-style board of columns and items. |
| `rkit:braindump` | Parse unstructured text — notes, emails, dictation — into organized action items. |
| `rkit:columns` | Read your Day Plan Prioritizer's custom columns and what's open or done in each. |
| `rkit:concepts` | ResultMaps product and domain concept reference. |
| `rkit:headlines` | View and manage EOS headlines (People & Customer Headlines) for a team. |
| `rkit:level10` | View and manage EOS Level 10 meeting artifacts — to-dos, issues, and headlines. |
| `rkit:meetings` | Build and refresh a local ResultMaps team, project, and 1:1 IDs reference doc. |
| `rkit:open` | Open anything in ResultKit in your browser, or get the right link for it. |
| `rkit:pages` | List, read, create, update, move, and delete team Pages (the wiki/docs tree). |
| `rkit:password-reset` | Trigger a password reset email for a user (admin only). |
| `rkit:profile` | View your profile stats, measurables, rocks, feedback, and progress dashboard. |
| `rkit:projects` | List active projects for a team and manage project items. |
| `rkit:result-feed` | View and interact with team daily check-ins (result feeds). |
| `rkit:result-update` | Compose and submit your daily check-in — the 90-second update practice. |
| `rkit:reviews` | View and manage performance reviews, submit assessments, sign off, and rate core values. |
| `rkit:scorecard` | View and manage your team's scorecard (measures/measurables). |
| `rkit:seats` | View and manage your team's accountability chart (seats). |
| `rkit:setup` | First-run configuration for ResultKit — sets up your API token and default team. |
| `rkit:strategy` | View and manage your team's strategy tree — goals, rocks, objectives, and more. |
| `rkit:success-criteria` | Review, grade, write, and rewrite the Success Criteria of any process document. |
| `rkit:teams` | List your teams, view members, change roles, and manage team logos. |
| `rkit:today` | View and manage today's day plan — the daily prioritizer. |
| `rkit:vision` | View a team's vision and mission data (framework-aware). |
| `rkit:weekly` | View and manage the team weekly board (Level 10 for EOS teams). |

## Prerequisites

- A ResultMaps account with an API token ([get one here](https://resultmaps.com))
- `curl` and `jq` available in your shell
- One of the supported AI coding agents (see installation below)

---

## Installation

### Claude Code

Requires [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI.

**Install via plugin marketplace (recommended):**

```
/plugin marketplace add ResultKit-ai/resultkit-skills
/plugin install rkit@resultkit
```

**Update to latest:**

```
/plugin marketplace update
```

Then run `/rkit:setup` to configure your API token and default team.

### OpenAI Codex CLI

Requires [Codex CLI](https://github.com/openai/codex).

**Install skills:**

```bash
git clone https://github.com/ResultKit-ai/resultkit-skills.git
mkdir -p ~/.agents/skills
cp -r resultkit-skills/skills/* ~/.agents/skills/
```

**Update to latest:**

```bash
cd resultkit-skills && git pull
cp -r skills/* ~/.agents/skills/
```

Then run `$rkit:setup` to configure your API token and default team.

### Google Gemini CLI

Requires [Gemini CLI](https://github.com/google-gemini/gemini-cli).

**Install as extension:**

```bash
gemini extensions install https://github.com/ResultKit-ai/resultkit-skills
```

**Or install skills manually:**

```bash
git clone https://github.com/ResultKit-ai/resultkit-skills.git
mkdir -p ~/.gemini/skills
cp -r resultkit-skills/skills/* ~/.gemini/skills/
```

**Update to latest:**

```bash
cd resultkit-skills && git pull
cp -r skills/* ~/.gemini/skills/
```

Then run the setup skill to configure your API token and default team.

---

## Quick Start

| Action | Claude Code | Codex CLI | Gemini CLI |
|--------|-------------|-----------|------------|
| Configure token + team | `/rkit:setup` | `$rkit:setup` | `rkit:setup` |
| Show today's day plan | `/rkit:today` | `$rkit:today` | `rkit:today` |
| Add item to today | `/rkit:today add` | `$rkit:today add` | `rkit:today add` |
| View your default board | `/rkit:board` | `$rkit:board` | `rkit:board` |
| View team weekly board | `/rkit:weekly` | `$rkit:weekly` | `rkit:weekly` |
| Parse meeting notes | `/rkit:braindump` | `$rkit:braindump` | `rkit:braindump` |

## Configuration

All config lives in `~/.config/resultkit/config.json`:

```json
{
  "api_token": "<your-bearer-token>",
  "default_team_id": 123,
  "api_base": "https://api.resultmaps.com/api/v2"
}
```

Run the `rkit:setup` skill to create or update this file.

---

## Maintainer Guide

### Repository Structure

```
.claude-plugin/
  plugin.json            # Claude Code plugin manifest
  marketplace.json       # Claude Code marketplace catalog
gemini-extension.json    # Gemini CLI extension manifest
skills/
  setup/                 # /rkit:setup skill
    SKILL.md
    scripts/api.sh       # Copy of shared api.sh
    references/
  today/                 # /rkit:today skill
  board/                 # /rkit:board skill
  weekly/                # /rkit:weekly skill
  braindump/             # /rkit:braindump skill
scripts/
  api.sh                 # Source of truth for the API caller
  deploy.sh              # Deployment script
  fetch-openapi.sh       # Fetch latest OpenAPI spec
  install.sh             # Legacy installer (deprecated)
specs/                   # Spec-Kit feature specs (one per skill)
constitution.md          # Core principles all skills must follow
api-reference.md         # V2 API endpoint summary
```

### How the plugin works

The plugin name is `rkit` (set in `.claude-plugin/plugin.json`). Claude Code automatically namespaces skills by combining the plugin name with the skill folder name:

- `skills/today/SKILL.md` becomes `/rkit:today`
- `skills/board/SKILL.md` becomes `/rkit:board`

Users install via the marketplace defined in `.claude-plugin/marketplace.json`, which points to this GitHub repo as the source.

### Updating api.sh

`scripts/api.sh` is the source of truth. Each skill has its own copy at `skills/*/scripts/api.sh` because plugins must be self-contained (no path traversal outside the plugin root).

After editing `scripts/api.sh`, sync it to all skills:

```bash
for skill in skills/*/; do
  cp scripts/api.sh "$skill/scripts/api.sh"
  chmod +x "$skill/scripts/api.sh"
done
```

### Releasing a new version

1. Make your changes to skill files, api.sh, etc.
2. Run `/sync-plugin` to sync shared files and bump the version (or `/sync-plugin 2.0.0` for a specific version).
3. Bump the `version` in `gemini-extension.json` to match.
4. Commit and push to `main`.
5. Claude Code users run `/plugin marketplace update`. Gemini CLI users re-run `gemini extensions install`.

### Adding a new skill

1. Create `skills/<name>/SKILL.md` with the standard frontmatter:
   ```yaml
   ---
   name: rkit:<name>
   description: What it does.
   user-invocable: true
   allowed-tools: Bash, Read, AskUserQuestion
   ---
   ```
2. Add a `scripts/` folder and copy `api.sh` into it.
3. Add a `references/` folder if the skill needs reference docs.
4. Add the api.sh path resolver to the Current State section (searches Claude Code plugin cache, Claude Code manual install, Codex CLI, Gemini CLI, and local dev):
   ```
   - api.sh: !`(setopt +o nomatch 2>/dev/null; shopt -s nullglob 2>/dev/null; for p in "$HOME/.claude/plugins/"*/rkit/skills/<name>/scripts/api.sh "$HOME/.claude/skills/rkit:<name>/scripts/api.sh" "$HOME/.agents/skills/<name>/scripts/api.sh" "$HOME/.gemini/skills/<name>/scripts/api.sh" "scripts/api.sh"; do [ -f "$p" ] && echo "$p" && break; done) || echo "NOT_FOUND"`
   ```
5. Follow the principles in `constitution.md`.
6. Bump the version in `plugin.json` and push.

### Testing locally

Run Claude Code with the plugin loaded directly from the repo:

```bash
claude --plugin-dir /path/to/resultkit-skills
```

Skills will be available as `/rkit:setup`, `/rkit:today`, etc. without needing to install from the marketplace.

### Syncing the API reference

Use the project skill `/rkit-sync-api-doc` to compare the live OpenAPI spec against `api-reference.md` and update it. Then copy the updated reference to each skill that includes it:

```bash
for skill in setup today board weekly; do
  cp api-reference.md "skills/$skill/references/api-reference.md"
done
```

## License

MIT
