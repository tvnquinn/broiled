import SwiftUI

struct ScheduleEditView: View {
    let habit: Habit
    let settings: UserSettings

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var activeDays: Set<Int>
    @State private var timesByWeekday: [Int: Date]
    @State private var typesByWeekday: [Int: String]
    @State private var minDuration: Int
    // Custom-type entry: the alert needs to know which weekday it's editing.
    @State private var customTypeWeekday: Int?
    @State private var customTypeText = ""

    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    init(habit: Habit, settings: UserSettings) {
        self.habit = habit
        self.settings = settings
        let schedule = habit.schedule
        _activeDays = State(initialValue: Set(schedule.map(\.weekday)))
        _timesByWeekday = State(initialValue: Dictionary(uniqueKeysWithValues: schedule.map { entry in
            (entry.weekday, Calendar.current.date(bySettingHour: entry.hour, minute: entry.minute, second: 0, of: Date()) ?? Date())
        }))
        _typesByWeekday = State(initialValue: Dictionary(uniqueKeysWithValues: schedule.compactMap { entry in
            entry.workoutType.map { (entry.weekday, $0) }
        }))
        _minDuration = State(initialValue: habit.minDurationMinutes)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            // Scrollable body with Save pinned below: a full week of day rows (each now
            // two lines tall with its type menu) overflows any iPhone screen - without
            // this, Save sat off-screen and was untappable (caught by the UI tests).
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
                            .accessibilityIdentifier("dayToggle-\(weekday)")
                        }
                    }
                }

                if !activeDays.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("DEADLINE PER DAY").font(.caption2).foregroundStyle(Theme.inkMuted).tracking(1)
                        ForEach(WeekdaySchedule.sortedMondayFirst(activeDays), id: \.self) { weekday in
                            VStack(spacing: 8) {
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
                                // v0.2 Wave 2: optional per-day workout type. Common
                                // types + free text; "any workout" clears it.
                                Menu {
                                    ForEach(WorkoutEntry.commonTypes, id: \.self) { type in
                                        Button(type) { typesByWeekday[weekday] = type }
                                    }
                                    Button("custom…") {
                                        customTypeText = ""
                                        customTypeWeekday = weekday
                                    }
                                    if typesByWeekday[weekday] != nil {
                                        Button("any workout", role: .destructive) { typesByWeekday[weekday] = nil }
                                    }
                                } label: {
                                    HStack {
                                        Text(typesByWeekday[weekday] ?? "any workout")
                                            .font(.system(size: 13))
                                            .foregroundStyle(typesByWeekday[weekday] == nil ? Theme.inkMuted : Theme.accent)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Theme.inkMuted)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .accessibilityIdentifier("typeMenu-\(weekday)")
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
                    }
                    .padding(20)
                }

                Button {
                    save()
                } label: {
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
        .alert("what kind of workout?", isPresented: Binding(
            get: { customTypeWeekday != nil },
            set: { if !$0 { customTypeWeekday = nil } }
        )) {
            TextField("e.g. bouldering", text: $customTypeText)
                .autocorrectionDisabled()
            Button("Set") {
                if let weekday = customTypeWeekday {
                    let trimmed = customTypeText.trimmingCharacters(in: .whitespacesAndNewlines)
                    typesByWeekday[weekday] = trimmed.isEmpty ? nil : trimmed
                }
                customTypeWeekday = nil
            }
            Button("Cancel", role: .cancel) { customTypeWeekday = nil }
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

    private func save() {
        let calendar = Calendar.current
        let schedule: [WeekdaySchedule] = WeekdaySchedule.sortedMondayFirst(activeDays).map { weekday in
            let time = timesByWeekday[weekday] ?? defaultTime()
            let comps = calendar.dateComponents([.hour, .minute], from: time)
            return WeekdaySchedule(weekday: weekday, hour: comps.hour ?? 18, minute: comps.minute ?? 0, workoutType: typesByWeekday[weekday])
        }
        habit.schedule = schedule
        habit.minDurationMinutes = minDuration

        // The old locked-in deadline would otherwise keep masking today's freshly edited
        // time - see UserSettings.todayOverride.
        settings.clearTodayOverride()
        try? context.save()

        if let newDeadline = habit.deadline(for: Date()) {
            NotificationService.shared.scheduleDeadlinePair(deadline: newDeadline, durationMinutes: minDuration, workoutType: habit.workoutType(for: Date()))
        } else {
            NotificationService.shared.cancelDeadlinePair()
        }

        dismiss()
    }
}
