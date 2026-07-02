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
}
