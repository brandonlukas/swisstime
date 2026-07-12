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
        let data = try JSONEncoder().encode(workout.travelCopy)
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

/// Where shared workouts point on the web: the Pages site that owns the
/// app's universal links. The workout rides in the URL FRAGMENT, which
/// never reaches any server — the page is only a fallback face for a
/// friend without Lido; a phone with Lido never loads it.
enum WorkoutLink {
    /// Effectively write-once: links live forever in old chat threads,
    /// so if Lido ever moves domains, this host must stay ACCEPTED (in
    /// `matches`) even if new links mint elsewhere.
    static let base = URL(string: "https://brandonlukas.github.io/lido/w")!

    /// Longer links get SPLIT by Messages — the preview card keeps the
    /// bare URL and the fragment strands as plain text (seen on device,
    /// 2026-07-11). Under this length they survive whole; over it, the
    /// share falls back to the .lido file, which always transfers.
    static let messageSafeLength = 500

    /// Inbound fragments larger than this are junk by construction (we
    /// never mint past `messageSafeLength`; the slack covers format
    /// drift). The cap's real job is bounding the deflate: unchecked, a
    /// crafted ~1MB fragment would inflate toward a gigabyte before any
    /// later size check could object.
    static let fragmentCap = 4_000

    /// Whether a URL is ours to answer AT ALL. The app stays mute on
    /// every other link from the associated domain — a widened AASA
    /// must not turn support pages into false "couldn't read" alerts —
    /// and the host compares case-folded because iOS routes applinks
    /// case-insensitively.
    static func matches(_ url: URL) -> Bool {
        url.host()?.lowercased() == base.host() && url.path() == base.path()
    }

    /// The link, or nil when the program can't fit a Messages-safe one
    /// — the transport policy lives here, beside the constant it
    /// enforces, not in whichever view happens to share.
    static func messageSafeURL(for workout: Workout) -> URL? {
        guard let link = url(for: workout),
              link.absoluteString.count < messageSafeLength else { return nil }
        return link
    }

    /// The workout as a tappable https link — deflated JSON, base64url,
    /// after the #. Compression isn't thrift, it's transport: a typical
    /// program has to fit under `messageSafeLength`.
    static func url(for workout: Workout) -> URL? {
        guard let json = try? JSONEncoder().encode(workout.travelCopy),
              let squeezed = try? (json as NSData).compressed(using: .zlib) as Data,
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        else { return nil }
        components.fragment = squeezed.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return components.url
    }

    /// The reverse trip: a tapped universal link back into an
    /// import-ready workout, or nil for links that aren't ours.
    static func workout(from url: URL) -> Workout? {
        guard matches(url),
              let fragment = url.fragment(), fragment.count < fragmentCap
        else { return nil }
        var base64 = fragment
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else { return nil }
        // Deflated since 2026-07; a payload that won't inflate is read
        // as plain JSON, so nothing hangs on the format's history.
        let json = (try? (data as NSData).decompressed(using: .zlib) as Data) ?? data
        return Workout.imported(fromShared: json)
    }
}

// A share item carrying BOTH a link proxy and a file representation was
// tried and reverted (2026-07-11): representation order is a global
// preference, not per-destination matching — Files happily takes a URL
// (saving a bookmark), so no ordering serves link-to-Messages and
// file-to-Files from one item. The share button shares the link; the
// deliberate file export lives in the workout's edit list.

extension Workout {
    /// The most exercises a shared workout may carry — far past any
    /// honest program, and small enough that the preview renders
    /// instantly.
    static let importedExerciseCap = 100

    /// What travels when a workout is shared: the program, not the
    /// sender's history — and not its identities. Import mints fresh ids
    /// regardless, and a payload full of distinct UUIDs is pure entropy
    /// to the deflate that has to fit the link under Messages' limit;
    /// one repeated blank id compresses to almost nothing.
    var travelCopy: Workout {
        let blank = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
        var copy = self
        copy.lastPlayedAt = nil
        copy.createdAt = nil
        copy.id = blank
        for index in copy.exercises.indices {
            copy.exercises[index].id = blank
        }
        return copy
    }

    /// Reads a shared `.lido` file into a workout ready to enter this
    /// library, or nil for anything that isn't one.
    static func imported(from url: URL) -> Workout? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size < 1_000_000,
              let data = try? Data(contentsOf: url)
        else { return nil }
        return imported(fromShared: data)
    }

    /// The one gate every arriving workout passes — file or link. The
    /// result is exactly what Add to Library appends; the preview must
    /// never show a program that differs from what arrives.
    ///
    /// The lenient decoder forgives missing fields (that's vintage); the
    /// work here is junk: an empty husk or an implausibly large payload
    /// bounces, and everything a hand-edited payload could inflate is
    /// clamped — text to the forms' caps, numbers to the app's ranges
    /// (an Infinity duration would trap `Int()` in Format.mmss), ids to
    /// fresh ones so a twice-opened share can never collide, dates to a
    /// blank history that starts now, at the top of the list.
    static func imported(fromShared data: Data) -> Workout? {
        guard data.count < 1_000_000,
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
