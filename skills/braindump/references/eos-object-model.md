# EOS Object Model Reference

## Object Types

### Action Item
- **Definition**: General task
- **Default destination**: Personal Planner (Day Plan)
- **Priority signal**: Base level
- **Due date**: Ask if not clear from context

### To-do
- **Definition**: Action item committed in an L10 or 1:1 meeting
- **Key differentiator**: 7-day due date from meeting
- **Destinations**: L10 meeting, 1:1 meeting, Personal Planner, Project (can exist in multiple)
- **Priority signal**: Higher (committed)
- **Due date**: Must be 7 days from creation when associated with L10 or 1:1

### Issue
- **Definition**: Action item that is stuck/blocked, or a newly identified problem
- **Destinations**: Same rules as To-do/Action Item
- **Priority signal**: Elevated (needs resolution)
- **Special rule**: Always generates a corresponding To-do for resolution

### Project
- **Definition**: Collection of action items
- **Role**: Container, not a destination
- **Priority signal**: Higher if supports a rock

### Rock
- **Definition**: 90-day target
- **Role**: Reference context only (not created by this skill)
- **Priority signal**: Knowing an item supports a rock increases its priority weighting

### Milestone
- **Definition**: Sub-component of a rock or project
- **Role**: Reference context only (not created by this skill)
- **Priority signal**: Knowing an item supports a milestone increases its priority weighting

## Contexts / Destinations

Items can exist in multiple contexts simultaneously.

| Context | Description | Due Date Rule |
|---------|-------------|---------------|
| Personal Planner | Default destination; also called "Day Plan" or "Prioritizer" | Flexible |
| L10 Meeting | Weekly tactical meeting (Level 10) | 7 days |
| 1:1 Meeting | One-on-one meeting | 7 days (default, can override) |
| Project | Container for related action items | Inherited from project timeline |

## Priority Hierarchy

From highest to lowest priority signal:
1. Supports a rock or milestone
2. Issue (needs resolution)
3. To-do (committed in L10/1:1)
4. Action Item (base)
