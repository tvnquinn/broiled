import SwiftUI

struct SettingsView: View {
    let habit: Habit
    let settings: UserSettings
    let health: HealthKitService

    @Environment(\.dismiss) private var dismiss
    @State private var showScheduleEditor = false

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

                    Spacer()
                }
                .padding(20)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showScheduleEditor) {
                ScheduleEditView(habit: habit, settings: settings)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var scheduleSummary: String {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let days = WeekdaySchedule.sortedMondayFirst(habit.schedule.map(\.weekday)).map { names[$0 - 1] }
        return days.isEmpty ? "Not set" : days.joined(separator: ", ")
    }

    private func row(key: String, value: String, trailing: String) -> some View {
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
