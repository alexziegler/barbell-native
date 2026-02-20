import Foundation

/// Utilities for calculating estimated 1 rep max and related metrics
struct OneRepMaxCalculator {
    
    /// Calculates estimated 1RM using Brzycki formula
    /// Formula: weight × (36 / (37 - reps))
    /// Reference: Brzycki, Matt (1993). "Strength Testing—Predicting a One-Rep Max from Reps-to-Fatigue"
    static func brzycki(weight: Double, reps: Int) -> Double {
        if reps == 1 {
            return weight
        }
        // Only valid for reps <= maxRepsFor1RM
        guard reps > 0 && reps <= Constants.WorkoutValidation.maxRepsFor1RM else {
            return weight
        }
        return weight * (36.0 / (37.0 - Double(reps)))
    }
    
    /// Calculates estimated 1RM for a workout set
    static func estimated1RM(for set: WorkoutSet) -> Double {
        brzycki(weight: set.weight, reps: set.reps)
    }
    
    /// Calculates volume (weight × reps) for a set
    static func volume(for set: WorkoutSet) -> Double {
        set.weight * Double(set.reps)
    }
    
    /// Calculates total volume for multiple sets
    static func totalVolume(for sets: [WorkoutSet]) -> Double {
        sets.reduce(0) { $0 + volume(for: $1) }
    }
}

// MARK: - WorkoutSet Extensions

extension WorkoutSet {
    
    /// Estimated 1 rep max for this set using Brzycki formula
    var estimated1RM: Double {
        OneRepMaxCalculator.estimated1RM(for: self)
    }
    
    /// Volume (weight × reps) for this set
    var volume: Double {
        OneRepMaxCalculator.volume(for: self)
    }
}

// MARK: - Array Extensions

extension Array where Element == WorkoutSet {
    
    /// Total volume across all sets
    var totalVolume: Double {
        OneRepMaxCalculator.totalVolume(for: self)
    }
}
