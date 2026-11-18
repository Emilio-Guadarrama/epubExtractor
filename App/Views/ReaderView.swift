import SwiftUI

struct ReaderView: View {
    let book: Book

    var body: some View {
        Group {
            switch book.kind {
            case .epub: EpubReaderView(book: book)
            case .pdf: PDFReaderScreen(book: book)
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { book.lastOpenedAt = Date() }
    }
}
