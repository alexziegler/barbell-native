import Foundation
import WatchConnectivity

/// Service responsible for synchronizing data with Apple Watch
/// Separates data transformation and sending logic from connection management
@MainActor
final class WatchSyncService {
    private let logService: LogService
    
    init(logService: LogService) {
        self.logService = logService
    }
    
    /// Sends exercises to Watch if reachable
    func sendExercisesToWatch() {
        guard WCSession.default.isReachable else { return }
        
        let watchExercises = logService.exercises.map { exercise in
            WatchExercise(id: exercise.id, name: exercise.name, shortName: exercise.shortName)
        }
        
        guard let exercisesData = watchExercises.toData() else { return }
        
        let message: [String: Any] = [
            WatchMessageKey.action.rawValue: WatchMessageAction.exercisesUpdated.rawValue,
            WatchMessageKey.exercises.rawValue: exercisesData
        ]
        
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send exercises to Watch: \(error.localizedDescription)")
        }
    }
    
    /// Sends today's sets to Watch if reachable
    func sendTodaysSetsToWatch() {
        guard WCSession.default.isReachable else { return }
        
        let watchSets = logService.todaysSets.map { set in
            WatchSet(
                id: set.id,
                exerciseId: set.exerciseId,
                weight: set.weight,
                reps: set.reps,
                rpe: set.rpe,
                performedAt: set.performedAt
            )
        }
        
        guard let setsData = watchSets.toData() else { return }
        
        let message: [String: Any] = [
            WatchMessageKey.action.rawValue: WatchMessageAction.setsUpdated.rawValue,
            WatchMessageKey.sets.rawValue: setsData
        ]
        
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send sets to Watch: \(error.localizedDescription)")
        }
    }
    
    /// Sends last weights cache to Watch if reachable
    func sendLastWeightsToWatch() {
        guard WCSession.default.isReachable else { return }
        
        // Convert UUID keys to strings for JSON encoding
        var stringKeyedCache: [String: Double] = [:]
        for (key, value) in logService.lastWeightCache {
            stringKeyedCache[key.uuidString] = value
        }
        
        guard let weightsData = try? JSONEncoder().encode(stringKeyedCache) else { return }
        
        let message: [String: Any] = [
            WatchMessageKey.action.rawValue: WatchMessageAction.lastWeightsUpdated.rawValue,
            WatchMessageKey.lastWeights.rawValue: weightsData
        ]
        
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send last weights to Watch: \(error.localizedDescription)")
        }
    }
    
    /// Sync all data to Watch
    func syncAll() {
        sendExercisesToWatch()
        sendTodaysSetsToWatch()
        sendLastWeightsToWatch()
    }
    
    /// Prepares exercises response data
    func prepareExercisesResponse() -> [String: Any]? {
        let watchExercises = logService.exercises.map { exercise in
            WatchExercise(id: exercise.id, name: exercise.name, shortName: exercise.shortName)
        }
        
        guard let exercisesData = watchExercises.toData() else {
            return [WatchMessageKey.error.rawValue: "Failed to encode exercises"]
        }
        
        return [
            WatchMessageKey.success.rawValue: true,
            WatchMessageKey.exercises.rawValue: exercisesData
        ]
    }
    
    /// Prepares today's sets response data
    func prepareTodaysSetsResponse() -> [String: Any]? {
        let watchSets = logService.todaysSets.map { set in
            WatchSet(
                id: set.id,
                exerciseId: set.exerciseId,
                weight: set.weight,
                reps: set.reps,
                rpe: set.rpe,
                performedAt: set.performedAt
            )
        }
        
        guard let setsData = watchSets.toData() else {
            return [WatchMessageKey.error.rawValue: "Failed to encode sets"]
        }
        
        return [
            WatchMessageKey.success.rawValue: true,
            WatchMessageKey.sets.rawValue: setsData
        ]
    }
    
    /// Prepares last weights response data
    func prepareLastWeightsResponse() -> [String: Any]? {
        var stringKeyedCache: [String: Double] = [:]
        for (key, value) in logService.lastWeightCache {
            stringKeyedCache[key.uuidString] = value
        }
        
        guard let weightsData = try? JSONEncoder().encode(stringKeyedCache) else {
            return [WatchMessageKey.error.rawValue: "Failed to encode last weights"]
        }
        
        return [
            WatchMessageKey.success.rawValue: true,
            WatchMessageKey.lastWeights.rawValue: weightsData
        ]
    }
    
    /// Prepares log set response data
    func prepareLogSetResponse(result: LogSetResult) -> [String: Any] {
        let watchSet = WatchSet(
            id: result.set.id,
            exerciseId: result.set.exerciseId,
            weight: result.set.weight,
            reps: result.set.reps,
            rpe: result.set.rpe,
            performedAt: result.set.performedAt
        )
        
        var prResult: WatchPRResult?
        if let pr = result.prResult {
            prResult = WatchPRResult(
                newWeight: pr.newWeight,
                new1rm: pr.new1rm,
                newVolume: pr.newVolume
            )
        }
        
        let response = LogSetResponse(
            success: true,
            set: watchSet,
            prResult: prResult,
            error: nil
        )
        return response.toDictionary()
    }
}
