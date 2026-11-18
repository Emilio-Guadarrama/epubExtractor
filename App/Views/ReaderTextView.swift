import SwiftUI
import UIKit

/// Read-only UITextView wrapper. A UITextView (not SwiftUI `Text`) is used on purpose: Phase 2 needs
/// character-range highlighting and scroll-to-range for Read-Aloud, which `Text` cannot do.
struct ReaderTextView: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.alwaysBounceVertical = true
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 16, left: 20, bottom: 32, right: 20)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let coordinator = context.coordinator
        let textChanged = coordinator.lastText != text
        guard textChanged || coordinator.lastFontSize != fontSize else { return }

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

        if textChanged {
            view.setContentOffset(CGPoint(x: 0, y: -view.adjustedContentInset.top), animated: false)
        }
    }

    final class Coordinator {
        var lastText: String?
        var lastFontSize: CGFloat?
    }
}
