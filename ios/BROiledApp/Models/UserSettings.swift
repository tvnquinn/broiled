import Foundation
import SwiftData

@Model
final class UserSettings {
    var successStreak: Int
    var missStreak: Int
    var isAbandoned: Bool
    /// The last calendar day the reconciliation pass fully settled, as a DateKey string.
    /// Nil until onboarding completes.
    var lastSettledDateKey: String?
    var hasOnboarded: Bool

    /// Today's active deadline once it's been snoozed away from the base weekly schedule.
    /// Scoped by date key so a stale override never leaks into a new calendar day - see
    /// HomeView.deadline, which only trusts this when the date key matches today.
    var todayDeadlineOverride: Date?
    var todayDeadlineOverrideDateKey: String?

    init(
        successStreak: Int = 0,
        missStreak: Int = 0,
        isAbandoned: Bool = false,
        lastSettledDateKey: String? = nil,
        hasOnboarded: Bool = false
    ) {
        self.successStreak = successStreak
        self.missStreak = missStreak
        self.isAbandoned = isAbandoned
        self.lastSettledDateKey = lastSettledDateKey
        self.hasOnboarded = hasOnboarded
    }

    func setTodayOverride(_ date: Date) {
        todayDeadlineOverride = date
        todayDeadlineOverrideDateKey = DateKey.string(from: Date())
    }

    func todayOverride(calendar: Calendar = .current) -> Date? {
        guard todayDeadlineOverrideDateKey == DateKey.string(from: Date()) else { return nil }
        return todayDeadlineOverride
    }

    /// Locked milestone ladder - see plan.md "Insult pool" section.
    var rankTitle: String {
        switch successStreak {
        case 365...: return "final boss unlocked"
        case 100..<365: return "it's canon now"
        case 30..<100: return "you're giving main character energy"
        case 14..<30: return "left no crumbs"
        case 7..<14: return "you ate"
        case 1..<7: return "fresh meat, not roasted yet"
        default: return "unranked"
        }
    }
}
