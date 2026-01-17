import SwiftUI
@preconcurrency import Auth

struct HistoryView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var workoutService = WorkoutService()
    @State private var selectedExerciseId: UUID?
    @State private var showingPersonalBests = false

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
        .sheet(isPresented: $showingPersonalBests) {
            PersonalBestsView(workoutService: workoutService)
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
        let workoutDays = workoutService.getWorkoutDays(filteredBy: selectedExerciseId)
        let groupedByMonth = groupWorkoutsByMonth(workoutDays)

        return List {
            // Personal Bests Banner
            Section {
                personalBestsBanner
            }

            // Exercise Filter
            Section {
                exerciseFilterPicker
            }

            // Workout Days grouped by month
            ForEach(groupedByMonth, id: \.month) { monthGroup in
                Section {
                    ForEach(monthGroup.workouts) { workoutDay in
                        NavigationLink(destination: WorkoutDayDetailView(
                            workoutDay: workoutDay,
                            workoutService: workoutService
                        )) {
                            WorkoutDayRow(
                                workoutDay: workoutDay,
                                hasPR: workoutDay.sets.contains { workoutService.hasPR(setId: $0.id) }
                            )
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
        .listStyle(.insetGrouped)
    }

    private var personalBestsBanner: some View {
        Button {
            showingPersonalBests = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Personal Bests", systemImage: "trophy.fill")
                        .font(.headline)

                    if let total = workoutService.thousandPoundClubTotal() {
                        let totalLbs = total * 2.20462
                        Text("1000 lb Club: \(Int(totalLbs)) lbs (\(Int(total)) kg)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
    }

    private var exerciseFilterPicker: some View {
        Picker("Filter by Exercise", selection: $selectedExerciseId) {
            Text("All Exercises")
                .tag(nil as UUID?)

            ForEach(workoutService.exercises.sorted { $0.name < $1.name }) { exercise in
                Text(exercise.displayName)
                    .tag(exercise.id as UUID?)
            }
        }
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

// MARK: - Personal Bests View

struct PersonalBestsView: View {
    let workoutService: WorkoutService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // 1000 lb Club Section
                if let total = workoutService.thousandPoundClubTotal() {
                    Section {
                        thousandPoundClubView(total: total)
                    } header: {
                        Text("1000 lb Club")
                    }
                }

                // Personal Records by Exercise
                Section {
                    ForEach(sortedExercisesWithPRs, id: \.exercise.id) { item in
                        PRRow(
                            exercise: item.exercise,
                            bestSet: item.bestSet,
                            estimated1RM: item.estimated1RM
                        )
                    }
                } header: {
                    Text("Personal Records")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Personal Bests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func thousandPoundClubView(total: Double) -> some View {
        let totalLbs = total * 2.20462
        let targetLbs = 1000.0
        let progress = min(totalLbs / targetLbs, 1.0)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: totalLbs >= targetLbs ? "checkmark.seal.fill" : "trophy.fill")
                    .foregroundStyle(totalLbs >= targetLbs ? .green : .orange)
                    .font(.title2)

                VStack(alignment: .leading) {
                    Text("\(Int(totalLbs)) lbs")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("\(Int(total)) kg combined")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if totalLbs >= targetLbs {
                    Text("Achieved!")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
            }

            ProgressView(value: progress)
                .tint(totalLbs >= targetLbs ? .green : .orange)

            Text("Squat + Bench + Deadlift")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var sortedExercisesWithPRs: [(exercise: Exercise, bestSet: WorkoutSet, estimated1RM: Double)] {
        let bestSets = workoutService.bestSetsByExercise()
        let best1RMs = workoutService.best1RMByExercise()

        return workoutService.exercises
            .compactMap { exercise -> (Exercise, WorkoutSet, Double)? in
                guard let bestSet = bestSets[exercise.id],
                      let e1rm = best1RMs[exercise.id] else { return nil }
                return (exercise, bestSet, e1rm)
            }
            .sorted { $0.2 > $1.2 } // Sort by estimated 1RM descending
    }
}

struct PRRow: View {
    let exercise: Exercise
    let bestSet: WorkoutSet
    let estimated1RM: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.displayName)
                .font(.headline)

            HStack {
                VStack(alignment: .leading) {
                    Text("Best Set")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("\(formatWeight(bestSet.weight)) kg × \(bestSet.reps)")
                        .font(.subheadline)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Est. 1RM")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("\(formatWeight(estimated1RM)) kg")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        } else {
            return String(format: "%.1f", weight)
        }
    }
}

// MARK: - Supporting Types

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
    var hasPR: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Text(workoutDay.relativeDateString)
                        .font(.headline)

                    if hasPR {
                        Text("🏆")
                            .font(.subheadline)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    if let difficulty = workoutDay.averageDifficulty {
                        DifficultyIndicator(difficulty: difficulty)
                    }

                    Text("\(workoutDay.totalSets) sets")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if !workoutDay.exercises.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(workoutDay.exercises) { exercise in
                        ExerciseBadge(name: exercise.displayName)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct DifficultyIndicator: View {
    let difficulty: Double

    var body: some View {
        Text(String(format: "%.1f", difficulty))
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(WorkoutDay.difficultyColor(for: difficulty))
            )
    }
}

struct ExerciseBadge: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
            )
    }
}

/// A simple flow layout that wraps content to new lines
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint], sizes: [CGSize]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        totalHeight = currentY + lineHeight

        return (CGSize(width: totalWidth, height: totalHeight), positions, sizes)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .environment(AuthManager())
    }
}
