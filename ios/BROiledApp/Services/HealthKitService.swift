import Foundation
import HealthKit

/// Wraps HealthKit workout verification. Read-only - BROiled never writes to Health.
/// Requires the HealthKit capability (adds an entitlement) and
/// NSHealthShareUsageDescription in Info.plist. See ios/README.md.
@Observable
final class HealthKitService {
    private let store = HKHealthStore()
    var isAuthorized = false

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async {
        guard isHealthDataAvailable else { return }
        let workoutType = HKObjectType.workoutType()
        do {
            try await store.requestAuthorization(toShare: [], read: [workoutType])
            isAuthorized = true
        } catch {
            isAuthorized = false
        }
    }

    /// True if any workout source (Watch, Garmin via Health sync, Strava, gym
    /// equipment, etc.) logged a workout today meeting the minimum duration.
    func hasQualifyingWorkoutToday(minDurationMinutes: Int) async -> Bool {
        guard isHealthDataAvailable else { return false }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let workouts = (samples as? [HKWorkout]) ?? []
                let minSeconds = Double(minDurationMinutes * 60)
                let qualifies = workouts.contains { $0.duration >= minSeconds }
                continuation.resume(returning: qualifies)
            }
            store.execute(query)
        }
    }
}
