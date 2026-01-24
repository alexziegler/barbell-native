import SwiftUI

struct ContentView: View {
    @Environment(WatchSessionManager.self) private var sessionManager

    var body: some View {
        NavigationStack {
            VStack(spacing: WatchSpacing.sm) {
                NavigationLink {
                    QuickLogView()
                } label: {
                    HomePillButton(icon: "dumbbell.fill", title: "Log")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    RestTimerView()
                } label: {
                    HomePillButton(icon: "timer", title: "Timer")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .navigationTitle("Barbell")
        }
        .onAppear {
            sessionManager.requestInitialData()
        }
    }
}

// MARK: - Home Pill Button

struct HomePillButton: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: WatchSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))

            Text(title)
                .font(.watchBody.weight(.semibold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, WatchSpacing.md)
        .background(Color.watchAccent)
        .clipShape(Capsule())
    }
}

#Preview {
    ContentView()
        .environment(WatchSessionManager())
}
