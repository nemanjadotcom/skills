---
name: ralph-local
description: Autonomous local PRD implementation loop. Use when the user invokes /ralph-local or asks to implement a local PRD from docs/roadmap/prds using PRD-listed tasks in docs/roadmap/tasks, with one PRD worktree, local review gates, final GitHub PR creation, CodeRabbit iteration, and human-only merge.
---

# RALPH Local - Autonomous PRD Implementation

RALPH Local implements a local PRD by working through the task specs assigned to that PRD. It does not use GitHub issues for task selection. GitHub is used only after all local PRD tasks are complete, when the branch is pushed, a PR is opened, and CodeRabbit reviews the PR.

## ID Convention

PRD ids and task ids use different namespaces:

- PRD ids use `prd-<phase.sequence>`, for example `prd-4.86`.
- Task ids use normal roadmap numbering under that PRD, for example `4.86.1`, `4.86.2`, `4.86.3`.
- Do not use bare numeric ids such as `4.86` as PRD ids.

Example PRD frontmatter:

```yaml
---
id: "prd-4.86"
title: "Cap Table Sidebar and Designed Subpages"
status: "ready-for-tasking"
---
```

If the PRD file has no frontmatter id, the Ralph helper can infer the PRD id from a filename that starts with the same namespace, for example `prd-4.86-cap-table-sidebar-and-designed-subpages.md`. Frontmatter is still preferred because it is explicit.

Example generated task frontmatter:

```yaml
---
id: "4.86.1"
parent-prd: "prd-4.86"
title: "Cap table sidebar routes"
status: "pending"
depends_on: []
---
```

## Source Of Truth

RALPH Local uses three local sources:

- `docs/roadmap/prds/` - PRD files
- `docs/roadmap/tasks/` - active task specs
- `docs/roadmap/tasks/done/` - completed task specs

A PRD must include a Ralph task block:

```markdown
<!-- ralph-local:tasks:start -->
- `4.86.1` [Cap table sidebar routes](../tasks/4.86.1-cap-table-sidebar-routes.md)
- `4.86.2` [Cap table overview](../tasks/4.86.2-cap-table-overview.md)
<!-- ralph-local:tasks:end -->
```

Every listed task must include matching frontmatter. The task id in the PRD block and the task file frontmatter must match exactly. The task `parent-prd` value must match the PRD `id`.

## Pipeline

| Step | Command | What It Does |
|------|---------|-------------|
| 1 | `/grill-me` | Stress-test the idea before building |
| 2 | `/to-prd` | Create the local PRD in `docs/roadmap/prds/` |
| 3 | `/prd-to-tasks` | Create vertical-slice task specs and update the PRD Ralph task block |
| 4 | `/ralph-local` | Implement PRD-listed tasks in one worktree, then open a PR and iterate with CodeRabbit |

## Local PRD-To-Task Contract

`/prd-to-tasks` must create local Markdown task specs, not GitHub issues. The handoff is valid only when:

- Task files live under `docs/roadmap/tasks/`.
- Task IDs derive from the PRD id: `prd-1.1` → `1.1.1`, `1.1.2`, etc.
- Each task frontmatter includes `id`, `parent-prd`, `title`, `status: "pending"`, and `depends_on`.
- The PRD contains a parser-compatible block:

```markdown
<!-- ralph-local:tasks:start -->
- `1.1.1` [Task title](../tasks/1.1.1-task-title.md)
<!-- ralph-local:tasks:end -->
```

- Verify the handoff with:

```bash
node .agents/skills/ralph-local/task-queue.mjs summary <prd-ref>
node .agents/skills/ralph-local/task-queue.mjs next-task <prd-ref>
```

Do not substitute the GitHub `to-issues` flow for local Ralph tasks; Ralph Local only consumes the PRD task block and local task specs.

## Scripts

The project-local execution scripts live in:

```bash
.agents/skills/ralph-local/ralph-local.sh
.agents/skills/ralph-local/ralph-once.sh
.agents/skills/ralph-local/afk-ralph.sh
.agents/skills/ralph-local/task-queue.mjs
.agents/skills/ralph-local/coderabbit-review.mjs
.agents/skills/ralph-local/model.env
.agents/skills/ralph-local/instructions.md
.agents/skills/ralph-local/review.md
```

If `.agents/skills/ralph-local/` is missing, bootstrap it from the canonical skill runtime before claiming Ralph is runnable. See `references/project-local-runtime-bootstrap.md` for copy commands, executable-mode checks, syntax checks, and parser verification.

Dependency install behavior lives in `ralph-once.sh`: worktrees without `package.json` skip cleanly; `pnpm-lock.yaml` uses `pnpm` or `corepack pnpm`; `package-lock.json` uses `npm ci`; plain `package.json` falls back to `npm install`; missing package-manager prerequisites fail with an actionable message.

Codex sandbox behavior is explicit: `RALPH_CODEX_BYPASS_SANDBOX="1"` (or `RALPH_DEFAULT_CODEX_BYPASS_SANDBOX="1"` in project-local `model.env`) makes Ralph pass Codex's `--dangerously-bypass-approvals-and-sandbox` flag instead of `--full-auto`. Use this only on externally sandboxed hosts where Codex/bubblewrap fails with errors like `bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted`; keep the bypass project-local, not global.

## Usage

### Model defaults

Edit `.agents/skills/ralph-local/model.env` to change Ralph's default Codex model, reasoning effort, or CodeRabbit review iteration cap in one place. Runtime env vars override the file defaults:

```bash
RALPH_CODEX_MODEL="..." RALPH_CODEX_REASONING_EFFORT="..." RALPH_MAX_REVIEW_ITERATIONS="12" \
  .agents/skills/ralph-local/ralph-local.sh <prd-ref> afk
```

If `model.env` is missing, the scripts keep their built-in fallback defaults. See `references/model-configuration.md` for the resolution order, verification grep, active-process `ps` check, and the pitfall that changing `model.env` does not affect an already-running Ralph/Codex child process.

### Human-in-the-loop, one task

```bash
.agents/skills/ralph-local/ralph-local.sh <prd-ref> [once] [task-id]
```

Examples:

```bash
.agents/skills/ralph-local/ralph-local.sh prd-4.86
.agents/skills/ralph-local/ralph-local.sh docs/roadmap/prds/prd-4.86-cap-table-sidebar-and-designed-subpages.md
.agents/skills/ralph-local/ralph-local.sh prd-4.86 once 4.86.1
```

This creates or reuses the PRD worktree, selects one pending unblocked PRD-listed task, implements it, runs the local review gate, commits, and marks the task done.

### Autonomous PRD loop

```bash
.agents/skills/ralph-local/ralph-local.sh <prd-ref> afk [max-task-iterations]
```

Example:

```bash
.agents/skills/ralph-local/ralph-local.sh prd-4.86 afk 20
```

This runs all pending unblocked tasks listed by the PRD. After all are done, it pushes the PRD branch, opens or reuses a GitHub PR, waits for checks with `gh pr checks --watch --fail-fast`, reads CodeRabbit feedback, fixes actionable findings, pushes fixes, resolves addressed threads, and repeats until CodeRabbit is clean.

## Worktree Model

RALPH Local keeps all implementation work for a PRD in one branch and one worktree:

```text
Branch:   ralph/prd-<prd-slug>
Worktree: .agents/worktrees/ralph-<prd-slug>
```

The same worktree is reused across all tasks assigned to that PRD. This keeps context and commits together while isolating implementation from `main`.

## Task Selection Rules

1. Read the PRD Ralph task block.
2. Load only the task files listed in that block.
3. Ignore tasks not listed by the PRD.
4. Validate each listed task has matching `parent-prd` and matching `id`.
5. Pick the first PRD-listed task where:
   - `status` is `pending`
   - every id in `depends_on` is listed by the same PRD and has `status: "done"`
6. Stop if no task is runnable.
7. Signal complete when all PRD-listed tasks are done.

The order in the PRD block is the priority order. Numeric task id sorting is not the primary priority mechanism.

## Per-Task Loop

For each selected task, the scripts:

1. Mark the task `in-progress`.
2. Build context from the PRD, the selected task, and sibling task statuses.
3. Invoke Codex with `.agents/skills/ralph-local/instructions.md` using the configured Ralph Codex model and reasoning effort.
4. Require an implementation commit whose message starts with the task id.
5. Invoke Codex with `.agents/skills/ralph-local/review.md` against the task diff range using the configured Ralph Codex model and reasoning effort. The review must invoke `feature-dev:code-reviewer`, `differential-review:diff-review`, and `/supply-chain-risk-auditor` when applicable.
6. Refuse to close the task if uncommitted changes remain.
7. Verify the agent moved the task file to `docs/roadmap/tasks/done/` and set `status: "done"` on its frontmatter. If either is missing, exit non-zero and refuse to advance.

`docs/roadmap/ROADMAP.md` and `docs/changelog.md` are NOT touched in the worktree — updated on main after merge.

## CodeRabbit Phase

After all local PRD tasks are complete, AFK mode:

1. Pushes the PRD branch.
2. Opens or reuses a GitHub PR.
3. Runs `gh pr checks --watch --fail-fast` instead of sleep polling.
4. Reads CodeRabbit inline comments, top-level comments, and unresolved threads.
5. Fixes genuine actionable findings in batches using the configured Ralph Codex model and reasoning effort.
6. Replies to and resolves addressed or intentionally skipped threads.
7. Repeats until:
   - checks pass
   - CodeRabbit has no actionable findings
   - unresolved review threads are zero
   - `reviewDecision` is `APPROVED`
   - merge state is not blocked
8. Runs final verification.
9. Prints the human merge command.

RALPH Local must not dismiss CodeRabbit reviews, push empty commits to trigger re-review, spam `@coderabbitai review`, or merge the PR.

## Invocation Instructions

When the user invokes `/ralph-local`:

1. Parse arguments:
   - first argument: PRD reference, required
   - second argument: mode, `once` or `afk`, default `once`
   - third argument: task id for `once`, or max task iterations for `afk`, default `20`
2. If no PRD reference is provided, ask for it.
3. Verify `.agents/skills/ralph-local/` exists in the project root. If it is missing, do not hand-wave; bootstrap the project-local runtime from the canonical Ralph Local skill directory and verify syntax, executable modes, and parser output before running implementation. See `references/project-local-runtime-bootstrap.md`.
4. Run the project-local wrapper:

```bash
.agents/skills/ralph-local/ralph-local.sh <prd-ref> <mode> [task-id|max-task-iterations]
```

5. Report the final result. If AFK completes successfully, include the PR URL and the exact merge command:

```bash
gh pr merge <number> --merge
```

Only the human user may run the merge command.

## Tips

- If a `ralph-local once` run stays silent for a long time and the user asks to take over, first stop the existing Ralph process cleanly and confirm `process list` is empty before delegating or restarting. Never let a stale Ralph/Codex child and a replacement coder edit the same PRD worktree concurrently.
- Start with once mode for a new PRD to validate task granularity and prompt behavior.
- Keep tasks as thin vertical slices that are independently verifiable.
- Put dependency order in both `depends_on` and the PRD task block order.
- If the script says the PRD has no Ralph task block, run `/prd-to-tasks` or update the PRD before invoking RALPH Local.
