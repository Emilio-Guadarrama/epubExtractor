import Foundation
import AEXML

struct Epub2ContentParser: EpubContentParser {
    let contentsURL: URL
    let rootURL: URL
    let manifest: [String: ManifestItem]
    let chapters: [ChapterItem]

    /// - Parameter tocID: value of the spine's `toc` attribute (manifest id of the NCX file).
    init(manifest: [String: ManifestItem], epubContentsURL: URL, rootURL: URL, tocID: String?) {
        self.manifest = manifest
        self.contentsURL = epubContentsURL
        self.rootURL = rootURL

        let ncx = tocID.flatMap { manifest[$0] }
            ?? manifest["ncx"]
            ?? manifest.values.first { $0.mediaType == "application/x-dtbncx+xml" }

        if let href = ncx?.href {
            self.chapters = Self.parseChapters(ncxURL: epubContentsURL.resolvingEpubHref(href))
        } else {
            self.chapters = []
        }
    }

    private static func parseChapters(ncxURL: URL) -> [ChapterItem] {
        // Chapter srcs are relative to the NCX document, not the OPF.
        let epubContentsURL = ncxURL.deletingLastPathComponent()
        guard let contentData = try? Data(contentsOf: ncxURL),
            let contentDocument = try? AEXMLDocument(xml: contentData) else {
                return []
        }

        var chapters: [Epub2ChapterItem] = []

        for chapterElement in contentDocument.root["navMap"].children {
            if let chapter = Epub2ChapterItem(xmlElement: chapterElement, epubContentsURL: epubContentsURL) {
                chapters.append(chapter)
            }
        }

        chapters.sort { $0.playOrder < $1.playOrder }

        return chapters
    }
}
