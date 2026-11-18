import EpubExtractor
import SwiftUI

struct EpubReaderView: View {
    let book: Book

    @AppStorage("readerFontSize") private var fontSize = 18.0
    @AppStorage("speechRate") private var speechRate = 0.5
    @Environment(\.scenePhase) private var scenePhase

    @State private var model: EpubReaderModel?
    @State private var showingContents = false

    var body: some View {
        Group {
            if let model {
                if let epub = model.epub {
                    reader(model, epub: epub)
                } else if let error = model.loadError {
                    ContentUnavailableView("Could Not Open Book", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    ProgressView()
                }
            } else {
                ProgressView()
            }
        }
        .task {
            guard model == nil else { return }
            let created = EpubReaderModel(book: book)
            created.speech.setRate(Float(speechRate))
            model = created
            await created.load()
        }
        .onDisappear { model?.shutdown() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { model?.persistPosition(force: true) }
        }
        .onChange(of: speechRate) { _, rate in model?.speech.setRate(Float(rate)) }
    }

    private func reader(_ model: EpubReaderModel, epub: Epub) -> some View {
        let speech = model.speech
        let isSpeaking = speech.state != .idle
        return ReaderTextView(
            text: model.text.isEmpty ? "(This section has no text.)" : model.text,
            fontSize: fontSize,
            startLocation: model.startLocation,
            wordRange: isSpeaking ? speech.wordRange : nil,
            sentenceRange: isSpeaking ? speech.sentenceRange : nil,
            autoScroll: speech.state == .playing
        )
        .safeAreaInset(edge: .bottom) { playerBar(model, epub: epub) }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu("Text Size", systemImage: "textformat.size") {
                    Button("Larger", systemImage: "plus") { fontSize = min(fontSize + 2, 36) }
                    Button("Smaller", systemImage: "minus") { fontSize = max(fontSize - 2, 12) }
                }
                Button("Contents", systemImage: "list.bullet") { showingContents = true }
            }
        }
        .sheet(isPresented: $showingContents) {
            ContentsSheet(entries: model.contents, currentIndex: book.spineIndex) { index in
                showingContents = false
                Task { await model.jump(toSpine: index) }
            }
        }
    }

    private func playerBar(_ model: EpubReaderModel, epub: Epub) -> some View {
        PlayerBarView(
            speech: model.speech,
            positionLabel: "\(book.spineIndex + 1) of \(epub.spines.count)",
            unitName: "Section",
            rate: $speechRate,
            canGoBack: book.spineIndex > 0,
            canGoForward: book.spineIndex < epub.spines.count - 1,
            onPreviousUnit: { Task { await model.move(by: -1) } },
            onNextUnit: { Task { await model.move(by: 1) } },
            onToggle: { model.toggleSpeech(rate: Float(speechRate)) }
        )
    }
}

private struct ContentsSheet: View {
    let entries: [ContentsEntry]
    let currentIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        NavigationStack {
            List(entries) { entry in
                Button {
                    if let index = entry.spineIndex { onSelect(index) }
                } label: {
                    HStack {
                        Text(entry.label)
                            .padding(.leading, CGFloat(entry.depth) * 16)
                            .foregroundStyle(entry.spineIndex == nil ? .secondary : .primary)
                        Spacer()
                        if entry.spineIndex == currentIndex {
                            Image(systemName: "bookmark.fill").foregroundStyle(.tint)
                        }
                    }
                }
                .disabled(entry.spineIndex == nil)
            }
            .navigationTitle("Contents")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}
