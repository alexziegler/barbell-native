import SwiftUI

@main
struct barbell_nativeApp: App {
    @State private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
        }
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
