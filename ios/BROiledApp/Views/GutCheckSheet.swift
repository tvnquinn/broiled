import SwiftUI

struct GutCheckSheet: View {
    /// The bonus-workout flow reuses this sheet with its own question - same honesty
    /// gate, different thing being sworn to.
    var question: String = InsultPool.gutCheckQuestion
    let onYes: () -> Void
    let onNo: () -> Void

    var body: some View {
        ZStack {
            Theme.panel.ignoresSafeArea()
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

                Button(action: onYes) {
                    Text(InsultPool.gutCheckYes)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(13)
                        .background(Theme.ink)
                        .foregroundStyle(Theme.bg)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
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
        .preferredColorScheme(.dark)
    }
}
