import SwiftUI
import WatchKit

struct RestTimerView: View {
    @State private var selectedDuration: TimeInterval = 90
    @State private var remainingTime: TimeInterval = 0
    @State private var isRunning = false
    @State private var timer: Timer?

    private let presetDurations: [(label: String, seconds: TimeInterval)] = [
        ("1:00", 60),
        ("1:30", 90),
        ("2:00", 120),
        ("3:00", 180),
        ("5:00", 300)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: WatchSpacing.md) {
                if isRunning {
                    runningTimerView
                } else {
                    presetSelectionView
                }
            }
            .navigationTitle("Rest Timer")
        }
    }

    // MARK: - Preset Selection

    private var presetSelectionView: some View {
        ScrollView {
            VStack(spacing: WatchSpacing.sm) {
                ForEach(presetDurations, id: \.seconds) { preset in
                    Button {
                        startTimer(duration: preset.seconds)
                    } label: {
                        Text(preset.label)
                            .font(.watchMediumNumber)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, WatchSpacing.sm)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.watchAccent)
                }
            }
            .padding()
        }
    }

    // MARK: - Running Timer

    private var runningTimerView: some View {
        VStack(spacing: WatchSpacing.md) {
            // Circular progress
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(timerColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: progress)

                VStack {
                    Text(timeString)
                        .font(.watchLargeNumber)
                        .monospacedDigit()

                    Text("remaining")
                        .font(.watchCaption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120, height: 120)

            HStack(spacing: WatchSpacing.md) {
                // +30s button
                Button {
                    addTime(30)
                } label: {
                    Text("+30s")
                        .font(.watchCaption)
                }
                .buttonStyle(.bordered)
                .tint(.watchAccent)

                // Cancel button
                Button {
                    stopTimer()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
    }

    // MARK: - Computed Properties

    private var progress: Double {
        guard selectedDuration > 0 else { return 0 }
        return remainingTime / selectedDuration
    }

    private var timeString: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var timerColor: Color {
        if remainingTime <= 10 {
            return .red
        } else if remainingTime <= 30 {
            return .watchWarning
        } else {
            return .watchAccent
        }
    }

    // MARK: - Timer Actions

    private func startTimer(duration: TimeInterval) {
        selectedDuration = duration
        remainingTime = duration
        isRunning = true

        // Haptic to indicate start
        WKInterfaceDevice.current().play(.start)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            tick()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        remainingTime = 0

        WKInterfaceDevice.current().play(.stop)
    }

    private func addTime(_ seconds: TimeInterval) {
        remainingTime += seconds
        selectedDuration += seconds

        WKInterfaceDevice.current().play(.click)
    }

    private func tick() {
        guard remainingTime > 0 else {
            timerCompleted()
            return
        }

        remainingTime -= 1

        // Haptic feedback at milestones
        if remainingTime == 30 {
            WKInterfaceDevice.current().play(.notification)
        } else if remainingTime == 10 {
            WKInterfaceDevice.current().play(.notification)
        } else if remainingTime <= 3 && remainingTime > 0 {
            WKInterfaceDevice.current().play(.click)
        }
    }

    private func timerCompleted() {
        timer?.invalidate()
        timer = nil

        // Strong haptic for completion
        WKInterfaceDevice.current().play(.notification)

        // Brief delay then reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            WKInterfaceDevice.current().play(.notification)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                WKInterfaceDevice.current().play(.notification)
                isRunning = false
            }
        }
    }
}

#Preview {
    RestTimerView()
}
