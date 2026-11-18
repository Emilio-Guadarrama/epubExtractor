import Foundation
import AEXML

public struct ManifestItem: Sendable {
    public let id: String
    public let href: String?
    public let mediaType: String?
    /// EPUB 3 `properties` attribute split on whitespace (for example `nav`, `cover-image`).
    public let properties: Set<String>

    init(id: String, xmlElemet: AEXMLElement) {
        self.id = id
        self.href = xmlElemet.attributes["href"]
        self.mediaType = xmlElemet.attributes["media-type"]
        self.properties = Set((xmlElemet.attributes["properties"] ?? "").split(whereSeparator: \.isWhitespace).map(String.init))
    }
}
