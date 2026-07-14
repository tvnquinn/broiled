import WidgetKit
import SwiftUI
import ActivityKit

@main
struct BROiledWidgetsBundle: WidgetBundle {
    var body: some Widget {
        BroiledHomeWidget()
        BroiledLiveActivity()
    }
}

// MARK: - Home-screen widget (streak + today's countdown)

struct CountdownEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot.Data?
}

struct CountdownProvider: TimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(date: Date(), snapshot: WidgetSnapshot.Data(
            state: .pending, deadline: Date().addingTimeInterval(2 * 3600),
            workoutType: nil, streak: 3, bestStreak: 9))
    }

    func getSnapshot(in context: Context, completion: @escaping (CountdownEntry) -> Void) {
        completion(CountdownEntry(date: Date(), snapshot: WidgetSnapshot.read() ?? placeholder(in: context).snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CountdownEntry>) -> Void) {
        let snapshot = WidgetSnapshot.read()
        let entry = CountdownEntry(date: Date(), snapshot: snapshot)
        // The countdown itself ticks via Text(timerInterval:) with no timeline churn;
        // re-render at the deadline (state flips visually) or in an hour, whichever
        // is sooner. The app pokes reloadAllTimelines on every real state change.
        let refresh: Date
        if let deadline = snapshot?.deadline, deadline > Date() {
            refresh = min(deadline, Date().addingTimeInterval(3600))
        } else {
            refresh = Date().addingTimeInterval(3600)
        }
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct BroiledHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BroiledCountdown", provider: CountdownProvider()) { entry in
            BroiledHomeWidgetView(entry: entry)
                .containerBackground(Theme.bg, for: .widget)
        }
        .configurationDisplayName("BROiled countdown")
        .description("streak + today's deadline. no escape.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct BroiledHomeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CountdownEntry

    var body: some View {
        let snap = entry.snapshot
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(snap?.streak ?? 0) day streak")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
                Spacer()
                if family == .systemMedium, let best = snap?.bestStreak, best > 0 {
                    Text("best \(best)")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkMuted)
                }
            }
            Spacer(minLength: 0)
            switch snap?.state {
            case .pending:
                if let deadline = snap?.deadline, deadline > entry.date {
                    Text(snap?.workoutType.map { "\($0) in" } ?? "Workout in")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkMuted)
                    Text(timerInterval: entry.date...deadline, countsDown: true)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .monospacedDigit()
                } else {
                    Text("deadline passed")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.flame)
                }
            case .completed:
                Text("locked in ✓")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.success)
                Text("let's see about tomorrow")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkMuted)
            case .rest:
                Text("rest day")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.inkMuted)
            case .paused:
                Text("paused")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.inkMuted)
            case .silence:
                Text("...")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ash)
            case nil:
                Text("open BROiled")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Live Activity (lock screen + Dynamic Island countdown)

struct BroiledLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BroiledActivityAttributes.self) { context in
            // Lock-screen banner
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.workoutType.map { "\($0) in" } ?? "Workout in")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkMuted)
                    Text(timerInterval: Date()...max(Date(), context.state.deadline), countsDown: true)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .monospacedDigit()
                }
                Spacer()
                Text("\(context.state.streak) day streak")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
            }
            .padding(14)
            .activityBackgroundTint(Theme.bg)
            .activitySystemActionForegroundColor(Theme.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.workoutType ?? "workout")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkMuted)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.streak)🔥")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(timerInterval: Date()...max(Date(), context.state.deadline), countsDown: true)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                }
            } compactLeading: {
                Text("🔥").font(.system(size: 14))
            } compactTrailing: {
                Text(timerInterval: Date()...max(Date(), context.state.deadline), countsDown: true)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .monospacedDigit()
                    .frame(maxWidth: 52)
            } minimal: {
                Text("🔥").font(.system(size: 13))
            }
        }
    }
}
