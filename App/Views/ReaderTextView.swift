import SwiftUI
import UIKit

/// Read-only UITextView wrapper. A UITextView (not SwiftUI `Text`) is used because Read-Aloud needs
/// character-range highlighting and scroll-to-range, which `Text` cannot do.
struct ReaderTextView: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    /// Offset to bring to the top when `text` changes (resuming a saved position).
    var startLocation: Int = 0
    var wordRange: NSRange?
    var sentenceRange: NSRange?
    /// Follow the highlighted word. Pauses for a few seconds after the user scrolls by hand.
    var autoScroll = false

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.alwaysBounceVertical = true
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 16, left: 20, bottom: 32, right: 20)
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let coordinator = context.coordinator
        let textChanged = coordinator.lastText != text

        if textChanged || coordinator.lastFontSize != fontSize {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = fontSize * 0.35
            style.paragraphSpacing = fontSize * 0.6
            view.attributedText = NSAttributedString(string: text, attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body).withSize(fontSize),
                .foregroundColor: UIColor.label,
                .paragraphStyle: style
            ])
            coordinator.lastText = text
            coordinator.lastFontSize = fontSize
            coordinator.appliedRanges = []   // attributes were reset with the text

            if textChanged {
                view.setContentOffset(CGPoint(x: 0, y: -view.adjustedContentInset.top), animated: false)
                if startLocation > 0 {
                    let target = startLocation
                    Task { @MainActor [weak view] in
                        guard let view else { return }
                        view.layoutIfNeeded()
                        Self.scroll(view, to: NSRange(location: target, length: 1), anchor: 0.15, animated: false)
                    }
                }
            }
        }

        coordinator.applyHighlights(in: view, sentence: sentenceRange, word: wordRange)

        if autoScroll, let wordRange, coordinator.canAutoScroll {
            Self.scrollIfNeeded(view, to: wordRange)
        }
    }

    // MARK: - Scrolling

    /// Scrolls only when the word is near the edge of the visible area, so the text does not jitter.
    private static func scrollIfNeeded(_ view: UITextView, to range: NSRange) {
        guard let rect = rect(of: range, in: view) else { return }
        let top = view.contentOffset.y + view.adjustedContentInset.top
        let bottom = view.contentOffset.y + view.bounds.height - view.adjustedContentInset.bottom
        if rect.minY < top + 40 || rect.maxY > bottom - 80 {
            scroll(view, to: range, anchor: 0.35, animated: true)
        }
    }

    /// `anchor` is the fraction of the viewport height at which the range should land.
    private static func scroll(_ view: UITextView, to range: NSRange, anchor: CGFloat, animated: Bool) {
        guard let rect = rect(of: range, in: view) else { return }
        let viewport = view.bounds.height - view.adjustedContentInset.top - view.adjustedContentInset.bottom
        let minY = -view.adjustedContentInset.top
        let maxY = max(minY, view.contentSize.height - view.bounds.height + view.adjustedContentInset.bottom)
        let target = min(max(rect.minY - viewport * anchor, minY), maxY)
        view.setContentOffset(CGPoint(x: 0, y: target), animated: animated)
    }

    private static func rect(of range: NSRange, in view: UITextView) -> CGRect? {
        guard range.location >= 0, NSMaxRange(range) <= view.textStorage.length,
              let start = view.position(from: view.beginningOfDocument, offset: range.location),
              let end = view.position(from: start, offset: range.length),
              let textRange = view.textRange(from: start, to: end) else { return nil }
        let rect = view.firstRect(for: textRange)
        return rect.isNull || rect.isInfinite ? nil : rect
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var lastText: String?
        var lastFontSize: CGFloat?
        var appliedRanges: [NSRange] = []
        private var lastUserScroll = Date.distantPast
        private var isDragging = false

        var canAutoScroll: Bool { !isDragging && Date().timeIntervalSince(lastUserScroll) > 4 }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { isDragging = true }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            isDragging = false
            lastUserScroll = Date()
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { lastUserScroll = Date() }

        func applyHighlights(in view: UITextView, sentence: NSRange?, word: NSRange?) {
            let wanted = [sentence, word].compactMap { $0 }
            guard wanted != appliedRanges else { return }

            let storage = view.textStorage
            let length = storage.length
            storage.beginEditing()
            for old in appliedRanges where NSMaxRange(old) <= length {
                storage.removeAttribute(.backgroundColor, range: old)
            }
            if let sentence, NSMaxRange(sentence) <= length {
                storage.addAttribute(.backgroundColor, value: UIColor.tintColor.withAlphaComponent(0.15), range: sentence)
            }
            if let word, NSMaxRange(word) <= length {
                storage.addAttribute(.backgroundColor, value: UIColor.tintColor.withAlphaComponent(0.45), range: word)
            }
            storage.endEditing()
            appliedRanges = wanted
        }
    }
}
