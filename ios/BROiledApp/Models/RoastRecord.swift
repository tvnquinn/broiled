import Foundation
import SwiftData

enum RoastKind: String, Codable {
    case roast
    case compliment
}

/// v0.2 Wave 3, the Burn Book: one row per line the app actually threw at the user.
/// Unlock trackers count *distinct* lines against the pools in `InsultPool`; the
/// chronological list is the history page.
@Model
final class RoastRecord {
    var dateKey: String
    var line: String
    var kindRaw: String
    /// Where the line surfaced: "reckoning", "snooze", "success", "push-to-tomorrow",
    /// "bonus", "silence", "resume", "reactivation".
    var situation: String
    var loggedAt: Date

    var kind: RoastKind { RoastKind(rawValue: kindRaw) ?? .roast }

    init(dateKey: String, line: String, kind: RoastKind, situation: String, loggedAt: Date = Date()) {
        self.dateKey = dateKey
        self.line = line
        self.kindRaw = kind.rawValue
        self.situation = situation
        self.loggedAt = loggedAt
    }
}

/// Unlock math for the Burn Book - pure functions so the badge ladder is unit-testable.
enum BurnBook {
    /// Distinct lines seen, counted only against the current pool (a line that later
    /// leaves the pool shouldn't inflate the tracker).
    static func unlockedCount(seenLines: some Sequence<String>, pool: [String]) -> Int {
        let poolSet = Set(pool)
        return Set(seenLines).intersection(poolSet).count
    }

    /// Roast badge ladder - the badge names are themselves insults. Thresholds are
    /// tuned to the actual pool size (36 lines), so every badge is attainable; the
    /// plan's aspirational "50" tier maps to 30 here.
    static func roastBadge(unlocked: Int, total: Int) -> String? {
        if total > 0 && unlocked >= total { return "fully roasted" }
        switch unlocked {
        case 30...: return "well done"
        case 25...: return "roast magnet"
        case 10...: return "glutton for punishment"
        case 5...: return "certified punching bag"
        default: return nil
        }
    }

    /// Compliment ladder - the pool is only 10 lines deep, so the tiers sit at 3/7/all.
    /// "too hot to roast" (the reserved easter-egg line) is the crown badge.
    static func complimentBadge(unlocked: Int, total: Int) -> String? {
        if total > 0 && unlocked >= total { return InsultPool.tooHotToRoast }
        switch unlocked {
        case 7...: return "annoyingly consistent"
        case 3...: return "barely tolerable"
        default: return nil
        }
    }
}
