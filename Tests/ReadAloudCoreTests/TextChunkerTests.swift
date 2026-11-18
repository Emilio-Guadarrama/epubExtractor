import Foundation
import Testing
@testable import ReadAloudCore

@Suite struct TextChunkerTests {
    private func assertWellFormed(_ chunks: [SpeechChunk], text: String, from offset: Int = 0, maxLength: Int) {
        let ns = text as NSString
        var previousEnd = offset
        var covered = Set<Int>()
        for chunk in chunks {
            #expect(chunk.range.location >= previousEnd)
            #expect(chunk.range.length <= maxLength)
            #expect(ns.substring(with: chunk.range) == chunk.text)
            previousEnd = NSMaxRange(chunk.range)
            covered.formUnion(chunk.range.location..<NSMaxRange(chunk.range))
        }
        // Every non-whitespace character after `offset` is spoken exactly once.
        for index in offset..<ns.length {
            let unit = ns.character(at: index)
            let isSpace = Unicode.Scalar(unit).map { CharacterSet.whitespacesAndNewlines.contains($0) } ?? false
            if !isSpace { #expect(covered.contains(index), "missing index \(index)") }
        }
    }

    @Test func groupsSentencesUpToMaxLength() {
        let text = "One two. Three four. Five six. Seven eight."
        let chunks = TextChunker.chunks(in: text, maxLength: 25)
        assertWellFormed(chunks, text: text, maxLength: 25)
        #expect(chunks.count >= 2)
    }

    @Test func paragraphBreakEndsChunk() {
        let text = "First paragraph.\nSecond paragraph."
        let chunks = TextChunker.chunks(in: text, maxLength: 600)
        #expect(chunks.map(\.text) == ["First paragraph.\n", "Second paragraph."])
    }

    @Test func splitsOversizedSentenceAtWhitespace() {
        let text = String(repeating: "word ", count: 60) + "end."
        let chunks = TextChunker.chunks(in: text, maxLength: 50)
        assertWellFormed(chunks, text: text, maxLength: 50)
        #expect(chunks.count > 5)
    }

    @Test func splitsUnbrokenRunWithoutCuttingSurrogatePairs() {
        let text = String(repeating: "😀", count: 100)   // 200 UTF-16 units, no whitespace
        let chunks = TextChunker.chunks(in: text, maxLength: 51)
        assertWellFormed(chunks, text: text, maxLength: 51)
        for chunk in chunks { #expect(chunk.text.unicodeScalars.allSatisfy { $0 == "😀" }) }
    }

    @Test func honorsStartOffset() {
        let text = "Alpha one. Beta two. Gamma three."
        let offset = (text as NSString).range(of: "Beta").location
        let chunks = TextChunker.chunks(in: text, from: offset, maxLength: 600)
        assertWellFormed(chunks, text: text, from: offset, maxLength: 600)
        #expect(chunks.first?.range.location == offset)
        #expect(chunks.allSatisfy { !$0.text.contains("Alpha") })
    }

    @Test func emptyAndWhitespaceInputProduceNoChunks() {
        #expect(TextChunker.chunks(in: "").isEmpty)
        #expect(TextChunker.chunks(in: "  \n\n ").isEmpty)
        #expect(TextChunker.chunks(in: "abc", from: 10).isEmpty)
    }

    @Test func findsSentenceContainingLocation() {
        let ns = "One. Two three. Four." as NSString
        let location = ns.range(of: "three").location
        let range = TextChunker.sentenceRange(containing: location, in: ns)
        #expect(range.map { ns.substring(with: $0) } == "Two three. ")
        #expect(TextChunker.sentenceRange(containing: 999, in: ns) == nil)
    }

    @Test func skipsWhitespace() {
        let ns = "end.  \n Next" as NSString
        #expect(TextChunker.skipWhitespace(from: 4, in: ns) == ns.range(of: "Next").location)
        #expect(TextChunker.skipWhitespace(from: 100, in: ns) == ns.length)
    }
}
