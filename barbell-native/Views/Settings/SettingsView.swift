import SwiftUI
import Auth

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var logService = LogService()
    @State private var showingSignOutConfirmation = false
    @State private var showingAddExercise = false
    @State private var showingExerciseAdded = false
    @State private var isRebuildingPRs = false
    @State private var showingPRsRebuilt = false

    var body: some View {
        Form {
            Section("Exercises") {
                Button {
                    showingAddExercise = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle")
                }
            }

            Section {
                Button {
                    Task {
                        isRebuildingPRs = true
                        await logService.recomputePRs()
                        isRebuildingPRs = false
                        showingPRsRebuilt = true
                    }
                } label: {
                    HStack {
                        Label("Rebuild PRs", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        if isRebuildingPRs {
                            ProgressView()
                        }
                    }
                }
                .disabled(isRebuildingPRs)
            } header: {
                Text("Personal Records")
            } footer: {
                Text("Scan all your sets and recalculate personal records. Use this if PRs are missing or incorrect.")
            }

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
        .sheet(isPresented: $showingAddExercise) {
            if let userId = authManager.currentUser?.id {
                AddExerciseSheet(
                    logService: logService,
                    userId: userId,
                    onSuccess: {
                        showingExerciseAdded = true
                    }
                )
            }
        }
        .sensoryFeedback(.success, trigger: showingExerciseAdded)
        .sensoryFeedback(.success, trigger: showingPRsRebuilt)
        .overlay(alignment: .top) {
            if showingExerciseAdded {
                SettingsToast(icon: "checkmark.circle.fill", message: "Exercise Added", iconColor: .green)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showingExerciseAdded = false
                            }
                        }
                    }
            }
            if showingPRsRebuilt {
                SettingsToast(icon: "trophy.fill", message: "PRs Rebuilt", iconColor: .yellow)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showingPRsRebuilt = false
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut, value: showingExerciseAdded)
        .animation(.easeInOut, value: showingPRsRebuilt)
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

struct SettingsToast: View {
    let icon: String
    let message: String
    var iconColor: Color = .green

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
            Text(message)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.top, 8)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AuthManager())
}
