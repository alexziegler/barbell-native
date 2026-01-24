import SwiftUI
import WatchKit

struct QuickLogView: View {
    @Environment(WatchSessionManager.self) private var sessionManager

    var body: some View {
        Group {
            if sessionManager.exercises.isEmpty {
                emptyStateView
            } else {
                exerciseListView
            }
        }
        .navigationTitle("Log Set")
    }

    private var emptyStateView: some View {
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
    }

    private var exerciseListView: some View {
        List(sessionManager.exercises) { exercise in
            NavigationLink {
                WeightInputView(exercise: exercise)
            } label: {
                Text(exercise.displayName)
                    .font(.watchBody)
            }
        }
    }
}

// MARK: - Weight Input View

struct WeightInputView: View {
    @Environment(WatchSessionManager.self) private var sessionManager
    let exercise: WatchExercise

    @State private var weight: Double = 60.0
    @State private var showWeightPad = false

    var body: some View {
        VStack(spacing: WatchSpacing.md) {
            Text("Weight (kg)")
                .font(.watchCaption)
                .foregroundColor(.secondary)

            // Tappable weight display with stepper buttons
            HStack {
                Button {
                    if weight - 2.5 >= 0 {
                        weight -= 2.5
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.watchAccent)
                }
                .buttonStyle(.plain)

                Button {
                    showWeightPad = true
                } label: {
                    Text(String(format: "%.1f", weight))
                        .font(.watchLargeNumber)
                        .frame(minWidth: 80)
                }
                .buttonStyle(.plain)

                Button {
                    if weight + 2.5 <= 500 {
                        weight += 2.5
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.watchAccent)
                }
                .buttonStyle(.plain)
            }

            NavigationLink {
                RepsInputView(exercise: exercise, weight: weight)
            } label: {
                Text("Next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.watchAccent)
        }
        .navigationTitle(exercise.shortName ?? exercise.name)
        .onAppear {
            loadLastSet()
        }
        .sheet(isPresented: $showWeightPad) {
            WatchNumberPad(value: $weight, range: 0...500)
        }
    }

    private func loadLastSet() {
        if let lastSet = sessionManager.sets(for: exercise.id).first {
            weight = lastSet.weight
        }
    }
}

// MARK: - Reps Input View

struct RepsInputView: View {
    @Environment(WatchSessionManager.self) private var sessionManager
    let exercise: WatchExercise
    let weight: Double

    @State private var reps: Int = 5
    @State private var rpe: Double?
    @State private var showRPE = false

    var body: some View {
        VStack(spacing: WatchSpacing.md) {
            WatchIntStepperRow(
                label: "Reps",
                value: $reps,
                step: 1,
                range: 1...100
            )

            NavigationLink {
                ConfirmSetView(
                    exercise: exercise,
                    weight: weight,
                    reps: reps,
                    rpe: showRPE ? (rpe ?? 7.0) : nil
                )
            } label: {
                Text("Next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.watchAccent)

            Toggle("Add RPE", isOn: $showRPE)
                .font(.watchCaption)

            if showRPE {
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
            }
        }
        .navigationTitle("Reps")
        .onAppear {
            loadLastSet()
        }
    }

    private func loadLastSet() {
        if let lastSet = sessionManager.sets(for: exercise.id).first {
            reps = lastSet.reps
            rpe = lastSet.rpe
            showRPE = lastSet.rpe != nil
        }
    }
}

// MARK: - Confirm Set View

struct ConfirmSetView: View {
    @Environment(WatchSessionManager.self) private var sessionManager
    @Environment(\.dismiss) private var dismiss
    let exercise: WatchExercise
    let weight: Double
    let reps: Int
    let rpe: Double?

    @State private var isLogging = false
    @State private var showSuccess = false
    @State private var prResult: WatchPRResult?

    var body: some View {
        ScrollView {
            VStack(spacing: WatchSpacing.md) {
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
            }
            .padding()
        }
        .navigationTitle(exercise.shortName ?? exercise.name)
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
    }

    private func logSet() {
        isLogging = true

        sessionManager.logSet(
            exerciseId: exercise.id,
            weight: weight,
            reps: reps,
            rpe: rpe
        ) { response in
            isLogging = false

            if let response = response, response.success {
                prResult = response.prResult
                showSuccess = true

                // Haptic feedback
                if let prResult = prResult, prResult.hasAnyPR {
                    WKInterfaceDevice.current().play(.notification)
                } else {
                    WKInterfaceDevice.current().play(.success)
                }

                // Auto-dismiss after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showSuccess = false
                    // Pop to root
                    dismiss()
                }
            } else {
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }

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
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        QuickLogView()
            .environment(WatchSessionManager())
    }
}
