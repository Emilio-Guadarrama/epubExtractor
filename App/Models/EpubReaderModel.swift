import EpubExtractor
import Foundation
import Observation

struct ContentsEntry: Identifiable {
    let id = UUID()
    let label: String
    let depth: Int
    let spineIndex: Int?
}

/// State and navigation for one open EPUB, plus its Read-Aloud engine.
@MainActor
@Observable
final class EpubReaderModel {
    let book: Book
    let speech = SpeechEngine()

    private(set) var epub: Epub?
    private(set) var loadError: String?
    private(set) var text = ""
    private(set) var startLocation = 0
    private(set) var contents: [ContentsEntry] = []

    @ObservationIgnored private var latestPosition: Int
    @ObservationIgnored private var lastPersist = Date.distantPast
    @ObservationIgnored private var showGeneration = 0

    /// Minimum time between progress writes while speaking. Pause, stop, background and leaving the
    /// reader always write immediately.
    private static let persistInterval: TimeInterval = 5

    init(book: Book) {
        self.book = book
        self.latestPosition = book.textOffset

        speech.onPosition = { [weak self] location in self?.positionChanged(location) }
        speech.onStateChange = { [weak self] state in
            if state != .playing { self?.persistPosition(force: true) }
        }
        speech.onSectionFinished = { [weak self] in self?.advanceAfterSpeech() }
        speech.onSkipSection = { [weak self] delta in
            guard let self else { return }
            Task { await self.show(self.book.spineIndex + delta, autoplay: true) }
        }
    }

    // MARK: - Loading

    func load() async {
        guard epub == nil else { return }
        let directory = BookStorage.extractedURL(for: book.id)
        do {
            let opened = try await Task.detached { try EpubExtractor().open(extractedDirectory: directory) }.value
            guard !opened.spines.isEmpty else {
                loadError = "This book has no readable sections."
                return
            }
            epub = opened
            contents = Self.makeContents(for: opened)
            await show(book.spineIndex, startOffset: book.textOffset)
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Shows spine item `index`. If `autoplay`, Read-Aloud starts at `startOffset` once the text is loaded.
    func show(_ index: Int, startOffset: Int = 0, autoplay: Bool = false) async {
        guard let epub else { return }
        let clamped = min(max(index, 0), epub.spines.count - 1)
        let spine = epub.spines[clamped]

        showGeneration += 1
        let generation = showGeneration
        let loaded = await Task.detached { (try? epub.content(forSpine: spine)) ?? "" }.value
        guard generation == showGeneration else { return }   // a newer navigation superseded this one

        if clamped != book.spineIndex || startOffset == 0 {
            book.spineIndex = clamped
            book.textOffset = startOffset
        }
        latestPosition = startOffset
        text = loaded
        startLocation = startOffset

        speech.load(text: loaded, language: epub.language, resumeAt: startOffset)
        speech.nowPlaying = NowPlayingMetadata(
            title: title(forSpine: clamped),
            artist: book.author,
            album: book.title,
            artworkData: book.coverData
        )
        if autoplay { speech.play(from: startOffset) }
    }

    /// In-app previous/next: keeps speaking if Read-Aloud was playing.
    func move(by delta: Int) async {
        await show(book.spineIndex + delta, autoplay: speech.state == .playing)
    }

    func jump(toSpine index: Int) async {
        await show(index, autoplay: speech.state == .playing)
    }

    // MARK: - Read-Aloud

    func toggleSpeech(rate: Float) {
        speech.setRate(rate)
        speech.toggle()
    }

    private func advanceAfterSpeech() {
        guard let epub, book.spineIndex + 1 < epub.spines.count else {
            speech.stop()
            return
        }
        Task { await show(book.spineIndex + 1, autoplay: true) }
    }

    // MARK: - Progress

    private func positionChanged(_ location: Int) {
        latestPosition = location
        persistPosition(force: false)
    }

    /// Writes reading position, throttled so Read-Aloud does not hammer the store (and, later, sync).
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

    // MARK: - Contents

    private func title(forSpine index: Int) -> String {
        contents.first { $0.spineIndex == index }?.label ?? "Section \(index + 1)"
    }

    private static func makeContents(for epub: Epub) -> [ContentsEntry] {
        var result: [ContentsEntry] = []
        func walk(_ chapters: [ChapterItem], depth: Int) {
            for chapter in chapters {
                let label = chapter.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                result.append(ContentsEntry(
                    label: label.isEmpty ? "Untitled" : label,
                    depth: depth,
                    spineIndex: epub.spineIndex(for: chapter)
                ))
                walk(chapter.subChapters, depth: depth + 1)
            }
        }
        walk(epub.chapters, depth: 0)
        if result.isEmpty {
            result = epub.spines.indices.map { ContentsEntry(label: "Section \($0 + 1)", depth: 0, spineIndex: $0) }
        }
        return result
    }
}
