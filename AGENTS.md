# AGENTS.md

You are the **implementer** (Codex). Claude Code is the auditor: it writes the plan and reviews your PRs. Implement exactly what the issue says; do not deviate from the audited plan. If the spec is wrong or blocked, stop and say so in the PR.

Read first: your issue, `docs/planning/workflow.md`, `docs/planning/review-config.md`, and only the files the issue lists. `docs/design/DESIGN.md` for UI work.

## Inviolable rules

1. **Never remove, stub or regress Read-Aloud:** `AVSpeechSynthesizer` playback, word/sentence highlighting via `willSpeakRangeOfSpeechString`, auto-scroll, background audio, Lock Screen controls.
2. Keep `EpubExtractor` for EPUB and `PDFKit` for PDF.
3. SwiftData models: defaults or optionals on every property, no unique constraints. Throttle progress writes (at most every 5 s while speaking; immediate on pause, stop, background, leave).
4. Sync is Firebase via `SyncService`, not CloudKit. Never upload book files. Never commit secrets or Firebase config files.
5. Swift 6 language mode. No `@unchecked Sendable` or `nonisolated(unsafe)` without a comment explaining why it is safe. Delegate callbacks hop to the main actor with Sendable payloads.
6. Do not edit `PLAN.md`, `docs/design/DESIGN.md`, `docs/planning/review-config.md`, `docs/reviews/`, `LICENSE`, or existing fixtures.
7. No `Co-Authored-By`, no "Generated with" lines in commits or PR descriptions.

## What you deliver in each PR

- Branch `task/T-xx-short-name` from `master`, draft PR opened early, description one page: what changed, how verified, what is **not** verified.
- Tests for new logic (pure logic lives in `Sources/EpubExtractor` or `Sources/ReadAloudCore`).
- The commands from `review-config.md` run on macOS, with results. Required screenshots only.
- `docs/CHANGELOG.md` entry and any README update the issue names.

## Build and test

```sh
swift test
xcodegen && xcodebuild -project EpubReader.xcodeproj -scheme EpubReader -destination 'platform=iOS Simulator,name=iPhone 15' build
```

## Consumo eficiente

One fresh chat per task with only the issue, the handoff and the files to touch. Effort by task type: mechanical low, normal medium, hard high. Targeted tests while working, full suite once at the end. Screenshots only when required. Handoff and PR one page. Commit and push often.
