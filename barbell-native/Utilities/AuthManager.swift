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
        // Check for existing session synchronously to avoid flash of login screen
        if let session = supabaseClient.auth.currentSession, !session.isExpired {
            authState = .authenticated(session.user)
        }

        Task {
            await initialize()
        }
    }

    private func initialize() async {
        // Listen for auth state changes (sign in, sign out, token refresh)
        authStateTask = Task {
            for await (event, session) in supabaseClient.auth.authStateChanges {
                switch event {
                case .initialSession:
                    // Only update if we haven't already set state from stored session
                    if case .loading = authState {
                        if let session = session, !session.isExpired {
                            authState = .authenticated(session.user)
                        } else {
                            authState = .unauthenticated
                        }
                    }
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
