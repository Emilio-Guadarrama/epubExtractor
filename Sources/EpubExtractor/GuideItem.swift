import Foundation
import AEXML

public struct GuideItem: Sendable {
    public let title: String?
    public let href: String?
    public let type: String?

    init(xmlElement: AEXMLElement) {
        self.title = xmlElement.attributes["title"]
        self.href = xmlElement.attributes["href"]
        self.type = xmlElement.attributes["type"]
    }
}
