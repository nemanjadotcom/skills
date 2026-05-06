# RALPH Local Iteration Instructions

You are running inside a Ralph Local loop: an autonomous implementation cycle driven by one PRD and the local task specs listed by that PRD.

The orchestrator has already selected exactly one runnable task and marked it `in-progress`. Your job is to implement only that selected task, verify it, and commit the implementation. The script will run the review gate afterward and will mark the task `done` only after review passes.

## Scope Rules

1. **One task per iteration.** Work only on the selected task in the context below. Do not implement sibling tasks, even if they are nearby.

2. **The PRD task list is the source of truth.** Only tasks listed in the PRD's Ralph task block are in scope for this PRD.

3. **Dependency rule.** A task is blocked when any id in `depends_on` is not `done` among the PRD-listed tasks. The orchestrator already checked this before selecting the task.

4. **Task closure (in implementation commit):** (a) move task spec to `docs/roadmap/tasks/done/`; (b) set frontmatter `status: "done"`. PRD is never modified. **Do NOT touch `docs/changelog.md` or `docs/roadmap/ROADMAP.md`** — those are updated on main after merge.

## Implementation Workflow

Use TDD when the task contains behavior that can be tested.

1. **Plan behaviors.** Before writing code, list the concrete behaviors this task requires and the public interface each behavior should exercise.

2. **RED: write one failing test.** Add one behavior test through the public interface. Run the focused test and confirm it fails for the expected reason.

3. **GREEN: write minimal code.** Implement only enough to pass that test. Run the focused test and confirm it passes.

4. **Repeat one behavior at a time.** Continue red-green cycles until the task's acceptance criteria are covered.

5. **REFACTOR after green.** Only refactor after all tests are passing. Keep refactors limited to what the selected task needs.

When TDD does not apply, such as pure scaffolding, configuration, or documentation-only work, implement directly and explain why behavior tests were not appropriate.

## Verification

Run the verification steps from the selected task spec whenever possible. If the task does not name commands, detect the right checks from the repository configuration and docs.

Common defaults:

- Node.js/TypeScript: `pnpm run rebuild`, package-specific tests when present
- Python: `python3 -m pytest`
- Rust: `cargo test`
- Go: `go test ./...`

Do not commit with failing checks. If a failure is unrelated to your task and blocks progress, stop and report it clearly.

## Commit Rules

- Make a git commit for the implementation before returning.
- The commit message must start with the selected task id, for example: `4.86.1: add cap table sidebar routes`.
- Do not include unrelated changes.
- Do not push. The AFK script pushes only after all PRD tasks are complete.

## Quality Standards

Follow root `AGENTS.md`, app/package `ARCHITECTURE.md`, root `DESIGN.md` when touching web/UI, and any docs listed in the selected task's "Read First" section. Match existing code style, naming, and boundaries.

## Do Not

- Do not work on tasks outside the selected task.
- Do not add features not requested by the PRD or task.
- Do not mock internal modules; mock only external boundaries.
- Do not test private implementation details.
- Do not refactor unrelated code.
- Do not skip verification.
- Do not push.
- Do not open or merge a PR.
