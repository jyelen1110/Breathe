import SwiftUI

@main
struct BreatheApp: App {
    @StateObject private var episodeStore = EpisodeStore()
    @StateObject private var watchLink = WatchLink()
    @StateObject private var health = HealthDashboardModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(episodeStore)
                .environmentObject(health)
                .onAppear {
                    watchLink.episodeStore = episodeStore
                    watchLink.activate()
                }
        }
    }
}
