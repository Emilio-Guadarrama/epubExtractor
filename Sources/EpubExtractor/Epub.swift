import Foundation

private let titleKey = "dc:title"
private let authorKey = "dc:creator"
private let languageKey = "dc:language"
private let publisherKey = "dc:publisher"
private let identifierKey = "dc:identifier"

public enum EpubType: Sendable {
    case unknown
    case epub2
    case epub3
}

public struct Epub: Sendable {
    /// The URL of the folder that contains all the ePub data.
    public let epubDirectoryURL: URL

    /// The type of the ePub.
    public let type: EpubType

    /// URL to the ePub's cover image.
    public let coverURL: URL?

    /// Every metadata value in document order, keyed by element name (e.g. `dc:creator` may have several).
    public let metadataEntries: [String: [String]]

    /// The first value of each metadata element, keyed by element name.
    public var metadata: [String: String] {
        metadataEntries.compactMapValues(\.first)
    }

    /// The ePub's parsed manifest.
    public let manifest: [String: ManifestItem]

    /// The ePub's parsed guide.
    public let guide: [GuideItem]

    /// The ePub's parsed spine: the ordered list of files that make up the reading order.
    public let spines: [SpineItem]

    public var title: String? { metadataEntries[titleKey]?.first }

    /// All authors (`dc:creator`) in document order.
    public var authors: [String] { metadataEntries[authorKey] ?? [] }

    /// The first author, if any.
    public var author: String? { authors.first }

    public var language: String? { metadataEntries[languageKey]?.first }

    public var publisher: String? { metadataEntries[publisherKey]?.first }

    public var identifier: String? { metadataEntries[identifierKey]?.first }

    /// Table of contents, as a tree of chapters.
    public var chapters: [ChapterItem] {
        epubContentParser.chapters
    }

    /// Index in `spines` of the file a table-of-contents entry points to (its `#fragment` is ignored).
    public func spineIndex(for chapter: ChapterItem) -> Int? {
        let target = chapter.src.standardizedFileURL.path
        return spines.firstIndex { (try? epubContentParser.fileURL(forSpine: $0))?.path == target }
    }

    /// Plain text of one spine item. Thread-safe and suitable for text-to-speech.
    public func content(forSpine spine: SpineItem) throws -> String {
        try epubContentParser.plainText(forSpine: spine)
    }

    /// Styled content of one spine item. HTML import uses WebKit, so this must run on the main actor.
    @MainActor
    public func attributedContent(forSpine spine: SpineItem) throws -> NSAttributedString {
        try epubContentParser.attributedContent(forSpine: spine)
    }

    /// Plain text of the whole book, spine items separated by a blank line.
    public func allContent() throws -> String {
        try spines.map { try epubContentParser.plainText(forSpine: $0) }.joined(separator: "\n\n")
    }

    let epubContentParser: any EpubContentParser

    init(
        epubDirectoryURL: URL,
        type: EpubType,
        coverURL: URL?,
        metadataEntries: [String: [String]],
        manifest: [String: ManifestItem],
        guide: [GuideItem],
        spines: [SpineItem],
        epubContentParser: any EpubContentParser
    ) {
        self.epubDirectoryURL = epubDirectoryURL
        self.type = type
        self.coverURL = coverURL
        self.metadataEntries = metadataEntries
        self.manifest = manifest
        self.guide = guide
        self.spines = spines
        self.epubContentParser = epubContentParser
    }
}
