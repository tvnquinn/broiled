import SwiftUI

struct ScheduleEditView: View {
    let habit: Habit
    let settings: UserSettings

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var activeDays: Set<Int>
    @State private var workoutsByWeekday: [Int: [WorkoutScheduleDraft]]
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    init(habit: Habit, settings: UserSettings) {
        self.habit = habit
        self.settings = settings
        let schedule = habit.schedule
        _activeDays = State(initialValue: Set(schedule.map(\.weekday)))
        let grouped = Dictionary(grouping: schedule, by: \.weekday).mapValues { entries in
            entries
                .sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
                .map { entry in
                    WorkoutScheduleDraft(
                        time: Calendar.current.date(bySettingHour: entry.hour, minute: entry.minute, second: 0, of: Date()) ?? Date(),
                        type: entry.workoutType,
                        durationMinutes: entry.resolvedDuration(fallback: habit.minDurationMinutes)
                    )
                }
        }
        _workoutsByWeekday = State(initialValue: grouped)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Edit schedule")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .padding(.top, 24)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("DAYS").font(.caption2).foregroundStyle(Theme.inkMuted).tracking(1)
                            HStack(spacing: 8) {
                                ForEach(WeekdaySchedule.sortedMondayFirst(1...7), id: \.self) { weekday in
                                    Button { toggle(weekday) } label: {
                                        Text(weekdaySymbols[weekday - 1])
                                            .font(.system(size: 13, weight: .semibold))
                                            .frame(width: 34, height: 34)
                                            .background(activeDays.contains(weekday) ? Theme.ink : .clear)
                                            .foregroundStyle(activeDays.contains(weekday) ? Theme.panel : Theme.inkMuted)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Theme.lineStrong, lineWidth: activeDays.contains(weekday) ? 0 : 1.5))
                                    }
                                    .accessibilityIdentifier("dayToggle-\(weekday)")
                                }
                            }
                        }

                        if !activeDays.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("WORKOUTS PER DAY").font(.caption2).foregroundStyle(Theme.inkMuted).tracking(1)
                                ForEach(WeekdaySchedule.sortedMondayFirst(activeDays), id: \.self) { weekday in
                                    WorkoutDayEditor(
                                        weekdayName: fullName(weekday),
                                        workouts: Binding(
                                            get: { workoutsByWeekday[weekday] ?? [newDraft()] },
                                            set: { workoutsByWeekday[weekday] = $0 }
                                        )
                                    )
                                    .accessibilityIdentifier("scheduleDay-\(weekday)")
                                }
                            }
                        }
                    }
                    .padding(20)
                }

                Button(action: save) {
                    Text("Save")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Theme.accent)
                        .foregroundStyle(Theme.chrome)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(activeDays.isEmpty)
                .opacity(activeDays.isEmpty ? 0.4 : 1)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func toggle(_ weekday: Int) {
        if activeDays.contains(weekday) {
            activeDays.remove(weekday)
        } else {
            activeDays.insert(weekday)
            if workoutsByWeekday[weekday] == nil { workoutsByWeekday[weekday] = [newDraft()] }
        }
    }

    private func newDraft() -> WorkoutScheduleDraft {
        WorkoutScheduleDraft(
            time: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date(),
            type: nil,
            durationMinutes: 30
        )
    }

    private func fullName(_ weekday: Int) -> String {
        ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][weekday - 1]
    }

    private func save() {
        let calendar = Calendar.current
        habit.schedule = WeekdaySchedule.sortedMondayFirst(activeDays).flatMap { weekday in
            (workoutsByWeekday[weekday] ?? [newDraft()]).map { draft in
                let comps = calendar.dateComponents([.hour, .minute], from: draft.time)
                return WeekdaySchedule(
                    weekday: weekday,
                    hour: comps.hour ?? 18,
                    minute: comps.minute ?? 0,
                    workoutType: draft.type,
                    durationMinutes: draft.durationMinutes
                )
            }
        }
        // Kept only as a migration fallback for old schedule rows and pushed deadlines.
        habit.minDurationMinutes = habit.schedule.compactMap(\.durationMinutes).min() ?? 30
        settings.clearTodayOverride()
        try? context.save()

        if habit.isActiveDay(Date()) {
            NotificationService.shared.scheduleDay(
                workouts: habit.scheduledWorkouts(for: Date()),
                on: Date(),
                fallbackDuration: habit.minDurationMinutes
            )
        } else {
            NotificationService.shared.cancelDeadlinePair()
        }
        dismiss()
    }
}
