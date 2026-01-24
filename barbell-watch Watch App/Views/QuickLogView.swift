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
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.displayName)
                        .font(.watchBody)
                    if exercise.shortName != nil {
                        Text(exercise.name)
                            .font(.watchCaption)
                            .foregroundColor(.secondary)
                    }
                }
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
    @FocusState private var isFocused: Bool

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
                        .monospacedDigit()
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
        .focusable()
        .focused($isFocused)
        .digitalCrownRotation(
            $weight,
            from: 0,
            through: 500,
            by: 0.5,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .navigationTitle(exercise.shortName ?? exercise.name)
        .onAppear {
            loadLastSet()
            isFocused = true
        }
        .sheet(isPresented: $showWeightPad) {
            WatchNumberPad(value: $weight, range: 0...500)
        }
    }

    private func loadLastSet() {
        if let lastWeight = sessionManager.lastWeight(for: exercise.id) {
            weight = lastWeight
        }
    }
}

// MARK: - Reps Input View

struct RepsInputView: View {
    @Environment(WatchSessionManager.self) private var sessionManager
    let exercise: WatchExercise
    let weight: Double

    @State private var reps: Double = 5
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: WatchSpacing.md) {
            Text("Reps")
                .font(.watchCaption)
                .foregroundColor(.secondary)

            HStack {
                Button {
                    if reps > 1 {
                        reps -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.watchAccent)
                }
                .buttonStyle(.plain)

                Text("\(Int(reps))")
                    .font(.watchLargeNumber)
                    .monospacedDigit()
                    .frame(minWidth: 60)

                Button {
                    if reps < 100 {
                        reps += 1
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.watchAccent)
                }
                .buttonStyle(.plain)
            }

            NavigationLink {
                RPEInputView(exercise: exercise, weight: weight, reps: Int(reps))
            } label: {
                Text("Next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.watchAccent)
        }
        .focusable()
        .focused($isFocused)
        .digitalCrownRotation(
            $reps,
            from: 1,
            through: 100,
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .navigationTitle(exercise.shortName ?? exercise.name)
        .onAppear {
            loadLastSet()
            isFocused = true
        }
    }

    private func loadLastSet() {
        if let lastSet = sessionManager.sets(for: exercise.id).first {
            reps = Double(lastSet.reps)
        }
    }
}

// MARK: - RPE Input View

struct RPEInputView: View {
    @Environment(WatchSessionManager.self) private var sessionManager
    @Environment(\.dismiss) private var dismiss
    let exercise: WatchExercise
    let weight: Double
    let reps: Int

    @State private var rpe: Double = 7.0
    @State private var isLogging = false
    @State private var showSuccess = false
    @State private var prResult: WatchPRResult?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: WatchSpacing.md) {
            Text("RPE")
                .font(.watchCaption)
                .foregroundColor(.secondary)

            HStack {
                Button {
                    if rpe > 1 {
                        rpe -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.watchAccent)
                }
                .buttonStyle(.plain)

                Text("\(Int(rpe))")
                    .font(.watchLargeNumber)
                    .monospacedDigit()
                    .foregroundColor(rpeColor)
                    .frame(minWidth: 60)

                Button {
                    if rpe < 10 {
                        rpe += 1
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.watchAccent)
                }
                .buttonStyle(.plain)
            }

            Button {
                logSet()
            } label: {
                if isLogging {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Log Set")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.watchAccent)
            .disabled(isLogging)
        }
        .focusable()
        .focused($isFocused)
        .digitalCrownRotation(
            $rpe,
            from: 1,
            through: 10,
            by: 1,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .navigationTitle(exercise.shortName ?? exercise.name)
        .onAppear {
            loadLastSet()
            isFocused = true
        }
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
    }

    private var rpeColor: Color {
        switch rpe {
        case 1..<5:
            return .green
        case 5..<7:
            return .yellow
        case 7..<8.5:
            return .orange
        case 8.5..<10:
            return .red
        case 10:
            return .purple
        default:
            return .primary
        }
    }

    private func loadLastSet() {
        if let lastSet = sessionManager.sets(for: exercise.id).first,
           let lastRpe = lastSet.rpe {
            rpe = round(lastRpe)
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

                if let prResult = prResult, prResult.hasAnyPR {
                    WKInterfaceDevice.current().play(.notification)
                } else {
                    WKInterfaceDevice.current().play(.success)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showSuccess = false
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
