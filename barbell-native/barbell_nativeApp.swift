import SwiftUI
import UIKit
import WatchConnectivity
import Auth

@main
struct barbell_nativeApp: App {
    @State private var authManager = AuthManager()
    @State private var logService = LogService()

    init() {
        configureAppearance()
        // Configure WatchConnectivity early
        WatchSessionManager.shared.activateSession()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
                .environment(logService)
                .tint(Color.appAccent)
                .preferredColorScheme(.dark)
                .task {
                    // Configure with dependencies once view is ready
                    WatchSessionManager.shared.configure(
                        logService: logService,
                        userId: authManager.currentUser?.id
                    )
                }
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

    private func configureWatchConnectivity() {
        WatchSessionManager.shared.configure(
            logService: logService,
            userId: authManager.currentUser?.id
        )
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
