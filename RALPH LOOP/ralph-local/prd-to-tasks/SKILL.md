---
name: prd-to-tasks
description: Break a local PRD, plan, or spec into independently implementable vertical-slice task specs. Use when the user wants to convert a PRD into local tasks, create implementation phases, update docs/roadmap/tasks, or prepare a PRD for /ralph-local by adding parent-prd metadata and the PRD Ralph task block. You do NOT write application code.
---

# Create Tasks From A PRD

Break a local PRD or plan into independently implementable task specs using `docs/templates/task.md`. This is a planning skill only: do not write application code in `apps/` or `packages/`.

The output must prepare the PRD for `/ralph-local`, which means every generated task must have a `parent-prd` value and the PRD must list its tasks in a Ralph task block.

## Step 1: Gather Context

- Work from the conversation context when possible.
- If the current PRD is not clear, ask the user to reference the PRD file.
- Read the PRD in full before proposing tasks.
- Read `docs/templates/task.md` before creating task specs. If it is missing, create a minimal local Ralph task template instead of inventing a one-off shape.
- Read `docs/roadmap/ROADMAP.md` before choosing task ids or phase placement. If it is missing, create a roadmap index for the PRD/tasks as part of the scaffold.
- When bootstrapping missing local roadmap scaffolding, follow `references/local-roadmap-scaffold.md`.

Optional grounding reads:

- `package.json` at the affected app/package root for test and build commands
- `docs/changelog.md` in affected apps/packages for prior related work
- Relevant `ARCHITECTURE.md`, especially gotchas and boundaries
- Root `DESIGN.md` whenever the PRD touches `apps/web` or `packages/ui`

Never read `.env` or `.env.local`. Use `.env.example` files for environment variable discovery.

## Step 2: Identify The PRD Reference

PRD ids must use the `prd-<phase.sequence>` namespace.

Example:

```yaml
---
id: "prd-4.86"
title: "Cap Table Sidebar and Designed Subpages"
status: "ready-for-tasking"
---
```

Do not use bare task-style ids such as `4.86` as PRD ids. Bare numeric ids are reserved for roadmap tasks.

Prefer explicit PRD frontmatter. If a PRD has no frontmatter id, use a filename that starts with the PRD id, for example `prd-4.86-cap-table-sidebar-and-designed-subpages.md`.

Use this convention:

- PRD id: `prd-4.86`
- PRD filename: `prd-4.86-cap-table-sidebar-and-designed-subpages.md`
- Generated task ids: `4.86.1`, `4.86.2`, `4.86.3`
- Generated task filenames: `4.86.1-cap-table-sidebar-routes.md`
- Generated task `parent-prd`: `"prd-4.86"`

Every generated task must include this value in frontmatter:

```yaml
parent-prd: "prd-4.86"
```

## Step 3: Propose The Breakdown

Before creating files, present a numbered task breakdown. For each task, show:

- **Title**: short descriptive name
- **Apps/Packages touched**: which apps/packages it may modify
- **Goal**: what this task delivers and why it exists
- **Blocked by**: task ids that must complete first
- **User stories covered**: only if the PRD has user stories

Use vertical-slice tasks:

- Each task should deliver a narrow but complete path through all required layers.
- A completed task should be demoable or verifiable on its own.
- Prefer multiple small tasks over one broad task.
- Push back if a task is too large, too vague, or has unclear dependencies.

Before finalizing the task specs, invoke `ask-questions-if-underspecified` to identify unresolved ambiguity. Ask the user:

- Does the granularity feel right?
- Are the dependencies correct?
- Should any tasks be merged or split?

## Step 4: Create Or Update Task Specs

Create task files in `docs/roadmap/tasks/` using the template in `docs/templates/task.md`.

Task file naming:

```text
{id}-{kebab-case-title}.md
```

Required frontmatter:

```yaml
---
id: "4.86.1"
parent-prd: "prd-4.86"
title: "Task title"
status: "pending"
depends_on: []
blocks: []
packages_touched: []
packages_readonly: []
agent_notes: ""
---
```

Rules:

- `id` must be unique.
- `parent-prd` must match the PRD reference chosen in Step 2.
- `status` starts as `pending` unless updating an existing task.
- `depends_on` must use task ids, not filenames.
- `blocks` should mirror dependency relationships where useful.
- `packages_touched` controls the implementation agent's write scope.
- `packages_readonly` marks context that may be read but not modified.
- Include concrete verification commands whenever possible.

## Step 5: Update The PRD Ralph Task Block

After creating or updating tasks, update the PRD file with the exact list of tasks assigned to it.

Use this block format:

```markdown
## Ralph Tasks

<!-- ralph-local:tasks:start -->
- `4.86.1` [Cap table sidebar routes](../tasks/4.86.1-cap-table-sidebar-routes.md)
- `4.86.2` [Cap table overview](../tasks/4.86.2-cap-table-overview.md)
<!-- ralph-local:tasks:end -->
```

Rules:

- Keep only tasks assigned to this PRD in this block.
- The block lists task IDs the PRD owns; it does not track completion. Task `status` frontmatter and file location (`tasks/` vs `tasks/done/`) are the truth.
- The task id in backticks must exactly match the task frontmatter `id`.
- The link must point to the task file.
- The order of this block is Ralph Local's priority order.
- Do not list unrelated tasks even if they are in the same roadmap phase.

If the PRD already has a Ralph task block, update the content between the markers instead of adding a second block.

## Step 6: Update The Roadmap

Update `docs/roadmap/ROADMAP.md` when tasks are added, reordered, split, merged, or completed. Keep roadmap links consistent with the task file locations.

## Important Constraints

- Do not modify source code in `apps/` or `packages/`.
- Do not create or modify `ARCHITECTURE.md`; those are updated after implementation when architecture actually changes.
- Do not create vague placeholder tasks unless the user explicitly wants placeholders.
- If the PRD leaves major product behavior unclear, ask before finalizing tasks.
- Always read root `DESIGN.md` before planning tasks that touch `apps/web` or `packages/ui`.

## Key Files

- `docs/roadmap/ROADMAP.md` - phase sequencing and dependency graph
- `docs/roadmap/prds/` - PRD files, each with a Ralph task block when taskized
- `docs/roadmap/tasks/` - active task specs
- `docs/roadmap/tasks/done/` - completed task specs
- `docs/templates/task.md` - task spec template and field reference
- `docs/templates/feature.md` - domain doc template
- `docs/features/` - existing feature specs

## References

- `references/local-roadmap-scaffold.md` - minimal scaffold and validation checklist for repos missing `ROADMAP.md` or `docs/templates/task.md`.
