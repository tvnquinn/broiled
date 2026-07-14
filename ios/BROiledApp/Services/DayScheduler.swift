import Foundation
import SwiftData

/// The core state machine. DayLog is the source of truth for streaks - UserSettings'
/// successStreak/missStreak are a cache updated here, always trust a recompute from
/// DayLog over the cache if they ever drift. See the "database" discussion in the
/// project history: iOS background execution isn't guaranteed to run on schedule, so
/// `reconcile(...)` is what actually keeps the streak correct, not the notification
/// timing - call it on every launch/foreground before showing any UI.
@Observable
final class DayScheduler {
    private let context: ModelContext
    private let notifications = NotificationService.shared

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Reconciliation

    /// Walks forward from the last settled day to today, applying miss logic to any
    /// active day that was never resolved (app killed, background task never fired,
    /// user just didn't open the app). Call before rendering Home.
    func reconcile(habit: Habit, settings: UserSettings, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: Date())
        guard settings.hasOnboarded else { return }

        var cursor = settings.lastSettledDateKey.flatMap(DateKey.date(from:)) ?? today
        cursor = calendar.startOfDay(for: cursor)

        while cursor < today {
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            // Only settle days strictly before today - today's deadline may not have
            // passed yet, so it must be left for the live countdown/miss-check flow to
            // resolve, not blanket-marked missed the moment the app launches.
            if next < today {
                settleIfUnresolved(next, habit: habit, settings: settings, calendar: calendar)
            }
            cursor = next
        }
        settings.lastSettledDateKey = DateKey.string(from: today)

        // Pause over: clear the range and stamp today so Home shows the resume line
        // exactly one calendar day (whichever day the user next opens the app).
        if let end = settings.pauseEndDateKey, DateKey.string(from: today) > end {
            settings.pauseStartDateKey = nil
            settings.pauseEndDateKey = nil
            settings.resumeBannerDateKey = DateKey.string(from: today)
        }
        try? context.save()
    }

    private func settleIfUnresolved(_ day: Date, habit: Habit, settings: UserSettings, calendar: Calendar) {
        let key = DateKey.string(from: day)
        if let existing = fetchDayLog(key: key), existing.status != .pending {
            return // already resolved (completed, explicitly missed, or deferred to tomorrow)
        }
        // Paused days are exempt from miss logic entirely - no misses, streak frozen.
        guard !settings.isPaused(onKey: key) else { return }
        // A day counts as active if it's on the weekly schedule OR it carries a pushed
        // deadline override (push-to-tomorrow onto a rest day) - ghosting a deferred
        // workout still costs a miss.
        let carriesOverride = settings.todayDeadlineOverrideDateKey == key
        guard habit.isActiveDay(day, calendar: calendar) || carriesOverride else { return }
        recordMiss(dateKey: key, settings: settings)
    }

    // MARK: - Recording outcomes

    /// Returns false when the day was already resolved (nothing recorded) - callers use
    /// this to avoid writing duplicate history entries on double-logs.
    @discardableResult
    func recordSuccess(on date: Date, settings: UserSettings, viaHealthKit: Bool) -> Bool {
        let key = DateKey.string(from: date)
        let existing = fetchDayLog(key: key)
        guard existing?.status ?? .pending == .pending else { return false } // already resolved today - don't double-count the streak
        let log = existing ?? DayLog(dateKey: key)
        log.status = .completed
        log.verifiedByHealthKit = viaHealthKit
        if log.modelContext == nil { context.insert(log) }

        settings.successStreak += 1
        settings.missStreak = 0
        settings.isAbandoned = false
        notifications.cancelDeadlinePair()
        notifications.cancelMorningReckoning()
        try? context.save()
        return true
    }

    func recordMiss(dateKey: String, settings: UserSettings) {
        let existing = fetchDayLog(key: dateKey)
        guard existing?.status ?? .pending == .pending else { return } // already resolved - don't double-count the streak
        let log = existing ?? DayLog(dateKey: dateKey)
        log.status = .missed
        if log.modelContext == nil { context.insert(log) }

        settings.missStreak += 1
        settings.successStreak = 0
        if settings.missStreak >= 7 {
            settings.isAbandoned = true
            notifications.cancelAll()
        } else {
            notifications.scheduleMorningReckoning(missStreak: settings.missStreak)
        }
        try? context.save()
    }

    /// v0.2 push-to-tomorrow (rest-day tomorrow only): today drops out of streak math -
    /// not a success, not a miss - and the caller moves the deadline override onto
    /// tomorrow so the obligation follows. If tomorrow is a scheduled day, callers must
    /// use recordMiss instead (confirmed decision: pushing onto a scheduled day doesn't
    /// merge workouts, today just becomes a miss).
    func recordDeferred(dateKey: String) {
        let existing = fetchDayLog(key: dateKey)
        guard existing?.status ?? .pending == .pending else { return }
        let log = existing ?? DayLog(dateKey: dateKey)
        log.status = .deferred
        if log.modelContext == nil { context.insert(log) }
        try? context.save()
    }

    /// v0.2 Wave 2 rest-day flow: a workout on a non-scheduled day is recorded for
    /// history but leaves both streaks untouched - it's not a success (no streak
    /// advance) and obviously not a miss.
    @discardableResult
    func recordBonus(on date: Date, viaHealthKit: Bool) -> Bool {
        let key = DateKey.string(from: date)
        let existing = fetchDayLog(key: key)
        guard existing?.status ?? .pending == .pending else { return false }
        let log = existing ?? DayLog(dateKey: key)
        log.status = .bonus
        log.verifiedByHealthKit = viaHealthKit
        if log.modelContext == nil { context.insert(log) }
        try? context.save()
        return true
    }

    func recordSnooze(dateKey: String) -> Int {
        let log = fetchDayLog(key: dateKey) ?? DayLog(dateKey: dateKey)
        log.snoozeCount += 1
        if log.modelContext == nil { context.insert(log) }
        try? context.save()
        return log.snoozeCount
    }

    func reactivate(on date: Date, settings: UserSettings) {
        settings.isAbandoned = false
        settings.missStreak = 0
        recordSuccess(on: date, settings: settings, viaHealthKit: false)
    }

    // MARK: - Workout history (v0.2 Wave 2)

    /// One row per actual workout - multiple per day allowed (double sessions, bonus
    /// workouts). DayLog still owns the day's status; these are the history under it.
    func recordWorkoutEntry(on date: Date, type: String?, source: WorkoutSource, durationMinutes: Int) {
        let entry = WorkoutEntry(
            dateKey: DateKey.string(from: date),
            type: (type?.isEmpty == false ? type! : WorkoutEntry.genericType),
            source: source,
            durationMinutes: durationMinutes
        )
        context.insert(entry)
        try? context.save()
    }

    func workoutEntries(forKey key: String) -> [WorkoutEntry] {
        let descriptor = FetchDescriptor<WorkoutEntry>(predicate: #Predicate { $0.dateKey == key })
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Deadline scheduling

    func startCycle(deadline: Date, habit: Habit) {
        notifications.scheduleDeadlinePair(
            deadline: deadline,
            durationMinutes: habit.minDurationMinutes,
            workoutType: habit.workoutType(for: deadline)
        )
    }

    private func fetchDayLog(key: String) -> DayLog? {
        let descriptor = FetchDescriptor<DayLog>(predicate: #Predicate { $0.dateKey == key })
        return try? context.fetch(descriptor).first
    }

    func dayLog(for date: Date) -> DayLog? {
        fetchDayLog(key: DateKey.string(from: date))
    }
}
