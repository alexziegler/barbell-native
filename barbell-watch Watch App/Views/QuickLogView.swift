import SwiftUI
import WatchKit

struct QuickLogView: View {
    @Environment(WatchSessionManager.self) private var sessionManager

    @State private var currentStep: LogStep = .selectExercise
    @State private var selectedExercise: WatchExercise?
    @State private var weight: Double = 60.0
    @State private var reps: Int = 5
    @State private var rpe: Double?
    @State private var showRPE = false
    @State private var isLogging = false
    @State private var showSuccess = false
    @State private var prResult: WatchPRResult?

    enum LogStep {
        case selectExercise
        case enterWeight
        case enterReps
        case enterRPE
        case confirm
    }

    var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case .selectExercise:
                    exerciseSelectionView

                case .enterWeight:
                    weightInputView

                case .enterReps:
                    repsInputView

                case .enterRPE:
                    rpeInputView

                case .confirm:
                    confirmationView
                }
            }
            .navigationTitle("Log Set")
            .overlay {
                if showSuccess {
                    successOverlay
                }
            }
        }
    }

    // MARK: - Exercise Selection

    private var exerciseSelectionView: some View {
        Group {
            if sessionManager.exercises.isEmpty {
                VStack(spacing: WatchSpacing.md) {
                    if sessionManager.isLoading {
                        ProgressView()
                        Text("Loading...")
                            .font(.watchCaption)
                    } else if !sessionManager.isConnected {
                        Image(systemName: "iphone.slash")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text("iPhone not connected")
                            .font(.watchCaption)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            sessionManager.requestExercises()
                        }
                        .tint(.watchAccent)
                    } else {
                        Text("No exercises")
                            .font(.watchCaption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                List(sessionManager.exercises) { exercise in
                    Button {
                        selectedExercise = exercise
                        loadLastSetForExercise(exercise)
                        currentStep = .enterWeight
                    } label: {
                        Text(exercise.displayName)
                            .font(.watchBody)
                    }
                }
            }
        }
    }

    // MARK: - Weight Input

    private var weightInputView: some View {
        VStack(spacing: WatchSpacing.md) {
            if let exercise = selectedExercise {
                Text(exercise.displayName)
                    .font(.watchCaption)
                    .foregroundColor(.secondary)
            }

            WatchStepperRow(
                label: "Weight (kg)",
                value: $weight,
                step: 2.5,
                range: 0...500
            )

            HStack {
                Button("Back") {
                    currentStep = .selectExercise
                }
                .tint(.secondary)

                Button("Next") {
                    currentStep = .enterReps
                }
                .tint(.watchAccent)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Reps Input

    private var repsInputView: some View {
        VStack(spacing: WatchSpacing.md) {
            if let exercise = selectedExercise {
                Text(exercise.displayName)
                    .font(.watchCaption)
                    .foregroundColor(.secondary)
            }

            WatchIntStepperRow(
                label: "Reps",
                value: $reps,
                step: 1,
                range: 1...100
            )

            HStack {
                Button("Back") {
                    currentStep = .enterWeight
                }
                .tint(.secondary)

                Button("Next") {
                    currentStep = showRPE ? .enterRPE : .confirm
                }
                .tint(.watchAccent)
            }

            Toggle("Add RPE", isOn: $showRPE)
                .font(.watchCaption)
        }
        .padding(.horizontal)
    }

    // MARK: - RPE Input

    private var rpeInputView: some View {
        VStack(spacing: WatchSpacing.md) {
            Text("Rate of Perceived Exertion")
                .font(.watchCaption)
                .foregroundColor(.secondary)

            WatchStepperRow(
                label: "RPE",
                value: Binding(
                    get: { rpe ?? 7.0 },
                    set: { rpe = $0 }
                ),
                step: 0.5,
                range: 5...10,
                format: "%.1f"
            )

            HStack {
                Button("Back") {
                    currentStep = .enterReps
                }
                .tint(.secondary)

                Button("Next") {
                    currentStep = .confirm
                }
                .tint(.watchAccent)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Confirmation

    private var confirmationView: some View {
        ScrollView {
            VStack(spacing: WatchSpacing.md) {
                if let exercise = selectedExercise {
                    Text(exercise.displayName)
                        .font(.watchTitle)
                }

                HStack(spacing: WatchSpacing.lg) {
                    VStack {
                        Text(String(format: "%.1f", weight))
                            .font(.watchLargeNumber)
                        Text("kg")
                            .font(.watchCaption)
                            .foregroundColor(.secondary)
                    }

                    Text("\u{00D7}")
                        .font(.title2)
                        .foregroundColor(.secondary)

                    VStack {
                        Text("\(reps)")
                            .font(.watchLargeNumber)
                        Text("reps")
                            .font(.watchCaption)
                            .foregroundColor(.secondary)
                    }
                }

                if let rpe = rpe {
                    Text("RPE \(String(format: "%.1f", rpe))")
                        .font(.watchCaption)
                        .foregroundColor(.secondary)
                }

                WatchPrimaryButton(
                    title: "Log Set",
                    action: logSet,
                    isLoading: isLogging
                )

                Button("Edit") {
                    currentStep = .enterWeight
                }
                .tint(.secondary)
            }
            .padding()
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: WatchSpacing.md) {
                if let prResult = prResult, prResult.hasAnyPR {
                    PRCelebrationView(prTypes: prResult.prTypes)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.watchSuccess)

                    Text("Set Logged!")
                        .font(.watchTitle)
                }
            }
        }
        .onTapGesture {
            showSuccess = false
            resetForm()
        }
    }

    // MARK: - Actions

    private func loadLastSetForExercise(_ exercise: WatchExercise) {
        // Load the last set for this exercise to prefill values
        if let lastSet = sessionManager.sets(for: exercise.id).first {
            weight = lastSet.weight
            reps = lastSet.reps
            rpe = lastSet.rpe
            showRPE = lastSet.rpe != nil
        }
    }

    private func logSet() {
        guard let exercise = selectedExercise else { return }

        isLogging = true

        sessionManager.logSet(
            exerciseId: exercise.id,
            weight: weight,
            reps: reps,
            rpe: showRPE ? rpe : nil
        ) { response in
            isLogging = false

            if let response = response, response.success {
                prResult = response.prResult
                showSuccess = true

                // Haptic feedback
                if let prResult = prResult, prResult.hasAnyPR {
                    // Strong haptic for PR
                    WKInterfaceDevice.current().play(.notification)
                } else {
                    // Regular haptic for success
                    WKInterfaceDevice.current().play(.success)
                }

                // Auto-dismiss after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if showSuccess {
                        showSuccess = false
                        resetForm()
                    }
                }
            } else {
                // Error haptic
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }

    private func resetForm() {
        currentStep = .selectExercise
        selectedExercise = nil
        weight = 60.0
        reps = 5
        rpe = nil
        showRPE = false
        prResult = nil
    }
}

#Preview {
    QuickLogView()
        .environment(WatchSessionManager())
}
