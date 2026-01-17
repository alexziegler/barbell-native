import Foundation
@preconcurrency import Supabase
@preconcurrency import Auth

enum AuthState {
    case loading
    case authenticated(Auth.User)
    case unauthenticated
}

@Observable
@MainActor
final class AuthManager {
    private(set) var authState: AuthState = .loading
    private var authStateTask: Task<Void, Never>?

    var isAuthenticated: Bool {
        if case .authenticated = authState {
            return true
        }
        return false
    }

    var currentUser: Auth.User? {
        if case .authenticated(let user) = authState {
            return user
        }
        return nil
    }

    init() {
        Task {
            await initialize()
        }
    }

    private func initialize() async {
        // Check current session first to avoid the "initial session emitted after refresh" warning
        do {
            let session = try await supabaseClient.auth.session
            authState = .authenticated(session.user)
        } catch {
            authState = .unauthenticated
        }

        // Then listen for future auth state changes (skip initial emission)
        authStateTask = Task {
            for await (event, session) in supabaseClient.auth.authStateChanges {
                switch event {
                case .signedIn:
                    if let user = session?.user {
                        authState = .authenticated(user)
                    }
                case .signedOut:
                    authState = .unauthenticated
                case .tokenRefreshed:
                    if let user = session?.user {
                        authState = .authenticated(user)
                    }
                default:
                    break
                }
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        try await supabaseClient.auth.signIn(email: email, password: password)
    }

    func signInWithMagicLink(email: String) async throws {
        try await supabaseClient.auth.signInWithOTP(email: email)
    }

    func signUp(email: String, password: String) async throws {
        try await supabaseClient.auth.signUp(email: email, password: password)
    }

    func resetPassword(email: String) async throws {
        try await supabaseClient.auth.resetPasswordForEmail(email)
    }

    func signOut() async throws {
        try await supabaseClient.auth.signOut()
    }
}
