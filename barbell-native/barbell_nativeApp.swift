import SwiftUI
import UIKit
import WatchConnectivity
import Auth

@main
struct barbell_nativeApp: App {
    @State private var authManager = AuthManager()
    @State private var logService: LogService

    init() {
        // Create LogService first so we can hand it to WatchSessionManager
        // synchronously — before any WCSession message from the Watch arrives.
        let service = LogService()
        _logService = State(initialValue: service)
        configureAppearance()
        WatchSessionManager.shared.activateSession()
        // configure() must be called here, not in a .task, so the iPhone can
        // respond to Watch requests that arrive immediately after activation.
        WatchSessionManager.shared.configure(logService: service, userId: nil)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
                .environment(logService)
                .tint(Color.appAccent)
                .preferredColorScheme(.dark)
                .onChange(of: authManager.currentUser?.id) { _, newUserId in
                    WatchSessionManager.shared.updateUserId(newUserId)
                }
        }
    }

    private func configureAppearance() {
        // Navigation bar title color
        let accentUIColor = UIColor(Color.appAccent)

        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: accentUIColor
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: accentUIColor
        ]
    }


}

struct RootView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Group {
            switch authManager.authState {
            case .loading:
                ProgressView("Loading...")

            case .authenticated:
                MainTabView()

            case .unauthenticated:
                LoginView()
            }
        }
        .animation(.default, value: authManager.isAuthenticated)
    }
}
