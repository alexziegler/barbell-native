import SwiftUI
import WatchKit

struct RestTimerView: View {
    private let presetDurations: [(label: String, seconds: TimeInterval)] = [
        ("2:00", 120),
        ("3:00", 180),
        ("4:00", 240),
        ("5:00", 300)
    ]

    var body: some View {
        List(presetDurations, id: \.seconds) { preset in
            NavigationLink {
                RunningTimerView(duration: preset.seconds)
            } label: {
                Text(preset.label)
                    .font(.watchMediumNumber)
            }
        }
        .navigationTitle("Timer")
    }
}

// MARK: - Running Timer View

struct RunningTimerView: View {
    @Environment(\.dismiss) private var dismiss
    let duration: TimeInterval

    @State private var selectedDuration: TimeInterval
    @State private var remainingTime: TimeInterval
    @State private var timer: Timer?

    init(duration: TimeInterval) {
        self.duration = duration
        self._selectedDuration = State(initialValue: duration)
        self._remainingTime = State(initialValue: duration)
    }

    var body: some View {
        VStack(spacing: WatchSpacing.sm) {
            // Circular progress
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(timerColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: progress)

                VStack(spacing: 2) {
                    Text(timeString)
                        .font(.watchLargeNumber)
                        .monospacedDigit()
                }
            }
            .frame(width: 130, height: 130)

            // +30s button below the timer
            Button {
                addTime(30)
            } label: {
                Text("+30s")
                    .font(.watchBody)
            }
            .buttonStyle(.bordered)
            .tint(.watchAccent)
        }
        .navigationTitle(formatDuration(duration))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    stopTimer()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .tint(.red)
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
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

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if secs == 0 {
            return "\(minutes) min"
        }
        return "\(minutes):\(String(format: "%02d", secs))"
    }

    // MARK: - Timer Actions

    private func startTimer() {
        WKInterfaceDevice.current().play(.start)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            tick()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
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

        // Brief delay then dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            WKInterfaceDevice.current().play(.notification)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                WKInterfaceDevice.current().play(.notification)
                dismiss()
            }
        }
    }
}

#Preview {
    NavigationStack {
        RestTimerView()
    }
}
