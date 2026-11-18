import EpubExtractor
import SwiftUI

struct EpubReaderView: View {
    let book: Book

    @AppStorage("readerFontSize") private var fontSize = 18.0
    @AppStorage("speechRate") private var speechRate = 0.5
    @Environment(\.scenePhase) private var scenePhase

    @State private var model: EpubReaderModel?
    @State private var showingContents = false

    private struct Speed: Identifiable {
        let label: String
        let rate: Double
        var id: Double { rate }
    }

    private static let speeds = [
        Speed(label: "Slow", rate: 0.42), Speed(label: "Normal", rate: 0.5),
        Speed(label: "Fast", rate: 0.55), Speed(label: "Faster", rate: 0.6)
    ]

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
        let speech = model.speech
        return VStack(spacing: 8) {
            HStack {
                Text("\(book.spineIndex + 1) of \(epub.spines.count)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Picker("Speed", selection: $speechRate) {
                        ForEach(Self.speeds) { Text($0.label).tag($0.rate) }
                    }
                } label: {
                    Label(Self.speeds.first { $0.rate == speechRate }?.label ?? "Speed", systemImage: "speedometer")
                        .font(.footnote)
                }
            }
            HStack(spacing: 32) {
                Button("Previous Section", systemImage: "backward.end.fill") { Task { await model.move(by: -1) } }
                    .disabled(book.spineIndex <= 0)
                Button("Previous Sentence", systemImage: "gobackward") { speech.skipSentence(-1) }
                    .disabled(speech.state == .idle)
                Button(speech.state == .playing ? "Pause" : "Play",
                       systemImage: speech.state == .playing ? "pause.circle.fill" : "play.circle.fill") {
                    model.toggleSpeech(rate: Float(speechRate))
                }
                .font(.system(size: 44))
                Button("Next Sentence", systemImage: "goforward") { speech.skipSentence(1) }
                    .disabled(speech.state == .idle)
                Button("Next Section", systemImage: "forward.end.fill") { Task { await model.move(by: 1) } }
                    .disabled(book.spineIndex >= epub.spines.count - 1)
            }
            .labelStyle(.iconOnly)
            .font(.title3)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
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
