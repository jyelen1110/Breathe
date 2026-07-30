import SwiftUI
import WatchKit

/// Guided box breathing (4-4-4-4), paced with animation and haptic taps.
struct BreathingView: View {
    @EnvironmentObject private var workMode: WorkModeManager
    @Environment(\.dismiss) private var dismiss

    private enum Phase: String, CaseIterable {
        case inhale = "Breathe in"
        case holdIn = "Hold"
        case exhale = "Breathe out"
        case holdOut = "Hold "

        var scale: CGFloat {
            switch self {
            case .inhale, .holdIn: return 1.0
            case .exhale, .holdOut: return 0.45
            }
        }
    }

    private let phaseDuration: TimeInterval = 4
    private let totalCycles = 6

    @State private var phase: Phase = .inhale
    @State private var cycle = 1
    @State private var scale: CGFloat = 0.45
    @State private var finished = false
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 10) {
            if finished {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                Text("Nice work")
                    .font(.headline)
                Text("Check in with yourself in a few minutes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Done") {
                    workMode.resolveLastAlert(.breathingCompleted)
                    dismiss()
                }
            } else {
                Text(phase.rawValue)
                    .font(.headline)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.teal.opacity(0.9), .teal.opacity(0.3)],
                            center: .center, startRadius: 4, endRadius: 70
                        )
                    )
                    .frame(width: 110, height: 110)
                    .scaleEffect(scale)
                    .animation(.easeInOut(duration: phaseDuration), value: scale)
                Text("Cycle \(cycle) of \(totalCycles)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: startSession)
        .onDisappear { timer?.invalidate() }
    }

    private func startSession() {
        phase = .inhale
        cycle = 1
        applyPhase()
        timer = Timer.scheduledTimer(withTimeInterval: phaseDuration, repeats: true) { _ in
            advance()
        }
    }

    private func advance() {
        let phases = Phase.allCases
        let currentIndex = phases.firstIndex(of: phase) ?? 0
        if currentIndex == phases.count - 1 {
            if cycle >= totalCycles {
                timer?.invalidate()
                finished = true
                WKInterfaceDevice.current().play(.success)
                return
            }
            cycle += 1
        }
        phase = phases[(currentIndex + 1) % phases.count]
        applyPhase()
    }

    private func applyPhase() {
        scale = phase.scale
        WKInterfaceDevice.current().play(.directionUp)
    }
}
