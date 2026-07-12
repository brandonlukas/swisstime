import Foundation

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
    /// 2026-07-11). Under this length they survive whole; a program
    /// that can't fit doesn't share, and the share button says why.
    static let messageSafeLength = 500

    /// Inbound fragments larger than this are junk by construction (we
    /// never mint past `messageSafeLength`; the slack covers format
    /// drift). The cap's real job is bounding the deflate: unchecked, a
    /// crafted ~1MB fragment would inflate toward a gigabyte before any
    /// later size check could object.
    static let fragmentCap = 4_000

    /// Whether a URL is ours to answer AT ALL. The app stays mute on
    /// every other link from the associated domain — a widened AASA
    /// must not turn support pages into false "couldn't read" alerts.
    /// The host compares case-folded (iOS routes applinks
    /// case-insensitively), and the path accepts every spelling the
    /// AASA's `/lido/w*` component claims for the ONE page it means —
    /// a tap iOS routes to the app must never die in silence here.
    static func matches(_ url: URL) -> Bool {
        guard url.host()?.lowercased() == base.host() else { return false }
        let path = url.path()
        return path == base.path()
            || path == base.path() + "/"
            || path == base.path() + ".html"
    }

    /// The link, or nil when the program can't fit a Messages-safe one
    /// — the transport policy lives here, beside the constant it
    /// enforces, not in whichever view happens to share.
    static func messageSafeURL(for workout: Workout) -> URL? {
        guard let link = url(for: workout),
              link.absoluteString.count < messageSafeLength else { return nil }
        return link
    }

    /// The workout as a tappable https link — travel-encoded JSON,
    /// deflated, base64url, after the #. Both steps are transport, not
    /// thrift: a real program has to fit under `messageSafeLength`.
    static func url(for workout: Workout) -> URL? {
        guard let json = try? JSONEncoder().encode(TravelWorkout(workout)),
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
        guard let data = Data(base64Encoded: base64),
              // Every minted link has been deflated since before the
              // first release that could mint one — a fragment that
              // won't inflate is junk, not vintage.
              let json = try? (data as NSData).decompressed(using: .zlib) as Data
        else { return nil }
        return Workout.imported(fromShared: json)
    }
}

/// The traveling shape of a workout: the same JSON schema the app has
/// always decoded, minus everything the lenient decoders default — the
/// sender's history, identities (import mints fresh ones), empty text,
/// and every field at its default value. Half the bytes of a full
/// encoding BEFORE compression, which is what keeps real programs under
/// the Messages-safe length. The web fallback (lido/w.html) applies the
/// same defaults when it renders.
private struct TravelWorkout: Encodable {
    let title: String
    let details: String?
    let kind: WorkoutKind
    let colorIndex: Int?
    let items: [TravelExercise]

    init(_ workout: Workout) {
        title = workout.title
        details = workout.details.isEmpty ? nil : workout.details
        kind = workout.kind
        colorIndex = workout.colorIndex
        items = workout.exercises.map(TravelExercise.init)
    }
}

/// ⚠️ The omit-when-default literals below are WIRE constants, frozen
/// forever — they must equal the `decodeIfPresent` fallbacks in
/// Exercise.init(from:) (Models.swift), which old links in old chat
/// threads depend on. If the model's defaults ever change, these do
/// NOT follow; stop omitting that field instead.
private struct TravelExercise: Encodable {
    let name: String
    let instructions: String?
    let mode: ExerciseMode?
    let duration: TimeInterval?
    let halfwayAlert: Bool?
    let fiveSecondsAlert: Bool?
    let sets: Int?
    let reps: Int?
    let restDuration: TimeInterval?

    init(_ exercise: Exercise) {
        let sets = exercise.mode == .sets
        name = exercise.name
        instructions = exercise.instructions.isEmpty ? nil : exercise.instructions
        mode = sets ? .sets : nil
        duration = !sets && exercise.duration != 60 ? exercise.duration : nil
        halfwayAlert = exercise.halfwayAlert ? true : nil
        fiveSecondsAlert = exercise.fiveSecondsAlert ? nil : false
        self.sets = sets && exercise.sets != 4 ? exercise.sets : nil
        reps = sets ? exercise.reps : nil
        restDuration = sets && exercise.restDuration != 60 ? exercise.restDuration : nil
    }
}

extension Workout {
    /// The most exercises a shared workout may carry — far past any
    /// honest program, and small enough that the preview renders
    /// instantly.
    static let importedExerciseCap = 100

    /// The one gate every arriving workout passes. The result is
    /// exactly what Add to Library appends; the preview must never show
    /// a program that differs from what arrives.
    ///
    /// The lenient decoder forgives missing fields (that's both vintage
    /// and the travel encoding's whole trick); the work here is junk:
    /// an empty husk or an implausibly large payload bounces, and
    /// everything a hand-edited payload could inflate is clamped — text
    /// to the forms' caps, numbers to the app's ranges (an Infinity
    /// duration would trap `Int()` in Format.mmss), ids to fresh ones
    /// so a twice-opened share can never collide, dates to a blank
    /// history that starts now, at the top of the list.
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
        // The preview falls an empty title back to "Workout" — the
        // library must receive that same word, not a nameless row.
        if workout.title.isEmpty {
            workout.title = "Workout"
        }
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
