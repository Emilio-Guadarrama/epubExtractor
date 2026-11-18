import PDFKit
import SwiftUI

/// Wraps `PDFView`. Everything the view must react to is passed in as plain values (read by the parent's
/// body), so SwiftUI reliably calls `updateUIView` when the highlighted word or page changes.
struct PDFReaderView: UIViewRepresentable {
    let model: PDFReaderModel
    let pageIndex: Int
    let wordRange: NSRange?
    let sentenceRange: NSRange?
    let scrollRequest: PDFReaderModel.ScrollRequest?
    let autoScroll: Bool

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.usePageViewController(false)

        if let document = model.document {
            view.document = document
            if let page = document.page(at: model.pageIndex) { view.go(to: page) }
        }

        let coordinator = context.coordinator
        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: view
        )

        // Detect manual scrolling so auto-scroll does not fight the reader.
        let pan = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.userPanned))
        pan.cancelsTouchesInView = false
        pan.delegate = coordinator
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        context.coordinator.apply(
            to: view,
            pageIndex: pageIndex,
            word: wordRange,
            sentence: sentenceRange,
            scrollRequest: scrollRequest,
            autoScroll: autoScroll
        )
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private let model: PDFReaderModel
        private var lastScrollToken = -1
        private var lastHighlightKey: [NSRange] = []
        private var lastHighlightPage = -1
        private var lastUserScroll = Date.distantPast

        init(model: PDFReaderModel) { self.model = model }

        @objc func pageChanged(_ notification: Notification) {
            guard let view = notification.object as? PDFView,
                  let page = view.currentPage,
                  let index = view.document?.index(for: page) else { return }
            model.viewDidShowPage(index)
        }

        @objc func userPanned() { lastUserScroll = Date() }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }

        func apply(
            to view: PDFView,
            pageIndex: Int,
            word: NSRange?,
            sentence: NSRange?,
            scrollRequest: PDFReaderModel.ScrollRequest?,
            autoScroll: Bool
        ) {
            if let request = scrollRequest, request.token != lastScrollToken {
                lastScrollToken = request.token
                if let page = view.document?.page(at: request.page) { view.go(to: page) }
            }

            let key = [sentence, word].compactMap { $0 }
            guard key != lastHighlightKey || pageIndex != lastHighlightPage else { return }
            lastHighlightKey = key
            lastHighlightPage = pageIndex

            guard let page = view.document?.page(at: pageIndex), !key.isEmpty else {
                view.highlightedSelections = nil
                return
            }

            var selections: [PDFSelection] = []
            var wordSelection: PDFSelection?
            if let sentence, let selection = page.selection(for: sentence) {
                selection.color = UIColor.tintColor.withAlphaComponent(0.25)
                selections.append(selection)
            }
            if let word, let selection = page.selection(for: word) {
                selection.color = UIColor.tintColor.withAlphaComponent(0.55)
                selections.append(selection)
                wordSelection = selection
            }
            view.highlightedSelections = selections.isEmpty ? nil : selections

            if autoScroll, let wordSelection, Date().timeIntervalSince(lastUserScroll) > 4 {
                scrollIfNeeded(view, to: wordSelection, on: page)
            }
        }

        /// Scrolls only when the word is near or past the edge of the visible area.
        private func scrollIfNeeded(_ view: PDFView, to selection: PDFSelection, on page: PDFPage) {
            let rect = view.convert(selection.bounds(for: page), from: page)
            let visible = view.bounds
                .inset(by: view.safeAreaInsets)
                .insetBy(dx: 0, dy: 60)
            if !visible.contains(rect) {
                view.go(to: selection)
            }
        }
    }
}

/// PDF reader screen: page view plus the Read-Aloud player bar.
struct PDFReaderScreen: View {
    let book: Book

    @AppStorage("speechRate") private var speechRate = 0.5
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: PDFReaderModel?

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                ProgressView()
            }
        }
        .task {
            guard model == nil else { return }
            let created = PDFReaderModel(book: book)
            created.speech.setRate(Float(speechRate))
            model = created
        }
        .onDisappear { model?.shutdown() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model?.persistPosition(force: true) }
        }
        .onChange(of: speechRate) { _, rate in model?.speech.setRate(Float(rate)) }
    }

    private func content(_ model: PDFReaderModel) -> some View {
        let speech = model.speech
        let isSpeaking = speech.state != .idle
        return PDFReaderView(
            model: model,
            pageIndex: model.pageIndex,
            wordRange: isSpeaking ? speech.wordRange : nil,
            sentenceRange: isSpeaking ? speech.sentenceRange : nil,
            scrollRequest: model.scrollRequest,
            autoScroll: speech.state == .playing
        )
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if let message = model.message {
                    Text(message)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                }
                PlayerBarView(
                    speech: speech,
                    positionLabel: "Page \(model.pageIndex + 1) of \(model.pageCount)",
                    unitName: "Page",
                    rate: $speechRate,
                    canGoBack: model.pageIndex > 0,
                    canGoForward: model.pageIndex < model.pageCount - 1,
                    onPreviousUnit: { model.move(by: -1) },
                    onNextUnit: { model.move(by: 1) },
                    onToggle: { model.toggleSpeech(rate: Float(speechRate)) }
                )
            }
        }
    }
}
