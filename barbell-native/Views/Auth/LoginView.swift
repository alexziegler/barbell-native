import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showingMagicLinkSent = false
    @State private var showingPasswordReset = false
    @State private var showingSignUp = false
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    formSection
                    actionsSection
                }
                .padding()
            }
            .navigationTitle("Barbell")
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .alert("Magic Link Sent", isPresented: $showingMagicLinkSent) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Check your email for a login link")
            }
            .alert("Password Reset", isPresented: $showingPasswordReset) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Check your email for password reset instructions")
            }
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Track Your Lifts")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
    }

    private var formSection: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .textContentType(.password)
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 16) {
            Button {
                Task { await signIn() }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isLoading || email.isEmpty || password.isEmpty)

            Button("Sign in with Magic Link") {
                Task { await sendMagicLink() }
            }
            .disabled(isLoading || email.isEmpty)

            Divider()
                .padding(.vertical, 8)

            HStack {
                Button("Forgot Password?") {
                    Task { await resetPassword() }
                }
                .disabled(isLoading || email.isEmpty)

                Spacer()

                Button("Create Account") {
                    showingSignUp = true
                }
            }
            .font(.footnote)
        }
    }

    private func signIn() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await authManager.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func sendMagicLink() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await authManager.signInWithMagicLink(email: email)
            showingMagicLinkSent = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func resetPassword() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await authManager.resetPassword(email: email)
            showingPasswordReset = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct SignUpView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                }

                Section {
                    Button {
                        Task { await signUp() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Create Account")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isLoading || !isFormValid)
                }
            }
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .alert("Account Created", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Check your email to verify your account")
            }
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && password == confirmPassword && password.count >= 6
    }

    private func signUp() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await authManager.signUp(email: email, password: password)
            showingSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthManager())
}
