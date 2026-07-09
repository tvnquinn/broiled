import Foundation
import SwiftData

enum DayStatus: String, Codable {
    case pending
    case completed
    case missed
}

@Model
final class DayLog {
    /// "yyyy-MM-dd" in the device's current calendar/timezone - the source of truth for streaks.
    @Attribute(.unique) var dateKey: String
    var status: DayStatus
    var verifiedByHealthKit: Bool
    var snoozeCount: Int
    var insultShown: String?

    init(
        dateKey: String,
        status: DayStatus = .pending,
        verifiedByHealthKit: Bool = false,
        snoozeCount: Int = 0,
        insultShown: String? = nil
    ) {
        self.dateKey = dateKey
        self.status = status
        self.verifiedByHealthKit = verifiedByHealthKit
        self.snoozeCount = snoozeCount
        self.insultShown = insultShown
    }
}

enum DateKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func string(from date: Date) -> String { formatter.string(from: date) }
    static func date(from string: String) -> Date? { formatter.date(from: string) }
}
