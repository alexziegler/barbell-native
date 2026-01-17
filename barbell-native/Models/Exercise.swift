import Foundation

struct Exercise: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let name: String
    let category: String?
    let isBodyweight: Bool
    let shortName: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case category
        case isBodyweight = "is_bodyweight"
        case shortName = "short_name"
        case createdAt = "created_at"
    }

    /// Display name, preferring short name if available
    var displayName: String {
        shortName ?? name
    }
}
