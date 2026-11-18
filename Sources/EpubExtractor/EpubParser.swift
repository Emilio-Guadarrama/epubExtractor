import Foundation
import AEXML

public enum EpubParseError: Error, Equatable, Sendable {
    case rootFileNotFound
    case rootFileNotValid
    case unknownEpubType
}

struct EpubParser {
    func parseEpub(epubDirectoryURL: URL) throws -> Epub {
        let rootDirectory = epubDirectoryURL.standardizedFileURL

        guard let rootFileURL = self.rootFile(epubDirectoryURL: rootDirectory) else {
            throw EpubParseError.rootFileNotFound
        }

        guard let data = try? Data(contentsOf: rootFileURL),
            let rootDocument = try? AEXMLDocument(xml: data) else {
                throw EpubParseError.rootFileNotValid
        }

        let epubType = self.epubType(rootDocument: rootDocument)

        guard epubType != .unknown else {
            throw EpubParseError.unknownEpubType
        }

        let contentsURL = rootFileURL.deletingLastPathComponent()
        let metadata = self.epubMetaData(rootDocument: rootDocument)
        let manifest = self.manifest(rootDocument: rootDocument)
        let coverURL = self.epubCoverURL(rootDocument: rootDocument, manifest: manifest, contentDirectoryURL: contentsURL)
        let guide = self.guide(rootDocument: rootDocument)
        let spines = self.spine(rootDocument: rootDocument, manifest: manifest)

        let epubContentParser: any EpubContentParser
        if epubType == .epub2 {
            epubContentParser = Epub2ContentParser(
                manifest: manifest,
                epubContentsURL: contentsURL,
                rootURL: rootDirectory,
                tocID: rootDocument.root["spine"].attributes["toc"]
            )
        } else {
            epubContentParser = Epub3ContentParser(manifest: manifest, epubContentsURL: contentsURL, rootURL: rootDirectory)
        }

        return Epub(
            epubDirectoryURL: rootDirectory,
            type: epubType,
            coverURL: coverURL,
            metadataEntries: metadata,
            manifest: manifest,
            guide: guide,
            spines: spines,
            epubContentParser: epubContentParser
        )
    }

    private func rootFile(epubDirectoryURL: URL) -> URL? {
        let containerURL = epubDirectoryURL.appendingPathComponent("META-INF/container.xml")

        guard let data = try? Data(contentsOf: containerURL),
            let xmlDoc = try? AEXMLDocument(xml: data) else {
            return nil
        }

        let rootFiles = xmlDoc.root["rootfiles"].children
        // Prefer the OPF package; fall back to the first rootfile.
        let chosen = rootFiles.first { $0.attributes["media-type"] == "application/oebps-package+xml" } ?? rootFiles.first

        guard let path = chosen?.attributes["full-path"] else {
            return nil
        }
        let url = epubDirectoryURL.resolvingEpubHref(path)
        let rootPath = epubDirectoryURL.path
        return url.path.hasPrefix(rootPath + "/") ? url : nil
    }

    private func epubType(rootDocument: AEXMLDocument) -> EpubType {
        guard let versionString = rootDocument.root.attributes["version"],
              let major = versionString.split(separator: ".").first.flatMap({ Int($0) }) else {
            return .unknown
        }

        switch major {
        case 2: return .epub2
        case 3: return .epub3
        default: return .unknown
        }
    }

    private func epubMetaData(rootDocument: AEXMLDocument) -> [String: [String]] {
        var result: [String: [String]] = [:]
        for element in rootDocument.root["metadata"].children {
            result[element.name, default: []].append(element.value ?? "")
        }
        return result
    }

    private func epubCoverURL(rootDocument: AEXMLDocument, manifest: [String: ManifestItem], contentDirectoryURL: URL) -> URL? {
        // EPUB 3: manifest item flagged with properties="cover-image".
        if let href = manifest.values.first(where: { $0.properties.contains("cover-image") })?.href {
            return contentDirectoryURL.resolvingEpubHref(href)
        }

        if let coverHref = manifest["cover-image"]?.href {
            return contentDirectoryURL.resolvingEpubHref(coverHref)
        }

        // EPUB 2: <meta name="cover" content="manifest-id"/>.
        let coverMeta = rootDocument.root["metadata"].children.first { $0.attributes["name"] == "cover" }

        if let coverId = coverMeta?.attributes["content"],
            let coverHref = manifest[coverId]?.href {
            return contentDirectoryURL.resolvingEpubHref(coverHref)
        }

        return nil
    }

    private func manifest(rootDocument: AEXMLDocument) -> [String: ManifestItem] {
        var result: [String: ManifestItem] = [:]
        for element in rootDocument.root["manifest"].children {
            if let id = element.attributes["id"] {
                result[id] = ManifestItem(id: id, xmlElemet: element)
            }
        }
        return result
    }

    private func guide(rootDocument: AEXMLDocument) -> [GuideItem] {
        rootDocument.root["guide"].children.map { GuideItem(xmlElement: $0) }
    }

    private func spine(rootDocument: AEXMLDocument, manifest: [String: ManifestItem]) -> [SpineItem] {
        rootDocument.root["spine"].children.compactMap { SpineItem(xmlElement: $0, manifest: manifest) }
    }
}
