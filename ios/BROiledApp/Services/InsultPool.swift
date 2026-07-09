import Foundation

/// Phase 0 gen-z voice copy. Kept as the single source of truth so it can eventually be
/// namespaced by persona in Phase 1 (see plan.md "Reference: Phase 1 persona planning").
/// Every line here mirrors plan.md's "Insult pool (Phase 0 - Gen-Z meme voice)" section
/// and wireframe_phase0.html exactly - keep those three in sync when editing copy.
enum InsultPool {
    static let onboardingHeadline = "bro when are we fighting demons?"

    static let zeroStreak = [
        "kitchen's open, prove it",
        "day 1 - no crumbs yet, good or bad we'll see",
        "prep's done, cook time",
        "nobody's roasted you yet, rare mercy",
    ]

    static let reminder = [
        "still time to lock in, chef",
        "timer's running, get cooking",
        "your body's gonna be tea",
    ]

    static let missCheckMsg = [
        "did ya fold",
        "did you clock out",
        "no extensions",
        "is it a skill issue",
        "the audacity to not show up",
        "npc behavior",
        "take the l",
    ]

    static let snoozeMild = [
        "still marinating",
        "don't let it burn",
        "don't make me come back",
        "bro said 5 more minutes",
        "bro hit snooze",
        "don't make me roast you later",
        "not very main character of you today",
    ]

    static let snoozeSpicy = [
        "recipe for disaster and you're the recipe",
        "fire the chef, you're taking the burn today",
        "half baked and proud of it apparently",
        "lowkey embarrassing at this point",
        "this you - third time's not the charm",
        "simmer down - oh wait you already have",
    ]

    static let snoozeNuclear = [
        "fried chicken's probably the healthiest thing you ate today",
        "toast",
        "folded",
        "fumbled",
        "ash",
    ]

    /// snooze 1 -> MILD, 2-3 -> SPICY, 4+ -> NUCLEAR, cycling once exhausted.
    static func snoozeLine(forSnoozeCount count: Int) -> String {
        let pool: [String]
        switch count {
        case ...1: pool = snoozeMild
        case 2...3: pool = snoozeSpicy
        default: pool = snoozeNuclear
        }
        return pool.randomElement() ?? pool[0]
    }

    static let reckoning = [
        "yesterday - mid, no notes",
        "yesterday's leftovers went bad",
        "that workout ghosted itself",
    ]

    static let streak23 = [
        "this ain't a phase this is the plot",
        "you're speedrunning washed",
        "three days of vibes zero days of reps",
    ]

    static let streak46 = [
        "bro really said let it rot",
        "this is a recipe for disaster and you wrote it",
        "ngl u kinda down bad",
    ]

    static let finale = "chef, you're fired - no room for chopped losers here"

    static let reactivation = [
        "redemption arc or fluke, we'll see",
        "you a comeback king or is this just another fling",
        "character development",
    ]

    static let success = [
        "you ate - barely",
        "certified chef - for today",
        "rare w, emphasis on rare",
        "showed up to glow up - barely",
        "aura +100 allegedly",
        "certified banger - for today",
        "slay but let's not get ahead of ourselves",
        "understood the assignment - barely",
    ]

    /// Rare easter-egg line for very high streaks (100+ days) - reserved, not part of
    /// the regular success rotation. See plan.md.
    static let tooHotToRoast = "too hot to roast"

    /// Morning-after banner headline + line, tiered by consecutive miss count.
    /// 7+ is handled separately by the silence state, not this function.
    static func morningBanner(missStreak: Int) -> (headline: String, line: String) {
        switch missStreak {
        case ...1:
            return ("you skipped yesterday", reckoning.randomElement() ?? reckoning[0])
        case 2...3:
            return ("\(missStreak) days missed", streak23.randomElement() ?? streak23[0])
        default:
            return ("\(missStreak) days missed", streak46.randomElement() ?? streak46[0])
        }
    }
}
