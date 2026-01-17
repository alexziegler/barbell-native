import Foundation
import Observation
@preconcurrency import Supabase

@Observable
final class WorkoutService {
    private(set) var sets: [WorkoutSet] = []
    private(set) var exercises: [Exercise] = []
    private(set) var personalRecords: [PersonalRecord] = []
    private(set) var isLoading = false
    private(set) var error: Error?

    /// Fetches all sets for a user, ordered by performed_at descending
    /// Returns the fetched sets for chaining
    func fetchSets(for userId: UUID) async -> [WorkoutSet] {
        isLoading = true
        error = nil

        do {
            let fetchedSets: [WorkoutSet] = try await supabaseClient
                .from("sets")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("performed_at", ascending: false)
                .execute()
                .value

            await MainActor.run {
                self.sets = fetchedSets
                self.isLoading = false
            }
            return fetchedSets
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
            return []
        }
    }

    /// Fetches exercises by their IDs
    func fetchExercises(ids exerciseIds: Set<UUID>) async {
        guard !exerciseIds.isEmpty else { return }

        do {
            let fetchedExercises: [Exercise] = try await supabaseClient
                .from("exercises")
                .select()
                .in("id", values: Array(exerciseIds).map { $0.uuidString.lowercased() })
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

    /// Fetches all personal records for a user
    func fetchPersonalRecords(for userId: UUID) async {
        do {
            let fetchedPRs: [PersonalRecord] = try await supabaseClient
                .from("personal_records")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("performed_at", ascending: false)
                .execute()
                .value

            await MainActor.run {
                self.personalRecords = fetchedPRs
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }

    /// Fetches all workout data for a user (sets, exercises, PRs)
    func fetchAllData(for userId: UUID) async {
        isLoading = true
        error = nil

        // Fetch sets first to get exercise IDs
        let fetchedSets = await fetchSets(for: userId)
        let exerciseIds = Set(fetchedSets.map { $0.exerciseId })

        // Fetch exercises and PRs in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchExercises(ids: exerciseIds) }
            group.addTask { await self.fetchPersonalRecords(for: userId) }
        }

        await MainActor.run {
            self.isLoading = false
        }
    }

    /// Groups sets by date and returns WorkoutDay objects
    func getWorkoutDays() -> [WorkoutDay] {
        let calendar = Calendar.current

        // Group sets by day (stripping time component)
        let groupedSets = Dictionary(grouping: sets) { set in
            calendar.startOfDay(for: set.performedAt)
        }

        // Create WorkoutDay for each date
        return groupedSets.map { date, daySets in
            // Get unique exercise IDs for this day
            let exerciseIds = Set(daySets.map { $0.exerciseId })
            let dayExercises = exercises.filter { exerciseIds.contains($0.id) }

            return WorkoutDay(
                date: date,
                sets: daySets.sorted { $0.performedAt < $1.performedAt },
                exercises: dayExercises
            )
        }
        .sorted { $0.date > $1.date } // Most recent first
    }

    /// Returns the exercise for a given ID
    func exercise(for id: UUID) -> Exercise? {
        exercises.first { $0.id == id }
    }

    /// Returns personal records for a specific set
    func personalRecords(for setId: UUID) -> [PersonalRecord] {
        personalRecords.filter { $0.setId == setId }
    }

    /// Checks if a set has any associated personal record
    func hasPR(setId: UUID) -> Bool {
        personalRecords.contains { $0.setId == setId }
    }

    /// Returns the best set (heaviest weight) for each exercise
    func bestSetsByExercise() -> [UUID: WorkoutSet] {
        var bestSets: [UUID: WorkoutSet] = [:]
        for set in sets where !set.failed {
            if let existing = bestSets[set.exerciseId] {
                if set.weight > existing.weight {
                    bestSets[set.exerciseId] = set
                }
            } else {
                bestSets[set.exerciseId] = set
            }
        }
        return bestSets
    }

    /// Returns the estimated 1RM for a set using Brzycki formula
    func estimated1RM(for set: WorkoutSet) -> Double {
        if set.reps == 1 {
            return set.weight
        }
        // Brzycki formula: weight × (36 / (37 - reps))
        return set.weight * (36.0 / (37.0 - Double(set.reps)))
    }

    /// Returns the best estimated 1RM for each exercise
    func best1RMByExercise() -> [UUID: Double] {
        var best1RMs: [UUID: Double] = [:]
        for set in sets where !set.failed && set.reps > 0 && set.reps <= 12 {
            let e1rm = estimated1RM(for: set)
            if let existing = best1RMs[set.exerciseId] {
                if e1rm > existing {
                    best1RMs[set.exerciseId] = e1rm
                }
            } else {
                best1RMs[set.exerciseId] = e1rm
            }
        }
        return best1RMs
    }

    /// Calculates 1000 lb club total (squat + bench + deadlift in kg)
    /// Returns nil if any of the big 3 exercises are missing
    func thousandPoundClubTotal() -> Double? {
        let best1RMs = best1RMByExercise()
        let exerciseNames = exercises.reduce(into: [UUID: String]()) { $0[$1.id] = $1.name.lowercased() }

        var squat: Double?
        var bench: Double?
        var deadlift: Double?

        for (exerciseId, e1rm) in best1RMs {
            guard let name = exerciseNames[exerciseId] else { continue }
            if name.contains("squat") && !name.contains("front") {
                squat = max(squat ?? 0, e1rm)
            } else if name.contains("bench") {
                bench = max(bench ?? 0, e1rm)
            } else if name.contains("deadlift") {
                deadlift = max(deadlift ?? 0, e1rm)
            }
        }

        guard let s = squat, let b = bench, let d = deadlift else { return nil }
        return s + b + d
    }

    /// Filters workout days to only include sets for a specific exercise
    func getWorkoutDays(filteredBy exerciseId: UUID?) -> [WorkoutDay] {
        guard let exerciseId = exerciseId else {
            return getWorkoutDays()
        }

        let filteredSets = sets.filter { $0.exerciseId == exerciseId }
        let calendar = Calendar.current

        let groupedSets = Dictionary(grouping: filteredSets) { set in
            calendar.startOfDay(for: set.performedAt)
        }

        return groupedSets.map { date, daySets in
            let exerciseIds = Set(daySets.map { $0.exerciseId })
            let dayExercises = exercises.filter { exerciseIds.contains($0.id) }

            return WorkoutDay(
                date: date,
                sets: daySets.sorted { $0.performedAt < $1.performedAt },
                exercises: dayExercises
            )
        }
        .sorted { $0.date > $1.date }
    }
}
