import Foundation

struct Workout: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var details: String = ""
    var items: [Exercise] = []
    var lastPlayedAt: Date?
    /// Index into `Color.swissPalette`; optional so pre-palette files decode.
    var colorIndex: Int?

    var totalDuration: TimeInterval {
        items.reduce(0) { $0 + $1.estimatedDuration }
    }

    /// Distinct exercise names in order of appearance, for the list subtitle.
    var exerciseNames: [String] {
        var names: [String] = []
        for exercise in items where !names.contains(exercise.name) {
            names.append(exercise.name)
        }
        return names
    }

    mutating func update(exercise: Exercise) {
        if let index = items.firstIndex(where: { $0.id == exercise.id }) {
            items[index] = exercise
        }
    }
}

extension Workout {
    enum CodingKeys: String, CodingKey {
        case id, title, details, items, lastPlayedAt, colorIndex
    }

    /// Items were once an exercise/circuit enum; a legacy circuit flattens to
    /// its exercises in order (loop counts drop — the file keeps its content,
    /// not its repetition).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        details = try container.decodeIfPresent(String.self, forKey: .details) ?? ""
        lastPlayedAt = try container.decodeIfPresent(Date.self, forKey: .lastPlayedAt)
        colorIndex = try container.decodeIfPresent(Int.self, forKey: .colorIndex)
        // Probe for the legacy shape FIRST: Exercise decodes leniently
        // (every field defaulted), so a legacy enum-shaped item would
        // otherwise "succeed" as a blank exercise instead of failing over.
        if let legacy = try? container.decode([LegacyItem].self, forKey: .items) {
            items = legacy.flatMap(\.exercises)
        } else {
            items = try container.decodeIfPresent([Exercise].self, forKey: .items) ?? []
        }
    }
}

/// The retired exercise/circuit item enum, in its synthesized associated-value
/// encoding: `{"exercise": {"_0": {...}}}` / `{"circuit": {"_0": {...}}}`.
private enum LegacyItem: Decodable {
    case exercise(Exercise)
    case circuit([Exercise])

    var exercises: [Exercise] {
        switch self {
        case .exercise(let exercise): return [exercise]
        case .circuit(let exercises): return exercises
        }
    }

    private enum CodingKeys: String, CodingKey { case exercise, circuit }
    private enum Assoc: String, CodingKey { case value = "_0" }
    private struct LegacyCircuit: Decodable { var exercises: [Exercise] }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.exercise) {
            let nested = try container.nestedContainer(keyedBy: Assoc.self, forKey: .exercise)
            self = .exercise(try nested.decode(Exercise.self, forKey: .value))
        } else {
            let nested = try container.nestedContainer(keyedBy: Assoc.self, forKey: .circuit)
            self = .circuit(try nested.decode(LegacyCircuit.self, forKey: .value).exercises)
        }
    }
}

/// How an exercise runs in the player.
/// `interval`: one timed block, auto-advances — hands-free routines.
/// `sets`: untimed work you end with a tap, with a rest countdown between sets.
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
    /// Rest between sets, counted down; the next set starts when it hits zero.
    var restDuration: TimeInterval = 60

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
}

extension Exercise {
    enum CodingKeys: String, CodingKey {
        case id, name, instructions, mode, duration, halfwayAlert, fiveSecondsAlert,
             sets, reps, restDuration
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
    }
}
