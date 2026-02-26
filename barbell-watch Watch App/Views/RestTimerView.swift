import SwiftUI
import WatchKit
import UserNotifications

// MARK: - Extended Runtime Session Delegate
// Kept as a plain NSObject subclass — no ObservableObject needed because
// the view never re-renders based on session state.

private final class ExtendedSessionDelegate: NSObject, WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        // selfCare sessions last up to 10 minutes — longer than any preset.
        // Local notification handles the alert if this ever fires.
    }

    func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {}
}

// MARK: - Rest Timer List

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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    let duration: TimeInterval

    @State private var extendedSession: WKExtendedRuntimeSession?
    @State private var sessionDelegate = ExtendedSessionDelegate()
    @State private var selectedDuration: TimeInterval
    @State private var endDate: Date
    @State private var hapticTimer: Timer?
    @State private var isCompleted = false
    @State private var firedMilestones: Set<Int> = []

    init(duration: TimeInterval) {
        self.duration = duration
        self._selectedDuration = State(initialValue: duration)
        self._endDate = State(initialValue: Date().addingTimeInterval(duration))
    }

    var body: some View {
        // TimelineView drives display updates at 1-second intervals, including
        // while the display is dimmed in Always On mode.
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let remaining = max(0, endDate.timeIntervalSince(context.date))
            if isLuminanceReduced {
                aodContent(remaining: remaining)
            } else {
                activeContent(remaining: remaining)
            }
        }
        .navigationTitle(formatDuration(duration))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    stopEverything()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .tint(.red)
            }
        }
        .onAppear {
            requestNotificationPermission()
            startTimer()
        }
        .onDisappear {
            hapticTimer?.invalidate()
            extendedSession?.invalidate()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                syncFromEndDate()
            }
        }
    }

    // MARK: - Active Display

    @ViewBuilder
    private func activeContent(remaining: TimeInterval) -> some View {
        VStack(spacing: WatchSpacing.sm) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: progress(remaining: remaining))
                    .stroke(timerColor(remaining: remaining), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text(timeString(remaining: remaining))
                    .font(.watchLargeNumber)
                    .monospacedDigit()
            }
            .frame(width: 130, height: 130)

            Button {
                addTime(30)
            } label: {
                Text("+30s")
                    .font(.watchBody)
            }
            .buttonStyle(.bordered)
            .tint(.watchAccent)
        }
    }

    // MARK: - Always On Display
    // Simplified, low-luminance layout shown when the wrist is lowered.
    // Apple guidelines: minimal color, no rapid animation, large readable text.

    @ViewBuilder
    private func aodContent(remaining: TimeInterval) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: progress(remaining: remaining))
                    .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(timeString(remaining: remaining))
                        .font(.system(size: 38, weight: .thin))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.9))
                    Text("REST")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .kerning(2)
                }
            }
            .frame(width: 130, height: 130)
        }
    }

    // MARK: - Helpers

    private func progress(remaining: TimeInterval) -> Double {
        guard selectedDuration > 0 else { return 0 }
        return remaining / selectedDuration
    }

    private func timeString(remaining: TimeInterval) -> String {
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func timerColor(remaining: TimeInterval) -> Color {
        if remaining <= 10 { return .red }
        if remaining <= 30 { return .watchWarning }
        return .watchAccent
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return secs == 0 ? "\(minutes) min" : "\(minutes):\(String(format: "%02d", secs))"
    }

    // MARK: - Timer Control

    private func startTimer() {
        endDate = Date().addingTimeInterval(selectedDuration)
        // Extended runtime session keeps the app process running after the
        // wrist is lowered, which lets the haptic timer continue firing.
        let session = WKExtendedRuntimeSession()
        session.delegate = sessionDelegate
        session.start()
        extendedSession = session
        scheduleCompletionNotification()
        WKInterfaceDevice.current().play(.start)

        // Haptic timer only — display is driven by TimelineView above.
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            let remaining = max(0, endDate.timeIntervalSinceNow)

            if remaining <= 0 {
                guard !isCompleted else { return }
                timerCompleted()
                return
            }

            checkMilestone(at: 30, remaining: remaining)
            checkMilestone(at: 10, remaining: remaining)

            let secs = Int(remaining)
            if secs <= 3 {
                let key = -secs
                if !firedMilestones.contains(key) {
                    firedMilestones.insert(key)
                    WKInterfaceDevice.current().play(.click)
                }
            }
        }
    }

    private func stopEverything() {
        hapticTimer?.invalidate()
        hapticTimer = nil
        extendedSession?.invalidate()
        extendedSession = nil
        cancelNotification()
        WKInterfaceDevice.current().play(.stop)
    }

    private func addTime(_ seconds: TimeInterval) {
        endDate = endDate.addingTimeInterval(seconds)
        selectedDuration += seconds
        WKInterfaceDevice.current().play(.click)
        scheduleCompletionNotification()
    }

    private func syncFromEndDate() {
        guard !isCompleted else { return }
        if endDate.timeIntervalSinceNow <= 0 {
            timerCompleted()
        }
    }

    private func checkMilestone(at milestone: Int, remaining: TimeInterval) {
        guard !firedMilestones.contains(milestone),
              remaining <= Double(milestone) else { return }
        firedMilestones.insert(milestone)
        WKInterfaceDevice.current().play(.notification)
    }

    private func timerCompleted() {
        guard !isCompleted else { return }
        isCompleted = true
        hapticTimer?.invalidate()
        hapticTimer = nil
        extendedSession?.invalidate()
        extendedSession = nil
        cancelNotification()

        WKInterfaceDevice.current().play(.notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            WKInterfaceDevice.current().play(.notification)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                WKInterfaceDevice.current().play(.notification)
                dismiss()
            }
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func scheduleCompletionNotification() {
        cancelNotification()
        let timeUntilEnd = endDate.timeIntervalSinceNow
        guard timeUntilEnd > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest Complete"
        content.body = "Time to get back to it!"
        content.sound = .defaultCritical

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeUntilEnd, repeats: false)
        let request = UNNotificationRequest(identifier: "barbellRestTimer", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["barbellRestTimer"])
    }
}

#Preview {
    NavigationStack {
        RestTimerView()
    }
}
