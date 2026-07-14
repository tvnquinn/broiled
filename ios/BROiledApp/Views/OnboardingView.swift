import SwiftUI

/// Editor-only identity for one planned workout. The persisted schedule stays a small
/// Codable value; UUIDs exist here so two sessions on one weekday edit independently.
struct WorkoutScheduleDraft: Identifiable {
    let id = UUID()
    var time: Date
    var type: String?
    var durationMinutes: Int
}

struct PlannedWorkoutEditor: View {
    @Binding var draft: WorkoutScheduleDraft
    let canDelete: Bool
    let onDelete: () -> Void
    @State private var showingCustomType = false
    @State private var customType = ""

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Menu {
                    ForEach(WorkoutEntry.commonTypes, id: \.self) { type in
                        Button(type) { draft.type = type }
                    }
                    Button("custom…") {
                        customType = draft.type ?? ""
                        showingCustomType = true
                    }
                    if draft.type != nil {
                        Button("any workout", role: .destructive) { draft.type = nil }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(draft.type ?? "any workout")
                            .foregroundStyle(draft.type == nil ? Theme.inkMuted : Theme.accent)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkMuted)
                    }
                }
                Spacer()
                DatePicker("", selection: $draft.time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                if canDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "minus.circle.fill")
                    }
                    .foregroundStyle(Theme.flame)
                    .accessibilityLabel("Remove workout")
                }
            }

            HStack {
                Text("duration").font(.system(size: 13)).foregroundStyle(Theme.inkMuted)
                Spacer()
                Stepper("\(draft.durationMinutes) min", value: $draft.durationMinutes, in: 5...300, step: 5)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink)
                    .fixedSize()
            }
        }
        .padding(11)
        .background(Theme.bg.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .alert("what kind of workout?", isPresented: $showingCustomType) {
            TextField("e.g. bouldering", text: $customType)
                .autocorrectionDisabled()
            Button("Set") {
                let trimmed = customType.trimmingCharacters(in: .whitespacesAndNewlines)
                draft.type = trimmed.isEmpty ? nil : trimmed
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct WorkoutDayEditor: View {
    let weekdayName: String
    @Binding var workouts: [WorkoutScheduleDraft]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(weekdayName).font(.subheadline.bold()).foregroundStyle(Theme.ink)
            ForEach($workouts) { $draft in
                PlannedWorkoutEditor(
                    draft: $draft,
                    canDelete: workouts.count > 1,
                    onDelete: { workouts.removeAll { $0.id == draft.id } }
                )
            }
            Button {
                workouts.append(WorkoutScheduleDraft(time: defaultTime(), type: nil, durationMinutes: 30))
            } label: {
                Label("add another workout", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(12)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func defaultTime() -> Date {
        Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    }
}

struct OnboardingView: View {
    let habit: Habit
    let onStart: (Date?) -> Void

    @State private var activeDays: Set<Int>
    @State private var workoutsByWeekday: [Int: [WorkoutScheduleDraft]]
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    init(habit: Habit, onStart: @escaping (Date?) -> Void) {
        self.habit = habit
        self.onStart = onStart
        let days: Set<Int> = ProcessInfo.processInfo.arguments.contains("UI-TESTING") ? Set(1...7) : [2, 4, 6]
        _activeDays = State(initialValue: days)
        let defaultTime = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
        _workoutsByWeekday = State(initialValue: Dictionary(uniqueKeysWithValues: days.map {
            ($0, [WorkoutScheduleDraft(time: defaultTime, type: nil, durationMinutes: 30)])
        }))
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(InsultPool.onboardingHeadline)
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
                                }
                            }
                        }
                    }
                    .padding(20)
                }

                Button(action: commit) {
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

    private func commit() {
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
        habit.minDurationMinutes = habit.schedule.compactMap(\.durationMinutes).min() ?? 30
        onStart(habit.deadline(for: Date()))
    }
}
