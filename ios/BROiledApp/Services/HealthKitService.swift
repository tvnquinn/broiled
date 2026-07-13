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

    /// v0.2 Wave 1: background workout detection. When a workout syncs to HealthKit while
    /// the app is backgrounded, the observer fires and `onWorkoutDetected` runs (the caller
    /// re-queries for a qualifying workout and settles the day). Requires the HealthKit
    /// "Background Delivery" entitlement checkbox - see ios/README.md.
    ///
    /// This is the real fix for the success push never firing: without it, nothing in the
    /// app executes between backgrounding and the next launch, so `fireSuccessPush()` had
    /// no caller and the stale miss-check question would fire even after a finished workout.
    func startObservingWorkouts(onWorkoutDetected: @escaping () -> Void) {
        guard isHealthDataAvailable else { return }
        let workoutType = HKObjectType.workoutType()

        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { _, completionHandler, error in
            if error == nil {
                onWorkoutDetected()
            }
            completionHandler()
        }
        store.execute(query)

        store.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { _, _ in
            // Best effort - if the entitlement is missing this fails quietly and the
            // foreground check in HomeView still covers the in-app path.
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
