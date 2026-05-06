# Claude Skills

A public collection of Claude Code skills and reusable agent workflows.

---

## Skills

### Design

- `design-brand-kit`
  - Generate brand systems, visual directions, typography ideas, color palettes, and presentation-style layouts.

### Planning

- `grill-me`
  - Stress-test a product idea or implementation plan with focused questions before execution.

- `shape`
  - Turn a rough idea into a complete PRD by auto-answering the product and engineering decision tree.

- `to-prd`
  - Convert conversation context or a plan into a PRD suitable for implementation.

- `to-issues`
  - Break a PRD into independently grabbable GitHub issues using vertical slices.

### Ralph

- `ralph`
  - Autonomous PRD implementation loop for GitHub issue-based workflows.
  - Includes Claude and Codex variants.

- `ralph-local`
  - Local PRD implementation loop using `docs/roadmap/prds/` and `docs/roadmap/tasks/` instead of GitHub issues for task selection.

- `prd-to-tasks`
  - Convert a local PRD into Ralph Local task specs.

---

## General

- `ask-questions-if-underspecified` - https://github.com/trailofbits/skills/tree/main/plugins/ask-questions-if-underspecified
  - Forces clarification when requirements are vague or incomplete before execution.

---

## Disclaimer

Always inspect skills before using them.

Skills may contain unsafe prompts, shell commands, automation logic, or malicious instructions.

Do not blindly trust or execute skills from the internet.

Review everything manually before use.

---

## License

MIT
