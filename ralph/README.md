# Ralph Loop

Ralph is a small set of agent skills and scripts for turning a product idea into shipped code:

1. Stress-test the idea.
2. Write a PRD.
3. Break the PRD into small vertical slices.
4. Let an agent implement one slice at a time with tests, commits, and review gates.

This repo contains three versions:

- **Ralph for Claude**: Claude Code-oriented workflow.
- **Ralph for Codex**: Codex-oriented workflow with model config, worktree isolation, and CodeRabbit review loops.
- **Ralph Local**: local-file workflow that uses PRDs and task specs in `docs/roadmap/` instead of GitHub issues for task selection.

## Repo Layout

```text
RALPH LOOP/ralph/
  ralph-claude/   Claude Code skills and scripts
  ralph-codex/    Codex skills and scripts
  ralph-local/    Local PRD/task workflow
```

There are also ready-to-copy `.agents/skills/` and `.claude/skills/` folders under `RALPH LOOP/` for project-local installs.

## Claude Version

Use this when your implementation agent is Claude Code.

Pipeline:

```text
/grill-me -> /to-prd -> /to-issues -> /ralph
```

Main idea:

- PRDs and sub-tasks live as GitHub issues.
- `ralph-once.sh` implements one sub-issue and stops.
- `afk-ralph.sh` runs multiple iterations and opens a PR.
- AFK mode uses Docker sandboxing.

Useful files:

```text
RALPH LOOP/ralph/ralph-claude/
```

## Codex Version

Use this when your implementation agent is Codex.

Pipeline:

```text
/grill-me -> /to-prd -> /to-issues -> /ralph
```

Main idea:

- PRDs and sub-tasks live as GitHub issues.
- Codex implements sub-issues with TDD.
- Work can run once, AFK, or AFK with review.
- Model defaults live in `ralph/config.env`.
- Worktree mode keeps implementation isolated without Docker.

Useful files:

```text
RALPH LOOP/ralph/ralph-codex/
```

Common entrypoints:

```bash
.agents/skills/ralph/ralph-once.sh <prd-issue-number>
.agents/skills/ralph/afk-ralph.sh <prd-issue-number> 20
.agents/skills/ralph/ralph-afk-and-review-worktree.sh <prd-issue-number> 20 10
```

## Local Version

Use this when you want the planning source of truth in your repo instead of GitHub issues.

Pipeline:

```text
/shape-local -> /prd-to-tasks -> /ralph-local
```

Main idea:

- PRDs live in `docs/roadmap/prds/`.
- Tasks live in `docs/roadmap/tasks/`.
- Task IDs derive from the PRD ID:

```text
prd-1.1 -> 1.1.1, 1.1.2, 1.1.3
```

- Ralph Local picks the next unblocked task from the PRD task block.
- After all tasks are done, it opens a GitHub PR and can iterate on CodeRabbit feedback.

Useful files:

```text
RALPH LOOP/ralph/ralph-local/
```

Common entrypoints:

```bash
.agents/skills/ralph-local/ralph-local.sh <prd-ref>
.agents/skills/ralph-local/ralph-local.sh <prd-ref> afk 20
```

## Requirements

- Git
- GitHub CLI (`gh`) for GitHub issue and PR flows
- Claude Code for the Claude version
- Codex CLI for the Codex version
- Docker Desktop for Claude AFK sandbox mode
- Node.js for Ralph Local helper scripts

## Recommended Use

Start human-in-the-loop:

```bash
ralph-once.sh <prd-or-issue>
```

Once the first slice looks good, switch to AFK mode.

Keep PRDs clear and sub-issues small. Ralph works best when each task is a thin vertical slice with concrete acceptance criteria.
