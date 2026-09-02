import SwiftUI
import SwiftData

@main
struct MoodLockApp: App {
    let modelContainer: ModelContainer = {
        let configuration = ModelConfiguration(url: AppGroup.modelStoreURL)
        return try! ModelContainer(for: MoodEntry.self, configurations: configuration)
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
