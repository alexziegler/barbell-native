import SwiftUI

@main
struct BarbellWatchApp: App {
    @State private var sessionManager = WatchSessionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sessionManager)
        }
    }
}
