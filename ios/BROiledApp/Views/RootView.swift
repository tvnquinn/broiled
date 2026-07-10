import SwiftUI
import SwiftData

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

    enum ActiveSheet: Identifiable {
        case gutCheck
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
                        onLoggedTapped: { sheet = .gutCheck },
                        onMissCheckFired: { sheet = .snooze },
                        onAutoSuccess: { logSuccess(settings: settings, viaHealthKit: true) },
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
                        case .snooze:
                            SnoozeSheet(
                                onSnooze: { minutes in snooze(minutes: minutes, habit: habit, settings: settings); sheet = nil },
                                onQuit: { quitToday(habit: habit, settings: settings); sheet = nil }
                            )
                            .presentationDetents([.medium])
                        case .settings:
                            SettingsView(habit: habit, settings: settings, health: health)
                        }
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
            // UI tests skip the HealthKit/notification system permission prompts - those are
            // OS chrome, not app behavior under test, and HealthKit's sheet isn't a standard
            // alert XCUITest can reliably dismiss.
            if !ProcessInfo.processInfo.arguments.contains("UI-TESTING") {
                await health.requestAuthorization()
                await NotificationService.shared.requestAuthorization()
            }
            if let habit = habits.first, let settings = allSettings.first, settings.hasOnboarded {
                engine.reconcile(habit: habit, settings: settings)
                if !settings.isAbandoned {
                    let todayKey = DateKey.string(from: Date())
                    let completedToday = dayLogs.first { $0.dateKey == todayKey }?.status == .completed
                    if !completedToday, let deadline = settings.todayOverride() ?? habit.deadline(for: Date()) {
                        engine.startCycle(deadline: deadline, habit: habit)
                    }
                }
            }
        }
    }

    private func bootstrapIfNeeded() {
        if habits.isEmpty { context.insert(Habit()) }
        if allSettings.isEmpty { context.insert(UserSettings()) }
        try? context.save()
    }

    private func start(deadline: Date, habit: Habit, settings: UserSettings) {
        settings.hasOnboarded = true
        settings.lastSettledDateKey = DateKey.string(from: Date())
        settings.setTodayOverride(deadline)
        scheduler?.startCycle(deadline: deadline, habit: habit)
        try? context.save()
    }

    private func logSuccess(settings: UserSettings, viaHealthKit: Bool) {
        scheduler?.recordSuccess(on: Date(), settings: settings, viaHealthKit: viaHealthKit)
    }

    private func snooze(minutes: Int, habit: Habit, settings: UserSettings) {
        let key = DateKey.string(from: Date())
        _ = scheduler?.recordSnooze(dateKey: key)
        let newDeadline = Date().addingTimeInterval(Double(minutes * 60))
        settings.setTodayOverride(newDeadline)
        scheduler?.startCycle(deadline: newDeadline, habit: habit)
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
    }
}
