# Backlog

Order is priority. Each item becomes an issue from `task-template.md` when it is next. Status: `todo`, `ready` (spec and decisions done), `in progress`, `in review`, `done`.

| ID | Title | Effort | Depends on | Status |
|---|---|---|---|---|
| T-00 | Make Phases 0 to 2b build and pass on macOS (no behavior change) | medium | D-01 | todo |
| T-01 | Design tokens, generated covers, library redesign (grid, list by author, filters, search, sort, Continue shelf) | medium | T-00, D-06 | todo |
| T-02 | Reader chrome (tap to toggle, floating controls, `⋯` menu), themes, typography and settings sheet | high | T-01 | todo |
| T-03 | Book-wide progress % and scrubber ("Section n of N", %) | medium | T-02 | todo |
| T-04 | Mini player, Listen sheet, sleep timer, voice picker | high | T-02 | todo |
| T-05 | Search in book, bookmarks, highlights (models + UI, Contents tabs) | high | T-02, D-11 | todo |
| T-06 | `SyncService` + Firebase (auth, Firestore schema, rules, offline, "not on this device" state) | high | T-00, D-02, D-03, D-10 | todo |
| T-07 | Android spike A0: EPUB library choice, TTS range callbacks on Samsung TTS, MediaSession | high | D-08, D-09 | todo |
| T-08 | Android A1: library and EPUB/PDF readers, tablet layouts | high | T-07 | todo |
| T-09 | Android A2: Read-Aloud with highlighting, foreground media service | high | T-08 | todo |
| T-10 | Android A3: sync client against the T-06 schema | high | T-06, T-09 | todo |
| T-11 | Paged reading mode (true pagination, "Page n of N") | high | T-03, D-07 | todo |

## T-00 sketch (first handoff)

- `swift test` passes on macOS: fix compile errors and wrong assertions in `EpubExtractor` and `ReadAloudCore` and their tests.
- `xcodegen` generates the project; the app builds for the iOS Simulator with Swift 6 strict concurrency, zero warnings that indicate data races.
- Smoke test on a simulator or iPhone: import `Metamorphosis-jackson.epub`, open, Read-Aloud plays with highlighting; import a text PDF, same.
- No behavior or API changes except those required to compile. Every change is listed in the PR with the compiler message that forced it.
- Out of scope: any design change, new feature, dependency upgrade not required to build.

## Notes

- Phases 0, 1, 2 and 2b of `PLAN.md` are already written but unverified; they are the input to T-00, not separate tasks.
- T-01 to T-05 follow `docs/design/DESIGN.md`. T-06 follows `PLAN.md` section 4 and decision D-04.
