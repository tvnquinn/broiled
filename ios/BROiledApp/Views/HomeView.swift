import SwiftUI

struct HomeView: View {
    let habit: Habit
    let settings: UserSettings
    let health: HealthKitService
    let isCompletedToday: Bool
    let onLoggedTapped: () -> Void
    let onMissCheckFired: () -> Void
    let onAutoSuccess: () -> Void
    let onSettingsTapped: () -> Void

    @State private var now = Date()
    @State private var checkedThisCycle = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var successHeadline: String?

    private var deadline: Date {
        settings.todayOverride() ?? habit.deadline(for: Date()) ?? Date()
    }

    /// The actual miss-check doesn't fire at the bare deadline - HealthKit needs time for
    /// a just-started workout to land even if the user heads out right at the deadline.
    /// See plan.md's notification schedule: deadline + duration + 30min.
    private var missCheckTime: Date {
        deadline.addingTimeInterval(Double(habit.minDurationMinutes * 60) + 30 * 60)
    }

    private var remaining: TimeInterval {
        deadline.timeIntervalSince(now)
    }

    private var yesterdayMissed: Bool {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return false }
        return habit.isActiveDay(yesterday) && settings.missStreak > 0
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button(action: onSettingsTapped) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17))
                            .foregroundStyle(Theme.inkMuted)
                    }
                }

                if yesterdayMissed {
                    let banner = InsultPool.morningBanner(missStreak: settings.missStreak)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(banner.headline).font(.system(size: 14, weight: .regular))
                        Text(banner.line).font(.system(size: 14, weight: .bold))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.flame.opacity(0.13))
                    .foregroundStyle(Theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.flame, lineWidth: 0).padding(.leading, -3))
                } else {
                    HStack {
                        Text("\(settings.successStreak) day streak").font(.system(size: 14)).foregroundStyle(Theme.inkMuted)
                        Spacer()
                        if settings.successStreak >= 1 {
                            Text(settings.rankTitle).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.accent)
                        }
                    }
                }

                Spacer()
                if isCompletedToday {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(successHeadline ?? InsultPool.successHeadline[0])
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.success)
                        Text(InsultPool.successSub)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.inkMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 14)
                    .background(Theme.success.opacity(0.14))
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Theme.success)
                            .frame(height: 3)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    VStack(spacing: 6) {
                        Text("Workout in").font(.system(size: 17)).foregroundStyle(Theme.inkMuted)
                        Text(format(remaining))
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .foregroundStyle(remaining > 0 ? Theme.accent : Theme.flame)
                            .monospacedDigit()
                        Text("deadline \(deadline.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 14.5))
                            .foregroundStyle(Theme.inkMuted)
                    }
                }
                Spacer()

                Button(action: onLoggedTapped) {
                    Text(isCompletedToday ? InsultPool.lockedInDoneButton : InsultPool.lockedInButton)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Theme.panel)
                        .foregroundStyle(Theme.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(isCompletedToday)
                .opacity(isCompletedToday ? 0.4 : 1)
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
        .onReceive(timer) { date in
            now = date
            guard !isCompletedToday else { return }
            if now >= missCheckTime && !checkedThisCycle {
                checkedThisCycle = true
                Task { await checkOutcome() }
            }
        }
        .onChange(of: isCompletedToday) { _, completed in
            if completed {
                successHeadline = InsultPool.successHeadlineLine()
            }
        }
        .onAppear {
            if isCompletedToday && successHeadline == nil {
                successHeadline = InsultPool.successHeadlineLine()
            }
        }
        .onChange(of: deadline) { _, _ in checkedThisCycle = false }
    }

    private func checkOutcome() async {
        let found = await health.hasQualifyingWorkoutToday(minDurationMinutes: habit.minDurationMinutes)
        if found {
            onAutoSuccess()
        } else {
            onMissCheckFired()
        }
    }

    private func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
