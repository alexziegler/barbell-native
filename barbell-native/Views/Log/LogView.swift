import SwiftUI

struct LogView: View {
    @State private var showingAddExercise = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "dumbbell.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Log Your Sets")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start logging your workout sets here")
                .foregroundStyle(.secondary)

            Button {
                showingAddExercise = true
            } label: {
                Label("Add Exercise", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .navigationTitle("Log")
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseSheet()
        }
    }
}

struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var exerciseName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Name") {
                    TextField("e.g., Bench Press", text: $exerciseName)
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        // TODO: Save exercise
                        dismiss()
                    }
                    .disabled(exerciseName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LogView()
    }
}
