import Foundation

/// On-disk layout, derived from the book id so no absolute path is ever persisted
/// (the app container path changes between installs and updates):
///
///     Application Support/Books/<id>/original.epub|pdf
///     Application Support/Books/<id>/extracted/        (EPUB only)
enum BookStorage {
    static var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Books", isDirectory: true)
    }

    static func directory(for id: UUID) -> URL {
        root.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    static func originalURL(for book: Book) -> URL {
        directory(for: book.id).appendingPathComponent("original.\(book.kind.rawValue)")
    }

    static func extractedURL(for id: UUID) -> URL {
        directory(for: id).appendingPathComponent("extracted", isDirectory: true)
    }

    static func delete(_ book: Book) {
        try? FileManager.default.removeItem(at: directory(for: book.id))
    }
}
