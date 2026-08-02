import Foundation

/// Calibration-week data recorder: appends heart-rate readings, step counts and
/// labeled events (button presses, probe answers) to per-day CSV files in the
/// watch app's documents directory. Files transfer to the iPhone for export.
final class CaptureLogger {
    static let shared = CaptureLogger()

    private let queue = DispatchQueue(label: "capture.logger")
    private var pending: [String: [String]] = [:]

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func day(_ date: Date = Date()) -> String {
        Self.dayFormatter.string(from: date)
    }

    func logHR(_ bpm: Double) {
        append(to: "hr-\(day()).csv", line: "\(Int(Date().timeIntervalSince1970)),\(Int(bpm.rounded()))")
    }

    func logSteps(_ stepsLastFiveMinutes: Int) {
        append(to: "steps-\(day()).csv", line: "\(Int(Date().timeIntervalSince1970)),\(stepsLastFiveMinutes)")
    }

    /// Event types: session_start, session_stop, felt, probe_sent, probe_yes, probe_no.
    func logEvent(_ type: String, bpm: Double, steps: Int) {
        append(to: "events-\(day()).csv", line: "\(Int(Date().timeIntervalSince1970)),\(type),\(Int(bpm.rounded())),\(steps)")
    }

    private func append(to file: String, line: String) {
        queue.async {
            self.pending[file, default: []].append(line)
            if self.pending.values.reduce(0, { $0 + $1.count }) >= 24 {
                self.flushLocked()
            }
        }
    }

    /// Synchronous flush — call before transferring files off the watch.
    func flush() {
        queue.sync { flushLocked() }
    }

    private func flushLocked() {
        for (file, lines) in pending where !lines.isEmpty {
            let url = documents.appendingPathComponent(file)
            guard let data = (lines.joined(separator: "\n") + "\n").data(using: .utf8) else { continue }
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url)
            }
        }
        pending.removeAll()
    }

    var allFiles: [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: documents, includingPropertiesForKeys: nil
        )) ?? []
        return contents.filter { $0.pathExtension == "csv" }
    }
}
