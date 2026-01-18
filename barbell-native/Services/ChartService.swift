import Foundation
import Observation
@preconcurrency import Supabase

/// Data point for chart display
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

/// Metric types for progression charts
enum ChartMetric: String, CaseIterable, Identifiable {
    case heaviestWeight = "Heaviest Weight"
    case predicted1RM = "Predicted 1RM"
    case totalVolume = "Total Volume"

    var id: String { rawValue }

    var unit: String {
        switch self {
        case .heaviestWeight, .predicted1RM:
            return "kg"
        case .totalVolume:
            return "kg"
        }
    }
}

/// Time range options for charts
enum ChartTimeRange: String, CaseIterable, Identifiable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .oneMonth: return 30
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .oneYear: return 365
        }
    }

    var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
}

@Observable
final class ChartService {
    private(set) var exercises: [Exercise] = []
    private(set) var sets: [WorkoutSet] = []
    private(set) var isLoading = false
    private(set) var error: Error?

    /// Fetches all exercises for the picker
    func fetchExercises() async {
        do {
            let fetchedExercises: [Exercise] = try await supabaseClient
                .from("exercises")
                .select()
                .order("name", ascending: true)
                .execute()
                .value

            await MainActor.run {
                self.exercises = fetchedExercises
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }

    /// Fetches sets for a specific exercise and user within a time range
    func fetchSets(exerciseId: UUID, userId: UUID, since startDate: Date) async {
        isLoading = true

        do {
            let fetchedSets: [WorkoutSet] = try await supabaseClient
                .from("sets")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("exercise_id", value: exerciseId.uuidString)
                .gte("performed_at", value: ISO8601DateFormatter().string(from: startDate))
                .order("performed_at", ascending: true)
                .execute()
                .value

            await MainActor.run {
                self.sets = fetchedSets
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }

    /// Returns chart data points for the selected metric, grouped by day
    func getChartData(for metric: ChartMetric) -> [ChartDataPoint] {
        let calendar = Calendar.current

        // Group sets by day
        let groupedByDay = Dictionary(grouping: sets.filter { !$0.failed }) { set in
            calendar.startOfDay(for: set.performedAt)
        }

        return groupedByDay.compactMap { date, daySets -> ChartDataPoint? in
            let value: Double

            switch metric {
            case .heaviestWeight:
                guard let maxWeight = daySets.map({ $0.weight }).max() else { return nil }
                value = maxWeight

            case .predicted1RM:
                let e1rms = daySets
                    .filter { $0.reps > 0 && $0.reps <= 12 }
                    .map { estimated1RM(for: $0) }
                guard let maxE1RM = e1rms.max() else { return nil }
                value = maxE1RM

            case .totalVolume:
                let volume = daySets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
                guard volume > 0 else { return nil }
                value = volume
            }

            return ChartDataPoint(date: date, value: value)
        }
        .sorted { $0.date < $1.date }
    }

    /// Calculates estimated 1RM using Brzycki formula
    private func estimated1RM(for set: WorkoutSet) -> Double {
        if set.reps == 1 {
            return set.weight
        }
        return set.weight * (36.0 / (37.0 - Double(set.reps)))
    }

    /// Returns the exercise for a given ID
    func exercise(for id: UUID) -> Exercise? {
        exercises.first { $0.id == id }
    }
}
