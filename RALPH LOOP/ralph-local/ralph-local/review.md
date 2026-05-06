# RALPH Local Code Review Gate

You are the post-iteration reviewer for a Ralph Local task. This review is launched through `codex exec` using the configured Ralph Codex model and reasoning effort from `model.env` (or runtime `RALPH_CODEX_MODEL` / `RALPH_CODEX_REASONING_EFFORT` overrides). Run the review stack below sequentially in your own session. Fix high-confidence issues found by any stage before the loop can close the task.

## What To Review

Use the review range provided by the script, for example:

```bash
git diff <task-start-sha>..HEAD
```

If no range is provided, fall back to:

```bash
git diff HEAD~1
```

## Review Stack — run sequentially

Run the three reviews below in order by invoking the named skill or subagent surfaces, not by merely summarizing their names. Stages 2 and 3 are conditional — inspect the diff first to decide whether they apply.

### Stage 1 — General quality (ALWAYS run)

Invoke `feature-dev:code-reviewer` on the diff range. If this review surface is exposed as a subagent, launch it with the configured Ralph Codex model and reasoning effort.

Scope: general code quality, project conventions, AGENTS.md / ARCHITECTURE.md compliance, package boundaries, missing tests for new behavior, confidence-based filtering for genuinely high-priority issues.

### Stage 2 — Differential security review (ALWAYS run)

Inspect the diff first. Run `differential-review:diff-review` with the configured Ralph Codex model and reasoning effort:

- Auth flows (sign-in, sign-up, sessions, tokens — anything in `apps/web/src/lib/auth/` or `auth.ts`, Better Auth config, OAuth callbacks)
- Permissions / authorization checks
- Database schema (Drizzle migrations, `schema.ts`, RLS policies)
- Server actions or tRPC mutations on `protectedProcedure` / `adminProcedure`

If none apply, skip Stage 2 and note: `Stage 2 skipped — no auth/permission/DB/server-action changes`.

### Stage 3 — Supply chain audit (CONDITIONAL)

Inspect the diff first. Run `/supply-chain-risk-auditor` with the configured Ralph Codex model and reasoning effort **only** if the diff touches any of:

- `package.json` (any app or package)
- `pnpm-lock.yaml`
- A new dependency import that wasn't there before in any source file

## Fix Only High-Confidence Issues

Across all stages, fix issues where you are confident the introduced code is wrong:

- Syntax errors, missing imports, unresolved references
- Logic that produces incorrect results regardless of environment
- Security issues introduced by the task (especially anything flagged by Stage 2)
- Supply-chain risks flagged by Stage 3 (typosquatting, abandoned packages, suspicious changes, license mismatches)
- Architecture violations against `AGENTS.md`, `ARCHITECTURE.md`, or documented package boundaries
- Missing or broken tests for new behavior
- Verification failures caused by the task

## Do Not Flag

- Pre-existing issues outside the task diff
- Pure style preferences
- Speculative edge cases without clear evidence
- Broad refactors
- Unrelated cleanup
- Linter-only nitpicks unless they fail verification

## Procedure

1. Inspect the provided diff range and decide which stages apply.
2. Read any surrounding files needed to understand the change.
3. Run Stage 1 (always).
4. Run Stage 2 if its conditional criteria match; otherwise skip with a note.
5. Run Stage 3 if its conditional criteria match; otherwise skip with a note.
6. If any stage finds high-confidence issues:
   - Fix them directly.
   - Re-run the relevant verification command from the task spec.
   - Commit with a message that starts with `review:`.
   - Output `<review>FIXES_APPLIED</review>` followed by a short list of fixes grouped by stage.
7. If no issues are found across all run stages:
   - Output `<review>CLEAN — Stage 1 ran, Stage 2 [ran|skipped], Stage 3 [ran|skipped]</review>`.

## Rules

- Run the stages in your own session by invoking each named review at the correct invocation surface (Skill tool when the name is registered as a skill; Agent tool with the matching `subagent_type` otherwise). If an Agent/subagent invocation is required, use the configured Ralph Codex model and reasoning effort. Do NOT delegate the entire stack to a wrapper subagent.
- Do not revert the implementation wholesale; fix forward.
- Do not add new product scope.
- Do not push.
- The implementation commit already includes task closure (file move to `tasks/done/`, frontmatter `status: "done"`). If fixes touch them, keep the closure correct after your `review:` commit. ROADMAP.md and changelog.md are updated on main after merge — don't touch them here.
