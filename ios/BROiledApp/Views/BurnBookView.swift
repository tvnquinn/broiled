import SwiftUI
import SwiftData

/// v0.2 Wave 3: the Burn Book - every line the app has thrown, chronological, with
/// unlock trackers and the insult-named badge ladder. Settings drill-in.
struct BurnBookView: View {
    @Query(sort: \RoastRecord.loggedAt, order: .reverse) private var records: [RoastRecord]

    private var roastPool: [String] { InsultPool.burnBookRoasts }
    private var complimentPool: [String] { InsultPool.burnBookCompliments }

    private var unlockedRoasts: Int {
        BurnBook.unlockedCount(seenLines: records.filter { $0.kind == .roast }.map(\.line), pool: roastPool)
    }

    private var unlockedCompliments: Int {
        BurnBook.unlockedCount(seenLines: records.filter { $0.kind == .compliment }.map(\.line), pool: complimentPool)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("the Burn Book")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 24)

                    HStack(spacing: 10) {
                        tracker(count: unlockedRoasts, total: roastPool.count, label: "insults unlocked", tint: Theme.accent)
                        tracker(count: unlockedCompliments, total: complimentPool.count, label: "compliments unlocked", tint: Theme.success)
                    }

                    let roastBadge = BurnBook.roastBadge(unlocked: unlockedRoasts, total: roastPool.count)
                    let complimentBadge = BurnBook.complimentBadge(unlocked: unlockedCompliments, total: complimentPool.count)
                    if roastBadge != nil || complimentBadge != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("BADGES").font(.caption2).foregroundStyle(Theme.inkMuted).tracking(1)
                            HStack(spacing: 8) {
                                if let roastBadge {
                                    badge(roastBadge, tint: Theme.accent)
                                }
                                if let complimentBadge {
                                    badge(complimentBadge, tint: Theme.success)
                                }
                            }
                        }
                    }

                    if records.isEmpty {
                        Text("nothing collected yet. the roasts will come, don't worry")
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.inkMuted)
                            .padding(.top, 12)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("HISTORY").font(.caption2).foregroundStyle(Theme.inkMuted).tracking(1)
                            ForEach(records) { record in
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(record.line)
                                            .font(.system(size: 13.5))
                                            .foregroundStyle(Theme.ink)
                                        Text(historyDate(record))
                                            .font(.system(size: 11))
                                            .foregroundStyle(Theme.inkMuted)
                                    }
                                    Spacer()
                                    Text(record.kind == .compliment ? "W" : "L")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(record.kind == .compliment ? Theme.success : Theme.accent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background((record.kind == .compliment ? Theme.success : Theme.accent).opacity(0.14))
                                        .clipShape(Capsule())
                                }
                                .padding(12)
                                .background(Theme.panel)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func tracker(count: Int, total: Int, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(count)/\(total)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func badge(_ name: String, tint: Color) -> some View {
        Text(name)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 1))
    }

    private func historyDate(_ record: RoastRecord) -> String {
        guard let date = DateKey.date(from: record.dateKey) else { return record.dateKey }
        return "\(date.formatted(date: .abbreviated, time: .omitted)) · \(record.situation)"
    }
}
