---
name: rkit:meetings
description: Find your meetings in ResultKit by a loose name — your 1:1s and the teams whose meetings you sit in — without saying which company or team they belong to. Use this skill when users ask "what meetings do I have", "who do I meet with at Acme", "list my 1:1s", "which 1:1 is the one with Lisa", "my one-on-ones", or need a 1:1 or team ID they described in words. It is the meetings part of rkit:my-setup and answers through it. Read-only. To work inside a meeting (add a to-do, move an issue), use rkit:1on1 or rkit:level10.
user-invocable: true
---

# rkit:meetings

The meetings part of `rkit:my-setup`. This skill holds no logic of its own, so the two can never disagree.

Load the `rkit:my-setup` skill and follow it. Where skills cannot load each other, read `../my-setup/SKILL.md`, which sits beside this skill's folder; its `find.sh` is in `../my-setup/scripts/`.

Narrow the search to meetings:

- 1:1s: add `1on1` to the search words, for example `find.sh acme 1on1`.
- Team meetings: add `team`, for example `find.sh acme team`. Each team line is a team whose meeting the user can open.
