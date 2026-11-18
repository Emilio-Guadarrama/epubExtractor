import Foundation

/// Thread-safe, WebKit-free (X)HTML to plain text conversion, suitable for text-to-speech.
/// Tolerant of undefined entities and malformed markup (unlike `XMLParser`).
enum PlainTextExtractor {
    private static let blockTags: Set<String> = [
        "p", "div", "br", "li", "ul", "ol", "tr", "table", "section", "article", "blockquote",
        "h1", "h2", "h3", "h4", "h5", "h6", "pre", "hr", "dt", "dd", "figure", "figcaption", "header", "footer"
    ]
    private static let skippedTags: Set<String> = ["script", "style", "head"]

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "mdash": "—", "ndash": "–", "hellip": "…", "lsquo": "‘", "rsquo": "’",
        "ldquo": "“", "rdquo": "”", "copy": "©", "shy": ""
    ]

    static func text(fromHTML html: String) -> String {
        var output = ""
        var skipDepthTag: String?
        var index = html.startIndex

        func appendBreak() {
            if !output.isEmpty && !output.hasSuffix("\n") { output.append("\n") }
        }

        while index < html.endIndex {
            let char = html[index]
            if char == "<" {
                if html[index...].hasPrefix("<!--") {
                    guard let end = html.range(of: "-->", range: index..<html.endIndex) else { break }
                    index = end.upperBound
                    continue
                }
                guard let close = html[index...].firstIndex(of: ">") else { break }
                let tagBody = html[html.index(after: index)..<close]
                index = html.index(after: close)

                if tagBody.hasPrefix("!") || tagBody.hasPrefix("?") { continue }

                let isClosing = tagBody.hasPrefix("/")
                let nameStart = isClosing ? tagBody.index(after: tagBody.startIndex) : tagBody.startIndex
                let rawName = tagBody[nameStart...].prefix { !$0.isWhitespace && $0 != "/" }
                let name = rawName.lowercased().split(separator: ":").last.map(String.init) ?? ""

                if let skipping = skipDepthTag {
                    if isClosing && name == skipping { skipDepthTag = nil }
                    continue
                }
                if !isClosing, skippedTags.contains(name), !tagBody.hasSuffix("/") {
                    skipDepthTag = name
                    continue
                }
                if blockTags.contains(name) { appendBreak() }
            } else if skipDepthTag != nil {
                index = html.index(after: index)
            } else if char == "&" {
                if let semicolon = html[index...].prefix(12).firstIndex(of: ";") {
                    let entity = String(html[html.index(after: index)..<semicolon])
                    if let decoded = decode(entity) {
                        output.append(decoded)
                        index = html.index(after: semicolon)
                        continue
                    }
                }
                output.append(char)
                index = html.index(after: index)
            } else {
                output.append(char)
                index = html.index(after: index)
            }
        }
        return normalize(output)
    }

    private static func decode(_ entity: String) -> String? {
        if entity.hasPrefix("#") {
            let digits = entity.dropFirst()
            let value: UInt32?
            if digits.hasPrefix("x") || digits.hasPrefix("X") {
                value = UInt32(digits.dropFirst(), radix: 16)
            } else {
                value = UInt32(digits, radix: 10)
            }
            guard let value, let scalar = Unicode.Scalar(value) else { return nil }
            return String(Character(scalar))
        }
        return namedEntities[entity]
    }

    /// Collapses runs of spaces/tabs, trims lines, and limits blank lines to one.
    private static func normalize(_ text: String) -> String {
        var lines: [String] = []
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let collapsed = rawLine.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\r" })
                .joined(separator: " ")
            if collapsed.isEmpty, lines.last?.isEmpty ?? true { continue }
            lines.append(collapsed)
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
