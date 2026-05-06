# Project-local Ralph runtime bootstrap

Use this when a repo has local Ralph PRDs/tasks but no `.agents/skills/ralph-local/` runtime yet.

## Trigger

- `docs/roadmap/prds/` and `docs/roadmap/tasks/` exist, or the user wants local Ralph execution.
- `.agents/skills/ralph-local/` is missing.
- The documented command `.agents/skills/ralph-local/ralph-local.sh ...` would otherwise be fake.

## Bootstrap

From the project root:

```bash
mkdir -p .agents/skills
cp -a /home/hermes/.hermes/skills/ralph/ralph-local .agents/skills/ralph-local
chmod +x \
  .agents/skills/ralph-local/ralph-local.sh \
  .agents/skills/ralph-local/ralph-once.sh \
  .agents/skills/ralph-local/afk-ralph.sh \
  .agents/skills/ralph-local/task-queue.mjs \
  .agents/skills/ralph-local/coderabbit-review.mjs
```

If copying from the canonical skill directory, keep the project-local `model.env` with the scripts so defaults remain centralized and repo-runnable.

## Verification

```bash
bash -n .agents/skills/ralph-local/ralph-local.sh
bash -n .agents/skills/ralph-local/ralph-once.sh
bash -n .agents/skills/ralph-local/afk-ralph.sh
bash -n .agents/skills/ralph-local/model.env
node --check .agents/skills/ralph-local/task-queue.mjs
node --check .agents/skills/ralph-local/coderabbit-review.mjs
.agents/skills/ralph-local/task-queue.mjs summary <prd-ref>
.agents/skills/ralph-local/task-queue.mjs next-task <prd-ref>
```

Expected result: syntax checks pass, summary lists PRD-owned tasks, and `next-task` prints the first pending unblocked task.

## Pitfall

Do not start implementation as part of bootstrap. Stop after verification and recommend once mode:

```bash
.agents/skills/ralph-local/ralph-local.sh <prd-ref> once <task-id>
```

Run AFK only after the first slice proves the task granularity and prompt behavior.