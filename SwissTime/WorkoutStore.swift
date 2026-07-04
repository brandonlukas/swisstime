import Foundation
import WidgetKit

@MainActor
final class WorkoutStore: ObservableObject {
    @Published var workouts: [Workout] = [] {
        didSet { if loaded { save() } }
    }

    private var loaded = false
    /// Debug-seeded runs never save: one edit in a seeded session would
    /// otherwise overwrite the real file with the fakes.
    private let seeded = ProcessInfo.processInfo.arguments.contains("-seedWorkouts")
    private let fileURL: URL

    init() {
        // Shared with the widget process; migrates the old Documents file.
        fileURL = AppGroup.dataFileURL("workouts.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Workout].self, from: data) {
            workouts = decoded
        }
        // Debug: fake a workout list (one untimed, one timed) for UI verification.
        if seeded {
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
        guard !seeded, let data = try? JSONEncoder().encode(workouts) else { return }
        try? data.write(to: fileURL, options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Starters & seeds

    private static func setsExercise(_ name: String, _ sets: Int, _ reps: Int,
                                     _ rest: TimeInterval) -> Exercise {
        var exercise = Exercise(name: name)
        exercise.mode = .sets
        exercise.sets = sets
        exercise.reps = reps
        exercise.restDuration = rest
        return exercise
    }

    private static func intervalExercise(_ name: String, _ duration: TimeInterval,
                                         halfway: Bool = false) -> Exercise {
        var exercise = Exercise(name: name)
        exercise.mode = .interval
        exercise.duration = duration
        exercise.halfwayAlert = halfway
        return exercise
    }

    /// The empty state's shelf: three curated starters, adopted one tap at
    /// a time. Three on purpose — enough to cover both modes without
    /// making the first screen a decision. Push Day teaches sets mode
    /// (Lap + rest clock); the other two are hands-free timed circuits.
    /// Fresh IDs per call, so re-adopting after a delete never collides.
    static func starterWorkouts() -> [Workout] {
        var pushDay = Workout(title: "Push Day", details: "Chest, shoulders, triceps.")
        pushDay.kind = .untimed
        pushDay.colorIndex = 3
        pushDay.exercises = [
            setsExercise("Bench press", 4, 8, 120),
            setsExercise("Overhead press", 3, 10, 90),
            setsExercise("Incline dumbbell press", 3, 12, 90),
            setsExercise("Triceps pushdown", 3, 12, 60),
        ]
        var core = Workout(title: "Core Circuit", details: "Every minute, something new.")
        core.kind = .timed
        core.colorIndex = 0
        core.exercises = [
            intervalExercise("Plank", 60),
            intervalExercise("Dead bug", 60),
            // "Halfway done." is the cue to switch sides.
            intervalExercise("Side plank", 60, halfway: true),
        ]
        // Pitched for a first-timer: dynamic moves carry the eight minutes
        // (a minute of crunches is far kinder than a minute of holding),
        // holds are capped at 60s, and the side plank's halfway cue splits
        // it into 30 a side. Hard-guy moves like hollow holds stay out —
        // anyone can finish this on day one, and nobody's bored by it.
        var abs = Workout(title: "Morning Abs", details: "Eight minutes, hands-free.")
        abs.kind = .timed
        abs.colorIndex = 4
        abs.exercises = [
            intervalExercise("Crunches", 60),
            intervalExercise("Heel taps", 60),
            intervalExercise("Reverse crunches", 60),
            intervalExercise("Side plank", 60, halfway: true),
            intervalExercise("Leg raises", 60),
            intervalExercise("Bicycle crunches", 60),
            intervalExercise("Mountain climbers", 60),
            intervalExercise("Plank", 60),
        ]
        return [pushDay, core, abs]
    }

    /// The untimed seed was "played" recently so it sorts first —
    /// `-autoOpenFirstWorkout` lands on the mark-as-done flow.
    private static func sampleWorkouts() -> [Workout] {
        var pushDay = Workout(title: "Push day", details: "Chest, shoulders, triceps.")
        pushDay.kind = .untimed
        pushDay.colorIndex = 3
        pushDay.lastPlayedAt = Date()
        pushDay.exercises = [
            setsExercise("Bench press", 4, 8, 120),
            setsExercise("Overhead press", 3, 10, 90),
            setsExercise("Incline dumbbell press", 3, 12, 90),
            setsExercise("Triceps pushdown", 3, 12, 60),
        ]
        var core = Workout(title: "Core circuit", details: "Every minute, something new.")
        core.kind = .timed
        core.colorIndex = 0
        core.exercises = [
            intervalExercise("Plank", 60),
            intervalExercise("Dead bug", 60),
            intervalExercise("Side plank", 60),
        ]
        return [pushDay, core]
    }
}
