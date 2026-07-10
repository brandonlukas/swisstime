import CoreTransferable
import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// The file a workout travels as, friend to friend — a `.lido` JSON
    /// file, declared in Support/Info.plist as an exported type this app
    /// owns, so tapping one in Messages opens it here.
    static let lidoWorkout = UTType(exportedAs: "com.brandonlukas.swisstime.workout")
}

/// ShareLink's item: a workout leaving the library. Written lazily, only
/// when a share destination actually asks for the file.
struct WorkoutFile: Transferable {
    let workout: Workout

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .lidoWorkout) { file in
            SentTransferredFile(try write(file.workout),
                                allowAccessingOriginalFile: false)
        }
    }

    /// Writes the traveling file and returns its URL. In its own fresh
    /// temp directory: the filename IS the workout title (it's what the
    /// Messages bubble shows), and two exports of the same title must
    /// not race over one path.
    static func write(_ workout: Workout) throws -> URL {
        // The file carries the program, not the sender's history.
        var traveling = workout
        traveling.lastPlayedAt = nil
        traveling.createdAt = nil
        let data = try JSONEncoder().encode(traveling)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory,
                                                withIntermediateDirectories: true)
        let title = workout.title.trimmed.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = directory
            .appendingPathComponent(title.isEmpty ? "Workout" : title)
            .appendingPathExtension("lido")
        try data.write(to: url)
        return url
    }
}

extension Workout {
    /// The most exercises a shared file may carry — far past any honest
    /// program, and small enough that the preview list renders instantly.
    static let importedExerciseCap = 100

    /// Reads a shared `.lido` file into a workout ready to enter this
    /// library, or nil for anything that isn't one. The result is exactly
    /// what Add to Library appends — the preview must never show a
    /// program that differs from what arrives.
    ///
    /// The lenient decoder forgives missing fields (that's vintage); the
    /// work here is junk: an empty husk or an implausibly large file
    /// bounces, and everything a hand-edited file could inflate is
    /// clamped — text to the forms' caps, numbers to the app's ranges
    /// (an Infinity duration would trap `Int()` in Format.mmss), ids to
    /// fresh ones so a twice-opened file can never collide, dates to a
    /// blank history that starts now, at the top of the list.
    static func imported(from url: URL) -> Workout? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size < 1_000_000,
              let data = try? Data(contentsOf: url),
              var workout = try? JSONDecoder().decode(Workout.self, from: data)
        else { return nil }

        workout.id = UUID()
        workout.createdAt = Date()
        workout.lastPlayedAt = nil
        workout.title = String(workout.title.trimmed.prefix(FieldLimit.name))
        workout.details = String(workout.details.trimmed.prefix(FieldLimit.notes))
        workout.exercises = workout.exercises.prefix(importedExerciseCap).map { exercise in
            var safe = exercise
            safe.id = UUID()
            safe.name = String(safe.name.trimmed.prefix(FieldLimit.name))
            safe.instructions = String(safe.instructions.trimmed.prefix(FieldLimit.notes))
            safe.duration = clamped(safe.duration, 1...7200)
            safe.restDuration = clamped(safe.restDuration, 0...3600)
            safe.sets = min(max(1, safe.sets), 99)
            safe.reps = safe.reps.map { min(max(1, $0), 999) }
            return safe
        }
        guard !(workout.title.isEmpty && workout.exercises.isEmpty) else { return nil }
        return workout
    }

    /// NaN fails every comparison, so it must be caught by name — a
    /// plain min/max clamp would smuggle it through.
    private static func clamped(_ value: TimeInterval,
                                _ range: ClosedRange<TimeInterval>) -> TimeInterval {
        value.isFinite ? min(max(value, range.lowerBound), range.upperBound)
                       : range.lowerBound
    }
}
