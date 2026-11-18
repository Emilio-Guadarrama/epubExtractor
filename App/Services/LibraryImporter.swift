import EpubExtractor
import Foundation
import PDFKit
import SwiftData
import UIKit

struct ImportFailure: Identifiable {
    let id = UUID()
    let fileName: String
    let message: String
}

private enum ImportError: LocalizedError {
    case unsupportedType
    case passwordProtectedPDF
    case unreadablePDF

    var errorDescription: String? {
        switch self {
        case .unsupportedType: "Only .epub and .pdf files are supported."
        case .passwordProtectedPDF: "This PDF is password protected."
        case .unreadablePDF: "This PDF could not be opened."
        }
    }
}

@MainActor
enum LibraryImporter {
    /// Imports each file independently; returns the ones that failed.
    static func importFiles(_ urls: [URL], into context: ModelContext) async -> [ImportFailure] {
        var failures: [ImportFailure] = []
        for url in urls {
            do {
                try await importOne(url, into: context)
            } catch {
                failures.append(ImportFailure(fileName: url.lastPathComponent, message: error.localizedDescription))
            }
        }
        return failures
    }

    private static func importOne(_ url: URL, into context: ModelContext) async throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let kind = BookKind(fileExtension: url.pathExtension) else { throw ImportError.unsupportedType }

        let id = UUID()
        let directory = BookStorage.directory(for: id)
        let original = directory.appendingPathComponent("original.\(kind.rawValue)")
        let fallbackTitle = url.deletingPathExtension().lastPathComponent

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try await Task.detached { try FileManager().copyItem(at: url, to: original) }.value

            let book: Book
            switch kind {
            case .epub: book = try await makeEpubBook(id: id, original: original, fallbackTitle: fallbackTitle)
            case .pdf: book = try makePDFBook(id: id, original: original, fallbackTitle: fallbackTitle)
            }
            context.insert(book)
            try context.save()
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    private static func makeEpubBook(id: UUID, original: URL, fallbackTitle: String) async throws -> Book {
        let epub = try await EpubExtractor().extract(epubURL: original, to: BookStorage.extractedURL(for: id))
        let title = epub.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let book = Book(
            id: id,
            title: (title?.isEmpty == false ? title : nil) ?? fallbackTitle,
            author: epub.authors.joined(separator: ", "),
            kind: .epub
        )
        book.coverData = epub.coverURL.flatMap { thumbnailJPEG(fromImageAt: $0) }
        return book
    }

    private static func makePDFBook(id: UUID, original: URL, fallbackTitle: String) throws -> Book {
        guard let document = PDFDocument(url: original) else { throw ImportError.unreadablePDF }
        guard !document.isLocked else { throw ImportError.passwordProtectedPDF }

        let attributes = document.documentAttributes
        let title = (attributes?[PDFDocumentAttribute.titleAttribute] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let book = Book(
            id: id,
            title: (title?.isEmpty == false ? title : nil) ?? fallbackTitle,
            author: attributes?[PDFDocumentAttribute.authorAttribute] as? String ?? "",
            kind: .pdf
        )
        book.coverData = document.page(at: 0)?
            .thumbnail(of: CGSize(width: 400, height: 560), for: .mediaBox)
            .jpegData(compressionQuality: 0.8)
        return book
    }

    private static func thumbnailJPEG(fromImageAt url: URL) -> Data? {
        guard let image = UIImage(contentsOfFile: url.path), image.size.width > 0 else { return nil }
        let target = CGSize(width: 400, height: 400 * image.size.height / image.size.width)
        return (image.preparingThumbnail(of: target) ?? image).jpegData(compressionQuality: 0.8)
    }
}
