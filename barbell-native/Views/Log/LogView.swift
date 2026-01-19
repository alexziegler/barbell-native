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
    @State private var showingSuccess = false
    @State private var setToEdit: WorkoutSet?

    // PR celebration state
    @State private var prSetIds: Set<UUID> = []
    @State private var showingPRCelebration = false
    @State private var prCelebrationMessage: String = ""

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
                exercisePicker
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
        .sheet(item: $setToEdit) { set in
            EditSetSheet(set: set, logService: logService)
        }
        .sensoryFeedback(.success, trigger: showingSuccess)
        .task {
            await loadData()
        }
        .onAppear {
            Task {
                await logService.fetchExercises()
            }
        }
        .refreshable {
            await loadData()
        }
        .overlay {
            if showingPRCelebration {
                PRCelebrationOverlay(
                    message: prCelebrationMessage,
                    isShowing: $showingPRCelebration
                )
            }
        }
    }

    // MARK: - Subviews

    private var exercisePicker: some View {
        Picker("Exercise", selection: $selectedExerciseId) {
            Text("Select Exercise")
                .tag(nil as UUID?)

            ForEach(logService.exercises) { exercise in
                Text(exercise.name)
                    .tag(exercise.id as UUID?)
            }
        }
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
                    TodaysSetRow(set: set, hasPR: prSetIds.contains(set.id))
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

        let result = await logService.logSet(
            exerciseId: exerciseId,
            weight: weight,
            reps: reps,
            rpe: includeRPE ? rpe : nil,
            notes: notes.isEmpty ? nil : notes,
            failed: false,
            userId: userId
        )

        if let result = result {
            showingSuccess.toggle()
            notes = "" // Only clear notes

            // Check if this set achieved a PR
            if let prResult = result.prResult, prResult.hasAnyPR {
                prSetIds.insert(result.set.id)
                let exerciseName = selectedExercise?.name ?? "Exercise"
                prCelebrationMessage = "\(exerciseName)\n\(prResult.prTypes.joined(separator: " & "))"
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showingPRCelebration = true
                }
            }
        }
    }
}

// MARK: - Today's Set Row

struct TodaysSetRow: View {
    let set: WorkoutSet
    var hasPR: Bool = false

    var body: some View {
        HStack {
            if hasPR {
                Text("🏆")
                    .font(.subheadline)
            }

            Text("\(formatWeight(set.weight)) kg × \(set.reps)")
                .font(.body)

            Spacer()

            if let rpe = set.rpe {
                Text(String(format: "%.0f", rpe))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(WorkoutDay.difficultyColor(for: rpe))
                    .frame(minWidth: 20, alignment: .trailing)
            }

            Text(set.performedAt, style: .time)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(minWidth: 55, alignment: .trailing)
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

// MARK: - PR Celebration Overlay

struct PRCelebrationOverlay: View {
    let message: String
    @Binding var isShowing: Bool
    @State private var confettiPieces: [ConfettiPiece] = []

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        isShowing = false
                    }
                }

            // Confetti
            ForEach(confettiPieces) { piece in
                ConfettiPieceView(piece: piece)
            }

            // Celebration card
            VStack(spacing: 16) {
                Text("🎉")
                    .font(.system(size: 60))

                Text("New PR!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text(message)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)

                Button {
                    withAnimation {
                        isShowing = false
                    }
                } label: {
                    Text("Awesome!")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: 300)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
        .onAppear {
            generateConfetti()
        }
        .sensoryFeedback(.success, trigger: isShowing)
    }

    private func generateConfetti() {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .appAccent]
        confettiPieces = (0..<50).map { _ in
            ConfettiPiece(
                color: colors.randomElement()!,
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                y: -20,
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.5...1.2)
            )
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let color: Color
    var x: CGFloat
    var y: CGFloat
    var rotation: Double
    var scale: CGFloat
}

struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    @State private var finalY: CGFloat = UIScreen.main.bounds.height + 50
    @State private var finalRotation: Double = 0
    @State private var finalX: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(piece.color)
            .frame(width: 10 * piece.scale, height: 10 * piece.scale)
            .rotationEffect(.degrees(finalRotation))
            .position(x: finalX, y: finalY)
            .onAppear {
                finalX = piece.x
                finalY = piece.y
                finalRotation = piece.rotation

                withAnimation(.easeOut(duration: Double.random(in: 2...4))) {
                    finalY = UIScreen.main.bounds.height + 50
                    finalX = piece.x + CGFloat.random(in: -100...100)
                    finalRotation = piece.rotation + Double.random(in: 360...720)
                }
            }
    }
}

#Preview {
    NavigationStack {
        LogView()
            .environment(AuthManager())
    }
}
