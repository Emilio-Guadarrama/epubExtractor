import Foundation
import AEXML

struct Epub3ChapterItem: ChapterItem {
    let src: URL
    let label: String?
    let subChapters: [ChapterItem]

    init?(xmlElement: AEXMLElement, epubContentsURL: URL) {
        let aElement = xmlElement["a"]

        guard let srcString = aElement.attributes["href"] else {
            return nil
        }

        self.src = epubContentsURL.resolvingEpubHref(srcString)
        self.label = aElement.value

        var subChapters: [Epub3ChapterItem] = []

        for subChapterElement in xmlElement["ol"]["li"].all ?? [] {
            if let subChapter = Epub3ChapterItem(xmlElement: subChapterElement, epubContentsURL: epubContentsURL) {
                subChapters.append(subChapter)
            }
        }

        self.subChapters = subChapters
    }
}
