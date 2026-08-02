import SwiftUI

/// Calibration data collected on the Watch, ready to export for analysis.
struct CaptureView: View {
    @State private var files: [URL] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if files.isEmpty {
                        Text("No capture data yet. Files arrive from the Watch during and after Work Mode sessions.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(files, id: \.self) { url in
                            HStack {
                                Text(url.lastPathComponent)
                                    .font(.subheadline.monospaced())
                                Spacer()
                                Text(sizeText(url))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("hr = heart rate every ~5s · steps = movement every 30s · events = your \"I feel it\" taps and check-in answers. After a few shifts, export everything to OneDrive for analysis.")
                }

                if !files.isEmpty {
                    Section {
                        ShareLink(items: files) {
                            Label("Export all files", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .navigationTitle("Data")
            .onAppear(perform: refresh)
            .onReceive(NotificationCenter.default.publisher(for: .captureUpdated)) { _ in
                refresh()
            }
        }
    }

    private func refresh() {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: WatchLink.captureDirectory, includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []
        files = contents
            .filter { $0.pathExtension == "csv" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private func sizeText(_ url: URL) -> String {
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
