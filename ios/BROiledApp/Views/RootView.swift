import SwiftUI
import SwiftData
import WidgetKit
import os

let rootLog = Logger(subsystem: "com.quinnnguyen.broiled", category: "root")

/// Coordinates onboarding vs. home vs. silence, and owns the singleton Habit/UserSettings
/// rows (Phase 0 is single-habit, so there's always exactly one of each after onboarding).
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var habits: [Habit]
    @Query private var allSettings: [UserSettings]
    @Query private var dayLogs: [DayLog]
    @Query(sort: \WorkoutEntry.loggedAt) private var workoutEntries: [WorkoutEntry]

    @State private var health = HealthKitService()
    @State private var scheduler: DayScheduler?
    @State private var sheet: ActiveSheet?
    @State private var notificationsDenied = false
    @Environment(\.scenePhase) private var scenePhase

    enum ActiveSheet: Identifiable {
        case gutCheck
        case bonusGutCheck
        case reactivationGutCheck
        case snooze
        case settings
        var id: Int { hashValue }
    }

    var body: some View {
        Group {
            // Bootstrapping the singleton rows happens in .task below, not here - inserting
            // model objects as a side effect of a computed property read from `body` risks
            // duplicate rows across SwiftUI's multiple body evaluations. Show a brief
            // loading state on the very first launch instead.
            if let habit = habits.first, let settings = allSettings.first {
                if !settings.hasOnboarded {
                    OnboardingView(habit: habit) { start(deadline: $0, habit: habit, settings: settings) }
                } else if settings.isAbandoned {
                    SilenceView { sheet = .reactivationGutCheck }
                        .sheet(item: $sheet) { active in
                            if case .reactivationGutCheck = active {
                                GutCheckSheet(
                                    question: "did you actually work out?",
                                    defaultType: WorkoutEntry.genericType,
                                    onYes: { type, duration in
                                        reactivate(type: type, durationMinutes: duration, settings: settings)
                                        sheet = nil
                                    },
                                    onNo: { sheet = nil }
                                )
                                .presentationDetents([.large])
                            }
                        }
                } else {
                    HomeView(
                        habit: habit,
                        settings: settings,
                        health: health,
                        isCompletedToday: dayLogs.first { $0.dateKey == DateKey.string(from: Date()) }?.status == .completed,
                        bonusLoggedToday: dayLogs.first { $0.dateKey == DateKey.string(from: Date()) }?.status == .bonus,
                        todayWorkouts: workoutEntries.filter { $0.dateKey == DateKey.string(from: Date()) },
                        todayInsult: dayLogs.first { $0.dateKey == DateKey.string(from: Date()) }?.insultShown,
                        notificationsDenied: notificationsDenied,
                        forceRestDay: ProcessInfo.processInfo.arguments.contains("UI-TESTING-REST-TODAY"),
                        onLoggedTapped: {
                            rootLog.info("locked-in tapped; presenting gut-check (was: \(String(describing: sheet)))")
                            sheet = .gutCheck
                        },
                        onMissCheckFired: { sheet = .snooze },
                        onAutoSuccess: { logHealthKitSuccess(settings: settings) },
                        onBonusTapped: { checkBonus(habit: habit, settings: settings) },
                        onSettingsTapped: { sheet = .settings },
                        onCountdownChanged: { syncWidgets() }
                    )
                    .sheet(item: $sheet) { active in
                        switch active {
                        case .gutCheck:
                            let plans = habit.scheduledWorkouts(for: Date())
                            GutCheckSheet(
                                suggestedTypes: plans.compactMap(\.workoutType),
                                defaultType: plans.first?.workoutType ?? WorkoutEntry.genericType,
                                defaultDuration: plans.first?.resolvedDuration(fallback: habit.minDurationMinutes) ?? 30,
                                onYes: { type, duration in
                                    logManualWorkout(type: type, durationMinutes: duration, settings: settings)
                                    sheet = nil
                                },
                                onNo: { sheet = nil }
                            )
                            .presentationDetents([.large])
                        case .bonusGutCheck:
                            GutCheckSheet(
                                question: InsultPool.bonusGutCheckQuestion,
                                defaultType: WorkoutEntry.genericType,
                                onYes: { type, duration in
                                    logManualBonus(type: type, durationMinutes: duration)
                                    sheet = nil
                                },
                                onNo: { sheet = nil }
                            )
                            .presentationDetents([.large])
                        case .reactivationGutCheck:
                            EmptyView()
                        case .snooze:
                            SnoozeSheet(
                                tomorrowIsScheduled: tomorrowIsScheduled(habit: habit),
                                onSnooze: { newDeadline in snooze(to: newDeadline, habit: habit, settings: settings); sheet = nil },
                                onPushToTomorrow: { insult in pushToTomorrow(habit: habit, settings: settings, shownInsult: insult); sheet = nil },
                                onTakeMiss: { quitToday(habit: habit, settings: settings); sheet = nil },
                                onQuit: { quitToday(habit: habit, settings: settings); sheet = nil }
                            )
                            .presentationDetents([.large])
                        case .settings:
                            SettingsView(habit: habit, settings: settings, health: health)
                        }
                    }
                    // The miss-check notification's "no" action (or a plain tap) opens the
                    // snooze/quit sheet. "yes" is handled entirely in the notification
                    // delegate (grace re-check) and never needs to open the app.
                    .onReceive(NotificationCenter.default.publisher(for: NotificationDelegate.didDeclineWorkout)) { _ in
                        let completedToday = dayLogs.first { $0.dateKey == DateKey.string(from: Date()) }?.status == .completed
                        if !completedToday { sheet = .snooze }
                    }
                }
            } else {
                ProgressView().tint(Theme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.bg)
            }
        }
        .task {
            bootstrapIfNeeded()
            let engine = DayScheduler(context: context)
            scheduler = engine
            let todayKey = DateKey.string(from: Date())
            let todayStatus = dayLogs.first { $0.dateKey == todayKey }?.status
            rootLog.info("launch: habits=\(habits.count) settings=\(allSettings.count) dayLogs=\(dayLogs.count) onboarded=\(allSettings.first?.hasOnboarded ?? false) abandoned=\(allSettings.first?.isAbandoned ?? false) missStreak=\(allSettings.first?.missStreak ?? -1) successStreak=\(allSettings.first?.successStreak ?? -1) today=\(todayKey) todayStatus=\(String(describing: todayStatus))")
            // UI tests skip the HealthKit/notification system permission prompts - those are
            // OS chrome, not app behavior under test, and HealthKit's sheet isn't a standard
            // alert XCUITest can reliably dismiss.
            if !ProcessInfo.processInfo.arguments.contains("UI-TESTING") {
                await health.requestAuthorization()
                await NotificationService.shared.requestAuthorization()
                notificationsDenied = await NotificationService.shared.isDenied()
                startBackgroundWorkoutObserver()
            }
            if let habit = habits.first, let settings = allSettings.first, settings.hasOnboarded {
                engine.reconcile(habit: habit, settings: settings)
                if !settings.isAbandoned && !settings.isPausedToday {
                    let todayKey = DateKey.string(from: Date())
                    let completedToday = dayLogs.first { $0.dateKey == todayKey }?.status == .completed
                    if !completedToday {
                        if let override = settings.todayOverride() {
                            engine.startCycle(deadline: override, habit: habit)
                        } else if habit.isActiveDay(Date()) {
                            engine.startDay(habit: habit)
                        }
                    }
                }
                syncWidgets()
            }
        }
        // Re-check on every foreground so the denied banner clears the moment the user
        // flips notifications back on in system Settings.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { notificationsDenied = await NotificationService.shared.isDenied() }
            syncWidgets()
        }
        // dayLogs covers success/miss/bonus/snooze; the settings row covers pause and
        // streak changes. Between them every widget-relevant mutation lands here.
        .onChange(of: dayLogs) { _, _ in syncWidgets() }
    }

    /// v0.2 Wave 3: keep the home-screen widget snapshot and the countdown Live
    /// Activity in lockstep with app state. Cheap enough to call generously.
    private func syncWidgets() {
        guard let habit = habits.first, let settings = allSettings.first, settings.hasOnboarded else { return }
        let todayKey = DateKey.string(from: Date())
        let status = dayLogs.first { $0.dateKey == todayKey }?.status
        let displayPlan = habit.displayWorkout(for: Date(), now: Date())
        let plannedDeadline = displayPlan.flatMap {
            Calendar.current.date(bySettingHour: $0.hour, minute: $0.minute, second: 0, of: Date())
        }
        let deadline = settings.todayOverride() ?? plannedDeadline
        let displayType = displayPlan?.workoutType

        let state: WidgetSnapshot.DayState
        if settings.isAbandoned {
            state = .silence
        } else if settings.isPausedToday {
            state = .paused
        } else if status == .completed {
            state = .completed
        } else if deadline == nil {
            state = .rest
        } else {
            state = .pending
        }

        WidgetSnapshot.write(WidgetSnapshot.Data(
            state: state,
            deadline: state == .pending ? deadline : nil,
            workoutType: displayType,
            streak: settings.successStreak,
            bestStreak: settings.bestStreak
        ))
        WidgetCenter.shared.reloadAllTimelines()

        // The Live Activity only exists while a countdown is actually running.
        let activityDeadline = (state == .pending && status ?? .pending == .pending) ? deadline : nil
        LiveActivityService.shared.sync(
            deadline: activityDeadline,
            workoutType: displayType,
            streak: settings.successStreak
        )
    }

    /// v0.2 Wave 1: when a workout syncs to HealthKit while backgrounded, settle the day,
    /// fire the success push (the previously-orphaned `fireSuccessPush`), and let
    /// recordSuccess cancel the now-stale miss-check. Fetches fresh from the context
    /// because the observer can fire hours after this view captured its @Query snapshots.
    private func startBackgroundWorkoutObserver() {
        health.startObservingWorkouts { [context] in
            Task { @MainActor in
                let habit = try? context.fetch(FetchDescriptor<Habit>()).first
                let settings = try? context.fetch(FetchDescriptor<UserSettings>()).first
                // Paused days are frozen: a workout during a pause neither advances the
                // streak nor settles anything, so skip auto-detection entirely.
                guard let habit, let settings, settings.hasOnboarded, !settings.isAbandoned,
                      !settings.isPausedToday else { return }

                let engine = DayScheduler(context: context)
                let today = Date()
                let todayKey = DateKey.string(from: today)
                guard engine.dayLog(for: today)?.status ?? .pending == .pending else { return }
                // Only auto-settle scheduled days (or a deferred obligation pushed onto
                // today) - rest-day bonus workouts are the Wave 2 flow.
                let isActive = habit.isActiveDay(today) || settings.todayDeadlineOverrideDateKey == todayKey
                guard isActive else { return }

                guard let detail = await health.qualifyingWorkoutToday(minDurationMinutes: habit.minimumQualifyingDuration(for: today)) else { return }
                guard engine.recordSuccess(on: today, settings: settings, viaHealthKit: true) else { return }
                engine.recordWorkoutEntry(on: today, type: detail.type, source: .healthKit, durationMinutes: detail.durationMinutes)
                NotificationService.shared.fireSuccessPush(successStreak: settings.successStreak)
            }
        }
    }

    private func bootstrapIfNeeded() {
        if habits.isEmpty { context.insert(Habit()) }
        if allSettings.isEmpty { context.insert(UserSettings()) }
        try? context.save()
    }

    private func start(deadline: Date?, habit: Habit, settings: UserSettings) {
        settings.hasOnboarded = true
        settings.lastSettledDateKey = DateKey.string(from: Date())
        // Onboarding on a rest day sets no deadline and schedules nothing - the next
        // launch on a scheduled day picks up the weekly schedule (see .task above).
        if deadline != nil {
            scheduler?.startDay(habit: habit)
        }
        try? context.save()
        // UI-test hook: the snooze sheet is normally only reachable after a deadline
        // passes (or via the miss-check notification), which a UI test can't wait for.
        if ProcessInfo.processInfo.arguments.contains("UI-TESTING-OPEN-SNOOZE") {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                sheet = .snooze
            }
        }
    }

    private func logHealthKitSuccess(settings: UserSettings) {
        guard let habit = habits.first else { return }
        guard scheduler?.recordSuccess(on: Date(), settings: settings, viaHealthKit: true) == true else { return }
        // The detection query already ran; re-fetch for the entry's real type/duration.
        Task { @MainActor in
            let detail = await health.qualifyingWorkoutToday(minDurationMinutes: habit.minimumQualifyingDuration(for: Date()))
            scheduler?.recordWorkoutEntry(
                on: Date(),
                type: detail?.type ?? habit.workoutType(for: Date()),
                source: .healthKit,
                durationMinutes: detail?.durationMinutes ?? habit.minimumQualifyingDuration(for: Date())
            )
        }
    }

    /// The first manual entry settles the day; later entries are history only and never
    /// advance the streak twice. Saving both operations before dismissing fixes the old
    /// 0:00 screen that lingered after the honesty gate.
    private func logManualWorkout(type: String?, durationMinutes: Int, settings: UserSettings) {
        let today = Date()
        let pending = (scheduler?.dayLog(for: today)?.status ?? .pending) == .pending
        if pending {
            _ = scheduler?.recordSuccess(on: today, settings: settings, viaHealthKit: false)
        }
        scheduler?.recordWorkoutEntry(
            on: today,
            type: type,
            source: .manual,
            durationMinutes: durationMinutes
        )
        try? context.save()
        syncWidgets()
    }

    /// Bonus flow (rest days only): trust HealthKit first, fall back to the honesty gate.
    private func checkBonus(habit: Habit, settings: UserSettings) {
        if scheduler?.dayLog(for: Date())?.status == .bonus {
            sheet = .bonusGutCheck
            return
        }
        Task { @MainActor in
            if let detail = await health.qualifyingWorkoutToday(minDurationMinutes: habit.minimumQualifyingDuration(for: Date())) {
                if scheduler?.recordBonus(on: Date(), viaHealthKit: true) == true {
                    scheduler?.recordWorkoutEntry(on: Date(), type: detail.type, source: .healthKit, durationMinutes: detail.durationMinutes)
                }
            } else {
                sheet = .bonusGutCheck
            }
        }
    }

    private func logManualBonus(type: String?, durationMinutes: Int) {
        let today = Date()
        _ = scheduler?.recordBonus(on: today, viaHealthKit: false)
        scheduler?.recordWorkoutEntry(on: today, type: type, source: .manual, durationMinutes: durationMinutes)
        try? context.save()
    }

    private func snooze(to newDeadline: Date, habit: Habit, settings: UserSettings) {
        let key = DateKey.string(from: Date())
        _ = scheduler?.recordSnooze(dateKey: key)
        settings.setTodayOverride(newDeadline)
        scheduler?.startCycle(deadline: newDeadline, habit: habit)
        try? context.save()
        // In-place mutations don't trip the dayLogs onChange - sync explicitly.
        syncWidgets()
    }

    private func tomorrowIsScheduled(habit: Habit) -> Bool {
        // UI-test hooks: the real answer depends on the wall-clock weekday, which would
        // make the push-to-tomorrow UI tests flake by day of week. Forcing flags pin the
        // branch under test; production launches never pass them.
        let args = ProcessInfo.processInfo.arguments
        if args.contains("UI-TESTING-TOMORROW-SCHEDULED") { return true }
        if args.contains("UI-TESTING-TOMORROW-REST") { return false }
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else { return false }
        return habit.isActiveDay(tomorrow)
    }

    /// Rest-day-tomorrow only (the sheet routes scheduled tomorrows to onTakeMiss).
    /// Today drops out of streak math; the deadline override moves onto tomorrow at the
    /// same time-of-day, and reconcile() treats that day as active so ghosting it is a miss.
    private func pushToTomorrow(habit: Habit, settings: UserSettings, shownInsult: String) {
        let todayKey = DateKey.string(from: Date())
        scheduler?.recordDeferred(dateKey: todayKey)
        scheduler?.recordRoast(shownInsult, kind: .roast, situation: "push-to-tomorrow")

        let calendar = Calendar.current
        let currentDeadline = settings.todayOverride() ?? habit.deadline(for: Date()) ?? Date()
        let comps = calendar.dateComponents([.hour, .minute], from: currentDeadline)
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
           let tomorrowDeadline = calendar.date(bySettingHour: comps.hour ?? 18, minute: comps.minute ?? 0, second: 0, of: tomorrow) {
            settings.setOverride(deadline: tomorrowDeadline)
            scheduler?.startCycle(deadline: tomorrowDeadline, habit: habit)
        }
        try? context.save()
        syncWidgets()
    }

    private func quitToday(habit: Habit, settings: UserSettings) {
        let key = DateKey.string(from: Date())
        scheduler?.recordMiss(dateKey: key, settings: settings)
        let tomorrowDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        if habit.isActiveDay(tomorrowDate) {
            scheduler?.startDay(on: tomorrowDate, habit: habit)
        }
        try? context.save()
    }

    private func reactivate(type: String?, durationMinutes: Int, settings: UserSettings) {
        scheduler?.reactivate(on: Date(), settings: settings)
        scheduler?.recordWorkoutEntry(
            on: Date(),
            type: type,
            source: .manual,
            durationMinutes: durationMinutes
        )
    }
}
