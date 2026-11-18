import Foundation
import Testing
import EpubExtractor

@Suite struct FixtureEpubTests {
    private func fixture(_ name: String) throws -> URL {
        try #require(Bundle.module.url(forResource: name, withExtension: "epub", subdirectory: "Fixtures"))
    }

    private func makeExtractor() -> (EpubExtractor, URL) {
        let library = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return (EpubExtractor(libraryDirectory: library), library)
    }

    @Test(arguments: [("Metamorphosis-jackson", EpubType.epub2), ("spanish-tales-epub3", EpubType.epub3)])
    func extractsRealBooks(name: String, expectedType: EpubType) async throws {
        let (extractor, library) = makeExtractor()
        defer { try? FileManager.default.removeItem(at: library) }

        let epub = try await extractor.extract(epubURL: try fixture(name))

        #expect(epub.type == expectedType)
        #expect(epub.title?.isEmpty == false)
        #expect(!epub.spines.isEmpty)
        #expect(try epub.allContent().count > 1000)
    }

    @Test func removesManagedFolderOnFailure() async throws {
        let (extractor, library) = makeExtractor()
        defer { try? FileManager.default.removeItem(at: library) }

        let notAZip = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).epub")
        try Data("not a zip".utf8).write(to: notAZip)
        defer { try? FileManager.default.removeItem(at: notAZip) }

        await #expect(throws: (any Error).self) {
            try await extractor.extract(epubURL: notAZip)
        }
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: library.path)) ?? []
        #expect(leftovers.isEmpty)
    }
}
