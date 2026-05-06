# Ralph Local Model Configuration

Session learning: Ralph Local used to hardcode model names in multiple scripts and review prompts. The stable pattern is to keep human-editable defaults in one shell-sourcable config file, then let runtime environment variables override them.

## Files

- `model.env` — single place for defaults:
  - `RALPH_DEFAULT_CODEX_MODEL`
  - `RALPH_DEFAULT_CODEX_REASONING_EFFORT`
  - `RALPH_DEFAULT_MAX_REVIEW_ITERATIONS`
- `ralph-once.sh` — sources `model.env`, then computes `CODEX_MODEL` and `CODEX_REASONING_EFFORT`.
- `afk-ralph.sh` — sources `model.env`, then computes `CODEX_MODEL`, `CODEX_REASONING_EFFORT`, and `MAX_REVIEW_ITERATIONS`.
- `review.md` / `SKILL.md` — should describe the configured Ralph model/effort, not literal model names that go stale.

## Resolution Order

For model:

```bash
CODEX_MODEL="${RALPH_CODEX_MODEL:-${RALPH_DEFAULT_CODEX_MODEL:-gpt-5.5}}"
```

For reasoning effort:

```bash
CODEX_REASONING_EFFORT="${RALPH_CODEX_REASONING_EFFORT:-${RALPH_DEFAULT_CODEX_REASONING_EFFORT:-low}}"
```

For CodeRabbit review loop cap:

```bash
MAX_REVIEW_ITERATIONS="${RALPH_MAX_REVIEW_ITERATIONS:-${RALPH_DEFAULT_MAX_REVIEW_ITERATIONS:-10}}"
```

This gives three layers:

1. Runtime env var wins for one-off runs.
2. `model.env` controls normal defaults.
3. Built-in fallback keeps old behavior if `model.env` is missing.

## Verification

Run from the Ralph local skill directory:

```bash
bash -n ralph-once.sh
bash -n afk-ralph.sh
bash -n model.env
grep -RInE 'gpt-5\\.5|low' .
```

Expected grep result: literal `gpt-5.5` / `low` should appear only in `model.env` defaults and script fallback expressions, not prose instructions in `SKILL.md` or `review.md`.

When a Ralph process is already running, changing `model.env` does **not** affect that process. Verify the active Codex child directly:

```bash
ps -eo pid,ppid,stat,args | grep -E 'ralph-once\.sh|ralph-local\.sh|codex exec' | grep -v grep
```

Look for the actual `codex exec --model ...` argument. If it still shows the old model, stop/restart the Ralph run; do not claim the current task is using the new model until the child process confirms it.

If you terminate a stale `once` run before Codex commits, inspect the PRD worktree first. A common partial state is only the selected task frontmatter changed from `pending` to `in-progress`; reset it to `pending` before restarting so the task queue can select it cleanly.

## Pitfall

Do not move these defaults into a Markdown file. Shell scripts need config they can source directly; Markdown config is theater with extra parsing bugs.

Do not assume a model switch applies retroactively. Ralph passes the model to Codex at process launch; old child processes keep their original `--model` flag until killed or completed.