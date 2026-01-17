import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Log", systemImage: "dumbbell.fill", value: 0) {
                NavigationStack {
                    LogView()
                }
            }

            Tab("History", systemImage: "clock.fill", value: 1) {
                NavigationStack {
                    HistoryView()
                }
            }

            Tab("Charts", systemImage: "chart.line.uptrend.xyaxis", value: 2) {
                NavigationStack {
                    ChartsView()
                }
            }

            Tab("Settings", systemImage: "gear", value: 3) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AuthManager())
}
