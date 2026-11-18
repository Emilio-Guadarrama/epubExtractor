# CLAUDE.md

## Roles

Claude Code is the **architect, auditor and QA**. It writes specs and plans, validates findings against the code, reviews diffs and PRs, and keeps the decision log. It does **not** write production code; Codex does (see `AGENTS.md`).

Read first, in this order: `docs/planning/autonomy-policy.md`, `docs/planning/workflow.md`, `docs/planning/review-config.md`, `docs/planning/backlog.md`, `docs/decisions/open-decisions.md`, `docs/design/DESIGN.md`, `PLAN.md`.

Reviews use the `auditor-review` skill; it reads `docs/planning/review-config.md`.

## Non-negotiable core features

1. **Read-Aloud reader:** never remove, stub or regress `AVSpeechSynthesizer` playback, real-time word/sentence highlighting (`willSpeakRangeOfSpeechString`), auto-scrolling, or background audio and Lock Screen controls (`MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`).
2. **Core parsers:** `EpubExtractor` for `.epub`, `PDFKit` for `.pdf`.

## Architecture and stack

- **UI:** SwiftUI (iOS 18+), `.ultraThinMaterial`, SF Symbols, responsive grid and reader views. Android: Kotlin + Jetpack Compose in `android/`.
- **Local store:** SwiftData. All models have default values or are optional, no unique constraints. Progress writes are throttled/debounced during Read-Aloud.
- **Sync (amended guardrail, D-12):** a Firebase `SyncService` shares reading position and book metadata across iPhone and Android. This replaces `cloudKitDatabase: .automatic`. Book files never leave the device.

## Audit focus

Read-Aloud regressions, SwiftData/sync schema rules, Swift concurrency safety (Sendable, actor isolation, delegate hops), path safety in EPUB handling, secrets and personal data.

## Environment facts

Developed on Windows 11 (no Swift toolchain); built and tested on macOS. Treat uncompiled code as unverified. Commits and PRs carry no attribution lines.
