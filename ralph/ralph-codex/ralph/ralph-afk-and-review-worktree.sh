#!/usr/bin/env bash
set -euo pipefail

# ralph-afk-and-review-worktree.sh -- Worktree-isolated variant of
# ralph-afk-and-review.sh. Runs Codex on the host but inside an isolated git
# worktree at .agents/worktrees/ralph-prd-<N>. No Docker required.
#
# Usage: .agents/skills/ralph/ralph-afk-and-review-worktree.sh <prd-issue-number> [max-iterations] [max-review-rounds]
#
# Defaults: max-iterations=20, max-review-rounds=10.
#
# What this script does:
#   1. Creates a git worktree at .agents/worktrees/ralph-prd-<N> on branch
#      ralph/prd-<N>, branched from main
#   2. Copies files matching .worktreeinclude (env, prds, settings.local) into
#      the worktree, then installs dependencies there if a package manifest exists
#   3. Runs the implementation loop: each iteration, Codex picks one open
#      unblocked sub-issue, implements it, runs tests, commits, closes the issue
#   4. After every commit, runs the code-review gate (Codex with the
#      review-comprehensive prompt)
#   5. When all sub-issues are closed (or max iterations hit), pushes the
#      branch and creates a PR
#   6. Drives the PR through CodeRabbit review until approved with zero
#      unresolved threads (max-review-rounds bound)
#   7. Prints the final merge command and worktree-cleanup commands for the
#      human to copy
#
# Safety notes:
#   - Codex runs in full-auto mode inside the worktree. The worktree boundary
#     protects your main checkout, while Codex still has the permissions granted
#     by its own sandbox configuration.
#   - Per AGENTS.md, .env is never read by Codex — but this script copies
#     .env into the worktree via `cp` (no read of content). Acceptable.
#   - On exit, the worktree is left in place for inspection. Cleanup is the
#     human's job after merging the PR (commands printed in the final summary).

PRD_ISSUE="${1:?Usage: ralph-afk-and-review-worktree.sh <prd-issue-number> [max-iterations] [max-review-rounds]}"
MAX_ITERATIONS="${2:-20}"
MAX_REVIEW_ROUNDS="${3:-10}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/config.env" ]]; then
  source "${SCRIPT_DIR}/config.env"
fi
CODEX_MODEL="${RALPH_CODEX_MODEL:-gpt-5.5}"
CODEX_REASONING_EFFORT="${RALPH_CODEX_REASONING_EFFORT:-low}"
FORCE_WORKTREE_RESET="${RALPH_FORCE_WORKTREE_RESET:-0}"
REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
REPO_OWNER="${REPO%%/*}"
REPO_NAME="${REPO##*/}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
RALPH_SKILL_DIR="$SCRIPT_DIR"
ITERATION_PROMPT="$(cat "${RALPH_SKILL_DIR}/prompt.md")"
REVIEW_PROMPT="$(cat "${RALPH_SKILL_DIR}/review-comprehensive.md")"
PR_REVIEW_LOOP_PROMPT="$(cat "${RALPH_SKILL_DIR}/pr-review-loop-prompt.md")"
PRD_TITLE="$(gh issue view "$PRD_ISSUE" --repo "$REPO" --json title --jq '.title')"

cd "$REPO_ROOT"

BRANCH="ralph/prd-${PRD_ISSUE}"
WORKTREE_PATH="${REPO_ROOT}/.agents/worktrees/ralph-prd-${PRD_ISSUE}"
WORKTREE_INCLUDE="${REPO_ROOT}/.worktreeinclude"

echo "Starting AFK RALPH + REVIEW (worktree mode): PRD #${PRD_ISSUE}"
echo "  Worktree:                       ${WORKTREE_PATH}"
echo "  Branch:                         ${BRANCH}"
echo "  Max implementation iterations:  $MAX_ITERATIONS"
echo "  Max review rounds:              $MAX_REVIEW_ROUNDS"
echo ""

# --- Pre-flight: verify required tooling on host ---
for cmd in codex gh git; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command '$cmd' not found on PATH"
    exit 1
  fi
done

# State that influences the final summary
PR_NUMBER=""
REVIEW_VERDICT="NOT_RUN"  # NOT_RUN | READY_TO_MERGE | RATE_LIMITED | NEEDS_HUMAN | MAX_ROUNDS

final_summary() {
  echo ""
  echo "=========================================================="
  echo "RALPH+REVIEW SUMMARY (worktree mode)"
  echo "  PRD:       #${PRD_ISSUE}"
  echo "  Branch:    ${BRANCH}"
  echo "  Worktree:  ${WORKTREE_PATH}"
  if [[ -n "$PR_NUMBER" ]]; then
    echo "  PR:        #${PR_NUMBER} (https://github.com/${REPO}/pull/${PR_NUMBER})"
  else
    echo "  PR:        (not created)"
  fi
  echo "  Review:    ${REVIEW_VERDICT}"
  echo ""

  case "$REVIEW_VERDICT" in
    READY_TO_MERGE)
      # MERGE STRATEGY: --merge (preserves full commit history per AGENTS.md line 64).
      # NEVER use --squash or --rebase in this project — both erase the per-commit
      # history that AGENTS.md mandates be preserved on main via `git merge --no-ff`.
      # gh's --merge flag is the equivalent of git merge --no-ff (creates a merge commit).
      echo "PR is approved with zero unresolved threads. To merge:"
      echo ""
      echo "  gh pr merge ${PR_NUMBER} --repo ${REPO} --merge --delete-branch"
      echo ""
      echo "Then clean up the worktree:"
      echo "  git -C ${REPO_ROOT} worktree remove ${WORKTREE_PATH}"
      echo "  git -C ${REPO_ROOT} worktree prune"
      echo ""
      ;;
    RATE_LIMITED)
      echo "CodeRabbit hit its hourly rate limit during the review loop."
      echo "Wait ~60 minutes, then resume the review by running:"
      echo ""
      echo "  /pr-review-loop ${PR_NUMBER}"
      echo ""
      echo "Worktree left in place at ${WORKTREE_PATH} for follow-up commits."
      ;;
    NEEDS_HUMAN)
      echo "Review loop stopped because a CodeRabbit thread needs human judgment."
      echo "Inspect the PR and the worktree, then resume manually:"
      echo ""
      echo "  gh pr view ${PR_NUMBER} --comments"
      echo "  cd ${WORKTREE_PATH}"
      echo "  /pr-review-loop ${PR_NUMBER}"
      echo ""
      ;;
    MAX_ROUNDS)
      echo "Hit max review rounds (${MAX_REVIEW_ROUNDS}) without convergence."
      echo "Inspect the PR and decide whether to keep iterating:"
      echo ""
      echo "  gh pr view ${PR_NUMBER} --comments"
      echo "  /pr-review-loop ${PR_NUMBER}"
      echo ""
      ;;
    NOT_RUN)
      echo "Review loop did not run (likely no PR was created or implementation failed before the loop)."
      echo ""
      echo "Worktree left in place at ${WORKTREE_PATH} for inspection."
      echo "To remove it once you're done:"
      echo "  git -C ${REPO_ROOT} worktree remove --force ${WORKTREE_PATH}"
      echo "  git -C ${REPO_ROOT} worktree prune"
      ;;
  esac
  echo "=========================================================="
}

cleanup() {
  local exit_code=$?
  final_summary
  exit "$exit_code"
}
trap cleanup EXIT

# ====================================================================
# PHASE 0: Worktree setup
# ====================================================================
echo "=== Setting up worktree ==="

# Refuse to overwrite an existing RALPH worktree or branch unless the caller
# explicitly opts in. This preserves in-progress autonomous runs for inspection.
worktree_exists=0
branch_exists=0
path_exists=0
if git worktree list --porcelain | grep -q "^worktree ${WORKTREE_PATH}$"; then
  worktree_exists=1
fi
if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  branch_exists=1
fi
if [[ -e "$WORKTREE_PATH" ]]; then
  path_exists=1
fi

if [[ "$worktree_exists" -eq 1 || "$branch_exists" -eq 1 || "$path_exists" -eq 1 ]]; then
  if [[ "$FORCE_WORKTREE_RESET" != "1" ]]; then
    echo "ERROR: RALPH worktree state already exists for PRD #${PRD_ISSUE}."
    echo "  Branch exists:  ${branch_exists}"
    echo "  Worktree exists:${worktree_exists}"
    echo "  Path exists:    ${path_exists}"
    echo ""
    echo "Inspect or clean it manually, or rerun with:"
    echo "  RALPH_FORCE_WORKTREE_RESET=1 .agents/skills/ralph/ralph-afk-and-review-worktree.sh ${PRD_ISSUE} ${MAX_ITERATIONS} ${MAX_REVIEW_ROUNDS}"
    exit 1
  fi

  echo "RALPH_FORCE_WORKTREE_RESET=1 set; removing pre-existing worktree state..."
  if [[ "$worktree_exists" -eq 1 ]]; then
    git worktree remove --force "$WORKTREE_PATH" || true
  fi
  if [[ "$path_exists" -eq 1 ]]; then
    rm -rf "$WORKTREE_PATH"
  fi
  if [[ "$branch_exists" -eq 1 ]]; then
    git branch -D "$BRANCH" || true
  fi
fi
git worktree prune

# Ensure parent directory exists
mkdir -p "$(dirname "$WORKTREE_PATH")"

# Create worktree on a fresh branch from main (force-recreate the branch)
echo "Creating worktree on branch '${BRANCH}' from main..."
git worktree add -B "$BRANCH" "$WORKTREE_PATH" main

# Copy files matching .worktreeinclude into the worktree (per AGENTS.md)
if [[ -f "$WORKTREE_INCLUDE" ]]; then
  echo "Copying .worktreeinclude entries into worktree..."
  while IFS= read -r entry; do
    # Skip blank lines and comments
    [[ -z "$entry" || "$entry" =~ ^[[:space:]]*# ]] && continue
    src="${REPO_ROOT}/${entry}"
    dst="${WORKTREE_PATH}/${entry}"
    if [[ ! -e "$src" ]]; then
      echo "  skip (not found): $entry"
      continue
    fi
    mkdir -p "$(dirname "$dst")"
    if [[ -d "$src" ]]; then
      # Trailing slash on src means "copy contents", without copies the dir itself
      cp -R "$src" "$(dirname "$dst")/"
    else
      cp "$src" "$dst"
    fi
    echo "  copied: $entry"
  done < "$WORKTREE_INCLUDE"
else
  echo "No .worktreeinclude found — skipping selective copy."
fi

# Install dependencies in the worktree when a package manifest is present.
if [[ -f "${WORKTREE_PATH}/package.json" ]]; then
  echo "Running package install in worktree root..."
  if [[ -f "${WORKTREE_PATH}/package-lock.json" ]]; then
    (cd "$WORKTREE_PATH" && npm install --silent)
  elif command -v pnpm >/dev/null 2>&1; then
    (cd "$WORKTREE_PATH" && pnpm install --silent)
  else
    (cd "$WORKTREE_PATH" && npm install --silent)
  fi
elif [[ -f "${WORKTREE_PATH}/app/package.json" ]]; then
  echo "Running package install in worktree app/..."
  if [[ -f "${WORKTREE_PATH}/app/package-lock.json" ]]; then
    (cd "${WORKTREE_PATH}/app" && npm install --silent)
  elif command -v pnpm >/dev/null 2>&1; then
    (cd "${WORKTREE_PATH}/app" && pnpm install --silent)
  else
    (cd "${WORKTREE_PATH}/app" && npm install --silent)
  fi
else
  echo "No package manifest found — skipping dependency install."
fi

echo "Worktree ready at ${WORKTREE_PATH}"
echo ""

# Helper: run Codex inside the worktree with the Ralph model contract.
run_codex() {
  local prompt="$1"
  codex exec \
    --full-auto \
    --model "$CODEX_MODEL" \
    -c "model_reasoning_effort=\"${CODEX_REASONING_EFFORT}\"" \
    -C "$WORKTREE_PATH" \
    "$prompt"
}

# ====================================================================
# PHASE 1: Implementation loop
# ====================================================================
implementation_complete=false
for ((i=1; i<=MAX_ITERATIONS; i++)); do
  echo "=== RALPH iteration $i / $MAX_ITERATIONS ==="

  echo "Fetching PRD issue #${PRD_ISSUE}..."
  prd_body=$(gh issue view "$PRD_ISSUE" --repo "$REPO" --json number,title,state,body \
    --jq '"# PRD: \(.title) (#\(.number))\nState: \(.state)\n\n\(.body)"')

  echo "Finding sub-issues..."
  sub_issue_numbers=$(gh issue list --repo "$REPO" --state all --limit 500 --json number,body \
    --jq ".[] | select(.number != ${PRD_ISSUE}) | select(.body | contains(\"Parent PRD #${PRD_ISSUE}\")) | .number" \
    | sort -n | uniq || true)

  if [[ -z "$sub_issue_numbers" ]]; then
    echo "No sub-issues found. Nothing to do."
    exit 1
  fi

  open_count=0
  for num in $sub_issue_numbers; do
    state=$(gh issue view "$num" --repo "$REPO" --json state --jq '.state')
    if [[ "$state" == "OPEN" ]]; then
      open_count=$((open_count + 1))
    fi
  done

  if [[ "$open_count" -eq 0 ]]; then
    echo "=== RALPH: All sub-issues closed after $((i - 1)) iterations ==="
    implementation_complete=true
    break
  fi

  echo "$open_count open sub-issue(s) remaining."

  sub_issues=""
  for num in $sub_issue_numbers; do
    detail=$(gh issue view "$num" --repo "$REPO" --json number,title,state,body \
      --jq '"---\n## Sub-issue #\(.number): \(.title)\nState: \(.state)\n\n\(.body)"')
    sub_issues="${sub_issues}\n${detail}"
  done

  result=$(run_codex "${ITERATION_PROMPT}

${prd_body}

# Sub-issues
${sub_issues}

---

Read the PRD and sub-issues above. Then:
1. Identify which sub-issues are OPEN and not blocked by other OPEN issues.
2. Pick ONE open, unblocked sub-issue to work on (prioritize: architecture > integration > spikes > features > polish).
3. Implement that sub-issue. Keep the change small and focused.
4. Detect and run the project's test suite (check package.json, pyproject.toml, Makefile, Cargo.toml, AGENTS.md, etc.). Fix any failures.
5. Make a git commit with a descriptive message.
6. Close the sub-issue: gh issue close <number> --repo ${REPO} --comment \"Completed in \$(git rev-parse --short HEAD). <brief summary of what was done>\"
7. If ALL sub-issues are now closed, output <promise>COMPLETE</promise>.
ONLY WORK ON A SINGLE SUB-ISSUE PER ITERATION.")

  echo "$result"
  echo ""

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo "=== RALPH: All work complete after $i iterations ==="
    implementation_complete=true
    break
  fi

  # --- Code review gate ---
  echo "--- Code review for iteration $i ---"
  review_result=$(run_codex "${REVIEW_PROMPT}

Review the changes from the most recent commit. Use Codex model ${CODEX_MODEL} with reasoning effort ${CODEX_REASONING_EFFORT}. Invoke the required review skills named in the prompt. Follow the review procedure exactly.")

  echo "$review_result"
  echo ""

  if [[ "$review_result" == *"<review>FIXES_APPLIED</review>"* ]]; then
    echo "--- Review: fixes applied, continuing ---"
  else
    echo "--- Review: clean, continuing ---"
  fi
done

if [[ "$implementation_complete" == "false" ]]; then
  echo "=== RALPH: Reached max iterations ($MAX_ITERATIONS) without completion ==="
fi

# ====================================================================
# PHASE 2: Push branch + create PR
# ====================================================================
commits_ahead=$(git -C "$WORKTREE_PATH" rev-list --count main.."$BRANCH" 2>/dev/null || echo "0")

if [[ "$commits_ahead" -eq 0 ]]; then
  echo "No new commits on ${BRANCH}. Skipping push, PR, and review loop."
  exit 1
fi

echo ""
echo "Pushing branch ${BRANCH} (${commits_ahead} commit(s))..."
git -C "$WORKTREE_PATH" push --force-with-lease --set-upstream origin "$BRANCH"

existing_pr=$(gh pr view "$BRANCH" --repo "$REPO" --json number --jq '.number' 2>/dev/null || echo "")

if [[ -n "$existing_pr" ]]; then
  PR_NUMBER="$existing_pr"
  echo "PR #${PR_NUMBER} already exists for branch ${BRANCH}."
elif [[ "$implementation_complete" == "true" ]]; then
  echo "Creating pull request..."
  pr_url=$(gh pr create \
    --repo "$REPO" \
    --base main \
    --head "$BRANCH" \
    --title "$PRD_TITLE" \
    --body "$(cat <<EOF
Implements PRD #${PRD_ISSUE}.

## PRD
Closes #${PRD_ISSUE}
EOF
)")
  PR_NUMBER="${pr_url##*/}"
  echo "Created PR #${PR_NUMBER}: ${pr_url}"
else
  echo "Creating draft pull request (incomplete — max iterations reached)..."
  pr_url=$(gh pr create \
    --repo "$REPO" \
    --base main \
    --head "$BRANCH" \
    --title "[WIP] $PRD_TITLE" \
    --draft \
    --body "$(cat <<EOF
Partial implementation of PRD #${PRD_ISSUE} (max iterations reached).

## PRD
References #${PRD_ISSUE}
EOF
)")
  PR_NUMBER="${pr_url##*/}"
  echo "Created draft PR #${PR_NUMBER}: ${pr_url}"
  echo "Skipping review loop because the PR is a WIP draft."
  exit 1
fi

# ====================================================================
# PHASE 3: CodeRabbit review loop (DISABLED FOR NOW)
# ====================================================================
# echo ""
# echo "=== Starting CodeRabbit review loop on PR #${PR_NUMBER} ==="
#
# review_result=$(run_codex "${PR_REVIEW_LOOP_PROMPT}
#
# Repo: ${REPO}
# Owner: ${REPO_OWNER}
# Repo name: ${REPO_NAME}
# PR number: ${PR_NUMBER}
# Branch: ${BRANCH}
# Max review rounds: ${MAX_REVIEW_ROUNDS}
#
# Drive the PR + CodeRabbit review loop until the stopping condition is met. Use Codex model ${CODEX_MODEL} with reasoning effort ${CODEX_REASONING_EFFORT}. Follow the prompt exactly. Output one of: <promise>READY_TO_MERGE</promise>, <promise>RATE_LIMITED</promise>, or <promise>NEEDS_HUMAN</promise>.")
#
# echo "$review_result"
# echo ""
#
# if [[ "$review_result" == *"<promise>READY_TO_MERGE</promise>"* ]]; then
#   REVIEW_VERDICT="READY_TO_MERGE"
# elif [[ "$review_result" == *"<promise>RATE_LIMITED</promise>"* ]]; then
#   REVIEW_VERDICT="RATE_LIMITED"
# elif [[ "$review_result" == *"<promise>NEEDS_HUMAN</promise>"* ]]; then
#   REVIEW_VERDICT="NEEDS_HUMAN"
# else
#   REVIEW_VERDICT="MAX_ROUNDS"
# fi

# CodeRabbit disabled — PR created and ready for manual review
REVIEW_VERDICT="NOT_RUN"
echo ""
echo "CodeRabbit loop disabled. PR #${PR_NUMBER} created and ready for manual review."
echo ""

# Trap will print the final summary
exit 0
