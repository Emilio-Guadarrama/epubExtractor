import Foundation

/// A chapter from the ePub's table of contents.
public protocol ChapterItem: Sendable {
    var src: URL { get }
    var label: String? { get }
    var subChapters: [ChapterItem] { get }
}
