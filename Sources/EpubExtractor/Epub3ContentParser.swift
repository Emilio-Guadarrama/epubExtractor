import Foundation
import AEXML

struct Epub3ContentParser: EpubContentParser {
    let contentsURL: URL
    let rootURL: URL
    let manifest: [String: ManifestItem]
    let chapters: [ChapterItem]

    init(manifest: [String: ManifestItem], epubContentsURL: URL, rootURL: URL) {
        self.manifest = manifest
        self.contentsURL = epubContentsURL
        self.rootURL = rootURL

        let nav = manifest.values.first { $0.properties.contains("nav") }
            ?? manifest["nav"] ?? manifest["toc"] ?? manifest["htmltoc"]

        if let href = nav?.href {
            self.chapters = Self.parseChapters(navURL: epubContentsURL.resolvingEpubHref(href))
        } else {
            self.chapters = []
        }
    }

    private static func parseChapters(navURL: URL) -> [ChapterItem] {
        // Chapter hrefs are relative to the nav document, not the OPF.
        let navDirectory = navURL.deletingLastPathComponent()
        guard let contentData = try? Data(contentsOf: navURL),
            let contentDocument = try? AEXMLDocument(xml: contentData) else {
                return []
        }

        var chapters: [ChapterItem] = []

        let body = contentDocument.root["body"]
        let navItems = (body["nav"].all?.count ?? 0) > 0 ? body["nav"] : body["section"]["nav"]

        if let tocElement = navItems.all(withAttributes: ["epub:type": "toc"])?.first {
            for chapterElement in tocElement["ol"]["li"].all ?? [] {
                if let chapter = Epub3ChapterItem(xmlElement: chapterElement, epubContentsURL: navDirectory) {
                    chapters.append(chapter)
                }
            }
        }

        return chapters
    }
}
