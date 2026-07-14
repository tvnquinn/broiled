import SwiftUI
import SwiftData
import UserNotifications

@main
struct BROiledApp: App {
    let container: ModelContainer

    init() {
        // Set before any notification can arrive so the Yes/No miss-check actions are handled.
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        do {
            // UI tests launch with this flag so every run starts from a clean, in-memory
            // store instead of accumulating onboarding/streak state across test runs.
            if ProcessInfo.processInfo.arguments.contains("UI-TESTING") {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                container = try ModelContainer(for: Habit.self, DayLog.self, UserSettings.self, WorkoutEntry.self, RoastRecord.self, configurations: config)
            } else {
                container = try ModelContainer(for: Habit.self, DayLog.self, UserSettings.self, WorkoutEntry.self, RoastRecord.self)
            }
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
