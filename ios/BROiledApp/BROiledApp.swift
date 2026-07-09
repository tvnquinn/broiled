import SwiftUI
import SwiftData

@main
struct BROiledApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Habit.self, DayLog.self, UserSettings.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
