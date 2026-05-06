#!/usr/bin/env bash
set -euo pipefail

# afk-ralph.sh -- Compatibility entrypoint for autonomous RALPH.
# Usage: .agents/skills/ralph/afk-ralph.sh <prd-issue-number> [max-iterations]
#
# The old Docker runner has been retired. Autonomous RALPH now delegates to the
# Codex worktree runner, including the local review gate and CodeRabbit loop.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_ISSUE="${1:?Usage: afk-ralph.sh <prd-issue-number> [max-iterations]}"
MAX_ITERATIONS="${2:-20}"
MAX_REVIEW_ROUNDS="${RALPH_MAX_REVIEW_ROUNDS:-10}"

exec "${SCRIPT_DIR}/ralph-afk-and-review-worktree.sh" \
  "$PRD_ISSUE" \
  "$MAX_ITERATIONS" \
  "$MAX_REVIEW_ROUNDS"
