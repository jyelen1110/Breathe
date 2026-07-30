import Foundation
import HealthKit

/// iPhone-side health context: authorization plus the slow-moving signals
/// (resting HR, HRV, respiratory rate) that frame each day.
@MainActor
final class HealthDashboardModel: ObservableObject {
    @Published var isAuthorized = false
    @Published var restingHR: Double?
    @Published var hrvSDNN: Double?
    @Published var respiratoryRate: Double?

    private let store = HKHealthStore()

    var baselineEstimate: Double? {
        guard let restingHR else { return nil }
        return restingHR + DetectionSettings.load().baselineMarginBPM
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await HealthAccess.requestAuthorization(store: store)
            isAuthorized = true
            await refresh()
        } catch {
            isAuthorized = false
        }
    }

    func refresh() async {
        let bpm = HKUnit.count().unitDivided(by: .minute())
        restingHR = await HealthAccess.trailingAverage(
            store: store, type: .restingHeartRate, unit: bpm, days: 7
        )
        hrvSDNN = await HealthAccess.trailingAverage(
            store: store, type: .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli), days: 2
        )
        respiratoryRate = await HealthAccess.trailingAverage(
            store: store, type: .respiratoryRate, unit: bpm, days: 2
        )
    }
}
