import Foundation
import Observation
@preconcurrency import Supabase

/// Input for updating a set
struct UpdateSet: Codable {
    let weight: Double
    let reps: Int
    let rpe: Double?
    let notes: String?
}

/// Input for creating a new set
struct NewSet: Codable {
    let performedAt: Date
    let exerciseId: UUID
    let reps: Int
    let weight: Double
    let rpe: Double?
    let notes: String?
    let failed: Bool
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case performedAt = "performed_at"
        case exerciseId = "exercise_id"
        case reps
        case weight
        case rpe
        case notes
        case failed
        case userId = "user_id"
    }
}

/// Input for creating a new exercise
struct NewExercise: Codable {
    let name: String
    let shortName: String?
    let userId: UUID
    let isBodyweight: Bool
    let category: String?

    enum CodingKeys: String, CodingKey {
        case name
        case shortName = "short_name"
        case userId = "user_id"
        case isBodyweight = "is_bodyweight"
        case category
    }
}

/// Result from PR upsert RPC call
struct PRResult: Codable {
    let newWeight: Bool
    let new1rm: Bool
    let newVolume: Bool

    enum CodingKeys: String, CodingKey {
        case newWeight = "new_weight"
        case new1rm = "new_1rm"
        case newVolume = "new_volume"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        newWeight = (try? container.decode(Bool.self, forKey: .newWeight)) ?? false
        new1rm = (try? container.decode(Bool.self, forKey: .new1rm)) ?? false
        newVolume = (try? container.decode(Bool.self, forKey: .newVolume)) ?? false
    }

    var hasAnyPR: Bool {
        newWeight || new1rm || newVolume
    }

    var prTypes: [String] {
        var types: [String] = []
        if newWeight { types.append("Heaviest") }
        if new1rm { types.append("Best 1RM") }
        if newVolume { types.append("Best Volume") }
        return types
    }
}

/// Result from logging a set, including PR info
struct LogSetResult {
    let set: WorkoutSet
    let prResult: PRResult?
}

@MainActor
@Observable
final class LogService {
    private(set) var exercises: [Exercise] = []
    private(set) var todaysSets: [WorkoutSet] = []
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var error: Error?

    /// Cache of last used weight per exercise (exerciseId -> weight)
    private(set) var lastWeightCache: [UUID: Double] = [:]
    
    private let repository = WorkoutRepository()

    /// Returns the last used weight for an exercise, or nil if not cached
    func lastWeight(for exerciseId: UUID) -> Double? {
        lastWeightCache[exerciseId]
    }

    /// Fetches all available exercises
    func fetchExercises() async {
        isLoading = true
        do {
            let fetchedExercises = try await repository.fetchAllExercises()

            self.exercises = fetchedExercises
            self.isLoading = false

            // Proactively push exercises to Watch via applicationContext so
            // the Watch always has them, even across Watch app restarts.
            WatchSessionManager.shared.sendExercisesToWatch()
        } catch {
            self.error = error
            self.isLoading = false
        }
    }

    /// Fetches today's sets for a user
    func fetchTodaysSets(for userId: UUID) async {
        do {
            let fetchedSets = try await repository.fetchTodaysSets(for: userId)

            self.todaysSets = fetchedSets
            // Update cache from today's sets
            self.updateWeightCache(from: fetchedSets)
        } catch {
            self.error = error
        }
    }

    /// Fetches the last used weight for each exercise (for pre-filling)
    func fetchLastWeights(for userId: UUID) async {
        do {
            // Fetch the most recent sets for building weight cache
            let recentSets = try await repository.fetchRecentSets(for: userId)

            self.updateWeightCache(from: recentSets)
        } catch {
            print("Failed to fetch last weights: \(error)")
        }
    }

    /// Updates the weight cache from a list of sets (most recent wins)
    private func updateWeightCache(from sets: [WorkoutSet]) {
        for set in sets {
            // Only update if we don't already have a weight for this exercise
            // (since sets are ordered by date descending, first one is most recent)
            if lastWeightCache[set.exerciseId] == nil {
                lastWeightCache[set.exerciseId] = set.weight
            }
        }
    }

    /// Updates the cache for a specific exercise (called after logging a set)
    private func updateWeightCache(exerciseId: UUID, weight: Double) {
        lastWeightCache[exerciseId] = weight
    }

    /// Logs a new set and checks for PRs
    func logSet(
        exerciseId: UUID,
        weight: Double,
        reps: Int,
        rpe: Double?,
        notes: String?,
        failed: Bool,
        userId: UUID
    ) async -> LogSetResult? {
        self.isSaving = true

        let newSet = NewSet(
            performedAt: Date(),
            exerciseId: exerciseId,
            reps: reps,
            weight: weight,
            rpe: rpe,
            notes: notes,
            failed: failed,
            userId: userId
        )

        do {
            let savedSet = try await repository.insertSet(newSet)

            self.todaysSets.insert(savedSet, at: 0)
            self.updateWeightCache(exerciseId: exerciseId, weight: weight)
            self.isSaving = false

            // Check for PRs after inserting the set
            let prResult = try? await repository.upsertPRForSet(savedSet.id)

            // Recompute all PRs to ensure consistency
            try? await repository.recomputePRs()

            return LogSetResult(set: savedSet, prResult: prResult)
        } catch {
            self.error = error
            self.isSaving = false
            return nil
        }
    }


    /// Returns the exercise for a given ID
    func exercise(for id: UUID) -> Exercise? {
        exercises.first { $0.id == id }
    }

    /// Returns sets for a specific exercise from today
    func todaysSets(for exerciseId: UUID) -> [WorkoutSet] {
        todaysSets.filter { $0.exerciseId == exerciseId }
    }

    /// Deletes a set
    func deleteSet(_ set: WorkoutSet) async -> Bool {
        do {
            try await repository.deleteSet(set)

            self.todaysSets.removeAll { $0.id == set.id }

            // Recompute PRs since deletion can change them
            try? await repository.recomputePRs()

            return true
        } catch {
            self.error = error
            return false
        }
    }

    /// Updates an existing set
    func updateSet(
        _ set: WorkoutSet,
        weight: Double,
        reps: Int,
        rpe: Double?,
        notes: String?
    ) async -> Bool {
        self.isSaving = true

        do {
            let updatedSet = try await repository.updateSet(
                set,
                weight: weight,
                reps: reps,
                rpe: rpe,
                notes: notes
            )

            if let index = self.todaysSets.firstIndex(where: { $0.id == set.id }) {
                self.todaysSets[index] = updatedSet
            }
            self.isSaving = false

            // Recompute PRs since updates can change them
            try? await repository.recomputePRs()

            return true
        } catch {
            self.error = error
            self.isSaving = false
            return false
        }
    }

    /// Creates a new exercise
    func createExercise(
        name: String,
        shortName: String?,
        userId: UUID
    ) async -> Exercise? {
        self.isSaving = true

        let newExercise = NewExercise(
            name: name,
            shortName: shortName,
            userId: userId,
            isBodyweight: false,
            category: nil
        )

        do {
            let savedExercise = try await repository.createExercise(newExercise)

            self.exercises.append(savedExercise)
            self.exercises.sort { $0.name < $1.name }
            self.isSaving = false
            
            return savedExercise
        } catch {
            self.error = error
            self.isSaving = false
            return nil
        }
    }
    
    /// Recomputes all personal records
    /// This is a public-facing method for manual PR recalculation (e.g., from settings)
    func recomputePRs() async {
        do {
            try await repository.recomputePRs()
        } catch {
            print("Failed to recompute PRs: \(error)")
            self.error = error
        }
    }
}
