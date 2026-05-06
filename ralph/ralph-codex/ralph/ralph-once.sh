#!/usr/bin/env bash
set -euo pipefail

# ralph-once.sh -- Run one RALPH iteration against a GitHub PRD issue, then stop for human review.
# Usage: .agents/skills/ralph/ralph-once.sh <prd-issue-number>

PRD_ISSUE="${1:?Usage: ralph-once.sh <prd-issue-number>}"
REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/config.env" ]]; then
  source "${SCRIPT_DIR}/config.env"
fi
CODEX_MODEL="${RALPH_CODEX_MODEL:-gpt-5.5}"
CODEX_REASONING_EFFORT="${RALPH_CODEX_REASONING_EFFORT:-low}"

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
RALPH_SKILL_DIR="$SCRIPT_DIR"
ITERATION_PROMPT="$(cat "${RALPH_SKILL_DIR}/prompt.md")"

CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || echo "")"
if [[ -z "$CURRENT_BRANCH" || "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]]; then
  echo "ERROR: refusing to run RALPH once mode on '${CURRENT_BRANCH:-detached HEAD}'."
  echo "Create or switch to a feature branch first, for example:"
  echo "  git checkout -b ralph/prd-${PRD_ISSUE}"
  exit 1
fi

run_codex() {
  local prompt="$1"
  codex exec \
    --full-auto \
    --model "$CODEX_MODEL" \
    -c "model_reasoning_effort=\"${CODEX_REASONING_EFFORT}\"" \
    -C "$REPO_ROOT" \
    "$prompt"
}

echo "Fetching PRD issue #${PRD_ISSUE}..."

# Fetch the PRD issue body
prd_body=$(gh issue view "$PRD_ISSUE" --repo "$REPO" --json number,title,state,body \
  --jq '"# PRD: \(.title) (#\(.number))\nState: \(.state)\n\n\(.body)"')

# Find sub-issues that reference this PRD
echo "Finding sub-issues..."
sub_issue_numbers=$(gh issue list --repo "$REPO" --state all --limit 500 --json number,body \
  --jq ".[] | select(.number != ${PRD_ISSUE}) | select(.body | contains(\"Parent PRD #${PRD_ISSUE}\")) | .number" \
  | sort -n | uniq || true)

if [[ -z "$sub_issue_numbers" ]]; then
  echo "No sub-issues found referencing PRD #${PRD_ISSUE}."
  echo "Create sub-issues with '## Parent PRD' followed by '#${PRD_ISSUE}' in the body."
  exit 1
fi

# Fetch each sub-issue's full details
sub_issues=""
for num in $sub_issue_numbers; do
  detail=$(gh issue view "$num" --repo "$REPO" --json number,title,state,body \
    --jq '"---\n## Sub-issue #\(.number): \(.title)\nState: \(.state)\n\n\(.body)"')
  sub_issues="${sub_issues}\n${detail}"
done

echo "Found $(echo "$sub_issue_numbers" | wc -l | tr -d ' ') sub-issues. Starting RALPH iteration..."
echo ""

# Build the context and run Codex.
run_codex "${ITERATION_PROMPT}

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
ONLY WORK ON A SINGLE SUB-ISSUE PER ITERATION."

echo ""
echo "--- RALPH iteration complete. Review changes before running again. ---"
echo ""

# Suggest the next step based on git/PR state.
REPO_OWNER="${REPO%%/*}"

# Are there commits on this branch that aren't on main?
COMMITS_AHEAD="$(git rev-list --count "main..${CURRENT_BRANCH}" 2>/dev/null || echo "0")"

if [[ "$COMMITS_AHEAD" -eq 0 ]]; then
  echo "No new commits on '${CURRENT_BRANCH}' yet. Run /ralph ${PRD_ISSUE} again to take another sub-issue."
  exit 0
fi

# Is the branch pushed and does a PR already exist?
EXISTING_PR="$(gh pr view "$CURRENT_BRANCH" --repo "$REPO" --json number --jq '.number' 2>/dev/null || echo "")"

if [[ -n "$EXISTING_PR" ]]; then
  echo "Next step:"
  echo ""
  echo "  PR #${EXISTING_PR} already exists for this branch. Push your latest commit and start the CodeRabbit review:"
  echo ""
  echo "    git push origin HEAD"
  echo "    /pr-review-loop ${EXISTING_PR}"
  echo ""
  echo "Or take the next sub-issue first:"
  echo "    /ralph ${PRD_ISSUE}"
  exit 0
fi

echo "Next step (pick one):"
echo ""
echo "  A) Take another sub-issue before opening a PR:"
echo "       /ralph ${PRD_ISSUE}"
echo ""
echo "  B) Open a PR and start the CodeRabbit review:"
echo "       git push -u origin HEAD"
echo "       gh pr create --repo ${REPO} --base main --head ${CURRENT_BRANCH}"
echo "       # then copy the PR number into:"
echo "       /pr-review-loop <pr-number>"
