import Foundation

/// How a workout is done. A timed workout plays in the player, step by step
/// with voice cues; an untimed one is done at your own pace and logged with
/// a tap when it's finished.
enum WorkoutKind: String, Codable {
    case timed, untimed
}

struct Workout: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var details: String = ""
    var kind: WorkoutKind = .timed
    var exercises: [Exercise] = []
    var lastPlayedAt: Date?
    /// New workouts surface at the top of the list; optional so files from
    /// before the field keep their standing (they sort as never-created).
    var createdAt: Date? = Date()
    /// Index into `Palette.all`; optional so pre-palette files decode.
    var colorIndex: Int?

    var totalDuration: TimeInterval {
        exercises.reduce(0) { $0 + $1.estimatedDuration }
    }

    var totalSets: Int {
        exercises.reduce(0) { $0 + max(1, $1.sets) }
    }

    /// "3 exercises · 15 min" (timed) / "4 exercises · 13 sets" (untimed) —
    /// untimed workouts have no honest duration, so they count sets instead.
    var summaryLine: String {
        switch kind {
        case .timed: return Format.summary(count: exercises.count, duration: totalDuration)
        case .untimed: return Format.setsSummary(count: exercises.count, sets: totalSets)
        }
    }

    /// "Timed · 3 exercises · 15 min" — the summary with its mode up
    /// front, for rows that show a workout out of context (the sample
    /// shelf, a shared workout's preview). The kind is named exactly as
    /// the Type picker names it — "Untimed", never "Sets", which
    /// belongs to the Sets tab alone.
    var kindSummaryLine: String {
        "\(kind == .timed ? "Timed" : "Untimed") · \(summaryLine)"
    }

    /// Distinct exercise names in order of appearance, for the list subtitle.
    var exerciseNames: [String] {
        var names: [String] = []
        for exercise in exercises where !names.contains(exercise.name) {
            names.append(exercise.name)
        }
        return names
    }

    mutating func update(exercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[index] = exercise
        }
    }
}

extension Workout {
    // ⚠️ These keys (and the field defaults) are also decoded by the
    // share fallback page — lido/w.html in the brandonlukas.github.io
    // repo — which renders shared workouts for people without Lido.
    // Key or default changes must land there too.
    enum CodingKeys: String, CodingKey {
        case id, title, details, kind, lastPlayedAt, createdAt, colorIndex
        // The key predates the rename; files on disk keep it.
        case exercises = "items"
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
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        colorIndex = try container.decodeIfPresent(Int.self, forKey: .colorIndex)
        // Probe for the legacy shape FIRST: Exercise decodes leniently
        // (every field defaulted), so a legacy enum-shaped item would
        // otherwise "succeed" as a blank exercise instead of failing over.
        if let legacy = try? container.decode([LegacyItem].self, forKey: .exercises) {
            exercises = legacy.flatMap(\.exercises)
        } else {
            exercises = try container.decodeIfPresent([Exercise].self, forKey: .exercises) ?? []
        }
        // Files predate the workout-level kind: a workout built entirely of
        // sets-mode exercises was untimed in spirit, so it becomes one.
        kind = try container.decodeIfPresent(WorkoutKind.self, forKey: .kind)
            ?? (!exercises.isEmpty && exercises.allSatisfy { $0.mode == .sets } ? .untimed : .timed)
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

/// Rest lengths offered wherever a rest is picked (exercise form, Sets tab).
enum Presets {
    static let restDurations: [TimeInterval] = [15, 20, 30, 45, 60, 75, 90,
                                                120, 150, 180, 240, 300]
}

/// Hard caps on user-authored text — titles and names render in cards,
/// breadcrumbs, and the Live Activity, and unbounded text breaks them.
/// The forms enforce these as typed; imported files are clamped to the
/// same numbers, so the two can never drift apart.
enum FieldLimit {
    /// Workout titles and exercise names.
    static let name = 40
    /// Workout details and exercise instructions.
    static let notes = 120
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
    /// ⚠️ These fallbacks are also the WIRE defaults for shared links —
    /// TravelExercise (WorkoutTransfer.swift) omits fields that equal
    /// them, and w.html renders them — so they are frozen: changing one
    /// silently mutates every shared workout in transit.
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
