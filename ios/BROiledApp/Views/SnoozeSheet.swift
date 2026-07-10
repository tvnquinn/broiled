import SwiftUI

struct SnoozeSheet: View {
    let onSnooze: (Int) -> Void
    let onQuit: () -> Void

    @State private var selectedMinutes = 30
    private let options = [15, 30, 60, 180]

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
                    Picker("", selection: $selectedMinutes) {
                        ForEach(options, id: \.self) { minutes in
                            Text(label(for: minutes)).tag(minutes)
                        }
                    }
                    .tint(Theme.ink)
                }
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: [4])))

                Button {
                    onSnooze(selectedMinutes)
                } label: {
                    Text("Snooze")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(13)
                        .background(Theme.accent)
                        .foregroundStyle(Theme.chrome)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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

    private func label(for minutes: Int) -> String {
        minutes < 60 ? "+\(minutes) min" : "+\(minutes / 60) hr"
    }
}
