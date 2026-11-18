# Autonomy policy

## Roles

| Role | Who | Does | Does not |
|---|---|---|---|
| Owner | Emilio | Decides the items in "Owner-only"; supplies accounts and credentials | |
| Architect, auditor, QA | Claude Code | Specs (`PLAN.md`, `DESIGN.md`, issues), reviews diffs and PRs, keeps the decision log | Write production code (from the bootstrap onward) |
| Implementer | Codex | Implements the issue as specified; opens draft PRs; runs tests | Deviate from the audited plan; edit specs |

## Authorized without asking

- Claude: write or update specs and docs, open and answer review comments, run read-only analysis, run `auditor-review`, merge a routine PR (see merge policy), create branches and worktrees for review.
- Codex: everything inside its issue's scope; refactors needed to meet the acceptance criteria; adding tests; adding dependencies already named in the plan.

## Owner-only decisions (consult, do not assume)

- **Costs:** paid accounts, Firebase plan upgrades, CI minutes beyond free tiers, any recurring charge.
- **Credentials and sensitive data:** Firebase config files, signing certificates and keys, API keys. Never committed; never pasted in issues or PRs.
- **Destructive actions:** deleting user data or branches, force-push, rewriting history, dropping a SwiftData/Firestore schema.
- **Legal or commercial claims:** store listing text, privacy policy, DRM or copyright statements, licenses.
- **Identity:** app name, bundle IDs, publisher, icon, accent color.
- **Personal data:** analytics, authentication providers, anything that collects or syncs user data beyond reading position.
- **Public launch:** TestFlight external testing, App Store, Play Store.

## Restrictions in force

1. **Non-negotiable core features** (see `CLAUDE.md`): Read-Aloud with highlighting, auto-scroll and Lock Screen controls; EPUB and PDF parsers. A PR that removes, stubs or regresses any of them is Blocked.
2. **Unverified code:** Phases 0 to 2b were written without a compiler. Until T-00 passes on macOS, nothing built on them is merged.
3. **No secrets in the repository.** Config files for Firebase are git-ignored and documented.
4. **No attribution lines** in commits or PRs.
