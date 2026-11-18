# EpubExtractor

Swift package that unzips and parses EPUB 2 / EPUB 3 files. Requires Swift 6, iOS 18+ / macOS 15+.
Dependencies: [AEXML](https://github.com/tadija/AEXML), [ZIPFoundation](https://github.com/weichsel/ZIPFoundation).

> This fork is being modernized as the core of a reader app; see [PLAN.md](PLAN.md).
> The `Example/` UIKit demo still targets the old CocoaPods setup and is not buildable; the SwiftUI app in `App/` replaces it.

## Reader app (iOS 18+, iPhone and iPad)

SwiftUI app in `App/`: library grid, import of `.epub`/`.pdf` via the Files picker, EPUB reader (text, contents, text size) and PDF reader (`PDFKit`). Library data is stored locally with SwiftData. Read-Aloud is Phase 2.
Requires a Mac with Xcode 16+:

```sh
brew install xcodegen
xcodegen                      # generates EpubReader.xcodeproj from project.yml
open EpubReader.xcodeproj
```

Run the library tests with `swift test` (macOS) or from Xcode.

## Usage

```swift
import EpubExtractor

let extractor = EpubExtractor()                       // extracts under Application Support/EpubExtractor
let epub = try await extractor.extract(epubURL: url)  // runs off the calling actor

print(epub.title ?? "", epub.authors)
for spine in epub.spines {
    let text = try epub.content(forSpine: spine)     // thread-safe plain text, ready for text-to-speech
}

// Styled text (WebKit-backed, main actor only):
let attributed = try await MainActor.run { try epub.attributedContent(forSpine: epub.spines[0]) }

try extractor.removeExtractedEpub(epub)
```

## Changes from upstream 0.2.1

- Swift Package Manager instead of CocoaPods; SSZipArchive replaced by ZIPFoundation (rejects zip-slip paths).
- `async throws` extraction replaces `EpubExtractorDelegate`; failed extractions clean up after themselves.
- Fixed `identifier` (returned the publisher), `allContent()` (no separator), `linear` default, multiple `dc:creator`.
- Plain-text extraction no longer needs WebKit or the main thread; `attributedContent(forSpine:)` is `@MainActor`.
- TOC/NCX/nav lookup uses the spine `toc` attribute and `properties="nav"`; chapter URLs keep `#fragments`.
- Spine hrefs and `container.xml` paths that escape the extracted folder are rejected.

## License

MIT, see LICENSE. Original author: f-meloni.
