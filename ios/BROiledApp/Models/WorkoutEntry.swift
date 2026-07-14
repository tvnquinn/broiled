import Foundation
import SwiftData

enum WorkoutSource: String, Codable {
    case healthKit
    case manual
}

/// v0.2 Wave 2: one logged workout. Multiple entries per day are allowed (double
/// sessions, bonus workouts) - `DayLog` still owns the day's *status*; entries are the
/// history underneath it.
@Model
final class WorkoutEntry {
    var dateKey: String
    /// Display name, lowercase to match the app voice: "run", "lift", "yoga"...
    /// HealthKit-detected entries carry their real activity type.
    var type: String
    var sourceRaw: String
    var durationMinutes: Int
    var note: String?
    var loggedAt: Date

    var source: WorkoutSource { WorkoutSource(rawValue: sourceRaw) ?? .manual }

    init(
        dateKey: String,
        type: String,
        source: WorkoutSource,
        durationMinutes: Int,
        note: String? = nil,
        loggedAt: Date = Date()
    ) {
        self.dateKey = dateKey
        self.type = type
        self.sourceRaw = source.rawValue
        self.durationMinutes = durationMinutes
        self.note = note
        self.loggedAt = loggedAt
    }

    /// The default type when nothing more specific is known - schedule day without a
    /// type, or a manual log.
    static let genericType = "workout"

    /// Common types for the schedule picker - Apple-Fitness-style list, plus free text
    /// in the editor for anything else.
    static let commonTypes = ["lift", "run", "cycle", "swim", "yoga", "walk", "HIIT", "row", "climb", "sport"]
}
