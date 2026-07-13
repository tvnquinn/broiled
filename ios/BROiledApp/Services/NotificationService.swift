import Foundation
import UserNotifications

enum NotificationID {
    static let reminder = "broiled.reminder"
    static let missCheck = "broiled.missCheck"
    static let morningReckoning = "broiled.morningReckoning"
    static let success = "broiled.success"
}

enum NotificationAction {
    static let yesWorkingOut = "broiled.action.yesWorkingOut"
    static let noNotWorkingOut = "broiled.action.noNotWorkingOut"
}

enum NotificationCategoryID {
    static let missCheck = "broiled.category.missCheck"
}

/// Schedules the notification pair for a deadline (T-30min reminder, then the actual
/// miss-check at deadline + duration + 30min) plus the next-day morning reckoning push
/// and the backhanded-celebration success push. See plan.md "Notification schedule (Phase 0)".
final class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    /// Persisted so the "yes, i'm working out" grace path can reschedule the miss-check
    /// for a sensible amount of time later without needing the Habit passed into the
    /// notification delegate.
    private let durationKey = "broiled.lastMissCheckDurationMinutes"

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        registerCategories()
    }

    /// The miss-check is an interactive "are you working out?" notification with Yes/No
    /// actions rather than a flat accusation. See NotificationDelegate for what each does.
    func registerCategories() {
        let yes = UNNotificationAction(
            identifier: NotificationAction.yesWorkingOut,
            title: InsultPool.missCheckYesAction,
            options: []
        )
        let no = UNNotificationAction(
            identifier: NotificationAction.noNotWorkingOut,
            title: InsultPool.missCheckNoAction,
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: NotificationCategoryID.missCheck,
            actions: [yes, no],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    /// Call whenever a deadline is (re)set - onboarding, a new day, or a snooze.
    func scheduleDeadlinePair(deadline: Date, durationMinutes: Int) {
        cancelDeadlinePair()
        UserDefaults.standard.set(durationMinutes, forKey: durationKey)

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
        scheduleMissCheck(date: missCheckDate)
    }

    private func scheduleMissCheck(date: Date) {
        schedule(
            id: NotificationID.missCheck,
            title: InsultPool.missCheckQuestion,
            body: InsultPool.missCheckQuestionBody,
            date: date,
            categoryId: NotificationCategoryID.missCheck
        )
    }

    /// "yes, i'm working out" grace path: re-ask after roughly one more workout's worth of
    /// time, so HealthKit has a chance to log the finished session before we check again.
    func rescheduleMissCheckAfterGrace() {
        let minutes = max(UserDefaults.standard.integer(forKey: durationKey), 30)
        let date = Date().addingTimeInterval(Double(minutes * 60))
        scheduleMissCheck(date: date)
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

    private func schedule(id: String, title: String, body: String, date: Date, categoryId: String? = nil, calendar: Calendar = .current) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let categoryId { content.categoryIdentifier = categoryId }
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }
}

/// Handles taps on the interactive miss-check notification. Set as the notification
/// center's delegate in BROiledApp.init so it's live before any notification arrives.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    /// Posted when the user answers "no" (or taps the notification body) so RootView can
    /// open the snooze/quit sheet.
    static let didDeclineWorkout = Notification.Name("broiled.didDeclineWorkout")

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case NotificationAction.yesWorkingOut:
            // Grace: don't penalize, just re-ask after another workout's worth of time.
            NotificationService.shared.rescheduleMissCheckAfterGrace()
        case NotificationAction.noNotWorkingOut, UNNotificationDefaultActionIdentifier:
            NotificationCenter.default.post(name: Self.didDeclineWorkout, object: nil)
        default:
            break
        }
        completionHandler()
    }

    /// Show the notification even if the app is foregrounded, so the Yes/No prompt is
    /// never silently swallowed.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
