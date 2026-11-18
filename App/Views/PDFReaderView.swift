import PDFKit
import SwiftUI

struct PDFReaderView: UIViewRepresentable {
    let book: Book

    func makeCoordinator() -> Coordinator { Coordinator(book: book) }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.usePageViewController(false)

        if let document = PDFDocument(url: BookStorage.originalURL(for: book)) {
            view.document = document
            if let page = document.page(at: min(book.pdfPage, max(document.pageCount - 1, 0))) {
                view.go(to: page)
            }
        }

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: view
        )
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject {
        let book: Book
        init(book: Book) { self.book = book }

        @objc func pageChanged(_ notification: Notification) {
            guard let view = notification.object as? PDFView,
                  let page = view.currentPage,
                  let index = view.document?.index(for: page) else { return }
            // Local write only. Sync writes must be debounced when Phase 3 adds them.
            if book.pdfPage != index { book.pdfPage = index }
        }
    }
}
