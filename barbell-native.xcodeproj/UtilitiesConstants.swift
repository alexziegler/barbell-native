import Foundation

/// Application-wide constants
enum Constants {
    
    // MARK: - Data Limits
    
    enum DataLimits {
        /// Maximum number of recent sets to fetch for weight cache
        static let recentSetsLimit = 500
    }
    
    // MARK: - Powerlifting
    
    enum Powerlifting {
        /// The "Big Three" powerlifting exercises for 1000 lb club calculation
        enum BigThree {
            static let squat = "squat"
            static let bench = "bench"
            static let deadlift = "deadlift"
            
            /// Exercise names that should be excluded from big three matching
            static let exclusions = ["front squat", "overhead squat"]
            
            /// Checks if an exercise matches one of the big three
            static func matches(exercise: Exercise, name: String) -> Bool {
                let lowercaseName = exercise.name.lowercased()
                
                // Exclude specific variations
                for exclusion in exclusions {
                    if lowercaseName.contains(exclusion) {
                        return false
                    }
                }
                
                return lowercaseName.contains(name)
            }
        }
        
        /// Target total for the 1000 lb club (in pounds)
        static let thousandPoundClubTarget: Double = 1000.0
    }
    
    // MARK: - Weight Conversion
    
    enum WeightConversion {
        /// Kilograms to pounds conversion factor
        static let kgToLbsFactor: Double = 2.20462
        
        /// Pounds to kilograms conversion factor
        static let lbsToKgFactor: Double = 1.0 / kgToLbsFactor
    }
    
    // MARK: - RPE (Rate of Perceived Exertion)
    
    enum RPE {
        /// Valid RPE range
        static let minValue: Double = 0
        static let maxValue: Double = 10
        
        /// Checks if an RPE value is valid
        static func isValid(_ rpe: Double) -> Bool {
            rpe >= minValue && rpe <= maxValue
        }
    }
    
    // MARK: - Workout Validation
    
    enum WorkoutValidation {
        /// Minimum valid weight value
        static let minWeight: Double = 0
        
        /// Minimum valid reps value
        static let minReps: Int = 0
        
        /// Maximum reps for valid 1RM calculation (Brzycki formula)
        static let maxRepsFor1RM: Int = 12
        
        /// Validates workout set parameters
        static func isValid(weight: Double, reps: Int, rpe: Double?) -> Bool {
            guard weight > minWeight, reps > minReps else {
                return false
            }
            
            if let rpe = rpe {
                return RPE.isValid(rpe)
            }
            
            return true
        }
    }
}
