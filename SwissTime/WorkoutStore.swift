import Foundation

@MainActor
final class WorkoutStore: ObservableObject {
    @Published var workouts: [Workout] = [] {
        didSet { if loaded { save() } }
    }

    private var loaded = false
    private let fileURL: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documents.appendingPathComponent("workouts.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Workout].self, from: data) {
            workouts = decoded
        }
        // Debug: fake a workout list (one untimed, one timed) for UI
        // verification. Injected before `loaded`, so the fakes replace the
        // real list in memory but aren't persisted by themselves.
        if ProcessInfo.processInfo.arguments.contains("-seedWorkouts") {
            workouts = Self.sampleWorkouts()
        }
        loaded = true
    }

    func workout(_ id: UUID) -> Workout? {
        workouts.first { $0.id == id }
    }

    func update(_ workout: Workout) {
        guard let index = workouts.firstIndex(where: { $0.id == workout.id }) else { return }
        workouts[index] = workout
    }

    func delete(_ id: UUID) {
        workouts.removeAll { $0.id == id }
    }

    func markPlayed(_ id: UUID) {
        guard let index = workouts.firstIndex(where: { $0.id == id }) else { return }
        workouts[index].lastPlayedAt = Date()
    }

    /// Recently played first; never-played keep creation order after those.
    var sortedWorkouts: [Workout] {
        workouts.enumerated().sorted { a, b in
            let dateA = a.element.lastPlayedAt ?? .distantPast
            let dateB = b.element.lastPlayedAt ?? .distantPast
            if dateA != dateB { return dateA > dateB }
            return a.offset < b.offset
        }.map(\.element)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(workouts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// The untimed seed was "played" recently so it sorts first —
    /// `-autoOpenFirstWorkout` lands on the mark-as-done flow.
    private static func sampleWorkouts() -> [Workout] {
        func sets(_ name: String, _ sets: Int, _ reps: Int, _ rest: TimeInterval) -> Exercise {
            var exercise = Exercise(name: name)
            exercise.mode = .sets
            exercise.sets = sets
            exercise.reps = reps
            exercise.restDuration = rest
            return exercise
        }
        func interval(_ name: String, _ duration: TimeInterval) -> Exercise {
            var exercise = Exercise(name: name)
            exercise.mode = .interval
            exercise.duration = duration
            return exercise
        }
        var pushDay = Workout(title: "Push day", details: "Chest, shoulders, triceps.")
        pushDay.kind = .untimed
        pushDay.colorIndex = 3
        pushDay.lastPlayedAt = Date()
        pushDay.items = [
            sets("Bench press", 4, 8, 120),
            sets("Overhead press", 3, 10, 90),
            sets("Incline dumbbell press", 3, 12, 90),
            sets("Triceps pushdown", 3, 12, 60),
        ]
        var core = Workout(title: "Core circuit", details: "Every minute, something new.")
        core.kind = .timed
        core.colorIndex = 0
        core.items = [
            interval("Plank", 60),
            interval("Dead bug", 60),
            interval("Side plank", 60),
        ]
        return [pushDay, core]
    }
}
