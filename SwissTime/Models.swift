import Foundation

struct Workout: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var details: String = ""
    var items: [WorkoutItem] = []
    var lastPlayedAt: Date?
    /// Index into `Color.swissPalette`; optional so pre-palette files decode.
    var colorIndex: Int?

    var totalDuration: TimeInterval {
        items.reduce(0) { $0 + $1.duration }
    }

    /// Distinct exercise names in order of appearance, for the list subtitle.
    var exerciseNames: [String] {
        var names: [String] = []
        func add(_ name: String) {
            if !names.contains(name) { names.append(name) }
        }
        for item in items {
            switch item {
            case .exercise(let exercise):
                add(exercise.name)
            case .circuit(let circuit):
                circuit.exercises.forEach { add($0.name) }
            }
        }
        return names
    }
}

/// How an exercise runs in the player.
/// `interval`: one timed block, auto-advances — hands-free routines.
/// `sets`: untimed work you end with a tap, with a rest timer between sets.
enum ExerciseMode: String, Codable {
    case interval, sets
}

struct Exercise: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var instructions: String = ""
    var mode: ExerciseMode = .interval
    var duration: TimeInterval = 60
    var halfwayAlert: Bool = false
    var fiveSecondsAlert: Bool = true
    // Sets mode.
    var sets: Int = 4
    /// Display-only — never counted in the player.
    var reps: Int?
    var restDuration: TimeInterval = 60
    /// Down: rest counts to zero and auto-starts the next set.
    /// Up (default): rest counts past a chimed target; you start the next set.
    var restCountsDown: Bool = false

    /// Rough set length for planning totals only; sets are untimed in play.
    static let estimatedSetWork: TimeInterval = 45

    var estimatedDuration: TimeInterval {
        switch mode {
        case .interval:
            return duration
        case .sets:
            let count = TimeInterval(max(1, sets))
            return count * Self.estimatedSetWork + (count - 1) * restDuration
        }
    }

    /// "1:30" for interval, "4 × 12" / "4 sets" for sets — list trailing text.
    var trailingSummary: String {
        switch mode {
        case .interval:
            return Format.mmss(duration)
        case .sets:
            if let reps { return "\(sets) × \(reps)" }
            return "\(sets) set\(sets == 1 ? "" : "s")"
        }
    }

    func copy() -> Exercise {
        var copy = self
        copy.id = UUID()
        return copy
    }
}

extension Exercise {
    enum CodingKeys: String, CodingKey {
        case id, name, instructions, mode, duration, halfwayAlert, fiveSecondsAlert,
             sets, reps, restDuration, restCountsDown
    }

    /// Lenient decoding so pre-sets files (and pre-pond seeds) still open.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        instructions = try container.decodeIfPresent(String.self, forKey: .instructions) ?? ""
        mode = try container.decodeIfPresent(ExerciseMode.self, forKey: .mode) ?? .interval
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 60
        halfwayAlert = try container.decodeIfPresent(Bool.self, forKey: .halfwayAlert) ?? false
        fiveSecondsAlert = try container.decodeIfPresent(Bool.self, forKey: .fiveSecondsAlert) ?? true
        sets = try container.decodeIfPresent(Int.self, forKey: .sets) ?? 4
        reps = try container.decodeIfPresent(Int.self, forKey: .reps)
        restDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .restDuration) ?? 60
        restCountsDown = try container.decodeIfPresent(Bool.self, forKey: .restCountsDown) ?? false
    }
}

struct Circuit: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var loops: Int = 3
    var exercises: [Exercise] = []

    var duration: TimeInterval {
        TimeInterval(max(1, loops)) * exercises.reduce(0) { $0 + $1.estimatedDuration }
    }

    func copy() -> Circuit {
        var copy = self
        copy.id = UUID()
        copy.exercises = exercises.map { $0.copy() }
        return copy
    }
}

enum WorkoutItem: Identifiable, Codable, Equatable {
    case exercise(Exercise)
    case circuit(Circuit)

    var id: UUID {
        switch self {
        case .exercise(let exercise): return exercise.id
        case .circuit(let circuit): return circuit.id
        }
    }

    var duration: TimeInterval {
        switch self {
        case .exercise(let exercise): return exercise.estimatedDuration
        case .circuit(let circuit): return circuit.duration
        }
    }
}

extension Workout {
    mutating func add(_ exercise: Exercise, toCircuit circuitID: UUID?) {
        if let circuitID,
           let index = items.firstIndex(where: { $0.id == circuitID }),
           case .circuit(var circuit) = items[index] {
            circuit.exercises.append(exercise)
            items[index] = .circuit(circuit)
        } else {
            items.append(.exercise(exercise))
        }
    }

    mutating func update(exercise: Exercise) {
        for index in items.indices {
            switch items[index] {
            case .exercise(let existing) where existing.id == exercise.id:
                items[index] = .exercise(exercise)
                return
            case .circuit(var circuit):
                if let sub = circuit.exercises.firstIndex(where: { $0.id == exercise.id }) {
                    circuit.exercises[sub] = exercise
                    items[index] = .circuit(circuit)
                    return
                }
            default:
                break
            }
        }
    }

    mutating func update(circuit: Circuit) {
        if let index = items.firstIndex(where: { $0.id == circuit.id }) {
            items[index] = .circuit(circuit)
        }
    }

    mutating func deleteItem(_ id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items.remove(at: index)
            return
        }
        for index in items.indices {
            if case .circuit(var circuit) = items[index],
               let sub = circuit.exercises.firstIndex(where: { $0.id == id }) {
                circuit.exercises.remove(at: sub)
                items[index] = .circuit(circuit)
                return
            }
        }
    }

    /// Lifts a top-level exercise into an existing circuit (appended at the end).
    mutating func moveExercise(_ id: UUID, intoCircuit circuitID: UUID) {
        guard let itemIndex = items.firstIndex(where: { $0.id == id }),
              case .exercise(let exercise) = items[itemIndex],
              let circuitIndex = items.firstIndex(where: { $0.id == circuitID }),
              case .circuit(var circuit) = items[circuitIndex] else { return }
        circuit.exercises.append(exercise)
        items[circuitIndex] = .circuit(circuit)
        items.remove(at: itemIndex)
    }

    /// Pulls an exercise out of its circuit, placing it right after the circuit.
    mutating func moveExerciseOutOfCircuit(_ id: UUID) {
        for index in items.indices {
            if case .circuit(var circuit) = items[index],
               let sub = circuit.exercises.firstIndex(where: { $0.id == id }) {
                let exercise = circuit.exercises.remove(at: sub)
                items[index] = .circuit(circuit)
                items.insert(.exercise(exercise), at: index + 1)
                return
            }
        }
    }

    mutating func duplicateItem(_ id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            switch items[index] {
            case .exercise(let exercise):
                items.insert(.exercise(exercise.copy()), at: index + 1)
            case .circuit(let circuit):
                items.insert(.circuit(circuit.copy()), at: index + 1)
            }
            return
        }
        for index in items.indices {
            if case .circuit(var circuit) = items[index],
               let sub = circuit.exercises.firstIndex(where: { $0.id == id }) {
                circuit.exercises.insert(circuit.exercises[sub].copy(), at: sub + 1)
                items[index] = .circuit(circuit)
                return
            }
        }
    }
}
