import Foundation

struct Workout: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var details: String = ""
    var items: [WorkoutItem] = []
    var lastPlayedAt: Date?

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

struct Exercise: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var instructions: String = ""
    var duration: TimeInterval = 60
    var halfwayAlert: Bool = false
    var fiveSecondsAlert: Bool = true

    func copy() -> Exercise {
        var copy = self
        copy.id = UUID()
        return copy
    }
}

struct Circuit: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var loops: Int = 3
    var exercises: [Exercise] = []

    var duration: TimeInterval {
        TimeInterval(max(1, loops)) * exercises.reduce(0) { $0 + $1.duration }
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
        case .exercise(let exercise): return exercise.duration
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
