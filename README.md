# EpubExtractor

An EPUB/PDF reader with Read-Aloud for iPhone and iPad, built on a Swift package that unzips and parses EPUB 2 and EPUB 3 files.
Forked from [f-meloni/EpubExtractor](https://github.com/f-meloni/EpubExtractor) and being rebuilt as a full reader app. An Android app for tablets is planned.

> **Status: work in progress, not yet built or tested.** Phases 0 to 2 were written without access to a Swift toolchain.
> Run `swift test` and build the app on a Mac before relying on any of it. Plan and decisions: [PLAN.md](PLAN.md).

## Features

| | iOS app | Status |
|---|---|---|
| Library grid with covers, import from Files (`.epub`, `.pdf`), delete | SwiftUI + SwiftData | written |
| EPUB reader: contents, text size, saved position | `UITextView` | written |
| PDF reader with saved page | `PDFKit` | written |
| Read-Aloud for EPUB: word and sentence highlighting, auto-scroll, speed, skip by sentence or section | `AVSpeechSynthesizer` | written |
| Background audio and Lock Screen controls | `AVAudioSession`, `MPNowPlayingInfoCenter`, `MPRemoteCommandCenter` | written |
| Read-Aloud for PDF | `PDFKit` | planned (Phase 2b) |
| Cross-device sync (iPhone and Android tablet) | Firebase | planned (Phase 3) |
| Android app | Kotlin + Jetpack Compose | planned |

## Repository layout

```
Package.swift                  Swift package: two libraries, below
Sources/EpubExtractor/         EPUB unzip + parse (AEXML, ZIPFoundation)
Sources/ReadAloudCore/         Text chunking and sentence lookup for Read-Aloud (pure Foundation)
Tests/                         Swift Testing suites, including two real EPUB fixtures
App/                           SwiftUI iOS app (models, services, views)
project.yml                    XcodeGen spec that generates the Xcode project
Example/                       Legacy UIKit demo from upstream (CocoaPods, not buildable); source of the sample EPUBs
PLAN.md                        Audit, roadmap and decisions
```

## Build and run

Requires a Mac with Xcode 16+ (Swift 6, iOS 18 SDK).

```sh
swift test                     # library tests (macOS)

brew install xcodegen
xcodegen                       # generates EpubReader.xcodeproj from project.yml
open EpubReader.xcodeproj      # pick your iPhone or iPad, set a signing team, Run
```

To install on a device you need an Apple ID for signing; a free account works but the install expires after 7 days.
Read-Aloud and Lock Screen controls should be tested on a real device, not only the simulator.

## Using the library

Add the package and import `EpubExtractor`:

```swift
import EpubExtractor

let extractor = EpubExtractor()                        // extracts under Application Support/EpubExtractor
let epub = try await extractor.extract(epubURL: url)   // runs off the calling actor

print(epub.title ?? "", epub.authors)
for spine in epub.spines {
    let text = try epub.content(forSpine: spine)       // thread-safe plain text, ready for text-to-speech
}

// Styled text (WebKit-backed, main actor only):
let attributed = try await MainActor.run { try epub.attributedContent(forSpine: epub.spines[0]) }

// Reopen a book that was extracted earlier, then delete it:
let reopened = try extractor.open(extractedDirectory: epub.epubDirectoryURL)
try extractor.removeExtractedEpub(epub)
```

`ReadAloudCore` exposes `TextChunker.chunks(in:from:maxLength:)`, which splits text into sentence-aligned chunks with UTF-16 ranges,
and `TextChunker.sentenceRange(containing:in:)`.

## Design notes

- **Sync-ready model:** every SwiftData property has a default or is optional and nothing is unique. Sync will go through a Firebase `SyncService`, not CloudKit (decision recorded in PLAN.md), so one backend serves both iOS and Android.
- **Read-Aloud:** text is spoken as a queue of short utterances. This keeps highlighting accurate on long chapters and makes seeking and speed changes cheap. Progress writes are throttled to once per 5 seconds while speaking.
- **Privacy:** book files stay on the device; only reading position and metadata are planned to sync.

## Changes from upstream 0.2.1

- Swift Package Manager instead of CocoaPods; SSZipArchive replaced by ZIPFoundation (rejects zip-slip paths).
- `async throws` extraction replaces `EpubExtractorDelegate`; failed extractions clean up after themselves.
- Fixed `identifier` (returned the publisher), `allContent()` (no separator), the `linear` default and multiple `dc:creator` entries.
- Plain-text extraction no longer needs WebKit or the main thread; `attributedContent(forSpine:)` is `@MainActor`.
- Table of contents lookup uses the spine `toc` attribute and `properties="nav"`; chapter URLs keep their `#fragment`.
- Spine hrefs and `container.xml` paths that escape the extracted folder are rejected.

## License

MIT, see [LICENSE](LICENSE). Original author: f-meloni.
