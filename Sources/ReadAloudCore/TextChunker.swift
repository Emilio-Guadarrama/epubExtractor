import Foundation

/// A slice of a larger text, in UTF-16 offsets (the unit `AVSpeechSynthesizer` and `NSRange` use).
public struct SpeechChunk: Sendable, Equatable {
    public let range: NSRange
    public let text: String

    public init(range: NSRange, text: String) {
        self.range = range
        self.text = text
    }
}

/// Pure text logic for Read-Aloud, kept free of AVFoundation so it can be unit tested with `swift test`.
public enum TextChunker {
    /// Splits `text` (from UTF-16 offset `offset`) into speakable chunks of at most `maxLength` UTF-16 units.
    /// Chunks break on sentence boundaries; paragraph ends always end a chunk; a sentence longer than
    /// `maxLength` is split at whitespace. Whitespace-only chunks are dropped. Ranges are global to `text`.
    public static func chunks(in text: String, from offset: Int = 0, maxLength: Int = 600) -> [SpeechChunk] {
        let ns = text as NSString
        let total = ns.length
        let first = max(offset, 0)
        guard first < total, maxLength > 1 else { return [] }

        var result: [SpeechChunk] = []
        var chunkStart = first
        var chunkEnd = first

        func emit(_ start: Int, _ end: Int) {
            guard end > start else { return }
            let range = NSRange(location: start, length: end - start)
            let piece = ns.substring(with: range)
            if !piece.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(SpeechChunk(range: range, text: piece))
            }
        }

        ns.enumerateSubstrings(
            in: NSRange(location: first, length: total - first),
            options: [.bySentences, .substringNotRequired]
        ) { _, _, enclosing, _ in
            let sentenceEnd = NSMaxRange(enclosing)

            if enclosing.length > maxLength {
                emit(chunkStart, chunkEnd)
                var cursor = enclosing.location
                while sentenceEnd - cursor > maxLength {
                    let cut = breakPoint(in: ns, from: cursor, limit: cursor + maxLength)
                    emit(cursor, cut)
                    cursor = cut
                }
                chunkStart = cursor
                chunkEnd = sentenceEnd
            } else if chunkEnd - chunkStart + enclosing.length > maxLength {
                emit(chunkStart, chunkEnd)
                chunkStart = enclosing.location
                chunkEnd = sentenceEnd
            } else {
                if chunkEnd == chunkStart { chunkStart = enclosing.location }
                chunkEnd = sentenceEnd
            }

            // A paragraph break always ends a chunk, so pauses fall where a reader expects them.
            if ns.character(at: sentenceEnd - 1) == 0x0A {
                emit(chunkStart, chunkEnd)
                chunkStart = chunkEnd
            }
        }
        emit(chunkStart, chunkEnd)
        return result
    }

    /// Replaces single line breaks with spaces so hard-wrapped text (typical of PDF extraction) reads as
    /// flowing sentences; runs of two or more breaks (paragraphs) are kept. The result has exactly the same
    /// UTF-16 length as the input, so ranges in it are valid offsets in the original.
    public static func reflowed(_ text: String) -> String {
        var units = Array(text.utf16)
        let count = units.count
        func isBreak(_ unit: UInt16) -> Bool { unit == 0x0A || unit == 0x0D }

        var index = 0
        while index < count {
            guard isBreak(units[index]) else {
                index += 1
                continue
            }
            var end = index
            var breaks = 0
            while end < count, isBreak(units[end]) {
                // CR LF counts as one break.
                end += (units[end] == 0x0D && end + 1 < count && units[end + 1] == 0x0A) ? 2 : 1
                breaks += 1
            }
            if breaks == 1 {
                for position in index..<end { units[position] = 0x20 }
            }
            index = end
        }
        return String(decoding: units, as: UTF16.self)
    }

    /// The sentence (including trailing whitespace) containing UTF-16 offset `location`.
    public static func sentenceRange(containing location: Int, in text: NSString) -> NSRange? {
        guard location >= 0, location < text.length else { return nil }
        let paragraph = text.paragraphRange(for: NSRange(location: location, length: 0))
        var found: NSRange?
        text.enumerateSubstrings(in: paragraph, options: [.bySentences, .substringNotRequired]) { _, _, enclosing, stop in
            if NSLocationInRange(location, enclosing) {
                found = enclosing
                stop.pointee = true
            }
        }
        return found
    }

    /// First offset at or after `location` that is not whitespace, or `text.length` if none.
    public static func skipWhitespace(from location: Int, in text: NSString) -> Int {
        var index = max(location, 0)
        while index < text.length,
              let scalar = Unicode.Scalar(text.character(at: index)),
              CharacterSet.whitespacesAndNewlines.contains(scalar) {
            index += 1
        }
        return index
    }

    /// Cut position just after the last whitespace in the second half of `from..<limit`; otherwise `limit`
    /// (backed off so a surrogate pair is never split).
    private static func breakPoint(in ns: NSString, from: Int, limit: Int) -> Int {
        let floor = from + (limit - from) / 2
        var index = limit - 1
        while index > floor {
            if let scalar = Unicode.Scalar(ns.character(at: index)),
               CharacterSet.whitespacesAndNewlines.contains(scalar) {
                return index + 1
            }
            index -= 1
        }
        let isHighSurrogate = (0xD800...0xDBFF).contains(ns.character(at: limit - 1))
        return isHighSurrogate ? limit - 1 : limit
    }
}
