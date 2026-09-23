# Account, organization, team — boundaries

Mirror of `resultmaps-api2/.claude/skills/organization-expert/SKILL.md` (the source of truth), last synced 2026-09-23.


ResultKit has no tenants. An account is the billing entity, and that is it; an account can hold many organizations. An organization is the company: a root team together with every team beneath it, identified by that root team and never by an account. A team is a working unit inside an organization; the company is the top-level team, and teams nest beneath it. A person is a user, who belongs to teams through memberships. Every piece of data has a boundary, such as account, organization, team, or person. The boundary is a fact about the thing, found in the code or the spec, not a word to assume: billing lives at the account; a custom label can be organization-scoped or team-scoped, and it is whichever one it actually is; a To-Do can belong to a team or to a person. When a sentence says "tenant," "multi-tenant," or "tenant-scoped," the word is wrong, and the fix is to name the real boundary of that thing, never to swap in "organization." We run one database; nothing in ResultKit is multi-tenant.
