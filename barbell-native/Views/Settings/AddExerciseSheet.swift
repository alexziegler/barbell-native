import SwiftUI

struct AddExerciseSheet: View {
    @Environment(LogService.self) private var logService
    let userId: UUID
    let onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var shortName: String = ""
    @State private var isSaving = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Full Name", text: $name)
                        .textInputAutocapitalization(.words)

                    TextField("Display Name", text: $shortName)
                        .textInputAutocapitalization(.characters)
                } header: {
                    Text("Exercise Details")
                } footer: {
                    Text("Display name is a short abbreviation shown in lists (e.g., \"DL\" for Deadlift).")
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
                        Task {
                            await saveExercise()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave || isSaving)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private func saveExercise() async {
        isSaving = true
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedShortName = shortName.trimmingCharacters(in: .whitespaces)

        let exercise = await logService.createExercise(
            name: trimmedName,
            shortName: trimmedShortName.isEmpty ? nil : trimmedShortName,
            userId: userId
        )

        if exercise != nil {
            onSuccess()
            dismiss()
        }
        isSaving = false
    }
}

#Preview {
    AddExerciseSheet(
        userId: UUID(),
        onSuccess: {}
    )
    .environment(LogService())
}
