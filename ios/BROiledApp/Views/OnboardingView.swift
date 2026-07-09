import SwiftUI

struct OnboardingView: View {
    let habit: Habit
    let onStart: (Date) -> Void

    @State private var activeDays: Set<Int> = [2, 4, 6] // Mon, Wed, Fri (Calendar: 1=Sun)
    @State private var timesByWeekday: [Int: Date] = [:]
    @State private var minDuration = 30

    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                Text(InsultPool.onboardingHeadline)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 24)

                VStack(alignment: .leading, spacing: 10) {
                    Text("DAYS").font(.caption2).foregroundStyle(Theme.inkMuted).tracking(1)
                    HStack(spacing: 8) {
                        ForEach(1...7, id: \.self) { weekday in
                            Button {
                                toggle(weekday)
                            } label: {
                                Text(weekdaySymbols[weekday - 1])
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(width: 34, height: 34)
                                    .background(activeDays.contains(weekday) ? Theme.ink : .clear)
                                    .foregroundStyle(activeDays.contains(weekday) ? Theme.panel : Theme.inkMuted)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Theme.lineStrong, lineWidth: activeDays.contains(weekday) ? 0 : 1.5))
                            }
                        }
                    }
                }

                if !activeDays.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("DEADLINE PER DAY").font(.caption2).foregroundStyle(Theme.inkMuted).tracking(1)
                        ForEach(activeDays.sorted(), id: \.self) { weekday in
                            HStack {
                                Text(fullName(weekday)).font(.subheadline.bold()).foregroundStyle(Theme.ink)
                                Spacer()
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: { timesByWeekday[weekday] ?? defaultTime() },
                                        set: { timesByWeekday[weekday] = $0 }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                            }
                            .padding(12)
                            .background(Theme.panel)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                HStack {
                    Text("Minimum duration").foregroundStyle(Theme.ink)
                    Spacer()
                    Stepper("\(minDuration) min", value: $minDuration, in: 5...180, step: 5)
                        .fixedSize()
                }
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: [4])))

                Spacer()

                Button {
                    commit()
                } label: {
                    Text("Start")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Theme.accent)
                        .foregroundStyle(Theme.chrome)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(activeDays.isEmpty)
                .opacity(activeDays.isEmpty ? 0.4 : 1)
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
    }

    private func toggle(_ weekday: Int) {
        if activeDays.contains(weekday) {
            activeDays.remove(weekday)
        } else {
            activeDays.insert(weekday)
        }
    }

    private func defaultTime() -> Date {
        Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private func fullName(_ weekday: Int) -> String {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return names[weekday - 1]
    }

    private func commit() {
        let calendar = Calendar.current
        let schedule: [WeekdaySchedule] = activeDays.map { weekday in
            let time = timesByWeekday[weekday] ?? defaultTime()
            let comps = calendar.dateComponents([.hour, .minute], from: time)
            return WeekdaySchedule(weekday: weekday, hour: comps.hour ?? 18, minute: comps.minute ?? 0)
        }
        habit.schedule = schedule
        habit.minDurationMinutes = minDuration

        let today = Date()
        let deadline = habit.deadline(for: today) ?? calendar.date(byAdding: .day, value: 1, to: today) ?? today
        onStart(deadline)
    }
}
