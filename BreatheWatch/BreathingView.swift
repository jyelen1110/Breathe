import SwiftUI
import WatchKit

/// Guided box breathing (4-4-4-4), fully haptic-paced so it works eyes-closed:
/// three quick clicks announce the start, then one tap every second — a rising
/// tap while breathing in, a light click while holding, a falling tap while
/// breathing out.
struct BreathingView: View {
    @EnvironmentObject private var workMode: WorkModeManager
    @Environment(\.dismiss) private var dismiss

    private enum Phase: Int, CaseIterable {
        case inhale
        case holdIn
        case exhale
        case holdOut

        var label: String {
            switch self {
            case .inhale: return "Breathe in"
            case .holdIn, .holdOut: return "Hold"
            case .exhale: return "Breathe out"
            }
        }

        /// Distinct feel per phase, from the fixed watchOS haptic set.
        var haptic: WKHapticType {
            switch self {
            case .inhale: return .directionUp
            case .holdIn, .holdOut: return .click
            case .exhale: return .directionDown
            }
        }

        var targetScale: CGFloat {
            switch self {
            case .inhale, .holdIn: return 1.0
            case .exhale, .holdOut: return 0.45
            }
        }
    }

    private let secondsPerPhase = 4
    private let totalCycles = 6

    @State private var running = false
    @State private var finished = false
    @State private var cycle = 1
    @State private var secondsIntoCycle = 0
    @State private var scale: CGFloat = 0.45
    @State private var timer: Timer?

    private var currentPhase: Phase {
        Phase(rawValue: secondsIntoCycle / secondsPerPhase) ?? .inhale
    }

    private var secondsLeftInPhase: Int {
        secondsPerPhase - (secondsIntoCycle % secondsPerPhase)
    }

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
            } else if !running {
                Text("Get ready…")
                    .font(.headline)
                Circle()
                    .fill(circleFill)
                    .frame(width: 110, height: 110)
                    .scaleEffect(scale)
            } else {
                HStack(spacing: 6) {
                    Text(currentPhase.label)
                        .font(.headline)
                    Text("\(secondsLeftInPhase)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.teal)
                }
                Circle()
                    .fill(circleFill)
                    .frame(width: 110, height: 110)
                    .scaleEffect(scale)
                Text("Cycle \(cycle) of \(totalCycles)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: startSession)
        .onDisappear { timer?.invalidate() }
    }

    private var circleFill: RadialGradient {
        RadialGradient(
            colors: [.teal.opacity(0.9), .teal.opacity(0.3)],
            center: .center, startRadius: 4, endRadius: 70
        )
    }

    private func startSession() {
        timer?.invalidate()
        finished = false
        running = false
        cycle = 1
        secondsIntoCycle = 0
        scale = 0.45

        // Three quick clicks: "starting now".
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.35) {
                WKInterfaceDevice.current().play(.click)
            }
        }
        // Brief pause after the announcement, then the paced session begins.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            running = true
            tick()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                tick()
            }
        }
    }

    private func tick() {
        // At each phase boundary, launch the 4-second grow/shrink animation.
        if secondsIntoCycle % secondsPerPhase == 0 {
            withAnimation(.easeInOut(duration: Double(secondsPerPhase))) {
                scale = currentPhase.targetScale
            }
        }
        // One tap every second, in the current phase's pattern.
        WKInterfaceDevice.current().play(currentPhase.haptic)

        secondsIntoCycle += 1
        if secondsIntoCycle >= secondsPerPhase * Phase.allCases.count {
            secondsIntoCycle = 0
            if cycle >= totalCycles {
                timer?.invalidate()
                running = false
                finished = true
                WKInterfaceDevice.current().play(.success)
            } else {
                cycle += 1
            }
        }
    }
}
