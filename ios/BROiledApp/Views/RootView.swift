import SwiftUI
import SwiftData
import os

let rootLog = Logger(subsystem: "com.quinnnguyen.broiled", category: "root")

/// Coordinates onboarding vs. home vs. silence, and owns the singleton Habit/UserSettings
/// rows (Phase 0 is single-habit, so there's always exactly one of each after onboarding).
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var habits: [Habit]
    @Query private var allSettings: [UserSettings]
    @Query private var dayLogs: [DayLog]

    @State private var health = HealthKitService()
    @State private var scheduler: DayScheduler?
    @State private var sheet: ActiveSheet?
    @State private var notificationsDenied = false
    @Environment(\.scenePhase) private var scenePhase

    enum ActiveSheet: Identifiable {
        case gutCheck
        case bonusGutCheck
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
                    SilenceView { reactivate(settings: settings) }
                } else {
                    HomeView(
                        habit: habit,
                        settings: settings,
                        health: health,
                        isCompletedToday: dayLogs.first { $0.dateKey == DateKey.string(from: Date()) }?.status == .completed,
                        bonusLoggedToday: dayLogs.first { $0.dateKey == DateKey.string(from: Date()) }?.status == .bonus,
                        notificationsDenied: notificationsDenied,
                        forceRestDay: ProcessInfo.processInfo.arguments.contains("UI-TESTING-REST-TODAY"),
                        onLoggedTapped: {
                            rootLog.info("locked-in tapped; presenting gut-check (was: \(String(describing: sheet)))")
                            sheet = .gutCheck
                        },
                        onMissCheckFired: { sheet = .snooze },
                        onAutoSuccess: { logSuccess(settings: settings, viaHealthKit: true) },
                        onBonusTapped: { checkBonus(habit: habit, settings: settings) },
                        onSettingsTapped: { sheet = .settings }
                    )
                    .sheet(item: $sheet) { active in
                        switch active {
                        case .gutCheck:
                            GutCheckSheet(
                                onYes: { logSuccess(settings: settings, viaHealthKit: false); sheet = nil },
                                onNo: { sheet = nil }
                            )
                            .presentationDetents([.medium])
                        case .bonusGutCheck:
                            GutCheckSheet(
                                question: InsultPool.bonusGutCheckQuestion,
                                onYes: { logManualBonus(habit: habit); sheet = nil },
                                onNo: { sheet = nil }
                            )
                            .presentationDetents([.medium])
                        case .snooze:
                            SnoozeSheet(
                                tomorrowIsScheduled: tomorrowIsScheduled(habit: habit),
                                onSnooze: { newDeadline in snooze(to: newDeadline, habit: habit, settings: settings); sheet = nil },
                                onPushToTomorrow: { pushToTomorrow(habit: habit, settings: settings); sheet = nil },
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
                    if !completedToday, let deadline = settings.todayOverride() ?? habit.deadline(for: Date()) {
                        engine.startCycle(deadline: deadline, habit: habit)
                    }
                }
            }
        }
        // Re-check on every foreground so the denied banner clears the moment the user
        // flips notifications back on in system Settings.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { notificationsDenied = await NotificationService.shared.isDenied() }
        }
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

                guard let detail = await health.qualifyingWorkoutToday(minDurationMinutes: habit.minDurationMinutes) else { return }
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
        if let deadline {
            settings.setTodayOverride(deadline)
            scheduler?.startCycle(deadline: deadline, habit: habit)
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

    private func logSuccess(settings: UserSettings, viaHealthKit: Bool) {
        guard let habit = habits.first else { return }
        guard scheduler?.recordSuccess(on: Date(), settings: settings, viaHealthKit: viaHealthKit) == true else { return }
        if viaHealthKit {
            // The detection query already ran; re-fetch for the entry's real type/duration.
            Task { @MainActor in
                let detail = await health.qualifyingWorkoutToday(minDurationMinutes: habit.minDurationMinutes)
                scheduler?.recordWorkoutEntry(
                    on: Date(),
                    type: detail?.type ?? habit.workoutType(for: Date()),
                    source: .healthKit,
                    durationMinutes: detail?.durationMinutes ?? habit.minDurationMinutes
                )
            }
        } else {
            scheduler?.recordWorkoutEntry(
                on: Date(),
                type: habit.workoutType(for: Date()),
                source: .manual,
                durationMinutes: habit.minDurationMinutes
            )
        }
    }

    /// Bonus flow (rest days only): trust HealthKit first, fall back to the honesty gate.
    private func checkBonus(habit: Habit, settings: UserSettings) {
        Task { @MainActor in
            if let detail = await health.qualifyingWorkoutToday(minDurationMinutes: habit.minDurationMinutes) {
                if scheduler?.recordBonus(on: Date(), viaHealthKit: true) == true {
                    scheduler?.recordWorkoutEntry(on: Date(), type: detail.type, source: .healthKit, durationMinutes: detail.durationMinutes)
                }
            } else {
                sheet = .bonusGutCheck
            }
        }
    }

    private func logManualBonus(habit: Habit) {
        guard scheduler?.recordBonus(on: Date(), viaHealthKit: false) == true else { return }
        scheduler?.recordWorkoutEntry(on: Date(), type: nil, source: .manual, durationMinutes: habit.minDurationMinutes)
    }

    private func snooze(to newDeadline: Date, habit: Habit, settings: UserSettings) {
        let key = DateKey.string(from: Date())
        _ = scheduler?.recordSnooze(dateKey: key)
        settings.setTodayOverride(newDeadline)
        scheduler?.startCycle(deadline: newDeadline, habit: habit)
        try? context.save()
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
    private func pushToTomorrow(habit: Habit, settings: UserSettings) {
        let todayKey = DateKey.string(from: Date())
        scheduler?.recordDeferred(dateKey: todayKey)

        let calendar = Calendar.current
        let currentDeadline = settings.todayOverride() ?? habit.deadline(for: Date()) ?? Date()
        let comps = calendar.dateComponents([.hour, .minute], from: currentDeadline)
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
           let tomorrowDeadline = calendar.date(bySettingHour: comps.hour ?? 18, minute: comps.minute ?? 0, second: 0, of: tomorrow) {
            settings.setOverride(deadline: tomorrowDeadline)
            scheduler?.startCycle(deadline: tomorrowDeadline, habit: habit)
        }
        try? context.save()
    }

    private func quitToday(habit: Habit, settings: UserSettings) {
        let key = DateKey.string(from: Date())
        scheduler?.recordMiss(dateKey: key, settings: settings)
        let tomorrowDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        if let tomorrow = habit.deadline(for: tomorrowDate) {
            scheduler?.startCycle(deadline: tomorrow, habit: habit)
        }
        try? context.save()
    }

    private func reactivate(settings: UserSettings) {
        scheduler?.reactivate(on: Date(), settings: settings)
        if let habit = habits.first {
            scheduler?.recordWorkoutEntry(
                on: Date(),
                type: habit.workoutType(for: Date()),
                source: .manual,
                durationMinutes: habit.minDurationMinutes
            )
        }
    }
}
