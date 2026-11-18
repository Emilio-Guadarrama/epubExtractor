import Foundation
import SwiftData

enum BookKind: String, Codable, Sendable {
    case epub
    case pdf

    init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "epub": self = .epub
        case "pdf": self = .pdf
        default: return nil
        }
    }
}

/// Sync-ready model: every property has a default or is optional, and nothing is marked unique,
/// so it stays valid for CloudKit and for the planned Firebase sync records.
@Model
final class Book {
    var id: UUID = UUID()
    var title: String = ""
    var author: String = ""
    var kindRaw: String = BookKind.epub.rawValue
    var addedAt: Date = Date()
    var lastOpenedAt: Date?

    /// EPUB position: spine item index and character offset inside it (offset used by Read-Aloud in Phase 2).
    var spineIndex: Int = 0
    var textOffset: Int = 0
    /// PDF position.
    var pdfPage: Int = 0

    @Attribute(.externalStorage) var coverData: Data?

    var kind: BookKind {
        get { BookKind(rawValue: kindRaw) ?? .epub }
        set { kindRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), title: String, author: String, kind: BookKind) {
        self.id = id
        self.title = title
        self.author = author
        self.kindRaw = kind.rawValue
    }
}
