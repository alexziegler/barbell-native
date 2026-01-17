import SwiftUI
@preconcurrency import Auth

struct HistoryView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var workoutService = WorkoutService()

    var body: some View {
        Group {
            if workoutService.isLoading && workoutService.sets.isEmpty {
                loadingView
            } else if workoutService.sets.isEmpty {
                emptyStateView
            } else {
                workoutListView
            }
        }
        .navigationTitle("History")
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading workouts...")
                .foregroundStyle(.secondary)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "clock.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Workouts Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your past workouts and personal records will appear here")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
    }

    private var workoutListView: some View {
        let groupedByMonth = groupWorkoutsByMonth(workoutService.getWorkoutDays())

        return List {
            ForEach(groupedByMonth, id: \.month) { monthGroup in
                Section {
                    ForEach(monthGroup.workouts) { workoutDay in
                        NavigationLink(destination: WorkoutDayDetailView(
                            workoutDay: workoutDay,
                            workoutService: workoutService
                        )) {
                            WorkoutDayRow(workoutDay: workoutDay)
                        }
                    }
                } header: {
                    Text(monthGroup.monthString)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
    }

    private func groupWorkoutsByMonth(_ workouts: [WorkoutDay]) -> [MonthGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: workouts) { workout in
            calendar.dateInterval(of: .month, for: workout.date)?.start ?? workout.date
        }

        return grouped.map { monthStart, monthWorkouts in
            MonthGroup(month: monthStart, workouts: monthWorkouts.sorted { $0.date > $1.date })
        }
        .sorted { $0.month > $1.month }
    }

    private func loadData() async {
        guard let userId = authManager.currentUser?.id else { return }
        await workoutService.fetchAllData(for: userId)
    }
}

private struct MonthGroup {
    let month: Date
    let workouts: [WorkoutDay]

    var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }
}

struct WorkoutDayRow: View {
    let workoutDay: WorkoutDay

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workoutDay.relativeDateString)
                .font(.headline)

            HStack(spacing: 12) {
                Label("\(workoutDay.exerciseCount) exercise\(workoutDay.exerciseCount == 1 ? "" : "s")", systemImage: "dumbbell.fill")

                Label("\(workoutDay.totalSets) set\(workoutDay.totalSets == 1 ? "" : "s")", systemImage: "number")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !workoutDay.exercises.isEmpty {
                Text(workoutDay.exercises.map { $0.displayName }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .environment(AuthManager())
    }
}
