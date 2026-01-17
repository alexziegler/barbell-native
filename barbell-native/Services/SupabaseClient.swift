import Foundation
@preconcurrency import Supabase
@preconcurrency import Auth

let supabaseClient = SupabaseClient(
    supabaseURL: URL(string: "https://mdsxrphwydaofodkqqeb.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1kc3hycGh3eWRhb2ZvZGtxcWViIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ2NDU4NDEsImV4cCI6MjA3MDIyMTg0MX0.6Tn-7rADQgBQDyDqS6WLJaQoX5Tp3PxcpRqunrFuQDo",
    options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
            autoRefreshToken: true,
            emitLocalSessionAsInitialSession: true
        )
    )
)
