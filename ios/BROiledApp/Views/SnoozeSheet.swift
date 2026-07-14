import SwiftUI

/// v0.2 snooze redesign: a real time picker (any time later today) replaces the fixed
/// +15/+30/+1h/+3h options, plus a distinct "push to tomorrow" path:
/// - tomorrow is a rest day -> allowed, but it costs an extra insult on the spot
/// - tomorrow is already scheduled -> warning that today just becomes a miss (confirmed
///   decision: workouts don't merge), then routes through the normal quit path.
struct SnoozeSheet: View {
    /// Whether tomorrow is already on the weekly schedule.
    let tomorrowIsScheduled: Bool
    /// Snooze to an exact time later today.
    let onSnooze: (Date) -> Void
    /// Rest-day tomorrow path - caller defers today and moves the deadline to tomorrow.
    /// Passes the insult that was on screen so the Burn Book collects the real one.
    let onPushToTomorrow: (String) -> Void
    /// Scheduled-tomorrow path - today becomes a miss via the normal quit flow.
    let onTakeMiss: () -> Void
    let onQuit: () -> Void

    @State private var newDeadline = Date().addingTimeInterval(30 * 60)
    @State private var showTomorrowConfirm = false
    @State private var tomorrowInsult = InsultPool.tomorrowLine()

    var body: some View {
        ZStack {
            Theme.panel.ignoresSafeArea()
            VStack(spacing: 14) {
                Capsule().fill(Theme.lineStrong).frame(width: 36, height: 4).padding(.top, 10)

                Text(InsultPool.snoozeSheetTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Text("New deadline").foregroundStyle(Theme.ink)
                    Spacer()
                    DatePicker("", selection: $newDeadline, in: Date()..., displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(Theme.accent)
                }
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: [4])))

                Button {
                    onSnooze(newDeadline)
                } label: {
                    Text("Snooze")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(13)
                        .background(Theme.accent)
                        .foregroundStyle(Theme.chrome)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("snoozeConfirmButton")

                if showTomorrowConfirm {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tomorrowIsScheduled ? InsultPool.tomorrowAlreadyScheduledWarning : tomorrowInsult)
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if tomorrowIsScheduled {
                            Button(action: onTakeMiss) {
                                Text(InsultPool.tomorrowConfirmMiss)
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Theme.flame)
                                    .foregroundStyle(Theme.chrome)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            Button {
                                showTomorrowConfirm = false
                            } label: {
                                Text(InsultPool.tomorrowCancel)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(10)
                                    .foregroundStyle(Theme.inkMuted)
                            }
                        } else {
                            Button(action: { onPushToTomorrow(tomorrowInsult) }) {
                                Text("do it")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Theme.ink)
                                    .foregroundStyle(Theme.bg)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .accessibilityIdentifier("pushToTomorrowConfirmButton")
                        }
                    }
                    .padding(12)
                    .background(tomorrowIsScheduled ? Theme.flame.opacity(0.13) : Theme.accent.opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Button {
                        showTomorrowConfirm = true
                    } label: {
                        Text(InsultPool.tomorrowOptionLabel)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(13)
                            .foregroundStyle(Theme.ink)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.lineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [4])))
                    }
                    .accessibilityIdentifier("pushToTomorrowButton")
                }

                Button(action: onQuit) {
                    Text("I'm a Quitter")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(13)
                        .foregroundStyle(Theme.flame)
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.flame, lineWidth: 1.5))
                }
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
    }
}
