import SwiftData
import SwiftUI

@main
struct EpubReaderApp: App {
    /// Local store only. Cross-device sync goes through a Firebase `SyncService` (Phase 3), not CloudKit.
    private let container: ModelContainer = {
        do {
            return try ModelContainer(for: Book.self, configurations: ModelConfiguration(cloudKitDatabase: .none))
        } catch {
            fatalError("Could not create the library store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            LibraryView()
        }
        .modelContainer(container)
    }
}
