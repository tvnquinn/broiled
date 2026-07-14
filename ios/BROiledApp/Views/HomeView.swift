import SwiftUI

struct HomeView: View {
    let habit: Habit
    let settings: UserSettings
    let health: HealthKitService
    let isCompletedToday: Bool
    let bonusLoggedToday: Bool
    let notificationsDenied: Bool
    /// UI-test hook (UI-TESTING-REST-TODAY): pins the rest-day branch regardless of the
    /// wall-clock weekday. Production launches never set it.
    var forceRestDay = false
    let onLoggedTapped: () -> Void
    let onMissCheckFired: () -> Void
    let onAutoSuccess: () -> Void
    let onBonusTapped: () -> Void
    let onSettingsTapped: () -> Void

    @State private var now = Date()
    @State private var checkedThisCycle = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var successHeadline: String?

    /// Nil on a rest day. The old `?? Date()` fallback here was the "red 0:00 countdown
    /// on rest days" bug - a non-scheduled day has no deadline, full stop.
    private var deadline: Date? {
        if forceRestDay { return nil }
        return settings.todayOverride() ?? habit.deadline(for: Date())
    }

    private var isRestDay: Bool { deadline == nil }

    /// The actual miss-check doesn't fire at the bare deadline - HealthKit needs time for
    /// a just-started workout to land even if the user heads out right at the deadline.
    /// See plan.md's notification schedule: deadline + duration + 30min.
    private var missCheckTime: Date? {
        deadline?.addingTimeInterval(Double(habit.minDurationMinutes * 60) + 30 * 60)
    }

    private var remaining: TimeInterval {
        deadline?.timeIntervalSince(now) ?? 0
    }

    private var yesterdayMissed: Bool {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return false }
        return habit.isActiveDay(yesterday) && settings.missStreak > 0
    }

    private var isPausedToday: Bool { settings.isPausedToday }

    /// The welcome-back jab, shown only on the calendar day reconcile stamped when the
    /// pause ended. Takes the banner slot over the morning reckoning - it's fresher.
    private var showResumeBanner: Bool {
        settings.resumeBannerDateKey == DateKey.string(from: Date())
    }

    private var pauseEndsText: String {
        guard let end = settings.pauseEndDateKey, let endDate = DateKey.date(from: end) else { return "" }
        return "until \(endDate.formatted(date: .abbreviated, time: .omitted))"
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
                    .accessibilityIdentifier("settingsButton")
                }

                // v0.2 Wave 1: the entire consequence engine is notifications - if they're
                // denied, say so loudly and deep-link to system Settings.
                if notificationsDenied {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(InsultPool.notificationsDeniedTitle).font(.system(size: 14, weight: .bold))
                        Text(InsultPool.notificationsDeniedBody).font(.system(size: 13))
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text(InsultPool.notificationsDeniedButton)
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 14)
                                .background(Theme.flame)
                                .foregroundStyle(Theme.chrome)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.flame.opacity(0.13))
                    .foregroundStyle(Theme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if showResumeBanner {
                    Text(InsultPool.resumeLine)
                        .font(.system(size: 14, weight: .bold))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.accent.opacity(0.13))
                        .foregroundStyle(Theme.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if yesterdayMissed && !isPausedToday {
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
                        Text("\(settings.successStreak) day streak").font(.system(size: 15)).foregroundStyle(Theme.inkMuted)
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
                            .font(.system(size: 15, weight: .bold))
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
                } else if isPausedToday {
                    // Pause outranks the countdown even on a scheduled day - no deadline,
                    // no miss-check, streak frozen.
                    VStack(spacing: 6) {
                        Text(InsultPool.pausedLabel)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.inkMuted)
                        Text(InsultPool.pausedLine)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.inkMuted)
                            .multilineTextAlignment(.center)
                        if !pauseEndsText.isEmpty {
                            Text(pauseEndsText)
                                .font(.system(size: 12.5))
                                .foregroundStyle(Theme.inkMuted)
                        }
                    }
                } else if isRestDay {
                    // v0.2 Wave 2: a rest day is a real state, not a broken countdown.
                    if bonusLoggedToday {
                        Text(InsultPool.bonusLoggedLine)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Theme.ash.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        VStack(spacing: 6) {
                            Text(InsultPool.restDayLabel)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.inkMuted)
                            Text(InsultPool.restDaySub)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.inkMuted)
                        }
                    }
                } else if let deadline {
                    VStack(spacing: 6) {
                        Text(InsultPool.countdownLabel(workoutType: habit.workoutType(for: Date())))
                            .font(.system(size: 15)).foregroundStyle(Theme.inkMuted)
                        Text(format(remaining))
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .foregroundStyle(remaining > 0 ? Theme.accent : Theme.flame)
                            .monospacedDigit()
                        Text("deadline \(deadline.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.inkMuted)
                    }
                }
                Spacer()

                if isPausedToday && !isCompletedToday {
                    // No actions while paused - the whole point is that nothing is owed.
                } else if isRestDay && !isCompletedToday {
                    Button(action: onBonusTapped) {
                        Text(bonusLoggedToday ? InsultPool.bonusDoneButton : InsultPool.bonusButton)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(Theme.panel)
                            .foregroundStyle(Theme.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(bonusLoggedToday)
                    .opacity(bonusLoggedToday ? 0.4 : 1)
                    .accessibilityIdentifier("bonusWorkoutButton")
                } else {
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

                if !isCompletedToday && !isRestDay && !isPausedToday && remaining <= 0 {
                    Button(action: onMissCheckFired) {
                        Text("Push it back")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(13)
                            .foregroundStyle(Theme.flame)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
        .onReceive(timer) { date in
            now = date
            guard !isCompletedToday, !isPausedToday, let missCheckTime else { return }
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
        }
        // If not found, we do NOT auto-open the snooze sheet - that would declare failure
        // while the user might still be mid-workout. The interactive "are you working out?"
        // notification (which fires at this same time and presents even in the foreground)
        // is the single surface for that decision. The manual "Push it back" button below
        // stays available as a fallback if notifications are disabled.
    }

    private func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
