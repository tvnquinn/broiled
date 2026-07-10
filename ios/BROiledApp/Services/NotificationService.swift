import Foundation
import UserNotifications

enum NotificationID {
    static let reminder = "broiled.reminder"
    static let missCheck = "broiled.missCheck"
    static let morningReckoning = "broiled.morningReckoning"
    static let success = "broiled.success"
}

/// Schedules the notification pair for a deadline (T-30min reminder, then the actual
/// miss-check at deadline + duration + 30min) plus the next-day morning reckoning push
/// and the backhanded-celebration success push. See plan.md "Notification schedule (Phase 0)".
final class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Call whenever a deadline is (re)set - onboarding, a new day, or a snooze.
    func scheduleDeadlinePair(deadline: Date, durationMinutes: Int) {
        cancelDeadlinePair()

        let reminderDate = deadline.addingTimeInterval(-30 * 60)
        if reminderDate > Date() {
            schedule(
                id: NotificationID.reminder,
            title: "30 minutes left today",
            body: InsultPool.reminder.randomElement() ?? InsultPool.reminder[0],
                date: reminderDate
            )
        }

        let missCheckDate = deadline.addingTimeInterval(Double(durationMinutes * 60) + 30 * 60)
        schedule(
            id: NotificationID.missCheck,
            title: "you haven't worked out",
            body: InsultPool.missCheckMsg.randomElement() ?? InsultPool.missCheckMsg[0],
            date: missCheckDate
        )
    }

    func cancelDeadlinePair() {
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.reminder, NotificationID.missCheck])
    }

    /// Fires at 12:00 PM the day after a miss. Suppressed by the caller if the user
    /// already saw the in-app reckoning banner today - see DayScheduler.
    func scheduleMorningReckoning(missStreak: Int, calendar: Calendar = .current) {
        let (headline, line) = InsultPool.morningBanner(missStreak: missStreak)
        guard var comps = calendar.dateComponents([.year, .month, .day], from: Date()) as DateComponents? else { return }
        comps.hour = 12
        comps.minute = 0
        comps.second = 0
        guard let noonToday = calendar.date(from: comps) else { return }
        let fireDate = noonToday > Date() ? noonToday : (calendar.date(byAdding: .day, value: 1, to: noonToday) ?? noonToday)

        let content = UNMutableNotificationContent()
        content.title = headline
        content.body = line
        content.sound = .default
        let triggerComps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)
        let request = UNNotificationRequest(identifier: NotificationID.morningReckoning, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelMorningReckoning() {
        center.removePendingNotificationRequests(withIdentifiers: [NotificationID.morningReckoning])
    }

    /// Fires immediately - used when HealthKit catches a workout while backgrounded.
    func fireSuccessPush() {
        let content = UNMutableNotificationContent()
        content.title = InsultPool.successHeadline.randomElement() ?? InsultPool.successHeadline[0]
        content.body = InsultPool.successSub
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: NotificationID.success, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    private func schedule(id: String, title: String, body: String, date: Date, calendar: Calendar = .current) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }
}
