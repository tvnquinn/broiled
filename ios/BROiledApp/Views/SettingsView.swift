import SwiftUI

struct SettingsView: View {
    let habit: Habit
    let settings: UserSettings
    let health: HealthKitService

    @Environment(\.dismiss) private var dismiss
    @State private var showScheduleEditor = false
    @State private var showPauseEditor = false
    @State private var showBurnBook = false

    var body: some View {
        // NavigationStack push instead of a nested sheet: presenting a .sheet from inside
        // another .sheet silently failed to present on iOS 26 (verified via UI-test video -
        // the tap landed, the editor never appeared). A drill-in with a back button is the
        // idiomatic Settings pattern anyway.
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Settings").font(.system(size: 19, weight: .bold)).foregroundStyle(Theme.ink)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Theme.inkMuted)
                        }
                        .accessibilityIdentifier("closeSettingsButton")
                    }
                    .padding(.vertical, 16)

                    Button { showScheduleEditor = true } label: {
                        row(key: "SCHEDULE", value: scheduleSummary, trailing: "custom times ›")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("scheduleRowButton")

                    row(key: "HEALTHKIT", value: health.isAuthorized ? "Connected ›" : "Not connected ›", trailing: "")

                    Button { showPauseEditor = true } label: {
                        row(key: "PAUSE", value: pauseSummary, trailing: "date range ›")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("pauseRowButton")

                    Button { showBurnBook = true } label: {
                        row(key: "THE BURN BOOK", value: "every line you've earned", trailing: "open ›")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("burnBookRowButton")

                    Spacer()
                }
                .padding(20)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showScheduleEditor) {
                ScheduleEditView(habit: habit, settings: settings)
            }
            .navigationDestination(isPresented: $showPauseEditor) {
                PauseEditView(habit: habit, settings: settings)
            }
            .navigationDestination(isPresented: $showBurnBook) {
                BurnBookView()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var pauseSummary: String {
        guard let start = settings.pauseStartDateKey, let end = settings.pauseEndDateKey,
              let startDate = DateKey.date(from: start), let endDate = DateKey.date(from: end) else {
            return "Off"
        }
        let fmt: (Date) -> String = { $0.formatted(date: .abbreviated, time: .omitted) }
        return "\(fmt(startDate)) – \(fmt(endDate))"
    }

    private var scheduleSummary: String {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let days = WeekdaySchedule.sortedMondayFirst(habit.schedule.map(\.weekday)).map { names[$0 - 1] }
        return days.isEmpty ? "Not set" : days.joined(separator: ", ")
    }

    fileprivate func row(key: String, value: String, trailing: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key).font(.system(size: 11)).tracking(0.6).foregroundStyle(Theme.inkMuted)
            HStack {
                Text(value).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Theme.ink)
                Spacer()
                Text(trailing).font(.system(size: 12.5)).foregroundStyle(Theme.inkMuted)
            }
        }
        .padding(.vertical, 14)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Theme.line), alignment: .bottom)
        // Without an explicit content shape, the transparent Spacer gap between the two
        // texts is NOT tappable in a .plain-style Button - taps on the middle of the row
        // silently did nothing (caught by the UI test, which taps the row's exact center).
        .contentShape(Rectangle())
    }
}

/// v0.2 Wave 2 pause mode editor. Lives here rather than its own file because it's a
/// one-screen Settings drill-in, same as the schedule editor pattern.
struct PauseEditView: View {
    let habit: Habit
    let settings: UserSettings

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var startDate = Calendar.current.startOfDay(for: Date())
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: Date())) ?? Date()

    private var pauseActive: Bool {
        settings.pauseStartDateKey != nil && settings.pauseEndDateKey != nil
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                Text("Pause")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 24)

                Text("no notifications, no misses. streak frozen - not broken, not growing")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.inkMuted)

                if pauseActive {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(InsultPool.pausedLine)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text(activeRangeText)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.inkMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Theme.ash.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button {
                        resumeNow()
                    } label: {
                        Text(InsultPool.resumeNowButton)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Theme.accent)
                            .foregroundStyle(Theme.chrome)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityIdentifier("resumeNowButton")
                } else {
                    VStack(spacing: 10) {
                        HStack {
                            Text("From").foregroundStyle(Theme.ink)
                            Spacer()
                            DatePicker("", selection: $startDate, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                                .labelsHidden()
                        }
                        .padding(12)
                        .background(Theme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        HStack {
                            Text("Until").foregroundStyle(Theme.ink)
                            Spacer()
                            DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                .labelsHidden()
                        }
                        .padding(12)
                        .background(Theme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button {
                        pause()
                    } label: {
                        Text(InsultPool.pauseButton)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Theme.ink)
                            .foregroundStyle(Theme.bg)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityIdentifier("pauseConfirmButton")
                }

                Spacer()
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
    }

    private var activeRangeText: String {
        guard let start = settings.pauseStartDateKey, let end = settings.pauseEndDateKey,
              let startDate = DateKey.date(from: start), let endDate = DateKey.date(from: end) else { return "" }
        let fmt: (Date) -> String = { $0.formatted(date: .abbreviated, time: .omitted) }
        return "\(fmt(startDate)) – \(fmt(endDate))"
    }

    private func pause() {
        settings.pauseStartDateKey = DateKey.string(from: startDate)
        settings.pauseEndDateKey = DateKey.string(from: endDate)
        settings.resumeBannerDateKey = nil
        try? context.save()
        // "No notifications" starts immediately - everything pending dies, and the
        // per-launch scheduling in RootView won't re-arm anything while paused.
        NotificationService.shared.cancelAll()
        dismiss()
    }

    private func resumeNow() {
        settings.pauseStartDateKey = nil
        settings.pauseEndDateKey = nil
        // Ending it yourself still earns the welcome-back jab today.
        settings.resumeBannerDateKey = DateKey.string(from: Date())
        context.insert(RoastRecord(dateKey: DateKey.string(from: Date()), line: InsultPool.resumeLine, kind: .roast, situation: "resume"))
        try? context.save()
        // Re-arm today's cycle - pausing cancelled everything pending, and the
        // per-launch scheduling only runs at launch.
        if let deadline = settings.todayOverride() ?? habit.deadline(for: Date()) {
            NotificationService.shared.scheduleDeadlinePair(deadline: deadline, durationMinutes: habit.minDurationMinutes, workoutType: habit.workoutType(for: Date()))
        }
        dismiss()
    }
}
