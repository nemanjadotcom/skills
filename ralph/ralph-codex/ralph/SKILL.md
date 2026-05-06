---
name: ralph
description: Autonomous PRD implementation loop — turns GitHub issues into shipped code using TDD, code review gates, and git worktree isolation. The execution engine for the grill-me → write-a-prd → prd-to-issues → ralph pipeline.
---

# RALPH — Autonomous PRD Implementation

RALPH (Repeated Autonomous Loop for PRD Handling) implements a PRD stored as GitHub issues — autonomously, with TDD, and a code review gate after every iteration.

## The Pipeline

This skill is the execution engine for a 4-step coding workflow:

| Step | Command | What It Does |
|------|---------|-------------|
| 1 | `/grill-me` | Stress-test your idea with relentless questions before building |
| 2 | `/to-prd` | Turn the idea into an engineering spec (PRD) as a GitHub issue |
| 3 | `/to-issues` | Break the PRD into vertical-slice sub-issues with dependencies |
| 4 | `/ralph` | Implement each sub-issue autonomously with TDD + code review |

## Usage

### `/ralph <issue-number>` — Human-in-the-loop (start here)

```bash
.agents/skills/ralph/ralph-once.sh 42
```

Implements one sub-issue from PRD #42, then stops for your review. Run again for the next one. Recommended for your first few iterations.

### `/ralph <issue-number> afk [max-iterations]` — Autonomous

```bash
.agents/skills/ralph/afk-ralph.sh 42 20
```

Runs up to 20 iterations in a git worktree. Each iteration: implement one sub-issue, run tests, commit, run the local review gate with the Codex model and reasoning effort configured in `.agents/skills/ralph/config.env`, close the issue. When all sub-issues are done, pushes the branch, opens a PR, and drives CodeRabbit review.

### `/ralph <issue-number> afk-and-review [max-iterations] [max-review-rounds]` — Autonomous + CodeRabbit loop

```bash
.agents/skills/ralph/ralph-afk-and-review.sh 42 20 10
```

Compatibility entrypoint for the Codex-native worktree runner. Runs review with the model settings from `.agents/skills/ralph/config.env`.

### `/ralph <issue-number> afk-and-review-worktree [max-iterations] [max-review-rounds]` — Autonomous + CodeRabbit loop (worktree, no Docker)

```bash
.agents/skills/ralph/ralph-afk-and-review-worktree.sh 42 20 10
```

Same behavior as `afk-and-review` but uses a git worktree at `.agents/worktrees/ralph-prd-<N>` for isolation instead of a Docker container. Codex runs on the host with `cwd` set to the worktree, using model settings from `.agents/skills/ralph/config.env`. Worktree is left in place after exit for inspection — final summary prints both the merge command and the worktree-cleanup commands.

## Instructions

When the user invokes this skill:

1. Parse arguments: first is the PRD issue number (required), second is mode (`once` | `afk` | `afk-and-review` | `afk-and-review-worktree`, default `once`), third is max implementation iterations (default 20), fourth is max review rounds for the two `afk-and-review*` modes (default 10)
2. If no issue number is provided, ask for it
3. Verify `.agents/skills/ralph/` exists at the project root.
4. For `once` mode (default):
   ```bash
   .agents/skills/ralph/ralph-once.sh <issue-number>
   ```
   The script prints next-step suggestions at the end (run again, or push + `/pr-review-loop`).
5. For `afk` mode:
   ```bash
   .agents/skills/ralph/afk-ralph.sh <issue-number> <max-iterations>
   ```
6. For `afk-and-review` mode:
   ```bash
   .agents/skills/ralph/ralph-afk-and-review.sh <issue-number> <max-iterations> <max-review-rounds>
   ```
7. For `afk-and-review-worktree` mode (worktree-isolated, no Docker):
   ```bash
   .agents/skills/ralph/ralph-afk-and-review-worktree.sh <issue-number> <max-iterations> <max-review-rounds>
   ```
8. Report the result when complete (including the merge command for either `afk-and-review*` mode)

## How It Works

1. Scripts fetch the PRD issue and all sub-issues via `gh` CLI
2. Sub-issues are found by searching for `Parent PRD #<number>` in their body
3. Each iteration: Codex picks one open, unblocked sub-issue and implements it using TDD
4. Tests must pass before every commit (auto-detected from project config)
5. After committing, a code review gate runs a high-signal local review using the configured Codex model and reasoning effort; if named review skills or subagent surfaces are available, it invokes them, otherwise it performs the equivalent review directly
6. Codex closes the sub-issue on GitHub with a comment linking the commit
7. Loop continues until all sub-issues are closed

## Sub-Issue Format

Sub-issues created by `/to-issues` follow this format:

```markdown
## Parent PRD
#42

## What to build
Description of the work...

## Acceptance criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Blocked by
- #43
```

## Tips

- **Start with `/ralph` (once mode).** Validate the first iteration before going AFK.
- **Keep sub-issues small.** One logical change per sub-issue prevents context rot.
- **Use `/grill-me` first.** The more you think before coding, the better RALPH performs.
- **Use blocked-by.** Declare dependencies so RALPH works in the right order.
