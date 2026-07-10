import Foundation
import SwiftData

/// One active weekday's deadline. `weekday` follows Calendar convention: 1 = Sunday ... 7 = Saturday.
struct WeekdaySchedule: Codable, Identifiable, Equatable {
    var weekday: Int
    var hour: Int
    var minute: Int

    var id: Int { weekday }

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

    /// Today's deadline as a concrete Date, if today is an active day.
    func deadline(for date: Date, calendar: Calendar = .current) -> Date? {
        let weekday = calendar.component(.weekday, from: date)
        guard let entry = schedule.first(where: { $0.weekday == weekday }) else { return nil }
        return calendar.date(bySettingHour: entry.hour, minute: entry.minute, second: 0, of: date)
    }

    func isActiveDay(_ date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return schedule.contains { $0.weekday == weekday }
    }
}
