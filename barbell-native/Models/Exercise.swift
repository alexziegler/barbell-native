import Foundation

/// Represents an exercise that can be performed in workouts
///
/// Exercises can be either:
/// - Global exercises (userId = nil): Available to all users, typically system-defined
/// - User-specific exercises (userId present): Created by individual users for their own use
struct Exercise: Codable, Identifiable, Hashable {
    let id: UUID
    
    /// User who created this exercise. Nil for global/system exercises available to all users
    let userId: UUID?
    
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
    
    /// Whether this is a global exercise available to all users
    var isGlobal: Bool {
        userId == nil
    }
}
// MARK: - Exercise Extensions

extension Exercise {
    /// Checks if this exercise name matches common exercise names
    /// Used for features like the 1000 lb club calculation
    func matches(name searchName: String) -> Bool {
        self.name.localizedCaseInsensitiveContains(searchName)
    }
}

