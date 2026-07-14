import SwiftUI
import SwiftData

struct BurnBookView: View {
    @Query(sort: \RoastRecord.loggedAt, order: .reverse) private var records: [RoastRecord]

    private struct CollectedLine: Identifiable {
        let line: String
        let kind: RoastKind
        let records: [RoastRecord]
        var id: String { "\(kind.rawValue)-\(line)" }
        var latest: Date { records.map(\.loggedAt).max() ?? .distantPast }
    }

    private var roastPool: [String] { InsultPool.burnBookRoasts }
    private var complimentPool: [String] { InsultPool.burnBookCompliments }
    private var roastRecords: [RoastRecord] { records.filter { $0.kind == .roast } }
    private var complimentRecords: [RoastRecord] { records.filter { $0.kind == .compliment } }

    private var unlockedRoasts: Int {
        BurnBook.unlockedCount(seenLines: roastRecords.map(\.line), pool: roastPool)
    }

    private var unlockedCompliments: Int {
        BurnBook.unlockedCount(seenLines: complimentRecords.map(\.line), pool: complimentPool)
    }

    private var collectedLines: [CollectedLine] {
        Dictionary(grouping: records) { "\($0.kindRaw)-\($0.line)" }
            .values
            .compactMap { matches in
                guard let first = matches.first else { return nil }
                return CollectedLine(line: first.line, kind: first.kind, records: matches.sorted { $0.loggedAt > $1.loggedAt })
            }
            .sorted { $0.latest > $1.latest }
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("the burn book")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 24)

                    HStack(spacing: 10) {
                        tracker(count: unlockedRoasts, total: roastPool.count, label: "insults unlocked", tint: Theme.accent)
                        tracker(count: unlockedCompliments, total: complimentPool.count, label: "compliments unlocked", tint: Theme.success)
                    }

                    HStack(spacing: 10) {
                        volume(count: roastRecords.count, label: "insults received", tint: Theme.accent)
                        volume(count: complimentRecords.count, label: "compliments received", tint: Theme.success)
                    }

                    if roastRecords.count > complimentRecords.count {
                        Text(InsultPool.burnBookLosingLine)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.flame.opacity(0.13))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    let roastBadge = BurnBook.roastBadge(unlocked: unlockedRoasts, total: roastPool.count)
                    let complimentBadge = BurnBook.complimentBadge(unlocked: unlockedCompliments, total: complimentPool.count)
                    if roastBadge != nil || complimentBadge != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("BADGES").font(.caption2).foregroundStyle(Theme.inkMuted).tracking(1)
                            HStack(spacing: 8) {
                                if let roastBadge { badge(roastBadge, tint: Theme.accent) }
                                if let complimentBadge { badge(complimentBadge, tint: Theme.success) }
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
                            Text("COLLECTION").font(.caption2).foregroundStyle(Theme.inkMuted).tracking(1)
                            ForEach(collectedLines) { item in
                                collectedCard(item)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func collectedCard(_ item: CollectedLine) -> some View {
        let tint = item.kind == .compliment ? Theme.success : Theme.accent
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Text(item.line)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(item.kind == .compliment ? "W" : "L")  ×\(item.records.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tint.opacity(0.14))
                    .clipShape(Capsule())
            }
            // One compact, horizontally scrollable date rail. Internal situation names
            // such as "resume" and "reckoning" are intentionally not user-facing.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(item.records) { record in
                        Text(historyDate(record))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkMuted)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
            .frame(height: 16)
        }
        .padding(12)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func tracker(count: Int, total: Int, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(count)/\(total)").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(tint).monospacedDigit()
            Text(label).font(.system(size: 11.5)).foregroundStyle(Theme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func volume(count: Int, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(count)").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(tint).monospacedDigit()
            Text(label).font(.system(size: 11.5)).foregroundStyle(Theme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
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
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
