import Foundation

/// Represents a single workout set performed by a user
struct WorkoutSet: Codable, Identifiable, Hashable {
    let id: UUID
    let performedAt: Date
    let exerciseId: UUID
    let reps: Int
    let weight: Double
    let rpe: Double?
    let notes: String?
    let failed: Bool
    let userId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case performedAt = "performed_at"
        case exerciseId = "exercise_id"
        case reps
        case weight
        case rpe
        case notes
        case failed
        case userId = "user_id"
        case createdAt = "created_at"
    }
}
// MARK: - WorkoutSet Extensions

extension WorkoutSet {
    /// Whether this set was successfully completed (not failed)
    var isSuccessful: Bool {
        !failed
    }
    
    /// Whether this set has RPE (Rate of Perceived Exertion) data
    var hasRPE: Bool {
        rpe != nil
    }
    
    /// Whether this set has additional notes
    var hasNotes: Bool {
        notes != nil && !notes!.isEmpty
    }
}

