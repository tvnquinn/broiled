import Foundation
import ActivityKit

// Compiled into BOTH the app and the BROiledWidgets extension - the Live Activity
// attributes must be byte-identical on both sides, and the snapshot is the only
// channel the home-screen widget has into app state.

/// v0.2 Wave 3: the countdown Live Activity (lock screen + Dynamic Island).
struct BroiledActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var deadline: Date
        var workoutType: String?
        var streak: Int
    }
}

/// App -> widget data hand-off via the shared app-group container. The widget process
/// can't touch the SwiftData store, so the app writes a tiny snapshot on every state
/// change and pokes WidgetCenter.
enum WidgetSnapshot {
    static let suiteName = "group.com.quinnnguyen.broiled"
    private static let key = "broiled.widgetSnapshot"

    enum DayState: String, Codable {
        case pending    // countdown running
        case completed  // locked in
        case rest       // no deadline today
        case paused
        case silence    // 7-day give-up
    }

    struct Data: Codable {
        var state: DayState
        var deadline: Date?
        var workoutType: String?
        var streak: Int
        var bestStreak: Int
    }

    static func write(_ data: Data) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: key)
    }

    static func read() -> Data? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let encoded = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Data.self, from: encoded)
    }
}
