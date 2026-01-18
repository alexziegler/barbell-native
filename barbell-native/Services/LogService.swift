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

@Observable
final class LogService {
    private(set) var exercises: [Exercise] = []
    private(set) var todaysSets: [WorkoutSet] = []
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var error: Error?

    /// Fetches all available exercises
    func fetchExercises() async {
        isLoading = true
        do {
            let fetchedExercises: [Exercise] = try await supabaseClient
                .from("exercises")
                .select()
                .order("name", ascending: true)
                .execute()
                .value

            await MainActor.run {
                self.exercises = fetchedExercises
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }

    /// Fetches today's sets for a user
    func fetchTodaysSets(for userId: UUID) async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        do {
            let fetchedSets: [WorkoutSet] = try await supabaseClient
                .from("sets")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("performed_at", value: ISO8601DateFormatter().string(from: startOfDay))
                .order("performed_at", ascending: false)
                .execute()
                .value

            await MainActor.run {
                self.todaysSets = fetchedSets
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }

    /// Logs a new set
    func logSet(
        exerciseId: UUID,
        weight: Double,
        reps: Int,
        rpe: Double?,
        notes: String?,
        failed: Bool,
        userId: UUID
    ) async -> Bool {
        await MainActor.run {
            self.isSaving = true
        }

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
            let savedSet: WorkoutSet = try await supabaseClient
                .from("sets")
                .insert(newSet)
                .select()
                .single()
                .execute()
                .value

            await MainActor.run {
                self.todaysSets.insert(savedSet, at: 0)
                self.isSaving = false
            }
            return true
        } catch {
            await MainActor.run {
                self.error = error
                self.isSaving = false
            }
            return false
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
            try await supabaseClient
                .from("sets")
                .delete()
                .eq("id", value: set.id.uuidString)
                .execute()

            await MainActor.run {
                self.todaysSets.removeAll { $0.id == set.id }
            }
            return true
        } catch {
            await MainActor.run {
                self.error = error
            }
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
        await MainActor.run {
            self.isSaving = true
        }

        do {
            let updateData = UpdateSet(
                weight: weight,
                reps: reps,
                rpe: rpe,
                notes: notes
            )

            let updatedSet: WorkoutSet = try await supabaseClient
                .from("sets")
                .update(updateData)
                .eq("id", value: set.id.uuidString)
                .select()
                .single()
                .execute()
                .value

            await MainActor.run {
                if let index = self.todaysSets.firstIndex(where: { $0.id == set.id }) {
                    self.todaysSets[index] = updatedSet
                }
                self.isSaving = false
            }
            return true
        } catch {
            await MainActor.run {
                self.error = error
                self.isSaving = false
            }
            return false
        }
    }
}
