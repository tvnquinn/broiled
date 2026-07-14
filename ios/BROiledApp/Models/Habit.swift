import Foundation
import SwiftData

/// One active weekday's deadline. `weekday` follows Calendar convention: 1 = Sunday ... 7 = Saturday.
struct WeekdaySchedule: Codable, Identifiable, Equatable {
    var weekday: Int
    var hour: Int
    var minute: Int
    /// v0.2 Wave 2: optional per-day workout type ("run", "lift"...). Optional keeps
    /// previously-stored schedule JSON (which lacks the key) decoding cleanly, and the
    /// `= nil` default keeps the memberwise init compatible with existing call sites.
    var workoutType: String? = nil
    /// Duration belongs to this planned workout, not to the whole habit. Optional keeps
    /// schedule JSON from pre-multi-workout builds decoding; legacy rows fall back to
    /// Habit.minDurationMinutes until the user next saves the schedule.
    var durationMinutes: Int? = nil

    /// Schedule editors use their own UUID-backed drafts. This value is only a stable
    /// read identity for display and deliberately includes all instance fields so two
    /// workouts on the same weekday no longer collide.
    var id: String {
        "\(weekday)-\(hour)-\(minute)-\(workoutType ?? "any")-\(durationMinutes ?? 0)"
    }

    func resolvedDuration(fallback: Int) -> Int {
        durationMinutes ?? fallback
    }

    /// Display/storage order is always Monday-first (MTWTFSS), independent of Calendar's
    /// Sunday=1 convention and independent of the order days were selected in - a Swift
    /// `Set<Int>` has no stable iteration order, so anything built directly from one needs
    /// this to avoid landing in effectively-random order.
    static func mondayFirstRank(_ weekday: Int) -> Int { (weekday + 5) % 7 }

    static func sortedMondayFirst(_ weekdays: some Sequence<Int>) -> [Int] {
        weekdays.sorted { mondayFirstRank($0) < mondayFirstRank($1) }
    }
}

@Model
final class Habit {
    var name: String
    var minDurationMinutes: Int
    /// JSON-encoded [WeekdaySchedule]. Stored as Data rather than a native SwiftData
    /// relationship/dictionary to avoid relying on SwiftData's evolving support for
    /// nested Codable collections - this is guaranteed to work on any iOS 17+ SwiftData version.
    private var scheduleData: Data

    init(name: String = "Workout", minDurationMinutes: Int = 30, schedule: [WeekdaySchedule] = []) {
        self.name = name
        self.minDurationMinutes = minDurationMinutes
        self.scheduleData = (try? JSONEncoder().encode(schedule)) ?? Data()
    }

    var schedule: [WeekdaySchedule] {
        get { (try? JSONDecoder().decode([WeekdaySchedule].self, from: scheduleData)) ?? [] }
        set { scheduleData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    /// The day's final planned workout time. Consequences wait until this last chance:
    /// completing any one planned workout satisfies the day, so missing an earlier
    /// session must never settle the day as a miss while another is still ahead.
    func deadline(for date: Date, calendar: Calendar = .current) -> Date? {
        guard let entry = scheduledWorkouts(for: date, calendar: calendar).last else { return nil }
        return calendar.date(bySettingHour: entry.hour, minute: entry.minute, second: 0, of: date)
    }

    func scheduledWorkouts(for date: Date, calendar: Calendar = .current) -> [WeekdaySchedule] {
        let weekday = calendar.component(.weekday, from: date)
        return schedule
            .filter { $0.weekday == weekday }
            .sorted { lhs, rhs in
                (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
            }
    }

    /// The next planned workout for Home/Live Activity. After all planned times pass,
    /// keep showing the final one at 0:00 until the user logs or snoozes.
    func displayWorkout(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> WeekdaySchedule? {
        let entries = scheduledWorkouts(for: date, calendar: calendar)
        return entries.first { entry in
            guard let deadline = calendar.date(bySettingHour: entry.hour, minute: entry.minute, second: 0, of: date) else { return false }
            return deadline > now
        } ?? entries.last
    }

    func isActiveDay(_ date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return schedule.contains { $0.weekday == weekday }
    }

    /// The scheduled workout type for a date, if that day is active and has one set.
    func workoutType(for date: Date, calendar: Calendar = .current) -> String? {
        displayWorkout(for: date, now: date, calendar: calendar)?.workoutType
    }

    /// Any qualifying workout satisfies a multi-workout day, so HealthKit uses the
    /// shortest planned duration as its threshold.
    func minimumQualifyingDuration(for date: Date, calendar: Calendar = .current) -> Int {
        scheduledWorkouts(for: date, calendar: calendar)
            .map { $0.resolvedDuration(fallback: minDurationMinutes) }
            .min() ?? minDurationMinutes
    }

    func finalWorkoutDuration(for date: Date, calendar: Calendar = .current) -> Int {
        scheduledWorkouts(for: date, calendar: calendar).last?
            .resolvedDuration(fallback: minDurationMinutes) ?? minDurationMinutes
    }
}
