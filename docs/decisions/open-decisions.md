# Decisions

`open` needs the owner. `decided` is recorded for the auditor and implementer.

| ID | Decision | Status | Blocks | Default if unanswered |
|---|---|---|---|---|
| D-01 | Where does iOS get built and tested: a Mac the owner or Codex can use, or macOS CI (e.g. GitHub Actions `macos-latest`)? | **open** | T-00 and everything on iOS | Nothing iOS-side proceeds; Android spike (T-07) can start in parallel |
| D-02 | Paid Apple Developer Program account (installs beyond 7 days, TestFlight, Sign in with Apple) | **open** | T-06 on device, any distribution | Free signing, 7-day installs |
| D-03 | Firebase project, owner of the console, plan (Spark free vs Blaze). Config files stay out of git | **open** | T-06, T-10 | Spark |
| D-04 | Shared backend for sync: Firebase (Firestore + Auth) instead of CloudKit; SwiftData stays local | **decided** (owner) | | |
| D-05 | Keep `EpubExtractor` public API compatible with upstream 0.2.1? | **open** | | No; API already changed (async, no delegate) |
| D-06 | Identity: app name, bundle ID prefix (placeholder `app.epubreader`), accent color (proposed: amber) | **open** | T-01 visuals, release | Placeholders |
| D-07 | Pagination: scroll-per-section for v1 (progress %), paged mode later as T-11 | proposed | T-11 | As proposed |
| D-08 | Android EPUB parsing: Readium Kotlin toolkit vs porting this library's logic | **open** | T-07 | Decide from the A0 spike |
| D-09 | Android UI: Jetpack Compose (Material 3, adaptive layouts) | proposed | T-07 | Compose |
| D-10 | Sync authentication: Sign in with Apple + Google (Apple login required on iOS if any other social login is offered) | **open** | T-06 | Both |
| D-11 | Highlights and bookmarks sync: offsets only, or also the highlighted text (copyright and privacy) | **open** | T-05, T-06 | Offsets only |
| D-12 | Guardrail amendment: SwiftData local store + Firebase `SyncService` replaces `cloudKitDatabase: .automatic`; defaults/optionals and throttled writes still required | **decided** (owner) | | |
