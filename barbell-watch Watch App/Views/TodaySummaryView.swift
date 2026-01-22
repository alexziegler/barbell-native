import SwiftUI

struct TodaySummaryView: View {
    @Environment(WatchSessionManager.self) private var sessionManager

    var body: some View {
        NavigationStack {
            Group {
                if sessionManager.todaysSets.isEmpty {
                    emptyStateView
                } else {
                    summaryListView
                }
            }
            .navigationTitle("Today")
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: WatchSpacing.md) {
            if sessionManager.isLoading {
                ProgressView()
                Text("Loading...")
                    .font(.watchCaption)
            } else {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title)
                    .foregroundColor(.secondary)

                Text("No sets today")
                    .font(.watchBody)
                    .foregroundColor(.secondary)

                Text("Start logging!")
                    .font(.watchCaption)
                    .foregroundColor(.watchAccent)
            }
        }
    }

    // MARK: - Summary List

    private var summaryListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WatchSpacing.md) {
                // Stats header
                statsHeader

                Divider()

                // Sets by exercise
                ForEach(groupedSets, id: \.exerciseId) { group in
                    exerciseSection(group)
                }
            }
            .padding()
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: WatchSpacing.lg) {
            VStack {
                Text("\(sessionManager.todaysSets.count)")
                    .font(.watchMediumNumber)
                    .foregroundColor(.watchAccent)
                Text("Sets")
                    .font(.watchCaption)
                    .foregroundColor(.secondary)
            }

            VStack {
                Text("\(exerciseCount)")
                    .font(.watchMediumNumber)
                    .foregroundColor(.watchAccent)
                Text("Exercises")
                    .font(.watchCaption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Exercise Section

    private func exerciseSection(_ group: ExerciseGroup) -> some View {
        VStack(alignment: .leading, spacing: WatchSpacing.xs) {
            Text(group.exerciseName)
                .font(.watchTitle)
                .foregroundColor(.watchAccent)

            ForEach(group.sets) { set in
                setRow(set)
            }
        }
    }

    private func setRow(_ set: WatchSet) -> some View {
        HStack {
            Text("\(String(format: "%.1f", set.weight))kg")
                .font(.watchBody)

            Text("\u{00D7}")
                .foregroundColor(.secondary)

            Text("\(set.reps)")
                .font(.watchBody)

            if let rpe = set.rpe {
                Text("@\(String(format: "%.1f", rpe))")
                    .font(.watchCaption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Computed Properties

    private var exerciseCount: Int {
        Set(sessionManager.todaysSets.map { $0.exerciseId }).count
    }

    private var groupedSets: [ExerciseGroup] {
        let exerciseIds = sessionManager.todaysSets.map { $0.exerciseId }
        let uniqueIds = exerciseIds.uniqued()

        return uniqueIds.compactMap { exerciseId in
            let sets = sessionManager.todaysSets.filter { $0.exerciseId == exerciseId }
            guard !sets.isEmpty else { return nil }

            let exerciseName = sessionManager.exercise(for: exerciseId)?.displayName ?? "Unknown"

            return ExerciseGroup(
                exerciseId: exerciseId,
                exerciseName: exerciseName,
                sets: sets
            )
        }
    }
}

// MARK: - Supporting Types

private struct ExerciseGroup {
    let exerciseId: UUID
    let exerciseName: String
    let sets: [WatchSet]
}

// MARK: - Array Extension

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

#Preview {
    TodaySummaryView()
        .environment(WatchSessionManager())
}
