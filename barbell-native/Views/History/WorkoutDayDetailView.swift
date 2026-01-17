import SwiftUI

struct WorkoutDayDetailView: View {
    let workoutDay: WorkoutDay
    let workoutService: WorkoutService

    var body: some View {
        List {
            ForEach(workoutDay.setsByExerciseId, id: \.exerciseId) { exerciseGroup in
                Section {
                    ForEach(exerciseGroup.sets) { set in
                        SetRow(set: set, hasPR: workoutService.hasPR(setId: set.id))
                    }
                } header: {
                    Text(exerciseGroup.exercise?.displayName ?? "Unknown Exercise")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(workoutDay.formattedDate)
        .navigationBarTitleDisplayMode(.inline)
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

                    if let rpe = set.rpe {
                        Text("@\(rpe, specifier: "%.1f")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
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

            if hasPR {
                PRBadge()
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
        Text("PR")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
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
