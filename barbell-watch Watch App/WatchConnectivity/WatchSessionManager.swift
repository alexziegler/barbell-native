import Foundation
import WatchConnectivity
import Observation

/// Manages Watch Connectivity on the Watch side
@Observable
final class WatchSessionManager: NSObject {
    // MARK: - State

    private(set) var exercises: [WatchExercise] = []
    private(set) var todaysSets: [WatchSet] = []
    private(set) var lastWeightCache: [UUID: Double] = [:]
    private(set) var isConnected = false
    private(set) var isLoading = false
    private(set) var lastError: String?

    private let exercisesCacheKey = "cachedWatchExercises"

    /// Returns the last used weight for an exercise
    func lastWeight(for exerciseId: UUID) -> Double? {
        // First check today's sets
        if let todaySet = todaysSets.first(where: { $0.exerciseId == exerciseId }) {
            return todaySet.weight
        }
        // Fall back to cache from historical data
        return lastWeightCache[exerciseId]
    }

    // MARK: - Initialization

    override init() {
        super.init()
        // Load cached exercises immediately so the list is never empty on
        // launch, even before WatchConnectivity has a chance to connect.
        exercises = loadCachedExercises()
        activateSession()
    }

    private func activateSession() {
        guard WCSession.isSupported() else {
            print("WatchConnectivity not supported")
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Data Requests

    /// Request initial data from iPhone
    func requestInitialData() {
        requestExercises()
        requestTodaysSets()
        requestLastWeights()
    }

    /// Request exercises from iPhone
    func requestExercises() {
        guard WCSession.default.isReachable else {
            // Not an error if we already have exercises from cache.
            if exercises.isEmpty {
                lastError = "iPhone not reachable"
            }
            return
        }

        isLoading = true
        let message: [String: Any] = [
            WatchMessageKey.action.rawValue: WatchMessageAction.requestExercises.rawValue
        ]

        WCSession.default.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                self?.handleExercisesResponse(reply)
            }
        }, errorHandler: { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.lastError = error.localizedDescription
            }
        })
    }

    /// Request today's sets from iPhone
    func requestTodaysSets() {
        guard WCSession.default.isReachable else {
            lastError = "iPhone not reachable"
            return
        }

        isLoading = true
        let message: [String: Any] = [
            WatchMessageKey.action.rawValue: WatchMessageAction.requestTodaysSets.rawValue
        ]

        WCSession.default.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                self?.handleSetsResponse(reply)
            }
        }, errorHandler: { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                self?.lastError = error.localizedDescription
            }
        })
    }

    /// Request last weights cache from iPhone
    func requestLastWeights() {
        guard WCSession.default.isReachable else { return }

        let message: [String: Any] = [
            WatchMessageKey.action.rawValue: WatchMessageAction.requestLastWeights.rawValue
        ]

        WCSession.default.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                self?.handleLastWeightsResponse(reply)
            }
        }, errorHandler: { error in
            print("Failed to request last weights: \(error.localizedDescription)")
        })
    }

    // MARK: - Log Set

    /// Log a new set via iPhone
    func logSet(
        exerciseId: UUID,
        weight: Double,
        reps: Int,
        rpe: Double?,
        completion: @escaping (LogSetResponse?) -> Void
    ) {
        guard WCSession.default.isReachable else {
            lastError = "iPhone not reachable"
            completion(nil)
            return
        }

        let request = LogSetRequest(exerciseId: exerciseId, weight: weight, reps: reps, rpe: rpe)
        let message = request.toDictionary()

        WCSession.default.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                let response = LogSetResponse.from(dictionary: reply)
                if let response = response, response.success, let set = response.set {
                    // Add to local cache
                    self?.todaysSets.insert(set, at: 0)
                }
                completion(response)
            }
        }, errorHandler: { [weak self] error in
            DispatchQueue.main.async {
                self?.lastError = error.localizedDescription
                completion(nil)
            }
        })
    }

    // MARK: - Helpers

    /// Get exercise by ID
    func exercise(for id: UUID) -> WatchExercise? {
        exercises.first { $0.id == id }
    }

    /// Get sets for a specific exercise
    func sets(for exerciseId: UUID) -> [WatchSet] {
        todaysSets.filter { $0.exerciseId == exerciseId }
    }

    /// Get exercises that have sets today
    func exercisesWithSets() -> [WatchExercise] {
        let exerciseIds = Set(todaysSets.map { $0.exerciseId })
        return exercises.filter { exerciseIds.contains($0.id) }
    }

    // MARK: - Response Handlers

    private func handleExercisesResponse(_ reply: [String: Any]) {
        isLoading = false

        if let error = reply[WatchMessageKey.error.rawValue] as? String {
            lastError = error
            return
        }

        guard let data = reply[WatchMessageKey.exercises.rawValue] as? Data,
              let exercises = [WatchExercise].from(data: data) else {
            lastError = "Failed to decode exercises"
            return
        }

        self.exercises = exercises
        cacheExercises(exercises)
        lastError = nil
    }

    private func handleSetsResponse(_ reply: [String: Any]) {
        isLoading = false

        if let error = reply[WatchMessageKey.error.rawValue] as? String {
            lastError = error
            return
        }

        guard let data = reply[WatchMessageKey.sets.rawValue] as? Data,
              let sets = [WatchSet].from(data: data) else {
            lastError = "Failed to decode sets"
            return
        }

        self.todaysSets = sets
        lastError = nil
    }

    // MARK: - Exercise Cache

    /// Saves exercises to UserDefaults so they survive process restarts.
    private func cacheExercises(_ exercises: [WatchExercise]) {
        if let data = exercises.toData() {
            UserDefaults.standard.set(data, forKey: exercisesCacheKey)
        }
    }

    /// Loads exercises from UserDefaults. Returns an empty array if nothing is cached yet.
    private func loadCachedExercises() -> [WatchExercise] {
        guard let data = UserDefaults.standard.data(forKey: exercisesCacheKey),
              let exercises = [WatchExercise].from(data: data) else {
            return []
        }
        return exercises
    }

    /// Applies exercises received via applicationContext (background delivery from iPhone).
    private func applyApplicationContext(_ context: [String: Any]) {
        guard let data = context[WatchMessageKey.exercises.rawValue] as? Data,
              let exercises = [WatchExercise].from(data: data) else { return }
        self.exercises = exercises
        cacheExercises(exercises)
    }

    private func handleLastWeightsResponse(_ reply: [String: Any]) {
        guard let data = reply[WatchMessageKey.lastWeights.rawValue] as? Data,
              let weights = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return
        }

        // Convert string UUIDs back to UUID keys
        var cache: [UUID: Double] = [:]
        for (key, value) in weights {
            if let uuid = UUID(uuidString: key) {
                cache[uuid] = value
            }
        }
        self.lastWeightCache = cache
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("WCSession activation failed: \(error.localizedDescription)")
                self.lastError = error.localizedDescription
                return
            }

            self.isConnected = session.isReachable
            print("WCSession activated: reachable=\(session.isReachable)")

            // Apply any exercises the iPhone pushed while the Watch app was not running.
            // This is the primary delivery path for exercise data — it works regardless
            // of whether the iPhone is currently reachable.
            let context = session.receivedApplicationContext
            if !context.isEmpty {
                self.applyApplicationContext(context)
            }

            if session.isReachable {
                self.requestInitialData()
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.applyApplicationContext(applicationContext)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable
            print("WCSession reachability changed: \(session.isReachable)")

            if session.isReachable {
                self.requestInitialData()
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.handleIncomingMessage(message)
        }
    }

    private func handleIncomingMessage(_ message: [String: Any]) {
        guard let actionString = message[WatchMessageKey.action.rawValue] as? String,
              let action = WatchMessageAction(rawValue: actionString) else {
            return
        }

        switch action {
        case .exercisesUpdated:
            if let data = message[WatchMessageKey.exercises.rawValue] as? Data,
               let exercises = [WatchExercise].from(data: data) {
                self.exercises = exercises
                cacheExercises(exercises)
            }

        case .setsUpdated:
            if let data = message[WatchMessageKey.sets.rawValue] as? Data,
               let sets = [WatchSet].from(data: data) {
                self.todaysSets = sets
            }

        case .lastWeightsUpdated:
            if let data = message[WatchMessageKey.lastWeights.rawValue] as? Data,
               let weights = try? JSONDecoder().decode([String: Double].self, from: data) {
                var cache: [UUID: Double] = [:]
                for (key, value) in weights {
                    if let uuid = UUID(uuidString: key) {
                        cache[uuid] = value
                    }
                }
                self.lastWeightCache = cache
            }

        default:
            break
        }
    }
}
