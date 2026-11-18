import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Book.addedAt, order: .reverse) private var books: [Book]

    @State private var showingImporter = false
    @State private var isImporting = false
    @State private var failures: [ImportFailure] = []

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 20)]

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty && !isImporting {
                    ContentUnavailableView {
                        Label("No Books Yet", systemImage: "books.vertical")
                    } description: {
                        Text("Import an EPUB or PDF to start reading.")
                    } actions: {
                        Button("Import Books") { showingImporter = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    grid
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: Book.self) { ReaderView(book: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if isImporting {
                        ProgressView()
                    } else {
                        Button("Import", systemImage: "plus") { showingImporter = true }
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.epub, .pdf],
                allowsMultipleSelection: true
            ) { result in
                guard case .success(let urls) = result else { return }
                Task {
                    isImporting = true
                    failures = await LibraryImporter.importFiles(urls, into: context)
                    isImporting = false
                }
            }
            .alert("Some files could not be imported", isPresented: failuresBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failures.map { "\($0.fileName): \($0.message)" }.joined(separator: "\n"))
            }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(books) { book in
                    NavigationLink(value: book) {
                        BookCardView(book: book)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) { delete(book) }
                    }
                }
            }
            .padding(20)
        }
        .background(.background)
    }

    private var failuresBinding: Binding<Bool> {
        Binding(get: { !failures.isEmpty }, set: { if !$0 { failures = [] } })
    }

    private func delete(_ book: Book) {
        BookStorage.delete(book)
        context.delete(book)
        try? context.save()
    }
}
