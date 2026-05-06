# Local roadmap scaffold for `prd-to-tasks`

Use this when converting a PRD to local Ralph tasks in a repo that lacks the expected docs scaffold.

## Required files/directories

- `docs/roadmap/ROADMAP.md`
- `docs/roadmap/prds/`
- `docs/roadmap/tasks/`
- `docs/roadmap/tasks/done/`
- `docs/templates/task.md`

## Minimal task template

```markdown
---
id: ""
parent-prd: ""
title: ""
status: "pending"
depends_on: []
blocks: []
packages_touched: []
packages_readonly: []
agent_notes: ""
---

# Task: <title>

## What to build

## Acceptance criteria

## Implementation notes

## Tests and verification

## Out of scope
```

## Roadmap expectations

`ROADMAP.md` should act as the local planning index: list the PRD, link the task files, and preserve the same task order as the PRD Ralph task block when that order is intentional.

## Validation checklist

- Every task frontmatter has required fields.
- `parent-prd` matches the PRD id exactly.
- PRD Ralph block task ids match task frontmatter ids exactly.
- Links in the PRD Ralph block point to files under `../tasks/`.
- `task-queue.mjs summary <prd-ref>` lists the expected tasks.
- `task-queue.mjs next-task <prd-ref>` returns the first pending unblocked task.

## Pitfall

If `docs/templates/task.md` or `docs/roadmap/ROADMAP.md` is missing, create the scaffold instead of silently inventing a one-off task format. The scaffold is part of the local Ralph contract.