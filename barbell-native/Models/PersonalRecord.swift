import Foundation

/// Represents a personal record achievement for a specific exercise
struct PersonalRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let exerciseId: UUID
    let setId: UUID
    let metric: String
    let value: Double
    let workoutId: UUID?
    let performedAt: Date
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case exerciseId = "exercise_id"
        case setId = "set_id"
        case metric
        case value
        case workoutId = "workout_id"
        case performedAt = "performed_at"
        case userId = "user_id"
    }

    /// Human-readable metric name
    var metricDisplayName: String {
        switch metric {
        case "1rm": return "1 Rep Max"
        case "5rm": return "5 Rep Max"
        case "10rm": return "10 Rep Max"
        case "weight": return "Heaviest Weight"
        case "volume": return "Best Volume"
        default: return metric.uppercased()
        }
    }
}
// MARK: - PR Metric Constants

extension PersonalRecord {
    enum Metric {
        static let oneRepMax = "1rm"
        static let fiveRepMax = "5rm"
        static let tenRepMax = "10rm"
        static let weight = "weight"
        static let volume = "volume"
    }
}

