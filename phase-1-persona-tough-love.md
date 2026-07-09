---
name: BROiled Phase 1 Persona — Tough-Love Voice
overview: Original tough-love persona & insult pool reserved for Phase 1, when the persona system is built. This version emphasizes psychological pressure, decline urgency, and the "disappointed parent/rival" voice. Kept as a complete reference for Phase 1 persona implementation.
isProject: false
---

# BROiled Phase 1 Persona: Tough-Love Voice

This is the original motivation and insult pool for BROiled, designed around a tough-love psychological framework. Phase 0 ships with Gen-Z meme voice; this persona becomes a selectable option in Phase 1 once `Insults.json` is namespaced by persona × intensity.

---

## The core motivation (tough-love lens)

There's a mentality people describe as having "a bit of dog in you" — the extra gear that shows up when something's actually on the line, the refusal to take a soft no from yourself. Most people don't have easy access to that gear on a random Tuesday when the only thing at stake is whether they go to the gym. This app manufactures that gear on demand — it's the stand-in for stakes that aren't naturally there.

And underneath that: at some point you move out, and the one voice that never once said "good enough" goes quiet. Nobody's tracking your effort against your potential anymore. Nobody's unimpressed on your behalf. This app is built to be that voice again, on purpose — the parent who steps back in for the one thing you keep meaning to actually stick to, because you're the one who asked it to.

It's not therapy and it doesn't pretend to be encouraging. It's a rival and a disappointed relative who happen to live in your lock screen, and the entire game is proving them wrong.

---

## Why this is fun (not just mean)

A shame notification by itself is just a scold — annoying, not delightful. What makes this fun to actually use is the game loop wrapped around the insults, not the insults themselves:

- **Dread → relief is the core dopamine loop.** The countdown to deadline is real stakes, like a boss timer. Log the workout and the pending shame silently clears — that's a small win you get to feel *every day you succeed*, not just punishment on the days you fail.
- **A character, not a random-insult generator.** CARROT Fit (2014, still on the App Store, 4.7★) proved this genre works for a decade on one insight: people don't get attached to "insult #47," they get attached to a personality with a consistent voice. The tough-love parent is that character — consistent, principled, genuinely disappointed.
- **The silence is scarier than the noise.** The 7-day "I'm giving up on you" mechanic — the app going completely quiet until you prove yourself — is the sharpest hook in this design. Most apps nag harder when ignored; this one does the opposite, and making the user *earn back* the app's attention is a stronger emotional beat than any single insult.
- **Backhanded celebration closes the loop.** Success isn't met with silence or a green checkmark, it's met with grudging, sarcastic approval ("Congrats, you're not a loser today"). That's what makes the whole thing feel like a relationship with a character instead of a checklist.

---

## Tough-love insult pool

Organized by category with severity tags (MILD / SPICY / NUCLEAR) so the escalation structure works across any persona system.

**Patronizing resignation**
- "It's okay to be soft. Not everyone was built to be looked at twice." — SPICY
- "You don't have to be impressive. Someone has to be the friend people compare themselves to and feel better." — SPICY
- "It's fine, really. Someone has to be the 'before' picture." — MILD
- "Not everyone gets to be the catch. The only catch here is that you didn't work out today." — SPICY
- "Not everyone can be the top 20%. You've proved you're the bottom 20%." — SPICY
- "It's okay if the mirror isn't your friend right now. It's not lying to you, it's just tired of your excuses." — NUCLEAR

**Public perception**
- "Somewhere a stranger just walked past you, quietly grateful they're not you." — SPICY
- "You wanted people to look at you. Congrats, now they look at you with disgust." — NUCLEAR
- "Hot summer bod? More like not summer bod. Stay indoors this summer because nobody wants to see you at the beach." — NUCLEAR

**Decline / aging urgency**
- "You only get older and weaker from here. Today you just chose to speed it up for free." — SPICY
- "This is the youngest and strongest you will ever be again. You spent it on the couch." — SPICY
- "Every day you skip is a day closer to explaining to your knees why you waited." — MILD

**Social ranking**
- "Your friends talk about you when you're not in the group chat. This is one of those times." — SPICY
- "Even the friend who's nice to everyone had nothing nice to say about this." — SPICY

**Deadpan / "you just go" voice**
- "There's no secret. You just go. You didn't go. That's not complicated, you're just weak." — MILD
- "I don't think about it, I just go. You thought about it for an hour and still didn't." — MILD
- "It's not that deep. Get up, go. Somehow you still couldn't manage it." — MILD
- "Nobody's coming to make you go. Nobody ever will. And you're still just sitting there." — SPICY
- "You don't need to feel ready, you need to move. You did neither." — MILD

**Discipline-principle-flipped-to-insult** (paraphrased training philosophies, no real names/exact quotes — publicity-rights risk)
- "Everyone wants the body. Almost nobody wants the workout. Today you told me exactly which one you are." — SPICY
- "Real ones rest at the end. You rested at the beginning, the middle, and the end." — SPICY
- "Talent isn't required here. Effort is. You had neither today." — NUCLEAR
- "It doesn't get easier. It just gets more embarrassing that you still haven't started." — SPICY
- "You could've suffered for one hour today. Instead you get to feel like this a little longer." — SPICY
- "Discipline was supposed to set you free today. You chose the couch instead." — MILD
- "The part that actually changes you is the part you keep skipping. That's not a coincidence." — SPICY
- "Your mind told you to stop before you even started. You listened to the weakest part of yourself." — NUCLEAR
- "Everyone wants the outcome. Nobody wants the 5am part. You just proved which camp you're in." — SPICY

**Pushing through pain / injury**
- "Some people train through actual injuries. You couldn't train through mild inconvenience." — SPICY
- "There's a difference between can't and won't. You didn't even test which one this was." — MILD
- "Somebody came back stronger from a snapped Achilles. You haven't come back from a bad mood." — SPICY

**Hunger**
- "Hungry people don't need reminders. Looks like the only hunger you have is for a burger." — NUCLEAR

**Ego death / you vs. you**
- "It was never about anyone else. You still managed to lose to the only person who was supposed to matter — you, yesterday." — SPICY
- "Yesterday's version of you did nothing. Today's version matched it exactly." — MILD

**Sacrifice**
- "Everyone who got what you want gave something up for it. You gave up nothing today, and it shows." — SPICY
- "You didn't even have to sacrifice anything. You just had to show up. And you still didn't." — MILD

**Early mornings**
- "Someone else was up before the sun today, doing the thing you keep saying you'll start tomorrow." — MILD
- "The version of you that wins starts before it's convenient. You waited for convenient. It never came." — SPICY

**Adversity as fuel**
- "A bad day was supposed to be fuel. You just let it be an excuse instead." — MILD
- "Some people train harder because of a bad week. You used the bad week as the reason not to." — MILD

**Ex**
- "Your ex tells people they 'dodged a bullet.' Looks like they dodged a bus." — NUCLEAR

**Eagle / chicken**
- "Some people are eagles, some are chickens. At least chickens know what they are. You're still pretending." — NUCLEAR
- "You wanted to be the eagle in the story. You're the chicken they mention once to make the eagle look better." — NUCLEAR

Rough tier count: ~12 MILD / ~22 SPICY / ~9 NUCLEAR.

**Backhanded celebration (success day)**
- "Congrats, you're not a loser today. Let's see about tomorrow."
- "You did the bare minimum required to not be a disappointment. Enjoy it."
- "One day down. That's not a streak yet, that's a coincidence."
- "Fine. You showed up. Don't get used to being told that."
- "Today you were an eagle. We'll see what tomorrow's version of you is."

**Escalation ladder (consecutive misses)**
- *2–3 days:* "Two days isn't a slip anymore. That's a decision." / "This is starting to look like a personality, not a bad week."
- *4–6 days:* "At this point I'm not disappointed. I'm just not surprised." / "You had six chances and used all of them the same way."
- *7 days — finale, then goes silent:* "I've accepted you're not destined to be jacked. I'm giving up on you. Talk to me when you can prove you're worth it."
- *Reactivation:* "Oh. You're here. Let's see if that was a fluke." / "One workout doesn't undo a week of nothing. I'm watching again, though." / "You proved you can do it once. Now do it again before I actually care."

**Content note:** avoided lines that lean on real disability/illness (amputation, chemo) as a "no excuse" comparison — reads as exploiting others' hardship rather than roasting the user, cut deliberately.

---

## Phase 1 implementation notes

When building the persona system in Phase 1:
1. Namespace this pool as `persona: "tough-love-parent"` in `Insults.json`
2. All lines use the same MILD/SPICY/NUCLEAR severity tags as the meme voice, so snooze escalation is persona-agnostic
3. Consider offering this as the "Disappointed Coach" or "Tough-Love Parent" option in onboarding, contrasted against the Gen-Z meme voice
4. The core motivation ("bit of dog in you," step-in parent voice) should be the flavor text for this persona in the picker UI
5. No mechanical changes needed; just content + persona routing in the notification/screen logic
