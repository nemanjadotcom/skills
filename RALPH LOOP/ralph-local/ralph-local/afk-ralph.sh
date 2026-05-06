#!/usr/bin/env bash
set -euo pipefail

# afk-ralph.sh -- Run local RALPH until all PRD tasks are complete, then open a PR
# and iterate on CodeRabbit review feedback.
# Usage: .agents/skills/ralph-local/afk-ralph.sh <prd-ref> [max-task-iterations]
#
# Worktree creation and dependency install/skip checks are handled by ralph-once.sh
# on the first task iteration.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_ENV="${SCRIPT_DIR}/model.env"
if [[ -f "$MODEL_ENV" ]]; then
  # shellcheck source=/dev/null
  source "$MODEL_ENV"
fi

QUEUE="${SCRIPT_DIR}/task-queue.mjs"
CODERABBIT="${SCRIPT_DIR}/coderabbit-review.mjs"
ONCE="${SCRIPT_DIR}/ralph-once.sh"
PRD_REF="${1:?Usage: afk-ralph.sh <prd-ref> [max-task-iterations]}"
MAX_ITERATIONS="${2:-20}"
MAX_REVIEW_ITERATIONS="${RALPH_MAX_REVIEW_ITERATIONS:-${RALPH_DEFAULT_MAX_REVIEW_ITERATIONS:-10}}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
CODEX_MODEL="${RALPH_CODEX_MODEL:-${RALPH_DEFAULT_CODEX_MODEL:-gpt-5.5}}"
CODEX_REASONING_EFFORT="${RALPH_CODEX_REASONING_EFFORT:-${RALPH_DEFAULT_CODEX_REASONING_EFFORT:-low}}"

cd "$REPO_ROOT"

PRD_PATH="$(node "$QUEUE" prd-path "$PRD_REF")"
PRD_TITLE="$(node "$QUEUE" prd-title "$PRD_PATH")"
PRD_SLUG="$(node "$QUEUE" slug "$PRD_PATH")"
BRANCH="ralph/${PRD_SLUG}"
WORKTREE="${REPO_ROOT}/.agents/worktrees/ralph-${PRD_SLUG}"

run_codex() {
  local prompt="$1"
  codex exec \
    --full-auto \
    --model "$CODEX_MODEL" \
    -c "model_reasoning_effort=\"${CODEX_REASONING_EFFORT}\"" \
    -C "$WORKTREE" \
    "$prompt"
}

echo "Starting AFK Ralph Local for ${PRD_PATH}"
echo "Task iterations: ${MAX_ITERATIONS}"
echo "CodeRabbit iterations: ${MAX_REVIEW_ITERATIONS}"
echo ""

completed=0
for ((i=1; i<=MAX_ITERATIONS; i++)); do
  echo "=== Ralph task iteration ${i} / ${MAX_ITERATIONS} ==="

  set +e
  "$ONCE" "$PRD_PATH"
  once_status=$?
  set -e

  if [[ "$once_status" -eq 0 ]]; then
    echo ""
    continue
  fi

  if [[ "$once_status" -eq 2 ]]; then
    completed=1
    break
  fi

  echo "Ralph task iteration failed with exit code ${once_status}."
  exit "$once_status"
done

if [[ "$completed" -ne 1 ]]; then
  set +e
  (
    cd "$WORKTREE"
    node "$QUEUE" next-task "$PRD_PATH" >/dev/null 2>&1
  )
  next_status=$?
  set -e

  if [[ "$next_status" -eq 2 ]]; then
    completed=1
  else
    echo "Reached max task iterations without completing all PRD tasks."
    exit 1
  fi
fi

cd "$WORKTREE"

echo "=== All local PRD tasks complete ==="
node "$QUEUE" summary "$PRD_PATH"
echo ""

echo "Pushing ${BRANCH}..."
git push -u origin HEAD

pr_number="$(gh pr view --json number --jq '.number' 2>/dev/null || true)"
if [[ -z "$pr_number" ]]; then
  pr_body="$(node "$QUEUE" summary "$PRD_PATH")"
  gh pr create \
    --base main \
    --head "$BRANCH" \
    --title "$PRD_TITLE" \
    --body "$pr_body"
  pr_number="$(gh pr view --json number --jq '.number')"
fi

pr_url="$(gh pr view "$pr_number" --json url --jq '.url')"
echo "PR #${pr_number}: ${pr_url}"

# CodeRabbit review loop (DISABLED FOR NOW)
# for ((review_i=1; review_i<=MAX_REVIEW_ITERATIONS; review_i++)); do
#   echo "=== CodeRabbit iteration ${review_i} / ${MAX_REVIEW_ITERATIONS} ==="
#
#   set +e
#   node "$CODERABBIT" wait-checks "$pr_number"
#   checks_status=$?
#   set -e
#
#   if [[ "$checks_status" -ne 0 ]]; then
#     echo "PR checks failed or stopped early. Ralph will inspect the failures with the review context."
#   fi
#
#   if node "$CODERABBIT" is-clean "$pr_number"; then
#     echo "CodeRabbit review is clean."
#
#     echo "Running final verification..."
#     if pnpm run rebuild && pnpm test; then
#       echo "Final verification passed."
#       echo ""
#       echo "Ralph local is complete. Human merge command:"
#       echo "gh pr merge ${pr_number} --merge"
#       exit 0
#     fi
#
#     echo "Final verification failed. Ralph will attempt to fix it before another review pass."
#   fi
#
#   review_context="$(node "$CODERABBIT" summary "$pr_number")"
#
#   run_codex "You are in the Ralph Local CodeRabbit phase for PR #${pr_number}.
#
# ${review_context}
#
# Rules:
# - Run as Codex model ${CODEX_MODEL} with reasoning effort ${CODEX_REASONING_EFFORT}.
# - Use the CodeRabbit feedback and failing checks above as the source of truth.
# - Read the full surrounding files before changing code.
# - Fix genuine bugs and failed checks.
# - Do not blindly apply suggestions that conflict with AGENTS.md, architecture docs, or project conventions.
# - If a thread is a false positive or pre-existing issue, reply with a short @coderabbitai explanation before resolving it.
# - Resolve only review threads you addressed or explicitly answered.
# - You may use this helper to inspect or resolve threads:
#   node ${CODERABBIT} unresolved-threads ${pr_number}
#   node ${CODERABBIT} reply-thread THREAD_NODE_ID \"@coderabbitai <brief explanation>\"
#   node ${CODERABBIT} resolve-thread THREAD_NODE_ID
# - Commit fixes in one batch with a message that starts with \"review:\".
# - Push the branch after committing.
# - Do not dismiss CodeRabbit reviews.
# - Do not push empty commits.
#
# Output <coderabbit>FIXES_PUSHED</coderabbit> after you push fixes, or <coderabbit>NO_CHANGES</coderabbit> if there is nothing valid to change."
# done
#
# echo "Reached max CodeRabbit iterations without a clean review."
# echo "PR remains open: ${pr_url}"
# exit 1

echo ""
echo "=== Ralph Local complete ==="
echo "PR #${pr_number} created and ready for manual review."
echo "CodeRabbit loop disabled. Review the PR and merge manually:"
echo "gh pr merge ${pr_number} --merge"
