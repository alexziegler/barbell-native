import SwiftUI
import UIKit

@main
struct barbell_nativeApp: App {
    @State private var authManager = AuthManager()

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
                .tint(Color.appAccent)
                .preferredColorScheme(.dark)
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
