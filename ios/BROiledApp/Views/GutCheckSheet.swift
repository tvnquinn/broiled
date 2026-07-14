import SwiftUI

struct GutCheckSheet: View {
    var question: String = InsultPool.gutCheckQuestion
    var suggestedTypes: [String] = []
    let onYes: (String?, Int) -> Void
    let onNo: () -> Void

    @State private var workoutType: String?
    @State private var durationMinutes = 30
    @State private var customType = ""
    @State private var showingCustomType = false

    init(
        question: String = InsultPool.gutCheckQuestion,
        suggestedTypes: [String] = [],
        defaultType: String? = nil,
        defaultDuration: Int = 30,
        onYes: @escaping (String?, Int) -> Void,
        onNo: @escaping () -> Void
    ) {
        self.question = question
        self.suggestedTypes = suggestedTypes
        self.onYes = onYes
        self.onNo = onNo
        _workoutType = State(initialValue: defaultType)
        _durationMinutes = State(initialValue: defaultDuration)
    }

    private var typeOptions: [String] {
        Array(Set(suggestedTypes + WorkoutEntry.commonTypes)).sorted()
    }

    var body: some View {
        ZStack {
            Theme.panel.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    Capsule().fill(Theme.lineStrong).frame(width: 36, height: 4).padding(.top, 10)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(InsultPool.gutCheckPrompt).font(.system(size: 15)).foregroundStyle(Theme.ink)
                        Text(question).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Theme.accent.opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(spacing: 12) {
                        HStack {
                            Text("workout").foregroundStyle(Theme.inkMuted)
                            Spacer()
                            Menu {
                                ForEach(typeOptions, id: \.self) { type in
                                    Button(type) { workoutType = type }
                                }
                                Button("custom…") {
                                    customType = workoutType ?? ""
                                    showingCustomType = true
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(workoutType ?? "choose type")
                                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 10))
                                }
                                .foregroundStyle(Theme.accent)
                            }
                        }

                        HStack {
                            Text("duration").foregroundStyle(Theme.inkMuted)
                            Spacer()
                            Stepper("\(durationMinutes) min", value: $durationMinutes, in: 5...300, step: 5)
                                .foregroundStyle(Theme.ink)
                                .fixedSize()
                        }
                    }
                    .padding(14)
                    .background(Theme.bg.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button { onYes(workoutType, durationMinutes) } label: {
                        Text(InsultPool.gutCheckYes)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(13)
                            .background(Theme.ink)
                            .foregroundStyle(Theme.bg)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(workoutType == nil)
                    .opacity(workoutType == nil ? 0.45 : 1)

                    Button(action: onNo) {
                        Text(InsultPool.gutCheckNo)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(13)
                            .foregroundStyle(Theme.ink)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.lineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [4])))
                    }
                }
                .padding(20)
            }
        }
        .alert("what kind of workout?", isPresented: $showingCustomType) {
            TextField("e.g. bouldering", text: $customType)
                .autocorrectionDisabled()
            Button("Set") {
                let trimmed = customType.trimmingCharacters(in: .whitespacesAndNewlines)
                workoutType = trimmed.isEmpty ? nil : trimmed
            }
            Button("Cancel", role: .cancel) {}
        }
        .preferredColorScheme(.dark)
    }
}
