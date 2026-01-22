import Foundation

// MARK: - Message Keys

enum WatchMessageKey: String {
    case action
    case exercises
    case sets
    case exercise
    case set
    case exerciseId
    case weight
    case reps
    case rpe
    case success
    case error
    case prResult
    case userId
}

// MARK: - Actions

enum WatchMessageAction: String, Codable {
    case requestExercises
    case requestTodaysSets
    case logSet
    case exercisesUpdated
    case setsUpdated
    case logSetResponse
}

// MARK: - Lightweight Models for Watch

/// Lightweight exercise model for Watch
struct WatchExercise: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let shortName: String?

    var displayName: String {
        shortName ?? name
    }

    init(id: UUID, name: String, shortName: String?) {
        self.id = id
        self.name = name
        self.shortName = shortName
    }
}

/// Lightweight set model for Watch
struct WatchSet: Codable, Identifiable, Hashable {
    let id: UUID
    let exerciseId: UUID
    let weight: Double
    let reps: Int
    let rpe: Double?
    let performedAt: Date

    init(id: UUID, exerciseId: UUID, weight: Double, reps: Int, rpe: Double?, performedAt: Date) {
        self.id = id
        self.exerciseId = exerciseId
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.performedAt = performedAt
    }
}

// MARK: - Request/Response Types

/// Request to log a new set from Watch
struct LogSetRequest: Codable {
    let exerciseId: UUID
    let weight: Double
    let reps: Int
    let rpe: Double?

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            WatchMessageKey.action.rawValue: WatchMessageAction.logSet.rawValue,
            WatchMessageKey.exerciseId.rawValue: exerciseId.uuidString,
            WatchMessageKey.weight.rawValue: weight,
            WatchMessageKey.reps.rawValue: reps
        ]
        if let rpe = rpe {
            dict[WatchMessageKey.rpe.rawValue] = rpe
        }
        return dict
    }

    static func from(dictionary: [String: Any]) -> LogSetRequest? {
        guard let exerciseIdString = dictionary[WatchMessageKey.exerciseId.rawValue] as? String,
              let exerciseId = UUID(uuidString: exerciseIdString),
              let weight = dictionary[WatchMessageKey.weight.rawValue] as? Double,
              let reps = dictionary[WatchMessageKey.reps.rawValue] as? Int else {
            return nil
        }
        let rpe = dictionary[WatchMessageKey.rpe.rawValue] as? Double
        return LogSetRequest(exerciseId: exerciseId, weight: weight, reps: reps, rpe: rpe)
    }
}

/// PR result for Watch display
struct WatchPRResult: Codable {
    let newWeight: Bool
    let new1rm: Bool
    let newVolume: Bool

    var hasAnyPR: Bool {
        newWeight || new1rm || newVolume
    }

    var prTypes: [String] {
        var types: [String] = []
        if newWeight { types.append("Heaviest") }
        if new1rm { types.append("Best 1RM") }
        if newVolume { types.append("Best Volume") }
        return types
    }

    init(newWeight: Bool, new1rm: Bool, newVolume: Bool) {
        self.newWeight = newWeight
        self.new1rm = new1rm
        self.newVolume = newVolume
    }

    func toDictionary() -> [String: Any] {
        return [
            "newWeight": newWeight,
            "new1rm": new1rm,
            "newVolume": newVolume
        ]
    }

    static func from(dictionary: [String: Any]) -> WatchPRResult? {
        guard let newWeight = dictionary["newWeight"] as? Bool,
              let new1rm = dictionary["new1rm"] as? Bool,
              let newVolume = dictionary["newVolume"] as? Bool else {
            return nil
        }
        return WatchPRResult(newWeight: newWeight, new1rm: new1rm, newVolume: newVolume)
    }
}

/// Response after logging a set
struct LogSetResponse: Codable {
    let success: Bool
    let set: WatchSet?
    let prResult: WatchPRResult?
    let error: String?

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            WatchMessageKey.action.rawValue: WatchMessageAction.logSetResponse.rawValue,
            WatchMessageKey.success.rawValue: success
        ]
        if let set = set, let setData = try? JSONEncoder().encode(set) {
            dict[WatchMessageKey.set.rawValue] = setData
        }
        if let prResult = prResult {
            dict[WatchMessageKey.prResult.rawValue] = prResult.toDictionary()
        }
        if let error = error {
            dict[WatchMessageKey.error.rawValue] = error
        }
        return dict
    }

    static func from(dictionary: [String: Any]) -> LogSetResponse? {
        guard let success = dictionary[WatchMessageKey.success.rawValue] as? Bool else {
            return nil
        }

        var set: WatchSet?
        if let setData = dictionary[WatchMessageKey.set.rawValue] as? Data {
            set = try? JSONDecoder().decode(WatchSet.self, from: setData)
        }

        var prResult: WatchPRResult?
        if let prDict = dictionary[WatchMessageKey.prResult.rawValue] as? [String: Any] {
            prResult = WatchPRResult.from(dictionary: prDict)
        }

        let error = dictionary[WatchMessageKey.error.rawValue] as? String

        return LogSetResponse(success: success, set: set, prResult: prResult, error: error)
    }
}

// MARK: - Message Helpers

extension Array where Element == WatchExercise {
    func toData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func from(data: Data) -> [WatchExercise]? {
        try? JSONDecoder().decode([WatchExercise].self, from: data)
    }
}

extension Array where Element == WatchSet {
    func toData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    static func from(data: Data) -> [WatchSet]? {
        try? JSONDecoder().decode([WatchSet].self, from: data)
    }
}
