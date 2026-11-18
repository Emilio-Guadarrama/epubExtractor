# Review configuration (read by `auditor-review`)

## Immutable or read-only paths

- `LICENSE`
- `Tests/EpubExtractorTests/Fixtures/` (sample EPUBs; add new fixtures, never edit existing ones)
- `docs/reviews/` (written only by the auditor)
- `docs/planning/review-config.md`, `docs/design/DESIGN.md`, `PLAN.md` (changed only by the auditor)

## Commands

Full suite (macOS, run once at the end of a task):

```sh
swift test
xcodegen
xcodebuild -project EpubReader.xcodeproj -scheme EpubReader -destination 'platform=iOS Simulator,name=iPhone 15' build
```

Targeted:

```sh
swift test --filter ReadAloudCoreTests
swift test --filter EpubExtractorTests
```

Android (from T-07 on): `./gradlew test` in `android/`; instrumented tests only when the issue requires them.

A PR is not "verified" unless these ran on macOS and passed. State exactly which ran.

## Verdicts

- **Approved (Aprobado):** acceptance criteria met, invariants hold, suite green.
- **Changes required (Cambios requeridos):** list each finding as file, line, failure scenario, required change.
- **Blocked by decision (Bloqueado por decisión):** needs an owner decision; name the D-xx.

## Merge policy

Claude may merge a PR into `master` without asking when: verdict is Approved, the full suite is green on macOS, the PR touches no owner-only area (see `autonomy-policy.md`), and it changes no non-negotiable feature. Everything else waits for the owner. Squash-merge; no attribution lines.

## Project quality rules (checked on every PR)

**Read-Aloud and playback**
- `AVSpeechSynthesizerDelegate` callbacks stay non-isolated and hop to the main actor with Sendable payloads only; no non-Sendable value (utterance, notification) crosses an actor boundary.
- `state` is set before `startSpeaking` (it can finish synchronously); stale utterance callbacks are ignored by identity.
- Highlighting uses `willSpeakRangeOfSpeechString`; ranges are UTF-16 and global to the loaded text.
- Background audio (`UIBackgroundModes: audio`), `AVAudioSession` playback/spokenAudio, interruption and route-change handling, `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` stay intact; targets are removed in `shutdown()`.
- Auto-scroll yields to manual scrolling.

**Data and sync**
- Every SwiftData property has a default or is optional; no `@Attribute(.unique)`; keep models CloudKit-compatible.
- Progress writes are throttled (at most every 5 s while speaking; immediate on pause, stop, background, leave). No per-word writes, locally or to Firestore.
- Sync uploads reading position and book metadata only; never book files. Highlights sync as offsets, not copyrighted text, unless D-11 says otherwise.
- No secrets, tokens or personal data in code, logs, tests or screenshots.

**Swift quality**
- Swift 6 language mode, no `@unchecked Sendable` or `nonisolated(unsafe)` without a comment explaining why it is safe.
- No force-unwraps or `try!` outside tests (the one `fatalError` for container creation is the only allowed exception).
- Pure logic lives in packages (`EpubExtractor`, `ReadAloudCore`) with tests; UI code stays thin.
- Paths inside books are never trusted: resolved hrefs must stay inside the extracted folder.

**UI**
- Follows `docs/design/DESIGN.md`. Required screenshots per issue only: iPhone 15 and one iPad size, light and dark where the issue says so.

## Reviews folder

`docs/reviews/T-xx-review.md`, one file per PR, containing verdict, findings, what was verified and what was not.
