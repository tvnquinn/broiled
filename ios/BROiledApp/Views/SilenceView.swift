import SwiftUI

struct SilenceView: View {
    let onLogWorkout: () -> Void

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                Text(InsultPool.silenceStatusLine)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkMuted)

                VStack(alignment: .leading, spacing: 6) {
                    Text(InsultPool.silenceHeadline).font(.system(size: 13.5)).foregroundStyle(Theme.inkMuted)
                    Text(InsultPool.silenceSub).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.ash.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Spacer()

                Button(action: onLogWorkout) {
                    Text(InsultPool.logWorkoutButton)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Theme.ink)
                        .foregroundStyle(Theme.bg)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
    }
}
