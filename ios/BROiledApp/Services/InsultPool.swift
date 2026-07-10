import Foundation

/// Phase 0 gen-z voice copy. Kept as the single source of truth so it can eventually be
/// namespaced by persona in Phase 1 (see plan.md "Reference: Phase 1 persona planning").
/// Every line here mirrors plan.md's "Insult pool (Phase 0 - Gen-Z meme voice)" section
/// and wireframe_phase0.html - keep those in sync when editing copy.
enum InsultPool {
    static let onboardingHeadline = "when are you working out?"

    static let zeroStreak = [
        "kitchen's open, prove it",
        "day 1 - no crumbs yet, good or bad we'll see",
        "prep's done, cook time",
        "nobody's roasted you yet, rare mercy",
    ]

    static let reminder = [
        "still time to lock in and complete",
        "timer's running, get cooking",
        "breakfast time - are you toasting or toast",
        "lunch time, crunch time",
        "winner winner or are you the chicken dinner",
        "fire work today",
        "your body's gonna be tea",
    ]

    static let missCheckMsg = [
        "will you later?",
        "you snooze you lose",
        "did ya fold",
        "did you clock out",
        "no extensions",
        "is it a skill issue",
        "burned before you even started",
        "the audacity to not show up",
        "npc behavior",
        "take the l",
    ]

    static let snoozeMild = [
        "still marinating",
        "don't let it burn",
        "don't make me come back",
        "bro really said 5 more minutes",
        "bro hit snooze",
        "don't make me roast you later",
    ]

    static let snoozeSpicy = [
        "you're a recipe for disaster",
        "fire the chef, you're taking the burn today",
        "half baked and proud of it apparently",
        "low-key embarrassing at this point",
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

    static let reckoningCanonical = "is this who you are, or can you be better today?"

    static let reckoning = [
        reckoningCanonical,
        "mid, no notes",
        "leftovers went bad",
        "that workout ghosted itself",
    ]

    static let streak23 = [
        "this ain't a phase this is the plot",
        "you're speedrunning washed",
        "three days of vibes zero days of reps",
    ]

    static let streak46Canonical = "at this point i'm not disappointed i'm just not surprised"

    static let streak46 = [
        streak46Canonical,
        "bro really said let it rot",
        "you're down bad",
    ]

    static let silenceHeadline = "i'm giving up on you"
    static let silenceSub = "no room for chopped losers here, talk to me when you're worth it"

    static let reactivation = [
        "redemption arc or fluke, we'll see",
        "you a comeback king or is this just another fling",
        "character development",
    ]

    static let successHeadline = [
        "you're not a loser today",
        "you're not a dud today",
    ]

    static let successSub = "let's see about tomorrow"

    static let successAlternates = [
        "you ate - barely",
        "certified chef - for today",
        "rare w, emphasis on rare",
        "showed up to glow up",
        "aura +100 allegedly",
        "certified banger - for today",
        "slay but let's not get ahead of ourselves",
        "understood the assignment - barely",
    ]

    /// Rare easter-egg line for very high streaks (100+ days) - reserved, not part of
    /// the regular success rotation. See plan.md.
    static let tooHotToRoast = "too hot to roast"

    static let gutCheckPrompt = "this app is private, lying to it is embarrassing"
    static let gutCheckQuestion = "did you work out today?"
    static let gutCheckYes = "yes!"
    static let gutCheckNo = "...no I lied"

    /// Morning-after banner headline + line, tiered by consecutive miss count.
    /// 7+ is handled separately by the silence state, not this function.
    static func morningBanner(missStreak: Int) -> (headline: String, line: String) {
        switch missStreak {
        case ...1:
            return ("you skipped yesterday", reckoning.randomElement() ?? reckoningCanonical)
        case 2...3:
            return ("\(missStreak) days missed", streak23.randomElement() ?? streak23[0])
        default:
            return ("\(missStreak) days missed", streak46.randomElement() ?? streak46Canonical)
        }
    }
}
