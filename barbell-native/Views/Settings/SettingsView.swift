import SwiftUI
import Auth

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var showingSignOutConfirmation = false

    var body: some View {
        Form {
            Section("Account") {
                if let user = authManager.currentUser {
                    LabeledContent("Email", value: user.email ?? "Unknown")
                }

                Button("Sign Out", role: .destructive) {
                    showingSignOutConfirmation = true
                }
            }

            Section("App") {
                LabeledContent("Version", value: "1.0.0")
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog(
            "Sign Out",
            isPresented: $showingSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                Task {
                    try? await authManager.signOut()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AuthManager())
}
