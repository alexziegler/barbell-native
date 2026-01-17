import Foundation
import SwiftUI

struct WorkoutDay: Identifiable {
    let date: Date
    let sets: [WorkoutSet]
    let exercises: [Exercise]

    var id: Date { date }

    /// Total number of sets performed that day
    var totalSets: Int {
        sets.count
    }

    /// Number of unique exercises performed that day
    var exerciseCount: Int {
        exercises.count
    }

    /// Groups sets by exercise ID for display
    /// Returns tuples of (exerciseId, optional exercise, sets)
    var setsByExerciseId: [(exerciseId: UUID, exercise: Exercise?, sets: [WorkoutSet])] {
        // Group sets by exercise ID (from the sets themselves, not the exercises array)
        let grouped = Dictionary(grouping: sets) { $0.exerciseId }

        return grouped.map { exerciseId, exerciseSets in
            let exercise = exercises.first { $0.id == exerciseId }
            return (exerciseId, exercise, exerciseSets.sorted { $0.performedAt < $1.performedAt })
        }
        .sorted { group1, group2 in
            // Sort by first set time
            guard let first1 = group1.sets.first, let first2 = group2.sets.first else {
                return false
            }
            return first1.performedAt < first2.performedAt
        }
    }

    /// Formatted date string for display (without year)
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    /// Formatted date string with year for detail view title
    var formattedDateWithYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    /// Relative date string (Today, Yesterday, or day + month)
    var relativeDateString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return formattedDate
        }
    }

    // MARK: - Difficulty Calculation

    /// Average RPE across all sets (nil if no RPE data)
    var averageDifficulty: Double? {
        let setsWithRPE = sets.compactMap { $0.rpe }
        guard !setsWithRPE.isEmpty else { return nil }
        return setsWithRPE.reduce(0, +) / Double(setsWithRPE.count)
    }

    /// Color for the difficulty level
    static func difficultyColor(for difficulty: Double) -> Color {
        switch difficulty {
        case 0..<4:
            return .green
        case 4..<6:
            // Interpolate green to yellow
            let t = (difficulty - 4) / 2
            return Color(
                red: t,
                green: 0.8,
                blue: 0
            )
        case 6..<8:
            // Interpolate yellow to red
            let t = (difficulty - 6) / 2
            return Color(
                red: 1.0,
                green: 0.8 * (1 - t),
                blue: 0
            )
        case 8..<10:
            // Interpolate red to purple
            let t = (difficulty - 8) / 2
            return Color(
                red: 1.0 - (0.5 * t),
                green: 0,
                blue: 0.5 * t
            )
        default:
            return .purple
        }
    }
}
