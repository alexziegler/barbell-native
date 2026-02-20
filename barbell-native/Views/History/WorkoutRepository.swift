import Foundation
@preconcurrency import Supabase

/// Shared repository for workout data operations
/// Eliminates duplication between LogService and WorkoutService
@MainActor
final class WorkoutRepository {
    
    // MARK: - Set Operations
    
    /// Deletes a set from the database
    func deleteSet(_ set: WorkoutSet) async throws {
        try await supabaseClient
            .from("sets")
            .delete()
            .eq("id", value: set.id.uuidString)
            .execute()
    }
    
    /// Updates an existing set in the database
    func updateSet(
        _ set: WorkoutSet,
        weight: Double,
        reps: Int,
        rpe: Double?,
        notes: String?
    ) async throws -> WorkoutSet {
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
        
        return updatedSet
    }
    
    /// Inserts a new set into the database
    func insertSet(_ newSet: NewSet) async throws -> WorkoutSet {
        let savedSet: WorkoutSet = try await supabaseClient
            .from("sets")
            .insert(newSet)
            .select()
            .single()
            .execute()
            .value
        
        return savedSet
    }
    
    // MARK: - PR Operations
    
    /// Calls the RPC function to check/upsert PR for a specific set
    func upsertPRForSet(_ setId: UUID) async throws -> PRResult {
        let result: PRResult = try await supabaseClient
            .rpc("upsert_pr_for_set", params: ["p_set_id": setId.uuidString.lowercased()])
            .execute()
            .value
        return result
    }
    
    /// Calls the RPC function to recompute all PRs
    func recomputePRs() async throws {
        try await supabaseClient
            .rpc("recompute_prs")
            .execute()
    }
    
    // MARK: - Fetch Operations
    
    /// Fetches all sets for a user
    func fetchSets(for userId: UUID) async throws -> [WorkoutSet] {
        let fetchedSets: [WorkoutSet] = try await supabaseClient
            .from("sets")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("performed_at", ascending: false)
            .execute()
            .value
        
        return fetchedSets
    }
    
    /// Fetches today's sets for a user
    func fetchTodaysSets(for userId: UUID) async throws -> [WorkoutSet] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        let fetchedSets: [WorkoutSet] = try await supabaseClient
            .from("sets")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gte("performed_at", value: ISO8601DateFormatter().string(from: startOfDay))
            .order("performed_at", ascending: false)
            .execute()
            .value
        
        return fetchedSets
    }
    
    /// Fetches recent sets for building weight cache
    func fetchRecentSets(for userId: UUID, limit: Int? = nil) async throws -> [WorkoutSet] {
        let fetchLimit = limit ?? Constants.DataLimits.recentSetsLimit
        
        let recentSets: [WorkoutSet] = try await supabaseClient
            .from("sets")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("performed_at", ascending: false)
            .limit(fetchLimit)
            .execute()
            .value
        
        return recentSets
    }
    
    /// Fetches exercises by their IDs
    func fetchExercises(ids exerciseIds: Set<UUID>) async throws -> [Exercise] {
        guard !exerciseIds.isEmpty else { return [] }
        
        let fetchedExercises: [Exercise] = try await supabaseClient
            .from("exercises")
            .select()
            .in("id", values: Array(exerciseIds).map { $0.uuidString.lowercased() })
            .order("name", ascending: true)
            .execute()
            .value
        
        return fetchedExercises
    }
    
    /// Fetches all available exercises
    func fetchAllExercises() async throws -> [Exercise] {
        let fetchedExercises: [Exercise] = try await supabaseClient
            .from("exercises")
            .select()
            .order("name", ascending: true)
            .execute()
            .value
        
        return fetchedExercises
    }
    
    /// Fetches all personal records for a user
    func fetchPersonalRecords(for userId: UUID) async throws -> [PersonalRecord] {
        let fetchedPRs: [PersonalRecord] = try await supabaseClient
            .from("personal_records")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("performed_at", ascending: false)
            .execute()
            .value
        
        return fetchedPRs
    }
    
    // MARK: - Exercise Operations
    
    /// Creates a new exercise
    func createExercise(_ newExercise: NewExercise) async throws -> Exercise {
        let savedExercise: Exercise = try await supabaseClient
            .from("exercises")
            .insert(newExercise)
            .select()
            .single()
            .execute()
            .value
        
        return savedExercise
    }
}
