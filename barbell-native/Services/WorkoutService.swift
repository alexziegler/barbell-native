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
    func fetchSets(for userId: UUID) async {
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
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }

    /// Fetches all exercises for a user
    func fetchExercises(for userId: UUID) async {
        do {
            let fetchedExercises: [Exercise] = try await supabaseClient
                .from("exercises")
                .select()
                .eq("user_id", value: userId.uuidString)
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

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchSets(for: userId) }
            group.addTask { await self.fetchExercises(for: userId) }
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
}
