import Foundation

enum EpubContentError: Error, Equatable {
    case spineFileNotFound(String)
    case fileOutsideEpub(String)
    case unreadableContent(String)
}

protocol EpubContentParser: Sendable {
    /// Directory containing the OPF file; manifest hrefs are relative to it.
    var contentsURL: URL { get }
    /// Directory the whole ePub was extracted to; resolved files must stay inside it.
    var rootURL: URL { get }
    var chapters: [ChapterItem] { get }
    var manifest: [String: ManifestItem] { get }
}

extension EpubContentParser {
    func fileURL(forSpine spine: SpineItem) throws -> URL {
        guard let href = manifest[spine.idRef]?.href else {
            throw EpubContentError.spineFileNotFound(spine.idRef)
        }
        let url = contentsURL.resolvingEpubHref(href)
        let rootPath = rootURL.standardizedFileURL.path
        guard url.path == rootPath || url.path.hasPrefix(rootPath + "/") else {
            throw EpubContentError.fileOutsideEpub(href)
        }
        return url
    }

    func plainText(forSpine spine: SpineItem) throws -> String {
        let url = try fileURL(forSpine: spine)
        let data = try Data(contentsOf: url)
        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw EpubContentError.unreadableContent(spine.idRef)
        }
        return PlainTextExtractor.text(fromHTML: html)
    }
}
