#!/usr/bin/env bash
set -euo pipefail

# ralph-local.sh -- Human-facing wrapper for local RALPH modes.
# Usage:
#   .agents/skills/ralph-local/ralph-local.sh <prd-ref> [once|afk] [task-id|max-task-iterations]
#
# Examples:
#   .agents/skills/ralph-local/ralph-local.sh prd-20.2
#   .agents/skills/ralph-local/ralph-local.sh prd-20.2 once 20.2.1
#   .agents/skills/ralph-local/ralph-local.sh prd-20.2 afk 20

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ONCE="${SCRIPT_DIR}/ralph-once.sh"
AFK="${SCRIPT_DIR}/afk-ralph.sh"

usage() {
  cat >&2 <<'EOF'
Usage: .agents/skills/ralph-local/ralph-local.sh <prd-ref> [once|afk] [task-id|max-task-iterations]

Modes:
  once  Run one pending PRD task. Optional third argument is a task id.
  afk   Run pending PRD tasks until complete. Optional third argument is max task iterations.

Examples:
  .agents/skills/ralph-local/ralph-local.sh prd-20.2
  .agents/skills/ralph-local/ralph-local.sh prd-20.2 once 20.2.1
  .agents/skills/ralph-local/ralph-local.sh prd-20.2 afk 20
EOF
}

PRD_REF="${1:-}"
MODE="${2:-once}"
ARG="${3:-}"

if [[ -z "$PRD_REF" ]]; then
  usage
  exit 64
fi

case "$MODE" in
  once)
    if [[ -n "$ARG" ]]; then
      exec "$ONCE" "$PRD_REF" "$ARG"
    fi
    exec "$ONCE" "$PRD_REF"
    ;;
  afk)
    exec "$AFK" "$PRD_REF" "${ARG:-20}"
    ;;
  *)
    echo "Unknown ralph-local mode: $MODE" >&2
    usage
    exit 64
    ;;
esac
