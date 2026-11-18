import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension EpubContentParser {
    /// HTML import is backed by WebKit and must run on the main thread.
    @MainActor
    func attributedContent(forSpine spine: SpineItem) throws -> NSAttributedString {
        let data = try Data(contentsOf: try fileURL(forSpine: spine))
        return try NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )
    }
}
