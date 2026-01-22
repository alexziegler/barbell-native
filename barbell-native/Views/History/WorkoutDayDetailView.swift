import SwiftUI

struct WorkoutDayDetailView: View {
    let workoutDay: WorkoutDay
    let workoutService: WorkoutService

    @State private var setToEdit: WorkoutSet?

    var body: some View {
        List {
            // Summary section with difficulty
            if let difficulty = workoutDay.averageDifficulty {
                Section {
                    HStack {
                        Text("Average Difficulty")
                        Spacer()
                        DifficultyBadge(difficulty: difficulty)
                    }
                }
            }

            // Sets grouped by exercise
            ForEach(workoutDay.setsByExerciseId, id: \.exerciseId) { exerciseGroup in
                Section {
                    ForEach(exerciseGroup.sets) { set in
                        SetRow(set: set, hasPR: workoutService.hasPR(setId: set.id))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await workoutService.deleteSet(set) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    setToEdit = set
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.appAccent)
                            }
                    }
                } header: {
                    ExerciseSectionHeader(
                        name: exerciseGroup.exercise?.name ?? "Unknown Exercise",
                        sets: exerciseGroup.sets
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(workoutDay.formattedDateWithYear)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $setToEdit) { set in
            HistoryEditSetSheet(set: set, workoutService: workoutService)
        }
    }
}

// MARK: - History Edit Set Sheet

struct HistoryEditSetSheet: View {
    let set: WorkoutSet
    let workoutService: WorkoutService
    @Environment(\.dismiss) private var dismiss

    @State private var weightText: String
    @State private var reps: Int
    @State private var rpe: Double
    @State private var includeRPE: Bool
    @State private var isSaving = false

    init(set: WorkoutSet, workoutService: WorkoutService) {
        self.set = set
        self.workoutService = workoutService
        _weightText = State(initialValue: set.weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", set.weight)
            : String(format: "%.1f", set.weight))
        _reps = State(initialValue: set.reps)
        _rpe = State(initialValue: set.rpe ?? 5)
        _includeRPE = State(initialValue: set.rpe != nil)
    }

    private var weight: Double {
        Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var canSave: Bool {
        weight > 0 && reps > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }

                    Stepper(value: $reps, in: 1...100) {
                        HStack {
                            Text("Reps")
                            Spacer()
                            Text("\(reps)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                } header: {
                    Text("Set Details")
                }

                Section {
                    Toggle("Log RPE", isOn: $includeRPE)
                    if includeRPE {
                        VStack(spacing: 12) {
                            HStack {
                                Text("RPE")
                                Spacer()
                                Text(String(format: "%.0f", rpe))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(WorkoutDay.difficultyColor(for: rpe))
                                    .monospacedDigit()
                            }
                            GradientSlider(value: $rpe, range: 1...10, step: 1)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Difficulty (RPE)")
                }
            }
            .navigationTitle("Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveChanges()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave || isSaving)
                }
            }
        }
    }

    private func saveChanges() async {
        isSaving = true
        let success = await workoutService.updateSet(
            set,
            weight: weight,
            reps: reps,
            rpe: includeRPE ? rpe : nil,
            notes: set.notes
        )
        if success {
            dismiss()
        }
        isSaving = false
    }
}

struct DifficultyBadge: View {
    let difficulty: Double

    var body: some View {
        Text(String(format: "%.1f", difficulty))
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(WorkoutDay.difficultyColor(for: difficulty))
            )
    }
}

struct ExerciseSectionHeader: View {
    let name: String
    let sets: [WorkoutSet]

    private var averageRPE: Double? {
        let rpEs = sets.compactMap { $0.rpe }
        guard !rpEs.isEmpty else { return nil }
        return rpEs.reduce(0, +) / Double(rpEs.count)
    }

    var body: some View {
        HStack {
            Text(name)

            Spacer()

            if let rpe = averageRPE {
                Text(String(format: "%.1f", rpe))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(WorkoutDay.difficultyColor(for: rpe))
                    )
            }
        }
    }
}

struct SetRow: View {
    let set: WorkoutSet
    let hasPR: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(weightRepsText)
                        .font(.body)

                    if hasPR {
                        PRBadge()
                    }

                    if set.failed {
                        Text("(failed)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if let notes = set.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let rpe = set.rpe {
                Text(String(format: "%.0f", rpe))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(WorkoutDay.difficultyColor(for: rpe))
                    .frame(minWidth: 20, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
    }

    private var weightRepsText: String {
        let weightFormatted: String
        if set.weight.truncatingRemainder(dividingBy: 1) == 0 {
            weightFormatted = String(format: "%.0f", set.weight)
        } else {
            weightFormatted = String(format: "%.1f", set.weight)
        }
        return "\(weightFormatted) kg x \(set.reps)"
    }
}

struct PRBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Text("🏆")
                .font(.caption2)
            Text("PR")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.orange)
        )
    }
}

#Preview {
    let sampleExercise = Exercise(
        id: UUID(),
        userId: UUID(),
        name: "Bench Press",
        category: "chest",
        isBodyweight: false,
        shortName: "Bench",
        createdAt: Date()
    )

    let sampleSets = [
        WorkoutSet(
            id: UUID(),
            performedAt: Date(),
            exerciseId: sampleExercise.id,
            reps: 5,
            weight: 135,
            rpe: 7.0,
            notes: nil,
            failed: false,
            userId: UUID(),
            createdAt: Date()
        ),
        WorkoutSet(
            id: UUID(),
            performedAt: Date(),
            exerciseId: sampleExercise.id,
            reps: 5,
            weight: 155,
            rpe: 8.0,
            notes: "Felt strong",
            failed: false,
            userId: UUID(),
            createdAt: Date()
        ),
        WorkoutSet(
            id: UUID(),
            performedAt: Date(),
            exerciseId: sampleExercise.id,
            reps: 3,
            weight: 175,
            rpe: 9.5,
            notes: nil,
            failed: true,
            userId: UUID(),
            createdAt: Date()
        )
    ]

    let sampleDay = WorkoutDay(
        date: Date(),
        sets: sampleSets,
        exercises: [sampleExercise]
    )

    return NavigationStack {
        WorkoutDayDetailView(
            workoutDay: sampleDay,
            workoutService: WorkoutService()
        )
    }
}
