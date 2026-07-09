import Foundation

/// One finished workout — one toy in that month's pool. Title and color
/// are snapshots so the pond survives workout renames and deletions.
struct PondEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var completedAt: Date
    var workoutID: UUID
    var workoutTitle: String
    var colorIndex: Int
    /// A line the user wrote about how it went — the logbook's journal entry.
    var note: String?
    /// The lucky roll: a gilded pearl-and-gold colorway of the earned toy.
    /// Optional so pre-shiny files decode; nil reads as false.
    var shiny: Bool?

    var isShiny: Bool { shiny == true }
}

extension Array where Element == PondEntry {
    /// One day's finished workouts, in finish order — the single grouping
    /// the pool's calendar and the home-screen week strip both read, so
    /// the two surfaces can never disagree about what a day held (they
    /// may present it differently: the calendar stripes every workout,
    /// the widget's small squares show the last one's swatch).
    func finished(on day: Date, calendar: Calendar = .current) -> [PondEntry] {
        filter { calendar.isDate($0.completedAt, inSameDayAs: day) }
            .sorted { $0.completedAt < $1.completedAt }
    }
}

/// A calendar month — the pond's unit of time.
struct MonthKey: Hashable, Comparable, Codable {
    var year: Int
    var month: Int

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month], from: date)
        year = components.year ?? 2000
        month = components.month ?? 1
    }

    static var current: MonthKey { MonthKey(Date()) }

    /// "July"
    var monthName: String {
        Calendar.current.standaloneMonthSymbols[(month - 1 + 12) % 12]
    }

    /// "July 2026"
    var title: String { "\(monthName) \(year)" }

    /// Stable layout seed so a month's pond looks the same on every visit.
    var seed: UInt64 {
        UInt64(bitPattern: Int64(year)) &* 2654435761 &+ UInt64(month)
    }

    static func < (a: MonthKey, b: MonthKey) -> Bool {
        (a.year, a.month) < (b.year, b.month)
    }
}

/// xorshift64* — deterministic across runs and platforms, unlike
/// SystemRandomNumberGenerator, so seeded pond layouts never shuffle.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    /// Folds the 16 UUID bytes into a 64-bit seed.
    init(_ uuid: UUID) {
        let u = uuid.uuid
        let high = UInt64(u.0) << 56 | UInt64(u.1) << 48 | UInt64(u.2) << 40 | UInt64(u.3) << 32
                 | UInt64(u.4) << 24 | UInt64(u.5) << 16 | UInt64(u.6) << 8 | UInt64(u.7)
        let low  = UInt64(u.8) << 56 | UInt64(u.9) << 48 | UInt64(u.10) << 40 | UInt64(u.11) << 32
                 | UInt64(u.12) << 24 | UInt64(u.13) << 16 | UInt64(u.14) << 8 | UInt64(u.15)
        self.init(seed: high ^ low)
    }

    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545F4914F6CDD1D
    }
}
