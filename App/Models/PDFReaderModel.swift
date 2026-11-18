import Foundation
import Observation
import PDFKit
import ReadAloudCore

/// State and Read-Aloud for one open PDF. Speech runs one page at a time over the page's own text,
/// so word ranges map straight onto `PDFPage.selection(for:)` for highlighting.
/// PDFKit objects are not Sendable, so everything here stays on the main actor.
@MainActor
@Observable
final class PDFReaderModel {
    struct ScrollRequest: Equatable {
        let page: Int
        let token: Int
    }

    let book: Book
    let speech = SpeechEngine()
    let document: PDFDocument?

    /// Page whose text is loaded in the speech engine.
    private(set) var pageIndex: Int
    private(set) var scrollRequest: ScrollRequest?
    private(set) var message: String?

    var pageCount: Int { document?.pageCount ?? 0 }

    @ObservationIgnored private var latestPosition: Int
    @ObservationIgnored private var lastPersist = Date.distantPast
    @ObservationIgnored private var scrollToken = 0

    /// See `EpubReaderModel.persistInterval`.
    private static let persistInterval: TimeInterval = 5

    init(book: Book) {
        self.book = book
        let document = PDFDocument(url: BookStorage.originalURL(for: book))
        self.document = document
        self.pageIndex = min(max(book.pdfPage, 0), max((document?.pageCount ?? 1) - 1, 0))
        self.latestPosition = book.textOffset

        speech.onPosition = { [weak self] location in
            guard let self else { return }
            self.latestPosition = location
            self.persistPosition(force: false)
        }
        speech.onStateChange = { [weak self] state in
            if state != .playing { self?.persistPosition(force: true) }
        }
        speech.onSectionFinished = { [weak self] in self?.advanceAfterSpeech() }
        speech.onSkipSection = { [weak self] delta in self?.step(by: delta, autoplay: true) }

        if document == nil { message = "This PDF could not be opened." }
        loadPage(pageIndex, startOffset: book.textOffset)
    }

    // MARK: - Pages

    /// Called when the visible page changes. Ignored while Read-Aloud owns the page.
    func viewDidShowPage(_ index: Int) {
        guard speech.state == .idle, index != pageIndex else { return }
        loadPage(index, startOffset: 0)
    }

    private func loadPage(_ index: Int, startOffset: Int, autoplay: Bool = false) {
        guard let document, index >= 0, index < document.pageCount else { return }
        pageIndex = index
        book.pdfPage = index
        book.textOffset = startOffset
        latestPosition = startOffset

        let raw = document.page(at: index)?.string ?? ""
        speech.load(text: TextChunker.reflowed(raw), language: nil, resumeAt: startOffset)
        speech.nowPlaying = NowPlayingMetadata(
            title: book.title,
            artist: book.author,
            album: "Page \(index + 1) of \(document.pageCount)",
            artworkData: book.coverData
        )
        if autoplay { speech.play(from: startOffset) }
    }

    private func hasText(_ index: Int) -> Bool {
        guard let string = document?.page(at: index)?.string else { return false }
        return !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// First page at or after `start` (moving in `direction`) that has selectable text.
    private func nextPageWithText(from start: Int, direction: Int) -> Int? {
        var index = start
        while index >= 0, index < pageCount {
            if hasText(index) { return index }
            index += direction
        }
        return nil
    }

    private func requestScroll(to page: Int) {
        scrollToken += 1
        scrollRequest = ScrollRequest(page: page, token: scrollToken)
    }

    /// Moves to the next or previous page with text and scrolls the view there.
    func step(by delta: Int, autoplay: Bool) {
        let direction = delta >= 0 ? 1 : -1
        guard let target = nextPageWithText(from: pageIndex + direction, direction: direction) else {
            if autoplay && direction > 0 { speech.stop() }
            return
        }
        loadPage(target, startOffset: 0, autoplay: autoplay)
        requestScroll(to: target)
    }

    /// In-app previous/next page buttons: keep speaking if Read-Aloud was playing.
    func move(by delta: Int) {
        step(by: delta, autoplay: speech.state == .playing)
    }

    // MARK: - Read-Aloud

    func toggleSpeech(rate: Float) {
        if speech.state == .idle {
            // Start from the visible page, or the next page that actually has text.
            guard let target = nextPageWithText(from: pageIndex, direction: 1) else {
                message = "This PDF has no selectable text (it may be a scan), so it can't be read aloud."
                return
            }
            message = nil
            if target != pageIndex {
                loadPage(target, startOffset: 0)
                requestScroll(to: target)
            }
        }
        speech.setRate(rate)
        speech.toggle()
    }

    private func advanceAfterSpeech() {
        guard let next = nextPageWithText(from: pageIndex + 1, direction: 1) else {
            speech.stop()
            return
        }
        loadPage(next, startOffset: 0, autoplay: true)
        requestScroll(to: next)
    }

    // MARK: - Progress

    func persistPosition(force: Bool) {
        let now = Date()
        guard force || now.timeIntervalSince(lastPersist) >= Self.persistInterval else { return }
        if book.textOffset != latestPosition { book.textOffset = latestPosition }
        lastPersist = now
    }

    func shutdown() {
        persistPosition(force: true)
        speech.shutdown()
    }
}
