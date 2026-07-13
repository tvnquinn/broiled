import XCTest
import SwiftData
@testable import broiled

final class BroiledTests: XCTestCase {

    // MARK: - WeekdaySchedule ordering

    func testMondayFirstRank() {
        XCTAssertEqual(WeekdaySchedule.mondayFirstRank(2), 0) // Mon
        XCTAssertEqual(WeekdaySchedule.mondayFirstRank(3), 1) // Tue
        XCTAssertEqual(WeekdaySchedule.mondayFirstRank(4), 2) // Wed
        XCTAssertEqual(WeekdaySchedule.mondayFirstRank(5), 3) // Thu
        XCTAssertEqual(WeekdaySchedule.mondayFirstRank(6), 4) // Fri
        XCTAssertEqual(WeekdaySchedule.mondayFirstRank(7), 5) // Sat
        XCTAssertEqual(WeekdaySchedule.mondayFirstRank(1), 6) // Sun
    }

    /// Regression test: building the schedule array by mapping a Swift `Set<Int>` directly
    /// has undefined iteration order, which is why the app once showed "Fri, Thu, Mon, Wed"
    /// instead of selection order. sortedMondayFirst must always produce Mon...Sun order.
    func testSortedMondayFirstOrdersRegardlessOfInputOrder() {
        let scrambled: Set<Int> = [6, 5, 2, 4] // Fri, Thu, Mon, Wed
        XCTAssertEqual(WeekdaySchedule.sortedMondayFirst(scrambled), [2, 4, 5, 6]) // Mon, Wed, Thu, Fri
    }

    func testSortedMondayFirstWithFullWeek() {
        XCTAssertEqual(WeekdaySchedule.sortedMondayFirst(1...7), [2, 3, 4, 5, 6, 7, 1])
    }

    // MARK: - Habit deadline / active day

    func testDeadlineForActiveDay() {
        let habit = Habit(schedule: [WeekdaySchedule(weekday: 2, hour: 18, minute: 30)]) // Monday 6:30pm
        let calendar = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 6 // a Monday
        let monday = calendar.date(from: comps)!

        let deadline = habit.deadline(for: monday, calendar: calendar)
        XCTAssertNotNil(deadline)
        let deadlineComps = calendar.dateComponents([.hour, .minute], from: deadline!)
        XCTAssertEqual(deadlineComps.hour, 18)
        XCTAssertEqual(deadlineComps.minute, 30)
    }

    func testDeadlineNilAndInactiveForNonScheduledDay() {
        let habit = Habit(schedule: [WeekdaySchedule(weekday: 2, hour: 18, minute: 0)]) // only Monday
        let calendar = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 7 // a Tuesday
        let tuesday = calendar.date(from: comps)!

        XCTAssertNil(habit.deadline(for: tuesday, calendar: calendar))
        XCTAssertFalse(habit.isActiveDay(tuesday, calendar: calendar))
    }

    // MARK: - UserSettings today override

    func testTodayOverrideReturnsValueSetToday() {
        let settings = UserSettings()
        let deadline = Date().addingTimeInterval(3600)
        settings.setTodayOverride(deadline)
        XCTAssertEqual(settings.todayOverride(), deadline)
    }

    func testTodayOverrideIgnoresStaleDateKey() {
        let settings = UserSettings()
        settings.setTodayOverride(Date())
        settings.todayDeadlineOverrideDateKey = "2000-01-01" // simulate a leaked override from a prior day
        XCTAssertNil(settings.todayOverride())
    }

    /// Regression test: editing today's schedule was previously masked by a stale
    /// locked-in deadline from onboarding/snooze because nothing cleared the override.
    func testClearTodayOverride() {
        let settings = UserSettings()
        settings.setTodayOverride(Date())
        settings.clearTodayOverride()
        XCTAssertNil(settings.todayOverride())
        XCTAssertNil(settings.todayDeadlineOverride)
        XCTAssertNil(settings.todayDeadlineOverrideDateKey)
    }

    // MARK: - UserSettings rank ladder

    func testRankTitleThresholds() {
        let settings = UserSettings()
        let cases: [(Int, String)] = [
            (0, "unranked"),
            (1, "fresh meat, not roasted yet"),
            (6, "fresh meat, not roasted yet"),
            (7, "you ate"),
            (13, "you ate"),
            (14, "left no crumbs"),
            (29, "left no crumbs"),
            (30, "main character energy"),
            (99, "main character energy"),
            (100, "it's canon now"),
            (364, "it's canon now"),
            (365, "final boss unlocked"),
        ]
        for (streak, expected) in cases {
            settings.successStreak = streak
            XCTAssertEqual(settings.rankTitle, expected, "streak \(streak)")
        }
    }

    // MARK: - DateKey

    func testDateKeyRoundTrip() throws {
        let date = Date()
        let key = DateKey.string(from: date)
        let roundTripped = try XCTUnwrap(DateKey.date(from: key))
        XCTAssertEqual(DateKey.string(from: roundTripped), key)
    }

    // MARK: - DayScheduler

    @MainActor
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([Habit.self, UserSettings.self, DayLog.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// Regression test for the bug where tapping "I've locked in today" twice (or the
    /// automatic HealthKit check firing after a manual log) incremented the streak twice
    /// for the same real calendar day.
    @MainActor
    func testRecordSuccessDoesNotDoubleCountSameDay() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)
        let settings = UserSettings()
        context.insert(settings)

        scheduler.recordSuccess(on: Date(), settings: settings, viaHealthKit: false)
        XCTAssertEqual(settings.successStreak, 1)

        scheduler.recordSuccess(on: Date(), settings: settings, viaHealthKit: true)
        XCTAssertEqual(settings.successStreak, 1)
    }

    @MainActor
    func testRecordMissDoesNotDoubleCountSameDay() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)
        let settings = UserSettings()
        context.insert(settings)
        let key = DateKey.string(from: Date())

        scheduler.recordMiss(dateKey: key, settings: settings)
        XCTAssertEqual(settings.missStreak, 1)

        scheduler.recordMiss(dateKey: key, settings: settings)
        XCTAssertEqual(settings.missStreak, 1)
    }

    @MainActor
    func testRecordSuccessResetsMissStreakAndClearsAbandoned() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)
        let settings = UserSettings()
        settings.missStreak = 3
        settings.isAbandoned = true
        context.insert(settings)

        scheduler.recordSuccess(on: Date(), settings: settings, viaHealthKit: false)

        XCTAssertEqual(settings.missStreak, 0)
        XCTAssertEqual(settings.successStreak, 1)
        XCTAssertFalse(settings.isAbandoned)
    }

    @MainActor
    func testRecordMissMarksAbandonedAtSevenMisses() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)
        let settings = UserSettings()
        context.insert(settings)
        let calendar = Calendar(identifier: .gregorian)

        for offset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: -offset, to: Date())!
            scheduler.recordMiss(dateKey: DateKey.string(from: day), settings: settings)
        }

        XCTAssertEqual(settings.missStreak, 7)
        XCTAssertTrue(settings.isAbandoned)
    }

    /// Regression test for the reconcile bug: it used to walk its catch-up loop through
    /// *today* as well as past days, so opening the app on any scheduled day immediately
    /// recorded that day as missed - hours before the deadline even arrived, and before
    /// the user had any chance to log a workout.
    @MainActor
    func testReconcileDoesNotMarkTodayAsMissed() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)
        let calendar = Calendar(identifier: .gregorian)

        let habit = Habit(schedule: (1...7).map { WeekdaySchedule(weekday: $0, hour: 18, minute: 0) }) // every day
        let settings = UserSettings(hasOnboarded: true)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        settings.lastSettledDateKey = DateKey.string(from: yesterday)
        context.insert(habit)
        context.insert(settings)

        scheduler.reconcile(habit: habit, settings: settings, calendar: calendar)

        XCTAssertEqual(settings.missStreak, 0, "today must not be pre-emptively marked missed")
        XCTAssertNil(scheduler.dayLog(for: Date()))
    }

    /// Past unresolved active days should still be caught up as missed.
    @MainActor
    func testReconcileMarksPastUnresolvedActiveDaysAsMissed() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)
        let calendar = Calendar(identifier: .gregorian)

        let habit = Habit(schedule: (1...7).map { WeekdaySchedule(weekday: $0, hour: 18, minute: 0) }) // every day
        let settings = UserSettings(hasOnboarded: true)
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: calendar.startOfDay(for: Date()))!
        settings.lastSettledDateKey = DateKey.string(from: threeDaysAgo)
        context.insert(habit)
        context.insert(settings)

        scheduler.reconcile(habit: habit, settings: settings, calendar: calendar)

        // threeDaysAgo -> 2 days ago, 1 day ago get caught up; today is left alone.
        XCTAssertEqual(settings.missStreak, 2)
        XCTAssertNil(scheduler.dayLog(for: Date()))
    }

    /// A legitimate success logged after reconcile has run must still count - this is the
    /// scenario the reconcile bug broke: reconcile would mark today missed, then the
    /// double-completion guard in recordSuccess would silently swallow the real "yes!" tap.
    @MainActor
    func testSuccessAfterReconcileStillCounts() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)
        let calendar = Calendar(identifier: .gregorian)

        let habit = Habit(schedule: (1...7).map { WeekdaySchedule(weekday: $0, hour: 18, minute: 0) })
        let settings = UserSettings(hasOnboarded: true)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        settings.lastSettledDateKey = DateKey.string(from: yesterday)
        context.insert(habit)
        context.insert(settings)

        scheduler.reconcile(habit: habit, settings: settings, calendar: calendar)
        scheduler.recordSuccess(on: Date(), settings: settings, viaHealthKit: false)

        XCTAssertEqual(settings.successStreak, 1)
        XCTAssertEqual(scheduler.dayLog(for: Date())?.status, .completed)
    }
}

/// v0.2 Wave 1 coverage: banner determinism, snooze escalation tiers, push-to-tomorrow
/// deferral mechanics, the ghosted-deferral miss, and the de-chef copy sweep.
final class Wave1Tests: XCTestCase {

    // MARK: - Morning banner (flicker-bug regression)

    /// Regression test for the real-device bug where the 2+ day banner cycled through the
    /// whole roast pool every second (HomeView re-renders per tick and morningBanner used
    /// .randomElement()). The line must be a pure function of the miss streak.
    func testMorningBannerIsDeterministicPerStreak() {
        for streak in [1, 2, 3, 4, 5, 6] {
            let first = InsultPool.morningBanner(missStreak: streak)
            for _ in 0..<20 {
                let again = InsultPool.morningBanner(missStreak: streak)
                XCTAssertEqual(again.headline, first.headline, "streak \(streak)")
                XCTAssertEqual(again.line, first.line, "streak \(streak) line must not re-roll")
            }
        }
    }

    func testMorningBannerTiers() {
        let one = InsultPool.morningBanner(missStreak: 1)
        XCTAssertEqual(one.headline, "you skipped yesterday")
        XCTAssertEqual(one.line, InsultPool.reckoningCanonical)

        for streak in [2, 3] {
            let banner = InsultPool.morningBanner(missStreak: streak)
            XCTAssertEqual(banner.headline, "\(streak) days missed")
            XCTAssertTrue(InsultPool.streak23.contains(banner.line), "streak \(streak) pulls from streak23")
        }

        for streak in [4, 5, 6] {
            let banner = InsultPool.morningBanner(missStreak: streak)
            XCTAssertEqual(banner.headline, "\(streak) days missed")
            XCTAssertTrue(InsultPool.streak46.contains(banner.line), "streak \(streak) pulls from streak46")
        }
    }

    // MARK: - Snooze escalation tiers

    func testSnoozeLineTiers() {
        for _ in 0..<20 {
            XCTAssertTrue(InsultPool.snoozeMild.contains(InsultPool.snoozeLine(forSnoozeCount: 1)))
            XCTAssertTrue(InsultPool.snoozeSpicy.contains(InsultPool.snoozeLine(forSnoozeCount: 2)))
            XCTAssertTrue(InsultPool.snoozeSpicy.contains(InsultPool.snoozeLine(forSnoozeCount: 3)))
            XCTAssertTrue(InsultPool.snoozeNuclear.contains(InsultPool.snoozeLine(forSnoozeCount: 4)))
            XCTAssertTrue(InsultPool.snoozeNuclear.contains(InsultPool.snoozeLine(forSnoozeCount: 9)))
        }
    }

    // MARK: - De-chef sweep guard

    /// Locks in the v0.2 copy decision: no chef-persona addressing anywhere in the pools.
    func testNoChefReferencesAnywhere() {
        let allLines: [String] = InsultPool.zeroStreak + InsultPool.reminder
            + InsultPool.missCheckMsg + InsultPool.snoozeMild + InsultPool.snoozeSpicy
            + InsultPool.snoozeNuclear + InsultPool.reckoning + InsultPool.streak23
            + InsultPool.streak46 + InsultPool.reactivation + InsultPool.successHeadline
            + InsultPool.successAlternates + InsultPool.tomorrowInsults
            + [InsultPool.onboardingHeadline, InsultPool.missCheckQuestion,
               InsultPool.missCheckQuestionBody, InsultPool.missCheckYesAction,
               InsultPool.silenceHeadline, InsultPool.silenceSub, InsultPool.successSub,
               InsultPool.gutCheckPrompt, InsultPool.gutCheckQuestion,
               InsultPool.snoozeSheetTitle, InsultPool.tomorrowOptionLabel,
               InsultPool.tomorrowAlreadyScheduledWarning]
        for line in allLines {
            XCTAssertFalse(line.lowercased().contains("chef"), "chef reference survived the sweep: \"\(line)\"")
        }
    }

    // MARK: - Push-to-tomorrow deferral

    @MainActor
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([Habit.self, UserSettings.self, DayLog.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    @MainActor
    func testRecordDeferredPreservesStreaksAndSetsStatus() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)
        let settings = UserSettings()
        settings.successStreak = 4
        settings.missStreak = 0
        context.insert(settings)

        let key = DateKey.string(from: Date())
        scheduler.recordDeferred(dateKey: key)

        XCTAssertEqual(scheduler.dayLog(for: Date())?.status, .deferred)
        XCTAssertEqual(settings.successStreak, 4, "deferring must not touch the success streak")
        XCTAssertEqual(settings.missStreak, 0, "deferring is not a miss")
    }

    @MainActor
    func testRecordDeferredDoesNotOverwriteResolvedDay() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)
        let settings = UserSettings()
        context.insert(settings)

        scheduler.recordSuccess(on: Date(), settings: settings, viaHealthKit: false)
        scheduler.recordDeferred(dateKey: DateKey.string(from: Date()))

        XCTAssertEqual(scheduler.dayLog(for: Date())?.status, .completed, "a completed day must stay completed")
    }

    /// A deferred day must NOT be settled as a miss by the catch-up pass.
    @MainActor
    func testReconcileSkipsDeferredDay() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)
        let calendar = Calendar(identifier: .gregorian)

        let habit = Habit(schedule: (1...7).map { WeekdaySchedule(weekday: $0, hour: 18, minute: 0) })
        let settings = UserSettings(hasOnboarded: true)
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: Date()))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        settings.lastSettledDateKey = DateKey.string(from: twoDaysAgo)
        context.insert(habit)
        context.insert(settings)
        context.insert(DayLog(dateKey: DateKey.string(from: yesterday), status: .deferred))

        scheduler.reconcile(habit: habit, settings: settings, calendar: calendar)

        XCTAssertEqual(settings.missStreak, 0, "a deferred day is not a miss")
        XCTAssertEqual(scheduler.dayLog(for: yesterday)?.status, .deferred)
    }

    /// Ghosting the deferred obligation still costs a miss: a rest day that carries the
    /// pushed deadline override counts as active for reconciliation.
    @MainActor
    func testReconcileMissesGhostedDeferredDay() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)
        let calendar = Calendar(identifier: .gregorian)

        let habit = Habit(schedule: []) // no scheduled days at all - pure rest week
        let settings = UserSettings(hasOnboarded: true)
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: Date()))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        settings.lastSettledDateKey = DateKey.string(from: twoDaysAgo)
        // Simulate push-to-tomorrow having moved the obligation onto yesterday - then the
        // user never opened the app again.
        settings.todayDeadlineOverride = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday)
        settings.todayDeadlineOverrideDateKey = DateKey.string(from: yesterday)
        context.insert(habit)
        context.insert(settings)

        scheduler.reconcile(habit: habit, settings: settings, calendar: calendar)

        XCTAssertEqual(settings.missStreak, 1, "ghosting the deferred workout must cost a miss")
        XCTAssertEqual(scheduler.dayLog(for: yesterday)?.status, .missed)
    }

    // MARK: - Deadline override targeting

    /// setOverride keys the override to the deadline's own day, so a pushed-to-tomorrow
    /// deadline must not leak into today's countdown.
    func testSetOverrideForTomorrowIsInvisibleToday() throws {
        let settings = UserSettings()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let tomorrowDeadline = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: tomorrow)!

        settings.setOverride(deadline: tomorrowDeadline)

        XCTAssertNil(settings.todayOverride(), "tomorrow's pushed deadline must not show today")
        XCTAssertEqual(settings.todayDeadlineOverrideDateKey, DateKey.string(from: tomorrow))
    }

    // MARK: - Milestone rank (static accessor used by the success push)

    func testStaticRankTitleMatchesInstance() {
        let settings = UserSettings()
        for streak in [0, 1, 7, 14, 30, 100, 365] {
            settings.successStreak = streak
            XCTAssertEqual(UserSettings.rankTitle(forStreak: streak), settings.rankTitle)
        }
    }
}
