import Foundation
import ActivityKit

/// v0.2 Wave 3: owns the countdown Live Activity. One activity at a time - it mirrors
/// today's pending deadline and ends the moment the day resolves (or has no deadline).
/// This is the answer to the "persistent countdown" idea: pinned notifications don't
/// exist on iOS, a Live Activity is the system-native mechanism.
final class LiveActivityService {
    static let shared = LiveActivityService()
    private init() {}

    /// Reconcile the Live Activity with reality. Call whenever today's deadline/state
    /// changes: launch, snooze, success, miss, pause, push-to-tomorrow.
    func sync(deadline: Date?, workoutType: String?, streak: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        Task {
            if let deadline, deadline > Date() {
                let state = BroiledActivityAttributes.ContentState(deadline: deadline, workoutType: workoutType, streak: streak)
                // Stale at miss-check-ish time: past the deadline the countdown reads
                // 0:00 and the system may show it as outdated - that's accurate.
                let content = ActivityContent(state: state, staleDate: deadline.addingTimeInterval(30 * 60))
                if let existing = Activity<BroiledActivityAttributes>.activities.first {
                    await existing.update(content)
                } else {
                    _ = try? Activity.request(attributes: BroiledActivityAttributes(), content: content)
                }
            } else {
                await endAll()
            }
        }
    }

    func endAll() async {
        for activity in Activity<BroiledActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
