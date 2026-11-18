import Foundation
import AEXML

public struct SpineItem: Sendable {
    public let idRef: String
    /// Per the OPF spec, `linear` defaults to `yes` when the attribute is absent.
    public let linear: Bool
    public let href: String?

    init?(xmlElement: AEXMLElement, manifest: [String: ManifestItem]) {
        guard let idRef = xmlElement.attributes["idref"] else {
            return nil
        }

        self.idRef = idRef
        self.linear = xmlElement.attributes["linear"]?.caseInsensitiveCompare("no") != .orderedSame
        self.href = manifest[idRef]?.href
    }
}
