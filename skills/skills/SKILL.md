---
name: rkit:skills
description: Work with a team's skills in ResultKit through the connector. List the team's skills, read one by its title, use one (read its current version, then follow it), change one (add or edit a rule in its SKILL.md, add, change or remove a file), see a skill's versions and history, read an older version, go back to or restore a version, and copy a version into a new skill. A skill is a page of kind skill underneath, but use this skill, never rkit:pages, for anything about a skill. Make sure to use this skill whenever the user says "skill" about something their team keeps in ResultKit - "which skills do we have", "show me the Press Release skill", "use the Press Release skill to write...", "add this rule to Press Release", "change / edit / save the skill", "versions of the skill", "show the version from Nov 3", "go back to the version from Nov 3", "restore that version", "make a copy of that version".
user-invocable: true
allowed-tools: Bash(jq *), Read, Glob, Grep
---
# rkit:skills
A team keeps its skills on its Skills page: a SKILL.md and the files it uses, saved as versions. This skill lists them, reads and uses one, changes one, and shows, restores or copies a version. It drives the ResultKit connector's seven skill tools, named below by base name (the full name is `mcp__<server>__<tool>`; the server alias varies by install).
## Current State
- Default team: !`jq -r '.default_team_id // "NONE"' "${RESULTKIT_CONFIG:-$HOME/.config/resultkit/config.json}" 2>/dev/null || echo NONE`
## Rules
- **Only these seven tools.** `list_skills`, `get_skill`, `update_skill`, `list_skill_versions`, `get_skill_version`, `restore_skill_version`, `copy_skill_version`. Nothing else is called, nothing goes around the connector, and the connector's `guide` tool is skipped: the routing below is the whole skill.
- **Team.** The team in the ask, else the default team above (`team_id`, a number); never ask which team when there is a default. `NONE` and no team named: "No team specified and no default configured. Run `/rkit:setup`."
- **A skill is named by its title**, exactly as typed, in the `skill` argument. It has no id here: name it as a markdown link, `[Title](url)`, with the url the connector gave.
- **A version is named by when it was saved**: its `saved_at`, handed back character for character as `list_skill_versions` or `get_skill` gave it. A version has no number and no id: none is shown, asked for or written. Say each moment as a day and a time ("Nov 3, 2:41 PM").
- **Confirm every write.** Reads run at once. Before `update_skill`, `restore_skill_version` or `copy_skill_version`, ask one plain question in the reply (not AskUserQuestion) that names the skill and what will happen, and wait. On no: "Okay, nothing was saved." and no call.
- **Refusals are said in the connector's words, and that is the end of it.** Say the sentence as returned, alone (no preface, no account of what was or was not done), and stop: no other tool to get around it, no other skill in its place, none of the skill shown. A yes that follows a refusal has nothing waiting: say the sentence again, alone. A skill the person may not read answers exactly like a title that matches nothing; never say which.
- **Concise output.** Tables and short summaries, no filler.
## Argument Parsing
| Input | Behavior | Tool / flow |
|-------|----------|-------------|
| *(no args)*, "which skills does my team have?" | List the team's skills | `list_skills` |
| "show me {skill}", "open the {skill} skill" | Read one skill as it is now | `get_skill` |
| "use the {skill} skill to ..." | Read it, then do the task by it | `get_skill` |
| "add this rule to {skill}", "change {skill}", "add or remove a file in {skill}" | Change SKILL.md or a file; saved as a new version | `get_skill`, then `update_skill` |
| "versions of {skill}" | List its versions | `list_skill_versions` |
| "show the version of {skill} from {day}" | Read an older version | `list_skill_versions`, then `get_skill_version` |
| "go back to the version of {skill} from {day}" | Make that version the newest | `list_skill_versions`, then `restore_skill_version` |
| "make a copy of the {day} version of {skill}" *(+ "called {name}")* | Make a new skill from that version | `list_skill_versions`, then `copy_skill_version` |
## Flow: List Skills
Call `list_skills` with `team_id`. It answers `[{name, description, url}]`. Show a table of Skill (as a link) and Description. Skills the person may not read are not in it.
## Flow: Read or Use a Skill
Call `get_skill` with `team_id` and `skill` = the title as typed. It answers `{name, saved_at, skill_md, files: [{path, content}], url}`, always the current version.
- **Read** ("show me"): show SKILL.md whole, then each file under its path with its contents, then the link. Never a summary.
- **Use** ("use the X skill to ..."): read it first, **every time you use it**, even if you read it earlier in this conversation: it may have changed since, and nothing from an earlier read is kept. Then do the task by what this read says, SKILL.md and its files.
Neither writes anything. A title that matches nothing, two skills with one title, or a skill she may not read: the connector's sentence, and stop. Never list skills to look for a near match.
## Flow: Change a Skill
Covers a rule or text in SKILL.md, and a file added, changed or removed.
1. **Read** with `get_skill`, as above. Keep its `saved_at`.
2. **Build the change on what you read.** SKILL.md: `skill_md` is the whole new text, the asked change made and every other word as it was. A file added or changed: `files`, each a path and its whole text (changing one means the old text with the change in it). A file removed: `remove_files`, its path. Send only what changes: a file change sends no `skill_md`, a SKILL.md change sends no `files`. Write only what was asked: a section named but not written is its heading alone, and say so in the question.
3. **Confirm.** Name the skill and the change (the rule's words, or the file and the section). Wait.
4. **After yes, one `update_skill`**: `team_id`, `skill`, `read_version` = the `saved_at` from step 1, and the change. Do not read again between her yes and the save: the connector refuses a save built on an older read than the newest version, which is what keeps her from saving over a newer version she has not seen.
5. **Report.** It answers `{message, saved_by, saved_at, url}`: "[Title](url) is saved, by {saved_by}, {day and time}." Add any note the message carries.
   - `Nothing changed in {Title}.`: say nothing changed and nothing was saved.
   - Changed since it was read: read again at once with `get_skill`, build her change on that newer version, keeping what the other person added, and ask her to confirm adding it on top of that version. Your one closing message says both things: who saved the newer version and when, and that nothing was saved (the connector's words), then the question. No save before her next yes; then `read_version` is the newer `saved_at`.
## Flow: Versions
`list_skill_versions` answers `[{saved_at, saved_by, is_current, restored_from}]`, newest first. Show one line per version, newest first, with who saved it and the day and time; mark `(current)` on the one with `is_current` and no other; add "restored from {day}" where `restored_from` is set. No numbering, no number column.
**Finding the version she means** (every flow below): list first, then match the day she named to the version saved that day. Two on one day: ask which time. None that day: "No version was saved on {day}." with the list of when they were saved, and stop; never take the nearest, and read nothing.
**Read an older version.** After finding it, call `get_skill_version` once with `team_id`, `skill` and `saved_at`. It answers `{message, saved_by, saved_at, is_current, skill_md, files, url}`. Show who saved it and when, say whether it is the current version, then SKILL.md and each file under its path with its contents, then the link.
## Flow: Restore a Version
Find the version (above). The current version needs no restore: "Nothing changed: that is already the current version." and no call. Otherwise confirm, naming the skill and the version by its day: it becomes the newest version and every other stays. After yes, one `restore_skill_version` with `team_id`, `skill` and `saved_at`. It answers `{message, saved_by, saved_at, url}`: "[Title](url) now holds the version from {restored day}, saved as a new version by {saved_by}, {day and time of the save}." `Nothing changed in {Title}.`: say so.
## Flow: Copy a Version
Find the version (above). A name she gave goes in `name`; with none, do not ask for one: the connector names the copy "Copy of {Title}". Confirm, naming the version by its day and the new skill's name (the one she gave, or "Copy of {Title}"). After yes, one `copy_skill_version` with `team_id`, `skill`, `saved_at` and `name` only if she gave one. It answers with the new skill's `url`: `A new skill "[{name}](url)" was made.` The original is unchanged.
## Errors
| tool answers | Say |
|---|---|
| tools missing, or authorization error | Say exactly "The ResultKit connector isn't connected. Connect it (https://mcp.resultkit.ai) and try again." and nothing more. |
| `No skill named "{name}" was found.` | As returned. Nothing else. |
| `Several skills are named "{name}". Rename one of them in ResultKit, then try again.` | As returned. No write. |
| `A skill's versions are for the people who may change it.` | As returned. No version, date or older content. |
| `You can use {Title} but may not change it.` | As returned. It was not saved. |
| `No version of {Title} was saved at that time. ...` | List the versions again and use the `saved_at` exactly as given. |
| `Team not found or you don't have access to it.` | As returned. |
| any other refusal | Show it as returned. |
