import Foundation

/// Utility for formatting weight values consistently across the app
struct WeightFormatter {
    
    /// Formats a weight value, removing decimal places if not needed
    static func format(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        } else {
            return String(format: "%.1f", weight)
        }
    }
    
    /// Formats a weight with units
    static func formatWithUnit(_ weight: Double, unit: WeightUnit = .kg) -> String {
        "\(format(weight)) \(unit.rawValue)"
    }
    
    /// Converts kg to lbs
    static func kgToLbs(_ kg: Double) -> Double {
        kg * 2.20462
    }
    
    /// Converts lbs to kg
    static func lbsToKg(_ lbs: Double) -> Double {
        lbs / 2.20462
    }
}

enum WeightUnit: String {
    case kg = "kg"
    case lbs = "lbs"
}
