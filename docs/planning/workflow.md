# Workflow: auditor / implementer

Two agents, one owner. Claude Code is the architect, auditor and QA. Codex implements. The owner decides what only the owner can decide (see `autonomy-policy.md`).

## Handoff for each task

1. **Finding or need** is written in `backlog.md` (ID `T-xx`).
2. **Validation:** Claude confirms it against the code and `docs/design/DESIGN.md`, and resolves or lists blocking decisions in `docs/decisions/open-decisions.md`.
3. **Issue** is created from `task-template.md` (only when the owner asks for issues to be created) with verifiable acceptance criteria.
4. **Branch and worktree per task:** `task/T-xx-short-name`, cut from `master`. One task, one branch, one worktree. Never two writers on the same files.
5. **Draft PR** is opened early by Codex; the description is one page: what changed, how it was verified, what was not verified.
6. **Tests:** targeted tests while working, full suite once at the end (commands in `review-config.md`).
7. **Review:** Claude runs `auditor-review` and writes `docs/reviews/T-xx-review.md` with a verdict.
8. **Approval:** merge only per the merge policy in `review-config.md`.

## Rules

- Claude does not edit the implementer's production code. Findings go in the review as file, line, failure scenario and required change.
- Codex does not change `PLAN.md`, `docs/design/DESIGN.md` or `review-config.md`. If a spec is wrong, Codex stops and says so in the PR; Claude updates the spec.
- Branches: `master` is protected by convention (no direct pushes of feature work, no force-push). Commit and push often on the task branch.
- No attribution lines (no `Co-Authored-By`, no "Generated with" footers) in commits or PRs.
- This repository is developed on Windows and built on macOS. Anything that has not been compiled and run is reported as unverified, never as done.

## Consumo eficiente (efficient use)

- One fresh chat per task, with only the issue, this handoff and the files to touch.
- Effort by task type: mechanical low, normal medium, hard high (Read-Aloud, concurrency, sync).
- Targeted tests while working; full suite once at the end.
- Screenshots only where the issue requires them.
- Handoff and PR description: one page.
