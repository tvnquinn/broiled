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

    /// v0.2 push-to-tomorrow: the override can now target a future day (the deadline's own
    /// day), so a rest-day tomorrow can carry today's pushed obligation. `todayOverride()`
    /// only returns it once the calendar reaches that day, and reconcile() treats the
    /// override's day as active so silently blowing the deferred workout still costs a miss.
    func setOverride(deadline: Date) {
        todayDeadlineOverride = deadline
        todayDeadlineOverrideDateKey = DateKey.string(from: deadline)
    }

    func todayOverride(calendar: Calendar = .current) -> Date? {
        guard todayDeadlineOverrideDateKey == DateKey.string(from: Date()) else { return nil }
        return todayDeadlineOverride
    }

    /// Drops any locked-in override for today so a freshly edited schedule takes effect
    /// immediately instead of being masked by a stale snooze/onboarding deadline.
    func clearTodayOverride() {
        todayDeadlineOverride = nil
        todayDeadlineOverrideDateKey = nil
    }

    /// Locked milestone ladder - see plan.md "Insult pool" section.
    var rankTitle: String { Self.rankTitle(forStreak: successStreak) }

    static func rankTitle(forStreak streak: Int) -> String {
        switch streak {
        case 365...: return "final boss unlocked"
        case 100..<365: return "it's canon now"
        case 30..<100: return "main character energy"
        case 14..<30: return "left no crumbs"
        case 7..<14: return "you ate"
        case 1..<7: return "fresh meat, not roasted yet"
        default: return "unranked"
        }
    }
}
