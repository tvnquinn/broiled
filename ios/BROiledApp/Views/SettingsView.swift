import SwiftUI

struct SettingsView: View {
    let habit: Habit
    let health: HealthKitService

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings").font(.system(size: 19, weight: .bold)).foregroundStyle(Theme.ink).padding(.vertical, 16)

                row(key: "SCHEDULE", value: scheduleSummary, trailing: "custom times ›")
                row(key: "HEALTHKIT", value: health.isAuthorized ? "Connected ›" : "Not connected ›")

                Spacer()
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
    }

    private var scheduleSummary: String {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let days = habit.schedule.map { names[$0.weekday - 1] }
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
    }
}
