# PLAN.md — Approved direction, open items in section 5

**Amended guardrail (supersedes "Cross-Device Sync" in the repo guardrails):** SwiftData is the local store;
cross-device sync is via Firebase through a `SyncService`, not `cloudKitDatabase: .automatic`. Models must still
have default values/optionals, and progress writes must still be throttled/debounced during Read-Aloud.
All other guardrails (Read-Aloud, EPUB/PDF parsers) are unchanged.

Auditor: Claude Code. Implementer: Codex. Do not implement until the "Decisions" section is resolved.

## 1. Audit: what the repo actually is

`Emilio-Guadarrama/epubExtractor` is a fork of `f-meloni/EpubExtractor`: a ~680-line **CocoaPods library**
(Swift 4.2, iOS 8 target) that unzips an `.epub` (SSZipArchive) and parses OPF/NCX/nav (AEXML).
There is a small UIKit example app (`Example/`) that dumps `allContent()` into a `UITextView`.

**Not present (the guardrails describe these, but none exist yet):**
- No SwiftUI, no library/reader UI, no PDFKit/PDF support
- No `AVSpeechSynthesizer`, word highlighting, auto-scroll, Lock Screen / `MPNowPlayingInfoCenter`
- No SwiftData / CloudKit, no progress persistence
- No Android code. A Swift/SwiftUI app cannot run on the Samsung Tab S10+.

So "preserve Read-Aloud" has nothing to preserve yet; Read-Aloud is a feature to be built.

## 2. Library defects found (fix regardless of direction)

| # | File | Issue |
|---|------|-------|
| 1 | `Epub.swift` `identifier` | Returns `metadata[publisherKey]` (copy-paste bug); must use `identifierKey`. |
| 2 | `Epub.swift` `allContent()` | `joined()` with no separator: chapters run together. |
| 3 | `ArchiveExtractor.swift`, `Epub.swift` | `import UIKit` forces UIKit-only; Foundation (+ UIKit only where `NSAttributedString` HTML needs it). |
| 4 | `EpubExtractor.swift` | Callback-based; delegate fires on whatever thread SSZipArchive uses. Needs `async throws` API and `@MainActor`/`Sendable` safety. |
| 5 | `EpubExtractor.swift` | Caller must supply the destination folder; no cleanup. Needs managed per-book Application Support dir. |
| 6 | `EpubParser.swift` | `rootFile()` takes only first `rootfile`; `epubMetaData` loses repeated keys (multiple `dc:creator`); `epubType` uses `Float` parse of version. |
| 7 | `EpubParser.swift` | Unzip path is not validated against zip-slip (confirm SSZipArchive 2.1+ behavior or switch to a maintained unzip). |
| 8 | Podspec / Podfile | Swift 4.2, iOS 8, Quick/Nimble 1.1/5.1 are obsolete. Move to Swift Package Manager, iOS 18. |
| 9 | `Tests/Tests.swift` | 39 lines; effectively no coverage. Needs XCTest/Swift Testing against the bundled sample epubs. |

## 3. Proposed direction (Option A, recommended)

Build a native **SwiftUI reader app for iPhone 15 (and iPad)** on top of a modernized core.

Phase 0 — Modernize core (SPM package, iOS 18, Swift 6 mode, fix items 1–9). Gate: unit tests parse all 9 sample epubs.
Phase 1 — App shell: library grid (`.ultraThinMaterial`, SF Symbols), import via `.fileImporter`, reader view for EPUB (text from spines) and PDF (`PDFKit`).
Phase 2 — Read-Aloud (EPUB implemented, awaiting on-device verification; PDF Read-Aloud is Phase 2b: `PDFPage.string` per page, highlight via `PDFSelection`): `AVSpeechSynthesizer`, `willSpeakRangeOfSpeechString` highlighting, auto-scroll, `AVAudioSession` playback + background mode, `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter`.
Phase 3 — SwiftData + CloudKit: all properties defaulted/optional, no unique constraints, progress writes debounced (≥ 5 s or on pause/stop/scene change, never per utterance callback).

Audit checklist per PR: TTS delegate isolation (`@MainActor`), no audio-session deactivation on interruption without resume, no non-optional/unique SwiftData fields, no per-word persistence.

## 4. Android addition (owner chose "Also Android" for the Samsung Tab S10+)

**Stack: two native apps, one shared spec.** iOS stays SwiftUI/SwiftData per guardrails. Android is a separate
Kotlin + Jetpack Compose app in `android/` (buildable on this Windows machine with Android Studio; tablet-first
adaptive layouts for the Tab S10+, large-screen/two-pane). The iOS Read-Aloud guardrails apply equivalently:

| Concern | iOS | Android |
|---|---|---|
| EPUB parse | modernized `EpubExtractor` | Readium Kotlin toolkit or port of the same OPF/spine logic (decide in Phase A0) |
| PDF | `PDFKit` | `PdfRenderer` (or PdfiumAndroid) |
| TTS | `AVSpeechSynthesizer`, `willSpeakRangeOfSpeechString` | `TextToSpeech` + `UtteranceProgressListener.onRangeStart` |
| Background / lock screen | `AVAudioSession` + `MPNowPlayingInfoCenter` | foreground `MediaSessionService` + `MediaSession` notification |
| Local store | SwiftData | Room |

**Sync problem (needs a decision).** SwiftData + CloudKit only syncs Apple devices; it will never reach the Tab.
Options: (a) CloudKit for iPhone/iPad only, Android local-only; (b) a shared backend (Firebase/Supabase) for
both, with CloudKit dropped or kept only as a backup; (c) iPhone and Tab sync via a simple exported progress
file. Whatever is chosen, the model stays minimal and synced fields are only: book id (hash of file), title,
position (spine index + char offset), updated-at; writes debounced as in Phase 3.

Android phases run in parallel with iOS after Phase 0: A0 spike (EPUB lib choice, TTS range callbacks on Samsung
TTS), A1 library + readers, A2 Read-Aloud + MediaSession, A3 sync.

## 5. Decisions still needed from owner

1. ~~Sync approach~~ **DECIDED and APPROVED by owner: (b) shared backend on Firebase; the CloudKit guardrail is amended as below** (owner approved both). Backend: Firebase (Auth with Sign in with Apple + Google, Firestore with offline persistence; SDKs for both iOS and Android, free tier is ample). Supabase is the alternative. Confirm choice before Phase 3 / A3.
   - **Guardrail conflict:** the repo guardrails mandate SwiftData + `cloudKitDatabase: .automatic`. With a shared backend, CloudKit is not used for sync. Proposed amendment: SwiftData stays as the local store (keep defaults/optionals so CloudKit remains an option), and a `SyncService` protocol pushes/pulls the minimal progress record to Firestore. Debounce rules are unchanged (write on pause/stop/background or at most every 5 s, never per word).
   - Sync scope v1: reading position + book metadata only. Book files are NOT uploaded (copyright, size); each device imports its own copy, matched by content hash.
   - Conflict rule: last-writer-wins on `updatedAt`, server timestamp.
2. **Build machine for iOS:** Xcode needs a Mac. This machine is Windows 11. Is a Mac (or macOS CI) available? Android can be built here.
3. **Apple Developer account** (paid) for CloudKit and on-device installs beyond 7-day free signing.
4. Keep the `EpubExtractor` name/pod API compatibility, or free to break it?
