import Foundation
import WatchConnectivity
import Observation

/// Manages Watch Connectivity on the iPhone side
@Observable
@MainActor
final class WatchSessionManager: NSObject {
    static let shared = WatchSessionManager()

    private(set) var isReachable = false
    private(set) var isPaired = false
    private(set) var isWatchAppInstalled = false

    private var logService: LogService?
    private var syncService: WatchSyncService?
    private var userId: UUID?

    private override init() {
        super.init()
    }

    /// Activate the WCSession early (call from app init)
    func activateSession() {
        guard WCSession.isSupported() else {
            print("WatchConnectivity not supported on this device")
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
        print("WCSession activation requested")
    }

    /// Configure with dependencies (call after views are ready)
    func configure(logService: LogService, userId: UUID?) {
        self.logService = logService
        self.syncService = WatchSyncService(logService: logService)
        self.userId = userId
        print("WatchSessionManager configured with logService and userId: \(String(describing: userId))")
    }

    /// Update user ID when auth changes
    func updateUserId(_ userId: UUID?) {
        self.userId = userId
    }

    /// Send exercises to Watch
    func sendExercisesToWatch() {
        syncService?.sendExercisesToWatch()
    }

    /// Send today's sets to Watch
    func sendTodaysSetsToWatch() {
        syncService?.sendTodaysSetsToWatch()
    }

    /// Send last weights cache to Watch
    func sendLastWeightsToWatch() {
        syncService?.sendLastWeightsToWatch()
    }

    /// Sync all data to Watch
    func syncToWatch() {
        syncService?.syncAll()
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("WCSession activation failed: \(error.localizedDescription)")
                return
            }

            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable

            print("WCSession activated: paired=\(session.isPaired), installed=\(session.isWatchAppInstalled), reachable=\(session.isReachable)")
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated")
        // Reactivate session
        WCSession.default.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            print("WCSession reachability changed: \(session.isReachable)")

            if session.isReachable {
                self.syncToWatch()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            await self.handleMessage(message, replyHandler: replyHandler)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            await self.handleMessage(message, replyHandler: nil)
        }
    }
}

// MARK: - Message Handling

extension WatchSessionManager {
    @MainActor
    private func handleMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) async {
        guard let actionString = message[WatchMessageKey.action.rawValue] as? String,
              let action = WatchMessageAction(rawValue: actionString) else {
            replyHandler?([WatchMessageKey.error.rawValue: "Unknown action"])
            return
        }

        switch action {
        case .requestExercises:
            await handleRequestExercises(replyHandler: replyHandler)

        case .requestTodaysSets:
            await handleRequestTodaysSets(replyHandler: replyHandler)

        case .requestLastWeights:
            await handleRequestLastWeights(replyHandler: replyHandler)

        case .logSet:
            await handleLogSet(message: message, replyHandler: replyHandler)

        default:
            replyHandler?([WatchMessageKey.error.rawValue: "Unsupported action"])
        }
    }

    @MainActor
    private func handleRequestExercises(replyHandler: (([String: Any]) -> Void)?) async {
        guard let logService = logService, let syncService = syncService else {
            replyHandler?([WatchMessageKey.error.rawValue: "Services not available"])
            return
        }

        // Ensure exercises are loaded
        if logService.exercises.isEmpty {
            await logService.fetchExercises()
        }

        if let response = syncService.prepareExercisesResponse() {
            replyHandler?(response)
        } else {
            replyHandler?([WatchMessageKey.error.rawValue: "Failed to prepare exercises"])
        }
    }

    @MainActor
    private func handleRequestTodaysSets(replyHandler: (([String: Any]) -> Void)?) async {
        guard let logService = logService, let syncService = syncService, let userId = userId else {
            replyHandler?([WatchMessageKey.error.rawValue: "Services or userId not available"])
            return
        }

        // Fetch fresh data
        await logService.fetchTodaysSets(for: userId)

        if let response = syncService.prepareTodaysSetsResponse() {
            replyHandler?(response)
        } else {
            replyHandler?([WatchMessageKey.error.rawValue: "Failed to prepare sets"])
        }
    }

    @MainActor
    private func handleRequestLastWeights(replyHandler: (([String: Any]) -> Void)?) async {
        guard let logService = logService, let syncService = syncService, let userId = userId else {
            replyHandler?([WatchMessageKey.error.rawValue: "Services or userId not available"])
            return
        }

        // Ensure last weights are loaded
        if logService.lastWeightCache.isEmpty {
            await logService.fetchLastWeights(for: userId)
        }

        if let response = syncService.prepareLastWeightsResponse() {
            replyHandler?(response)
        } else {
            replyHandler?([WatchMessageKey.error.rawValue: "Failed to prepare last weights"])
        }
    }

    @MainActor
    private func handleLogSet(message: [String: Any], replyHandler: (([String: Any]) -> Void)?) async {
        guard let logService = logService, let syncService = syncService, let userId = userId else {
            replyHandler?([WatchMessageKey.error.rawValue: "Services or userId not available"])
            return
        }

        guard let request = LogSetRequest.from(dictionary: message) else {
            replyHandler?([WatchMessageKey.error.rawValue: "Invalid log set request"])
            return
        }

        // Log the set through LogService
        let result = await logService.logSet(
            exerciseId: request.exerciseId,
            weight: request.weight,
            reps: request.reps,
            rpe: request.rpe,
            notes: nil,
            failed: false,
            userId: userId
        )

        if let result = result {
            let response = syncService.prepareLogSetResponse(result: result)
            replyHandler?(response)
        } else {
            let response = LogSetResponse(
                success: false,
                set: nil,
                prResult: nil,
                error: "Failed to log set"
            )
            replyHandler?(response.toDictionary())
        }
    }
}
