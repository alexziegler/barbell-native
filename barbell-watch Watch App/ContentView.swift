import SwiftUI

struct ContentView: View {
    @Environment(WatchSessionManager.self) private var sessionManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WatchSpacing.sm) {
                    // Buttons
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

                    // Today's sets summary
                    if !sessionManager.todaysSets.isEmpty {
                        todaySummary
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Barbell")
        }
        .onAppear {
            sessionManager.requestInitialData()
        }
    }

    // MARK: - Today's Summary

    private var todaySummary: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Today's sets")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            ForEach(groupedSets, id: \.exerciseId) { group in
                HStack(spacing: 5) {
                    Text(group.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)

                    Text(String(repeating: "·", count: min(group.setCount, 12)))
                        .font(.system(size: 14))
                        .foregroundStyle(.watchAccent)
                        .kerning(1.5)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct ExerciseSummary {
        let exerciseId: UUID
        let displayName: String
        let setCount: Int
    }

    private var groupedSets: [ExerciseSummary] {
        // Preserve exercise order by first appearance in todaysSets
        var seen: [UUID] = []
        for set in sessionManager.todaysSets {
            if !seen.contains(set.exerciseId) {
                seen.append(set.exerciseId)
            }
        }
        return seen.map { id in
            let count = sessionManager.todaysSets.filter { $0.exerciseId == id }.count
            let name = sessionManager.exercise(for: id)?.displayName ?? "?"
            return ExerciseSummary(exerciseId: id, displayName: name, setCount: count)
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
