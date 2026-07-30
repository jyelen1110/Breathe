import SwiftUI

@main
struct BreatheWatchApp: App {
    @StateObject private var workMode = WorkModeManager()
    @StateObject private var episodeStore = EpisodeStore()
    @StateObject private var phoneLink = PhoneLink()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(workMode)
                .environmentObject(episodeStore)
                .environmentObject(phoneLink)
                .onAppear {
                    workMode.episodeStore = episodeStore
                    workMode.phoneLink = phoneLink
                    phoneLink.activate()
                    AlertCenter.shared.configure()
                }
        }
    }
}
