#!/usr/bin/env bash
set -euo pipefail

# ralph-once.sh -- Run one local RALPH iteration for a PRD-scoped task.
# Usage: .agents/skills/ralph-local/ralph-once.sh <prd-ref> [task-id]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_ENV="${SCRIPT_DIR}/model.env"
if [[ -f "$MODEL_ENV" ]]; then
  # shellcheck source=/dev/null
  source "$MODEL_ENV"
fi

QUEUE="${SCRIPT_DIR}/task-queue.mjs"
PRD_REF="${1:?Usage: ralph-once.sh <prd-ref> [task-id]}"
REQUESTED_TASK_ID="${2:-}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
CODEX_MODEL="${RALPH_CODEX_MODEL:-${RALPH_DEFAULT_CODEX_MODEL:-gpt-5.5}}"
CODEX_REASONING_EFFORT="${RALPH_CODEX_REASONING_EFFORT:-${RALPH_DEFAULT_CODEX_REASONING_EFFORT:-low}}"
CODEX_BYPASS_SANDBOX="${RALPH_CODEX_BYPASS_SANDBOX:-${RALPH_DEFAULT_CODEX_BYPASS_SANDBOX:-0}}"

cd "$REPO_ROOT"

PRD_PATH="$(node "$QUEUE" prd-path "$PRD_REF")"
PRD_SLUG="$(node "$QUEUE" slug "$PRD_PATH")"
BRANCH="ralph/${PRD_SLUG}"
WORKTREE="${REPO_ROOT}/.agents/worktrees/ralph-${PRD_SLUG}"

copy_worktree_includes() {
  local include_file="${REPO_ROOT}/.worktreeinclude"
  [[ -f "$include_file" ]] || return 0

  while IFS= read -r pattern || [[ -n "$pattern" ]]; do
    pattern="${pattern#"${pattern%%[![:space:]]*}"}"
    pattern="${pattern%"${pattern##*[![:space:]]}"}"

    [[ -z "$pattern" || "$pattern" == \#* || "$pattern" == \!* ]] && continue

    local clean_pattern="${pattern%/}"
    local src="${REPO_ROOT}/${clean_pattern}"
    local dest="${WORKTREE}/${clean_pattern}"

    if [[ -d "$src" ]]; then
      mkdir -p "$dest"
      cp -R "$src"/. "$dest"/
    elif [[ -f "$src" ]]; then
      mkdir -p "$(dirname "$dest")"
      cp "$src" "$dest"
    fi
  done < "$include_file"
}

install_worktree_dependencies() {
  echo "Checking dependencies in PRD worktree..."
  (
    cd "$WORKTREE"

    if [[ ! -f package.json ]]; then
      echo "No package.json found in PRD worktree; skipping dependency install."
      return 0
    fi

    if [[ -f pnpm-lock.yaml ]]; then
      if command -v pnpm >/dev/null 2>&1; then
        echo "pnpm-lock.yaml found; installing dependencies with pnpm."
        pnpm install
      elif command -v corepack >/dev/null 2>&1; then
        echo "pnpm-lock.yaml found but pnpm is not installed; installing dependencies with corepack pnpm."
        corepack pnpm install
      else
        echo "pnpm-lock.yaml found, but neither pnpm nor corepack is available." >&2
        echo "Install pnpm or enable Corepack, then rerun Ralph Local." >&2
        return 1
      fi
      return 0
    fi

    if [[ -f package-lock.json ]]; then
      if command -v npm >/dev/null 2>&1; then
        echo "package-lock.json found; installing dependencies with npm ci."
        npm ci
      else
        echo "package-lock.json found, but npm is not available." >&2
        echo "Install npm, then rerun Ralph Local." >&2
        return 1
      fi
      return 0
    fi

    if command -v npm >/dev/null 2>&1; then
      echo "package.json found without a supported lockfile; installing dependencies with npm install."
      npm install
    else
      echo "package.json found, but no usable package manager is available." >&2
      echo "Install npm, pnpm, or Corepack, then rerun Ralph Local." >&2
      return 1
    fi
  )
}

run_codex() {
  local prompt="$1"
  local codex_args=(exec)

  if [[ "$CODEX_BYPASS_SANDBOX" == "1" || "$CODEX_BYPASS_SANDBOX" == "true" || "$CODEX_BYPASS_SANDBOX" == "yes" ]]; then
    codex_args+=(--dangerously-bypass-approvals-and-sandbox)
  else
    codex_args+=(--full-auto)
  fi

  codex_args+=(
    --model "$CODEX_MODEL"
    -c "model_reasoning_effort=\"${CODEX_REASONING_EFFORT}\""
    -C "$WORKTREE"
  )

  codex "${codex_args[@]}" "$prompt"
}

prepare_worktree() {
  mkdir -p "${REPO_ROOT}/.agents/worktrees"

  if [[ -e "$WORKTREE/.git" || -f "$WORKTREE/.git" ]]; then
    echo "Using existing PRD worktree: $WORKTREE"
    return 0
  fi

  if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
    git worktree add "$WORKTREE" "$BRANCH"
  else
    git worktree add -b "$BRANCH" "$WORKTREE" HEAD
  fi

  copy_worktree_includes
  install_worktree_dependencies
  echo "Created PRD worktree: $WORKTREE"
}

run_iteration() {
  cd "$WORKTREE"

  local task_path
  local next_status
  set +e
  if [[ -n "$REQUESTED_TASK_ID" ]]; then
    task_path="$(node "$QUEUE" next-task "$PRD_PATH" "$REQUESTED_TASK_ID" 2>&1)"
  else
    task_path="$(node "$QUEUE" next-task "$PRD_PATH" 2>&1)"
  fi
  next_status=$?
  set -e

  if [[ "$next_status" -eq 2 ]]; then
    echo "All Ralph tasks for ${PRD_PATH} are complete."
    exit 2
  fi

  if [[ "$next_status" -ne 0 ]]; then
    echo "$task_path"
    exit "$next_status"
  fi

  local task_id
  task_id="$(node "$QUEUE" task-id "$task_path")"
  echo "Starting Ralph task ${task_id}: ${task_path}"

  node "$QUEUE" mark-in-progress "$task_path"
  local task_start_sha
  task_start_sha="$(git rev-parse HEAD)"

  local implementation_prompt
  local task_context
  implementation_prompt="$(<"${SCRIPT_DIR}/instructions.md")"
  task_context="$(node "$QUEUE" context "$PRD_PATH" "$task_path")"

  run_codex "${implementation_prompt}

${task_context}

---

Implement exactly the selected task above.
The orchestrator already marked it in-progress.
Do not select a different task.
Per instructions.md: include task closure in the implementation commit — (a) move docs/roadmap/tasks/{task-id}-*.md to docs/roadmap/tasks/done/, (b) set frontmatter status: \"done\". Do NOT touch docs/roadmap/ROADMAP.md or docs/changelog.md — those are updated on main after merge.
Commit the implementation with a message that starts with \"${task_id}:\"."

  if [[ "$(git rev-parse HEAD)" == "$task_start_sha" ]]; then
    echo "Implementation did not create a commit for task ${task_id}; refusing to mark it done."
    exit 1
  fi

  local review_prompt
  review_prompt="$(<"${SCRIPT_DIR}/review.md")"

  run_codex "${review_prompt}

Review range: ${task_start_sha}..HEAD

Review the changes for task ${task_id}. Use Codex model ${CODEX_MODEL} with reasoning effort ${CODEX_REASONING_EFFORT}. Invoke the required review skills named in the prompt. If you apply fixes, commit them with a message that starts with \"review:\"."

  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "The worktree still has uncommitted changes after implementation/review; refusing to mark task ${task_id} done."
    git status --short
    exit 1
  fi

  # Verify task closure in the implementation commit:
  # (a) task spec moved to tasks/done/, (b) frontmatter status: "done".
  # ROADMAP.md and changelog.md are updated on main after merge — not checked here.
  local done_path
  done_path="docs/roadmap/tasks/done/$(basename "$task_path")"

  if [[ -e "$task_path" ]]; then
    echo "Task file is still at $task_path — agent did not move it to tasks/done/."
    exit 1
  fi
  if [[ ! -e "$done_path" ]]; then
    echo "Task file not found at $done_path — agent did not complete the move."
    exit 1
  fi

  local task_title progress_file
  task_title="$(grep -m1 '^title:' "$done_path" | sed 's/^title:[[:space:]]*//' | tr -d '"')"
  progress_file="docs/roadmap/progress.md"
  [[ -f "$progress_file" ]] || printf '# Progress\n\n' > "$progress_file"
  printf '- [x] `%s` %s (%s)\n' "$task_id" "$task_title" "$(date '+%Y-%m-%d')" >> "$progress_file"
  git add "$progress_file"
  git commit -m "progress: ${task_id}"

  echo "Completed Ralph task ${task_id}."
}

prepare_worktree
run_iteration
