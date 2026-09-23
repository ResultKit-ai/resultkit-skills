---
name: rm-concepts
description: >
  ResultMaps product and domain concept reference. Use this skill whenever someone asks what ResultMaps is,
  what a business concept means in the product (rock, objective, WIG, measurable, scorecard, seat, vision,
  mission, result area, key result, milestone, item, issue, to-do, day plan, assignment, group, team, account),
  how management frameworks differ (EOS, OKR, 4DX, V2MOM, SRT, SVEP), what terminology maps to what,
  or needs general orientation on the product domain. Also use when someone says "explain concept",
  "domain overview", "product overview", "what does X mean", "EOS vs OKR", or "framework terminology".
  This is a conceptual reference — no code, no implementation details.
allowed-tools: Read, Glob, Grep
---

**Last updated:** 2026-09-23.

# ResultMaps Concepts

ResultMaps is a business operating system for team alignment. It helps organizations set direction, track execution, and run meetings — all adapted to whichever management framework the team uses.

## What ResultMaps Does

Organizations use ResultMaps to:
- Define where they're going (Vision, Mission, Values)
- Set quarterly and annual goals
- Break goals into actionable work
- Track progress with scorecards and measures
- Run structured weekly meetings
- Manage accountability through roles and seats

---

## Organizational Structure

### Account
Your account holds your subscription, payment details, and billing history. One account can pay for many organizations. Boundaries in full: `references/boundaries.md`.

### Organization
An organization is the company.

### Group (Team)
A team is a working unit inside an organization. The company is the top-level team, and teams nest beneath it.

### User
A person in the system. Users belong to one or more groups through memberships. A user can be a member of multiple teams simultaneously.

### Seat
A role on the accountability chart — think "VP of Sales" or "Marketing Lead," not the person filling it. A user is *assigned to* a seat. This separates the role from the person, so when someone leaves, the seat (and its accountabilities) stays. Seats are especially prominent in EOS, where rocks are tracked by seat.

### Group Membership
The link between a user and a group. A user can have different membership types across different groups.

---

## Strategic Planning Hierarchy

ResultMaps organizes strategic thinking in a top-down cascade:

```
Vision
  └── Mission
       └── Result Area
            └── Goal
                 ├── Key Result / Milestone
                 └── Item (actionable work)
                      └── Item (sub-task)
```

### Vision
Where the organization is headed. Can be personal (an individual's life direction) or team-level (the company's future state). Includes a description and a purpose ("why it matters"). EOS teams use the Vision/Traction Organizer (VTO) which adds core values, BHAG, and marketing strategy.

### Mission
How the organization achieves its vision. A group can have multiple missions. Missions contain result areas.

### Result Area
A focus area within a mission — the broad categories of work that matter. In EOS these are called "Annual Goals" or "1-Year Goals." In SRT they're called "Must Win Battles."

### Goal
A time-bound objective, typically quarterly (90 days). This is the core planning object. What it's *called* depends on the framework:

| Framework | Goal is called |
|-----------|---------------|
| OKR | Objective |
| EOS | Rock |
| 4DX | WIG (Wildly Important Goal) |
| V2MOM | Method |
| SRT | Must Win Battle |

Goals belong to either a user or a group (this is the "achievable" relationship — a goal is *achievable by* someone or some team).

### Key Result / Milestone
The measurable outcome beneath a goal. Proves whether the goal is on track or complete.

| Framework | Outcome is called |
|-----------|------------------|
| OKR | Key Result |
| EOS | Milestone |
| 4DX | Lead Measure |
| V2MOM | Measure |
| SRT | Result |

### Item
Actionable work — a task, to-do, or issue. Items form their own hierarchy (parent/child), so a large task can be broken into sub-tasks. Items can be aligned to goals, meaning "this work supports that objective."

---

## Object Types and Priority

Items aren't all equal. ResultMaps distinguishes several types, each carrying a different priority signal:

### Action Item
A general task. The base unit of work. Default destination is the personal prioritizer (day plan). Flexible due dates.

### To-Do
An action item that was *committed* in a meeting (L10 or 1:1). The act of committing elevates its priority. When created in a meeting context, it gets a 7-day due date from the meeting date.

### Issue
Something stuck, blocked, or newly identified as a problem. Issues always generate a corresponding to-do for resolution. They carry elevated priority because they need active attention.

### Project
A collection of related action items. A container, not a task itself. Projects that support a rock/objective carry higher priority.

**Shape:** A project's contents are usually two levels deep — direct children are **columns / section names** (Backlog, Doing, Done, etc.) and the actual to-dos are **grandchildren** under those columns. A minority of projects are flat checklists where items are direct children with no column layer. Any code or skill that pulls project contents must handle both shapes — see the Project Hierarchy section in `api-reference.md`.

### Rock
A 90-day target (EOS terminology). Not created as an item — rocks are goals. But knowing that an item supports a rock increases that item's priority weighting.

### Milestone
A sub-component of a rock or project. Like rocks, knowing an item supports a milestone boosts its priority.

### Priority Hierarchy (highest to lowest)
1. Supports a rock or milestone
2. Issue (needs resolution)
3. To-do (committed in meeting)
4. Action Item (base level)

---

## Contexts and Destinations

Items can exist in multiple contexts simultaneously:

| Context | Description | Due Date Rule |
|---------|-------------|---------------|
| Personal Prioritizer | Default home for all items; also called "Day Plan" | Flexible |
| L10 Meeting | Weekly tactical meeting (EOS Level 10) | 7 days from meeting |
| 1:1 Meeting | One-on-one meeting | 7 days (default, can override) |
| Project | Container for related action items | Inherited from project timeline |

---

## Planning and Execution

### Day Plan
A user's daily work plan. Contains day plan actions — the specific items they intend to work on that day, with estimated time, reported time, completion status, and the ability to defer to another date.

### Week Plan
A broader view — what a user plans to accomplish during the week.

### Assignment
A delegation. When someone assigns a goal or item to another user, it creates an assignment with a workflow status and notes. The assignment tracks who created it, who it's assigned to, and its current state.

---

## Scorecard and Measures

### Measure (Measurable)
A recurring metric tracked on the scorecard. Has a target value, a unit, and a data source. Measures belong to a group and can be linked to a seat and a user. EOS calls these "measurables."

### Measure Value
A single data point — one week's (or period's) recorded value for a measure.

### Rollup Measure
A measure that aggregates child measures. For example, a company-level "Total Revenue" that sums each team's revenue measure.

### Scorecard (Scoreboard)
The dashboard showing all measures for a team over time. EOS calls it a "scorecard," OKR calls it a "scoreboard."

---

## Meetings

ResultMaps supports structured recurring meetings. The name and format vary by framework:

| Framework | Weekly Meeting Name |
|-----------|-------------------|
| OKR | Weekly Sync |
| EOS | Weekly L10 (Level 10) |
| 4DX | Weekly Sync |
| V2MOM | Weekly Sync |
| SRT | Team Priorities |
| SVEP | Weekly Tactical |

### Meeting Sections
Weekly meetings typically include:
- **Wins / Segue** — good news and personal highlights (EOS calls this "Segue" or "Good News," others call it "Wins")
- **Scorecard review** — check the numbers
- **Rock/Objective review** — are quarterly goals on track?
- **To-Do review** — check last week's commitments
- **Issues (IDS)** — Identify, Discuss, Solve (EOS terminology). All frameworks track issues and challenges
- **Headlines** — notable updates for the team

### 1:1 Meeting
A one-on-one between two people (typically manager and direct report). Creates to-dos with 7-day due dates.

---

## Business Plans

Teams can define multi-horizon plans:
- **3-Year Picture** — long-range targets (EOS/OKR). Includes revenue, profit, and descriptive goals.
- **1-Year Plan** — annual targets
- **Quarterly Plans** (Q1–Q4) — each with description, target date, revenue, profit, and measurables

---

## Complete Framework Terminology Map

Each team in ResultMaps selects a management framework. This selection changes the labels used throughout the product. The underlying data model is the same — only the words change.

### OKR (Objectives and Key Results) — Default
| Concept | OKR Term |
|---------|----------|
| Top-level planning | Result Area |
| Goal | Objective |
| Outcome | Key Result |
| Weekly meeting | Weekly Sync |
| Execution page | OKR/Execution Tracker |
| Scorecard | Scoreboard |
| Measure | Measure |
| To-Do column | Priorities due (for the week) |
| Done column | Priorities done |
| Wins section | Wins |
| Big picture page | Big Picture |

### EOS (Entrepreneurial Operating System)
| Concept | EOS Term |
|---------|----------|
| Top-level planning | Annual Goal (1-Year Goal) |
| Goal | Rock |
| Outcome | Milestone |
| Weekly meeting | Weekly L10 (Level 10) |
| Execution page | Rocks |
| Scorecard | Scorecard |
| Measure | Measurable |
| To-Do column | To-Do |
| Done column | Done |
| Issues column | IDS (Identify, Discuss, Solve) |
| Wins section | Segue / Good News |
| Big picture page | Vision Traction Organizer (VTO) |

### 4DX (Four Disciplines of Execution)
| Concept | 4DX Term |
|---------|----------|
| Top-level planning | Result Area |
| Goal | WIG (Wildly Important Goal) |
| Outcome | Lead Measure |
| Weekly meeting | Weekly Sync |
| Execution page | OKR/Execution Tracker |

### V2MOM (Salesforce Methodology)
| Concept | V2MOM Term |
|---------|------------|
| Top-level planning | V2MOM |
| Goal | Method |
| Outcome | Measure |
| Weekly meeting | Weekly Sync |
| Execution page | Execution Tracker |
| Big picture page | V2MOM |

V2MOM has five components: Vision, Values, Methods, Measures, Obstacles.

### SRT (Strategy Realization Team)
| Concept | SRT Term |
|---------|----------|
| Top-level planning | Must Win Battle |
| Goal | Must Win Battle |
| Outcome | Result |
| Weekly meeting | Team Priorities |
| Execution page | MWB Tracker |

### SVEP (Pinnacle Variant)
| Concept | SVEP Term |
|---------|-----------|
| Weekly meeting | Weekly Tactical |
| Execution page | Execution Plan |

### Custom Terminology
Teams can also override any of these labels with their own custom names.

---

## Key Relationships Summary

- An **Account** holds many **Organizations** (billing only)
- An **Organization** is the company and holds its **Teams**
- **Teams** nest beneath the company's top-level team
- **Users** belong to **Teams** through **Memberships**
- **Users** are assigned to **Seats** (roles)
- **Groups** have a **Vision**, **Missions**, and **Measures**
- **Missions** contain **Result Areas**
- **Goals** are achievable by a **User** or a **Group**
- **Goals** have **Key Results** (outcomes) and aligned **Items** (work)
- **Items** can have child **Items** (sub-tasks)
- **Items** appear in **Day Plans**, **Meetings**, and **Projects**
- **Measures** are tracked on the **Scorecard** with periodic **Values**
