#!/usr/bin/env bash
set -euo pipefail

# ralph-afk-and-review.sh -- Compatibility entrypoint for autonomous RALPH review.
# Usage: .agents/skills/ralph/ralph-afk-and-review.sh <prd-issue-number> [max-iterations] [max-review-rounds]
#
# The old Docker runner has been retired. This entrypoint now delegates to the
# Codex worktree runner.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_ISSUE="${1:?Usage: ralph-afk-and-review.sh <prd-issue-number> [max-iterations] [max-review-rounds]}"
MAX_ITERATIONS="${2:-20}"
MAX_REVIEW_ROUNDS="${3:-10}"

exec "${SCRIPT_DIR}/ralph-afk-and-review-worktree.sh" \
  "$PRD_ISSUE" \
  "$MAX_ITERATIONS" \
  "$MAX_REVIEW_ROUNDS"
