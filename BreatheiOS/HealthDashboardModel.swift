import Foundation
import HealthKit

/// iPhone-side health context: authorization plus the slow-moving signals
/// (resting HR, HRV, respiratory rate) that frame each day.
@MainActor
final class HealthDashboardModel: ObservableObject {
    enum ConnectionState {
        case checking
        /// The permission sheet has never been completed.
        case notConnected
        /// Permission flow done and data is flowing.
        case connected
        /// Permission flow done but no data arrives — likely toggled off in the Health app.
        case connectedNoData
    }

    @Published var connection: ConnectionState = .checking
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
        try? await HealthAccess.requestAuthorization(store: store)
        await evaluateConnection()
    }

    /// Re-derives connection state from scratch. Runs on every launch and every
    /// pull-to-refresh, so the app never "forgets" it was connected after an
    /// update or relaunch.
    func evaluateConnection() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            connection = .notConnected
            return
        }
        let status = await HealthAccess.authorizationRequestStatus(store: store)
        if status == .shouldRequest {
            connection = .notConnected
            return
        }
        await refresh()
        connection = restingHR != nil ? .connected : .connectedNoData
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
