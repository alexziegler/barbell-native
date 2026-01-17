import Foundation

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

    /// Formatted date string for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// Relative date string (Today, Yesterday, etc.)
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
}
