---
name: to-issues
description: Break a plan, spec, or PRD into independently-grabbable GitHub issues using tracer-bullet vertical slices. Use when user wants to convert a plan into issues, create implementation tickets, or break down work into issues.
---

# To Issues

Break a plan into independently-grabbable GitHub issues using vertical slices (tracer bullets).

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes a GitHub issue number or URL as an argument, fetch it with `gh issue view <number>` (with comments).

Extract the parent PRD's **phase ID** (`prd-<phase.sequence>`):
- If the source is a local PRD file under `docs/roadmap/prds/`, read the frontmatter `id` field.
- If the source is a GitHub issue, parse the title prefix (e.g. `[12.5] ...` → phase id `prd-12.5`) or read the linked local PRD.
- If no phase ID is found, **stop and ask the user** for one in the form `prd-<phase.sequence>`. Sub-issue task IDs derive from this: `<phase.sequence>.1`, `<phase.sequence>.2`, …

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code.

### 3. Draft vertical slices

Break the plan into **tracer bullet** issues. Each issue is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

Slices may be 'HITL' or 'AFK'. HITL slices require human interaction, such as an architectural decision or a design review. AFK slices can be implemented and merged without human interaction. Prefer AFK over HITL where possible.

<vertical-slice-rules>
- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests)
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones
</vertical-slice-rules>

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each slice, show:

- **Title**: short descriptive name
- **Type**: HITL / AFK
- **Blocked by**: which other slices (if any) must complete first
- **User stories covered**: which user stories this addresses (if the source material has them)

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the dependency relationships correct?
- Should any slices be merged or split further?
- Are the correct slices marked as HITL and AFK?

Iterate until the user approves the breakdown.

### 5. Create the GitHub issues

For each approved slice, create a GitHub issue using `gh issue create`. Use the issue title format and body template below.

Title format: `<phase.sequence>.<n>: <short slice description>` (e.g. `12.5.1: Schema foundation + domain dedup`). The `<n>` is 1-indexed in the order slices were approved in step 4.

Create issues in dependency order (blockers first) so you can reference real issue numbers in the "Blocked by" field.

<issue-template>
## Parent PRD

#<parent-issue-number> (if the source was a GitHub issue, otherwise omit this section)

## What to build

A concise description of this vertical slice. Describe the end-to-end behavior, not layer-by-layer implementation.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Blocked by

- Blocked by #<issue-number> (if any)

Or "None - can start immediately" if no blockers.

</issue-template>

Do NOT close or modify any parent issue.

### 6. Append the new phase block to ROADMAP.md

After all sub-issues are created, register them in `docs/roadmap/ROADMAP.md` so they appear in the same view as ralph-local tasks.

Ask the user **once** where to insert the new phase block:

> Where should the new phase block go in `ROADMAP.md`? (paste a line of context, an existing phase heading like "## Phase 13: Scan Intelligence", or "end of file")

Then append a phase block at the chosen location:

```markdown
### Phase <phase.sequence>: <PRD title> [PRD: #<parent-issue-number>]

- [ ] [<phase.sequence>.1 <slice 1 title>](https://github.com/<owner>/<repo>/issues/<issue-1-number>)
- [ ] [<phase.sequence>.2 <slice 2 title>](https://github.com/<owner>/<repo>/issues/<issue-2-number>)
- ...
```

Notes:
- `[ ]` initially. The `[x]` flip happens post-merge per AGENTS.md step 11 (registry-on-main convention) — same as ralph-local tasks.
- Link target is the GitHub issue URL, not a local file (this is the GitHub flow). For ralph-local tasks the link target is `tasks/<id>-*.md` instead.
- If a `### Phase <phase.sequence>:` heading already exists in ROADMAP.md, **stop and ask the user** how to handle the collision (merge entries, pick a different phase id, etc.) rather than overwriting silently.

Commit the ROADMAP update directly on main with message `roadmap: register PRD #<parent-issue-number> sub-issues as <phase.sequence>.x`. Do not include the ROADMAP edit in the implementation PR — registry edits belong on main per AGENTS.md.
