import Foundation
import ZIPFoundation

/// Unzips an `.epub` into a managed folder and parses it.
///
/// ZIPFoundation rejects entries whose paths escape the destination (zip-slip), so malicious archives throw.
public struct EpubExtractor: Sendable {
    /// Folder under which each extracted book gets its own subfolder when no destination is given.
    public let libraryDirectory: URL

    /// - Parameter libraryDirectory: defaults to `Application Support/EpubExtractor`.
    public init(libraryDirectory: URL? = nil) {
        self.libraryDirectory = libraryDirectory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("EpubExtractor", isDirectory: true)
    }

    /// Extracts and parses an ePub off the calling actor.
    /// - Parameters:
    ///   - epubURL: the `.epub` file.
    ///   - destinationFolder: where to extract; a fresh folder in `libraryDirectory` when `nil`.
    /// - Returns: the parsed `Epub`. If extraction or parsing fails, a folder created by this call is removed.
    public func extract(epubURL: URL, to destinationFolder: URL? = nil) async throws -> Epub {
        let destination = destinationFolder
            ?? libraryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let createdByUs = destinationFolder == nil || !FileManager.default.fileExists(atPath: destination.path)

        return try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager()
            do {
                try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
                try fileManager.unzipItem(at: epubURL, to: destination)
                return try EpubParser().parseEpub(epubDirectoryURL: destination)
            } catch {
                if createdByUs { try? fileManager.removeItem(at: destination) }
                throw error
            }
        }.value
    }

    /// Parses a folder previously produced by `extract`, without unzipping again.
    public func open(extractedDirectory: URL) throws -> Epub {
        try EpubParser().parseEpub(epubDirectoryURL: extractedDirectory)
    }

    /// Deletes the extracted files of a book.
    public func removeExtractedEpub(_ epub: Epub) throws {
        try FileManager.default.removeItem(at: epub.epubDirectoryURL)
    }
}
