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
        let schema = Schema([Habit.self, UserSettings.self, DayLog.self, WorkoutEntry.self, RoastRecord.self])
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
            + [InsultPool.restDayLabel, InsultPool.restDaySub, InsultPool.bonusButton,
               InsultPool.bonusGutCheckQuestion, InsultPool.bonusLoggedLine,
               InsultPool.pausedLabel, InsultPool.pausedLine, InsultPool.resumeLine]
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
        let schema = Schema([Habit.self, UserSettings.self, DayLog.self, WorkoutEntry.self, RoastRecord.self])
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

/// v0.2 Wave 2 coverage: rest-day bonus workouts, pause mode, workout types.
final class Wave2Tests: XCTestCase {

    @MainActor
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([Habit.self, UserSettings.self, DayLog.self, WorkoutEntry.self, RoastRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: - Workout types

    /// Schedule JSON stored before workoutType existed must keep decoding (the field is
    /// optional precisely for this).
    func testScheduleDecodesLegacyJSONWithoutWorkoutType() throws {
        let legacy = #"[{"weekday":2,"hour":18,"minute":30}]"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([WeekdaySchedule].self, from: legacy)
        XCTAssertEqual(decoded.first?.weekday, 2)
        XCTAssertNil(decoded.first?.workoutType)
        XCTAssertNil(decoded.first?.durationMinutes)
    }

    func testMultiplePlannedWorkoutsUseNextForDisplayAndLastForConsequences() throws {
        let habit = Habit(minDurationMinutes: 30, schedule: [
            WeekdaySchedule(weekday: 2, hour: 8, minute: 0, workoutType: "run", durationMinutes: 25),
            WeekdaySchedule(weekday: 2, hour: 18, minute: 0, workoutType: "lift", durationMinutes: 60),
        ])
        let calendar = Calendar(identifier: .gregorian)
        let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 6, hour: 0)))
        let noon = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 6, hour: 12)))

        XCTAssertEqual(habit.scheduledWorkouts(for: monday, calendar: calendar).count, 2)
        XCTAssertEqual(habit.displayWorkout(for: monday, now: noon, calendar: calendar)?.workoutType, "lift")
        XCTAssertEqual(calendar.component(.hour, from: try XCTUnwrap(habit.deadline(for: monday, calendar: calendar))), 18)
        XCTAssertEqual(habit.minimumQualifyingDuration(for: monday, calendar: calendar), 25)
        XCTAssertEqual(habit.finalWorkoutDuration(for: monday, calendar: calendar), 60)
    }

    @MainActor
    func testOneSuccessSatisfiesMultiWorkoutDayAndCannotBecomeMiss() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)
        let settings = UserSettings()
        context.insert(settings)
        let key = DateKey.string(from: Date())

        XCTAssertTrue(scheduler.recordSuccess(on: Date(), settings: settings, viaHealthKit: false))
        scheduler.recordWorkoutEntry(on: Date(), type: "run", source: .manual, durationMinutes: 25)
        scheduler.recordMiss(dateKey: key, settings: settings)
        scheduler.recordWorkoutEntry(on: Date(), type: "lift", source: .manual, durationMinutes: 60)

        XCTAssertEqual(scheduler.dayLog(for: Date())?.status, .completed)
        XCTAssertEqual(settings.successStreak, 1, "the day advances once even with two logged workouts")
        XCTAssertEqual(settings.missStreak, 0, "a completed multi-workout day can never be insulted as missed")
        XCTAssertEqual(scheduler.workoutEntries(forKey: key).count, 2)
    }

    func testHabitWorkoutTypeForDate() {
        let habit = Habit(schedule: [
            WeekdaySchedule(weekday: 2, hour: 18, minute: 0, workoutType: "lift"), // Monday
            WeekdaySchedule(weekday: 4, hour: 18, minute: 0),                      // Wednesday, untyped
        ])
        let calendar = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 6 // a Monday
        let monday = calendar.date(from: comps)!
        comps.day = 8 // a Wednesday
        let wednesday = calendar.date(from: comps)!
        comps.day = 7 // a Tuesday (rest day)
        let tuesday = calendar.date(from: comps)!

        XCTAssertEqual(habit.workoutType(for: monday, calendar: calendar), "lift")
        XCTAssertNil(habit.workoutType(for: wednesday, calendar: calendar))
        XCTAssertNil(habit.workoutType(for: tuesday, calendar: calendar))
    }

    func testReminderTitleAndCountdownLabel() {
        XCTAssertEqual(InsultPool.reminderTitle(workoutType: "run"), "30 min till run")
        XCTAssertEqual(InsultPool.reminderTitle(workoutType: nil), "30 minutes left today")
        XCTAssertEqual(InsultPool.reminderTitle(workoutType: ""), "30 minutes left today")
        XCTAssertEqual(InsultPool.countdownLabel(workoutType: "swim"), "swim in")
        XCTAssertEqual(InsultPool.countdownLabel(workoutType: nil), "Workout in")
    }

    func testReminderCopyMatchesScheduledTimeContext() throws {
        let calendar = Calendar(identifier: .gregorian)
        func date(hour: Int) throws -> Date {
            try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 13, hour: hour)))
        }

        for _ in 0..<100 {
            let morning = InsultPool.reminderLine(for: try date(hour: 8), calendar: calendar)
            XCTAssertTrue((InsultPool.reminderGeneric + InsultPool.reminderMorning).contains(morning))
            XCTAssertFalse(InsultPool.reminderMidday.contains(morning))
            XCTAssertFalse(InsultPool.reminderEvening.contains(morning))

            let midday = InsultPool.reminderLine(for: try date(hour: 12), calendar: calendar)
            XCTAssertTrue((InsultPool.reminderGeneric + InsultPool.reminderMidday).contains(midday))
            XCTAssertFalse(InsultPool.reminderMorning.contains(midday))
            XCTAssertFalse(InsultPool.reminderEvening.contains(midday))

            let evening = InsultPool.reminderLine(for: try date(hour: 18), calendar: calendar)
            XCTAssertTrue((InsultPool.reminderGeneric + InsultPool.reminderEvening).contains(evening))
            XCTAssertFalse(InsultPool.reminderMorning.contains(evening))
            XCTAssertFalse(InsultPool.reminderMidday.contains(evening))
        }
        XCTAssertFalse(InsultPool.reminder.contains("fire work today"))
    }

    /// Multiple workouts on one day are all kept - DayLog owns status, entries are history.
    @MainActor
    func testMultipleWorkoutEntriesPerDay() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)

        scheduler.recordWorkoutEntry(on: Date(), type: "run", source: .healthKit, durationMinutes: 32)
        scheduler.recordWorkoutEntry(on: Date(), type: nil, source: .manual, durationMinutes: 30)

        let entries = scheduler.workoutEntries(forKey: DateKey.string(from: Date()))
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.contains { $0.type == "run" && $0.source == .healthKit })
        XCTAssertTrue(entries.contains { $0.type == WorkoutEntry.genericType && $0.source == .manual },
                      "a typeless entry falls back to the generic type")
    }

    // MARK: - Bonus workouts (rest-day flow)

    /// The locked decision: bonus workouts are recorded but never move either streak.
    @MainActor
    func testRecordBonusLeavesBothStreaksUntouched() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)
        let settings = UserSettings()
        settings.successStreak = 5
        settings.missStreak = 0
        context.insert(settings)

        scheduler.recordBonus(on: Date(), viaHealthKit: true)

        XCTAssertEqual(scheduler.dayLog(for: Date())?.status, .bonus)
        XCTAssertEqual(scheduler.dayLog(for: Date())?.verifiedByHealthKit, true)
        XCTAssertEqual(settings.successStreak, 5, "bonus must not advance the streak")
        XCTAssertEqual(settings.missStreak, 0)
    }

    @MainActor
    func testRecordBonusDoesNotOverwriteResolvedDay() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)
        let settings = UserSettings()
        context.insert(settings)

        scheduler.recordSuccess(on: Date(), settings: settings, viaHealthKit: false)
        scheduler.recordBonus(on: Date(), viaHealthKit: false)

        XCTAssertEqual(scheduler.dayLog(for: Date())?.status, .completed, "a completed day stays completed")
    }

    // MARK: - Pause mode

    func testIsPausedRangeIsInclusive() {
        let settings = UserSettings()
        settings.pauseStartDateKey = "2026-07-10"
        settings.pauseEndDateKey = "2026-07-15"

        XCTAssertFalse(settings.isPaused(onKey: "2026-07-09"))
        XCTAssertTrue(settings.isPaused(onKey: "2026-07-10"), "start day is paused")
        XCTAssertTrue(settings.isPaused(onKey: "2026-07-12"))
        XCTAssertTrue(settings.isPaused(onKey: "2026-07-15"), "end day is paused")
        XCTAssertFalse(settings.isPaused(onKey: "2026-07-16"))
        XCTAssertFalse(UserSettings().isPaused(onKey: "2026-07-12"), "no range set = never paused")
    }

    /// The whole point of pause mode: scheduled days inside the range produce no misses
    /// and the streak comes out the other side exactly as it went in.
    @MainActor
    func testReconcileSkipsPausedDaysAndFreezesStreak() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)
        let calendar = Calendar(identifier: .gregorian)

        let habit = Habit(schedule: (1...7).map { WeekdaySchedule(weekday: $0, hour: 18, minute: 0) })
        let settings = UserSettings(hasOnboarded: true)
        settings.successStreak = 9
        let start = calendar.startOfDay(for: Date())
        let fourDaysAgo = calendar.date(byAdding: .day, value: -4, to: start)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: start)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: start)!
        settings.lastSettledDateKey = DateKey.string(from: fourDaysAgo)
        // Pause covered three days ago through yesterday - every skipped day is exempt.
        settings.pauseStartDateKey = DateKey.string(from: threeDaysAgo)
        settings.pauseEndDateKey = DateKey.string(from: yesterday)
        context.insert(habit)
        context.insert(settings)

        scheduler.reconcile(habit: habit, settings: settings, calendar: calendar)

        XCTAssertEqual(settings.missStreak, 0, "paused days must not be settled as misses")
        XCTAssertEqual(settings.successStreak, 9, "streak frozen, not broken")
    }

    /// Once the pause range is behind us, reconcile clears it and stamps today for the
    /// one-day resume banner.
    @MainActor
    func testReconcileClearsExpiredPauseAndStampsResumeBanner() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)
        let calendar = Calendar(identifier: .gregorian)

        let habit = Habit(schedule: [])
        let settings = UserSettings(hasOnboarded: true)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        settings.lastSettledDateKey = DateKey.string(from: yesterday)
        settings.pauseStartDateKey = DateKey.string(from: calendar.date(byAdding: .day, value: -3, to: Date())!)
        settings.pauseEndDateKey = DateKey.string(from: yesterday)
        context.insert(habit)
        context.insert(settings)

        scheduler.reconcile(habit: habit, settings: settings, calendar: calendar)

        XCTAssertNil(settings.pauseStartDateKey)
        XCTAssertNil(settings.pauseEndDateKey)
        XCTAssertEqual(settings.resumeBannerDateKey, DateKey.string(from: Date()))
    }

    /// A still-active pause must survive reconcile untouched (no premature clear).
    @MainActor
    func testReconcileLeavesActivePauseAlone() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)

        let habit = Habit(schedule: [])
        let settings = UserSettings(hasOnboarded: true)
        settings.lastSettledDateKey = DateKey.string(from: Date())
        settings.pauseStartDateKey = DateKey.string(from: Date())
        let calendar = Calendar(identifier: .gregorian)
        settings.pauseEndDateKey = DateKey.string(from: calendar.date(byAdding: .day, value: 3, to: Date())!)
        context.insert(habit)
        context.insert(settings)

        scheduler.reconcile(habit: habit, settings: settings, calendar: calendar)

        XCTAssertNotNil(settings.pauseStartDateKey)
        XCTAssertNotNil(settings.pauseEndDateKey)
        XCTAssertNil(settings.resumeBannerDateKey)
        XCTAssertTrue(settings.isPausedToday)
    }

    // MARK: - Best streak (v0.2 Wave 3)

    /// bestStreak is a high-water mark: it rides successStreak up and survives resets.
    @MainActor
    func testBestStreakIsHighWaterMark() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)
        let settings = UserSettings()
        context.insert(settings)
        let calendar = Calendar(identifier: .gregorian)

        for offset in (0..<3).reversed() {
            let day = calendar.date(byAdding: .day, value: -offset, to: Date())!
            scheduler.recordSuccess(on: day, settings: settings, viaHealthKit: false)
        }
        XCTAssertEqual(settings.bestStreak, 3)

        scheduler.recordMiss(dateKey: "2099-01-01", settings: settings)
        XCTAssertEqual(settings.successStreak, 0)
        XCTAssertEqual(settings.bestStreak, 3, "a miss resets the streak, never the best")

        // Legacy rows (nil stored value) read as 0 rather than crashing.
        let legacy = UserSettings()
        XCTAssertEqual(legacy.bestStreak, 0)
    }

    // MARK: - Burn Book (v0.2 Wave 3)

    /// What Home shows is what the book collects: recordSuccess stores the compliment
    /// on the day AND records it, and the two must match.
    @MainActor
    func testRecordSuccessStoresAndCollectsSameComplimentLine() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)
        let settings = UserSettings()
        context.insert(settings)

        scheduler.recordSuccess(on: Date(), settings: settings, viaHealthKit: false)

        let stored = try XCTUnwrap(scheduler.dayLog(for: Date())?.insultShown)
        XCTAssertTrue(InsultPool.burnBookCompliments.contains(stored), "line comes from the compliment pool")
        let records = try context.fetch(FetchDescriptor<RoastRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.line, stored)
        XCTAssertEqual(records.first?.kind, .compliment)
        XCTAssertEqual(records.first?.situation, "success")
    }

    /// Snoozing surfaces (and collects) the escalation line, tier matching the count.
    @MainActor
    func testRecordSnoozeStoresAndCollectsEscalationLine() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)
        let key = DateKey.string(from: Date())

        XCTAssertEqual(scheduler.recordSnooze(dateKey: key), 1)
        let first = try XCTUnwrap(scheduler.dayLog(for: Date())?.insultShown)
        XCTAssertTrue(InsultPool.snoozeMild.contains(first), "first snooze pulls MILD")

        XCTAssertEqual(scheduler.recordSnooze(dateKey: key), 2)
        let second = try XCTUnwrap(scheduler.dayLog(for: Date())?.insultShown)
        XCTAssertTrue(InsultPool.snoozeSpicy.contains(second), "second snooze escalates to SPICY")

        let records = try context.fetch(FetchDescriptor<RoastRecord>())
        XCTAssertEqual(records.count, 2)
        XCTAssertTrue(records.allSatisfy { $0.kind == .roast && $0.situation == "snooze" })
    }

    /// The miss reckoning line lands in the book, and it's the same deterministic line
    /// the banner and the noon push will show.
    @MainActor
    func testRecordMissCollectsReckoningLine() throws {
        let context = try makeInMemoryContext()
        let scheduler = DayScheduler(context: context)
        let settings = UserSettings()
        context.insert(settings)

        scheduler.recordMiss(dateKey: DateKey.string(from: Date()), settings: settings)

        let records = try context.fetch(FetchDescriptor<RoastRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.line, InsultPool.morningBanner(missStreak: 1).line)
        XCTAssertEqual(records.first?.situation, "reckoning")
    }

    /// Unlock counting is by distinct line, intersected with the live pool.
    func testUnlockedCountDistinctAndPoolBound() {
        let pool = ["a", "b", "c"]
        XCTAssertEqual(BurnBook.unlockedCount(seenLines: ["a", "a", "b"], pool: pool), 2)
        XCTAssertEqual(BurnBook.unlockedCount(seenLines: ["a", "zombie-line"], pool: pool), 1, "lines no longer in the pool don't count")
        XCTAssertEqual(BurnBook.unlockedCount(seenLines: [], pool: pool), 0)
    }

    func testBadgeLadders() {
        let total = InsultPool.burnBookRoasts.count
        XCTAssertNil(BurnBook.roastBadge(unlocked: 4, total: total))
        XCTAssertEqual(BurnBook.roastBadge(unlocked: 5, total: total), "certified punching bag")
        XCTAssertEqual(BurnBook.roastBadge(unlocked: 10, total: total), "glutton for punishment")
        XCTAssertEqual(BurnBook.roastBadge(unlocked: 25, total: total), "roast magnet")
        XCTAssertEqual(BurnBook.roastBadge(unlocked: 30, total: total), "well done")
        XCTAssertEqual(BurnBook.roastBadge(unlocked: total, total: total), "fully roasted")

        let cTotal = InsultPool.burnBookCompliments.count
        XCTAssertNil(BurnBook.complimentBadge(unlocked: 2, total: cTotal))
        XCTAssertEqual(BurnBook.complimentBadge(unlocked: 3, total: cTotal), "barely tolerable")
        XCTAssertEqual(BurnBook.complimentBadge(unlocked: 7, total: cTotal), "annoyingly consistent")
        XCTAssertEqual(BurnBook.complimentBadge(unlocked: cTotal, total: cTotal), InsultPool.tooHotToRoast)
    }

    /// Every badge threshold must be reachable with the actual pool sizes.
    func testBadgeThresholdsAreAttainable() {
        XCTAssertGreaterThanOrEqual(InsultPool.burnBookRoasts.count, 30, "the top numeric roast tier must be reachable")
        XCTAssertGreaterThanOrEqual(InsultPool.burnBookCompliments.count, 7, "the top numeric compliment tier must be reachable")
        XCTAssertEqual(Set(InsultPool.burnBookRoasts).count, InsultPool.burnBookRoasts.count, "no duplicate roast lines")
        XCTAssertEqual(Set(InsultPool.burnBookCompliments).count, InsultPool.burnBookCompliments.count, "no duplicate compliment lines")
    }

    func testRareCollectiblesBelongToTrackablePools() {
        let allTrackable = Set(InsultPool.burnBookRoasts + InsultPool.burnBookCompliments)
        XCTAssertTrue(InsultPool.rareCollectibles.isSubset(of: allTrackable))
        XCTAssertTrue(InsultPool.uncommonCollectibles.isSubset(of: allTrackable))
        XCTAssertTrue(InsultPool.rareCollectibles.isDisjoint(with: InsultPool.uncommonCollectibles))
    }

    /// A past bonus day must never be re-settled as a miss by the catch-up pass.
    @MainActor
    func testReconcileSkipsBonusDay() throws {
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
        context.insert(DayLog(dateKey: DateKey.string(from: yesterday), status: .bonus))

        scheduler.reconcile(habit: habit, settings: settings, calendar: calendar)

        XCTAssertEqual(settings.missStreak, 0)
        XCTAssertEqual(scheduler.dayLog(for: yesterday)?.status, .bonus)
    }
}
