import SwiftUI
@preconcurrency import Auth

struct LogView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var logService = LogService()

    // Input state - persists between logs
    @State private var selectedExerciseId: UUID?
    @State private var weightText: String = "60"
    @State private var reps: Int = 5
    @State private var rpe: Double = 5
    @State private var includeRPE: Bool = true
    @State private var notes: String = ""

    // UI state
    @State private var showingExercisePicker = false
    @State private var showingSuccess = false
    @State private var setToEdit: WorkoutSet?

    private var selectedExercise: Exercise? {
        guard let id = selectedExerciseId else { return nil }
        return logService.exercise(for: id)
    }

    private var weight: Double {
        Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var canLog: Bool {
        selectedExerciseId != nil && weight > 0 && reps > 0
    }

    /// Groups today's sets by exercise
    private var setsByExercise: [(exerciseId: UUID, exercise: Exercise?, sets: [WorkoutSet])] {
        let grouped = Dictionary(grouping: logService.todaysSets) { $0.exerciseId }
        return grouped.map { exerciseId, sets in
            let exercise = logService.exercise(for: exerciseId)
            return (exerciseId, exercise, sets.sorted { $0.performedAt < $1.performedAt })
        }
        .sorted { group1, group2 in
            guard let first1 = group1.sets.first, let first2 = group2.sets.first else {
                return false
            }
            return first1.performedAt < first2.performedAt
        }
    }

    var body: some View {
        List {
            // Exercise Selection
            Section {
                exercisePickerButton
            } header: {
                Text("Exercise")
            }

            // Weight & Reps
            Section {
                weightInput
                repsInput
            } header: {
                Text("Set Details")
            }

            // RPE (optional)
            Section {
                rpeToggle
                if includeRPE {
                    rpeSlider
                }
            } header: {
                Text("Difficulty (RPE)")
            }

            // Log Button
            Section {
                logButton
            }

            // Today's Sets
            todaysSetsSection
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Log")
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerSheet(
                exercises: logService.exercises,
                selectedId: $selectedExerciseId
            )
        }
        .sheet(item: $setToEdit) { set in
            EditSetSheet(set: set, logService: logService)
        }
        .sensoryFeedback(.success, trigger: showingSuccess)
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }

    // MARK: - Subviews

    private var exercisePickerButton: some View {
        Button {
            showingExercisePicker = true
        } label: {
            HStack {
                Text(selectedExercise?.name ?? "Select Exercise")
                    .foregroundStyle(selectedExercise == nil ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
    }

    private var weightInput: some View {
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
    }

    private var repsInput: some View {
        Stepper(value: $reps, in: 1...100) {
            HStack {
                Text("Reps")
                Spacer()
                Text("\(reps)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var rpeToggle: some View {
        Toggle("Log RPE", isOn: $includeRPE)
    }

    private var rpeSlider: some View {
        VStack(spacing: 12) {
            HStack {
                Text("RPE")
                Spacer()
                Text(String(format: rpe.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", rpe))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(WorkoutDay.difficultyColor(for: rpe))
                    .monospacedDigit()
            }

            GradientSlider(value: $rpe, range: 1...10, step: 0.5)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var todaysSetsSection: some View {
        // Today's Sets Header - outside of list inset
        Section {
            Text("Today's Sets")
                .font(.title3)
                .fontWeight(.bold)
                .listRowInsets(EdgeInsets(top: AppSpacing.xl, leading: 0, bottom: AppSpacing.xs, trailing: 0))
                .listRowBackground(Color.clear)
        }

        if logService.todaysSets.isEmpty {
            // Empty state
            Section {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No sets logged yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
            }
        }

        // Exercise groups
        ForEach(setsByExercise, id: \.exerciseId) { group in
            Section {
                ForEach(group.sets) { set in
                    TodaysSetRow(set: set)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await logService.deleteSet(set) }
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
                    name: group.exercise?.name ?? "Unknown Exercise",
                    sets: group.sets
                )
            }
        }
    }

    private var logButton: some View {
        Button {
            Task {
                await logSet()
            }
        } label: {
            ZStack {
                // Invisible text to maintain consistent height
                Text("Log Set")
                    .fontWeight(.semibold)
                    .opacity(0)

                if logService.isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Log Set")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .foregroundStyle(.white)
        .glassEffect(.regular.interactive().tint(.appAccent))
        .controlSize(.large)
        .disabled(!canLog || logService.isSaving)
        .opacity(canLog && !logService.isSaving ? 1 : 0.5)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    // MARK: - Actions

    private func loadData() async {
        guard let userId = authManager.currentUser?.id else { return }
        await logService.fetchExercises()
        await logService.fetchTodaysSets(for: userId)
    }

    private func logSet() async {
        guard let userId = authManager.currentUser?.id,
              let exerciseId = selectedExerciseId else { return }

        let success = await logService.logSet(
            exerciseId: exerciseId,
            weight: weight,
            reps: reps,
            rpe: includeRPE ? rpe : nil,
            notes: notes.isEmpty ? nil : notes,
            failed: false,
            userId: userId
        )

        if success {
            showingSuccess.toggle()
            // Values persist - don't reset them
            notes = "" // Only clear notes
        }
    }
}

// MARK: - Today's Set Row

struct TodaysSetRow: View {
    let set: WorkoutSet

    var body: some View {
        HStack {
            Text("\(formatWeight(set.weight)) kg × \(set.reps)")
                .font(.body)

            if let rpe = set.rpe {
                Text("@\(rpe, specifier: "%.1f")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(set.performedAt, style: .time)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        } else {
            return String(format: "%.1f", weight)
        }
    }
}

// MARK: - Edit Set Sheet

struct EditSetSheet: View {
    let set: WorkoutSet
    let logService: LogService
    @Environment(\.dismiss) private var dismiss

    @State private var weightText: String
    @State private var reps: Int
    @State private var rpe: Double
    @State private var includeRPE: Bool
    @State private var isSaving = false

    init(set: WorkoutSet, logService: LogService) {
        self.set = set
        self.logService = logService
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
                                Text(String(format: rpe.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", rpe))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(WorkoutDay.difficultyColor(for: rpe))
                                    .monospacedDigit()
                            }
                            GradientSlider(value: $rpe, range: 1...10, step: 0.5)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Difficulty (RPE)")
                }
            }
            .navigationTitle("Edit Set")
            .navigationBarTitleDisplayMode(.inline)
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
        let success = await logService.updateSet(
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

// MARK: - Exercise Picker Sheet

struct ExercisePickerSheet: View {
    let exercises: [Exercise]
    @Binding var selectedId: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return exercises
        }
        return exercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredExercises) { exercise in
                Button {
                    selectedId = exercise.id
                    dismiss()
                } label: {
                    HStack {
                        Text(exercise.name)
                            .foregroundStyle(.primary)

                        Spacer()

                        if let shortName = exercise.shortName {
                            Text(shortName)
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

                        if selectedId == exercise.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Gradient Slider

struct GradientSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1

    private let trackHeight: CGFloat = 8
    private let thumbSize: CGFloat = 24

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - thumbSize
            let percentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let thumbX = width * percentage

            ZStack(alignment: .leading) {
                // Gradient track
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(
                        LinearGradient(
                            colors: [.green, .yellow, .orange, .red, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: trackHeight)
                    .padding(.horizontal, thumbSize / 2)

                // Thumb
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: thumbX)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let newX = min(max(0, gesture.location.x - thumbSize / 2), width)
                                let newPercentage = newX / width
                                let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * newPercentage

                                // Snap to step
                                let steppedValue = (newValue / step).rounded() * step
                                value = min(max(steppedValue, range.lowerBound), range.upperBound)
                            }
                    )
            }
        }
        .frame(height: thumbSize)
    }
}

#Preview {
    NavigationStack {
        LogView()
            .environment(AuthManager())
    }
}
