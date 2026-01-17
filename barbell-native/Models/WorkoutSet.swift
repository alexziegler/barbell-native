import Foundation

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
