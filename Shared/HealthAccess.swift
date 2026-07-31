import Foundation
import HealthKit

/// Central place for HealthKit authorization and simple baseline queries.
enum HealthAccess {

    static var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.respiratoryRate),
            HKQuantityType(.stepCount),
            HKObjectType.workoutType(),
        ]
    }

    static var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType()]
    }

    static func requestAuthorization(store: HKHealthStore) async throws {
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    /// Whether the app still needs to show the authorization sheet. Note: HealthKit
    /// never reveals whether *read* access was granted — only whether we've asked.
    /// "Connected" is therefore proven by actually receiving data.
    static func authorizationRequestStatus(store: HKHealthStore) async -> HKAuthorizationRequestStatus {
        await withCheckedContinuation { continuation in
            store.getRequestStatusForAuthorization(toShare: shareTypes, read: readTypes) { status, _ in
                continuation.resume(returning: status)
            }
        }
    }

    /// Average of a quantity over the trailing `days`, in the given unit.
    /// Used for resting HR (baseline anchor) and HRV/respiratory context.
    static func trailingAverage(
        store: HKHealthStore,
        type: HKQuantityTypeIdentifier,
        unit: HKUnit,
        days: Int
    ) async -> Double? {
        let quantityType = HKQuantityType(type)
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, _ in
                let value = statistics?.averageQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
