import SwiftUI

struct ContentView: View {
    @Environment(WatchSessionManager.self) private var sessionManager

    var body: some View {
        TabView {
            QuickLogView()
                .tag(0)

            RestTimerView()
                .tag(1)

            TodaySummaryView()
                .tag(2)
        }
        .tabViewStyle(.verticalPage)
        .onAppear {
            sessionManager.requestInitialData()
        }
    }
}

#Preview {
    ContentView()
        .environment(WatchSessionManager())
}
