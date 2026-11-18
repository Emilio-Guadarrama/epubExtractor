import EpubExtractor
import SwiftUI

struct EpubReaderView: View {
    @Bindable var book: Book
    @AppStorage("readerFontSize") private var fontSize = 18.0

    @State private var epub: Epub?
    @State private var loadError: String?
    @State private var text = ""
    @State private var showingContents = false

    var body: some View {
        Group {
            if let epub {
                content(for: epub)
            } else if let loadError {
                ContentUnavailableView("Could Not Open Book", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else {
                ProgressView()
            }
        }
        .task { await load() }
    }

    private func content(for epub: Epub) -> some View {
        ReaderTextView(text: text.isEmpty ? "(This section has no text.)" : text, fontSize: fontSize)
            .safeAreaInset(edge: .bottom) { pager(for: epub) }
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
                ContentsSheet(epub: epub, currentIndex: book.spineIndex) { index in
                    showingContents = false
                    Task { await show(index, in: epub) }
                }
            }
    }

    private func pager(for epub: Epub) -> some View {
        HStack {
            Button("Previous", systemImage: "chevron.left") { Task { await show(book.spineIndex - 1, in: epub) } }
                .disabled(book.spineIndex <= 0)
            Spacer()
            Text("\(book.spineIndex + 1) of \(epub.spines.count)")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
            Button("Next", systemImage: "chevron.right") { Task { await show(book.spineIndex + 1, in: epub) } }
                .disabled(book.spineIndex >= epub.spines.count - 1)
        }
        .labelStyle(.iconOnly)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func load() async {
        guard epub == nil else { return }
        let directory = BookStorage.extractedURL(for: book.id)
        do {
            let opened = try await Task.detached { try EpubExtractor().open(extractedDirectory: directory) }.value
            guard !opened.spines.isEmpty else {
                loadError = "This book has no readable sections."
                return
            }
            epub = opened
            await show(book.spineIndex, in: opened)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func show(_ index: Int, in epub: Epub) async {
        let clamped = min(max(index, 0), epub.spines.count - 1)
        let spine = epub.spines[clamped]
        let loaded = await Task.detached { (try? epub.content(forSpine: spine)) ?? "" }.value
        if clamped != book.spineIndex {
            book.spineIndex = clamped
            book.textOffset = 0
        }
        text = loaded
    }
}

private struct ContentsSheet: View {
    struct Entry: Identifiable {
        let id = UUID()
        let label: String
        let depth: Int
        let spineIndex: Int?
    }

    let epub: Epub
    let currentIndex: Int
    let onSelect: (Int) -> Void

    private var entries: [Entry] {
        var result: [Entry] = []
        func walk(_ chapters: [ChapterItem], depth: Int) {
            for chapter in chapters {
                let label = chapter.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                result.append(Entry(label: label.isEmpty ? "Untitled" : label, depth: depth, spineIndex: epub.spineIndex(for: chapter)))
                walk(chapter.subChapters, depth: depth + 1)
            }
        }
        walk(epub.chapters, depth: 0)
        if result.isEmpty {
            result = epub.spines.indices.map { Entry(label: "Section \($0 + 1)", depth: 0, spineIndex: $0) }
        }
        return result
    }

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
