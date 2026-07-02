import Foundation

@MainActor
final class PondStore: ObservableObject {
    @Published var entries: [PondEntry] = [] {
        didSet { if loaded { save() } }
    }

    private var loaded = false
    private let fileURL: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documents.appendingPathComponent("pond.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([PondEntry].self, from: data) {
            entries = decoded
        }
        // Debug: fake a populated pond (this month + history) for UI verification.
        // Injected before `loaded`, so the fakes aren't persisted by themselves.
        if ProcessInfo.processInfo.arguments.contains("-seedPond") {
            entries = Self.sampleEntries()
        }
        loaded = true
    }

    /// A finished workout drops one creature into this month's pond.
    func record(workout: Workout) {
        entries.append(PondEntry(
            completedAt: Date(),
            workoutID: workout.id,
            workoutTitle: workout.title,
            colorIndex: workout.colorIndex ?? 0
        ))
    }

    /// Strikes a finished workout from the record — its creature leaves the pond.
    func remove(_ id: UUID) {
        entries.removeAll { $0.id == id }
    }

    func entries(in month: MonthKey) -> [PondEntry] {
        entries.filter { MonthKey($0.completedAt) == month }
    }

    /// Every month with entries, newest first — the logbook's sections.
    var allMonths: [MonthKey] {
        Set(entries.map { MonthKey($0.completedAt) }).sorted(by: >)
    }

    /// Past months that have something to show, newest first.
    var monthsWithEntries: [MonthKey] {
        let current = MonthKey.current
        return Set(entries.map { MonthKey($0.completedAt) })
            .filter { $0 != current }
            .sorted(by: >)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Deterministic fakes: fixed IDs keep seeded pond layouts identical
    /// between launches, so screenshots can be compared.
    private static func sampleEntries() -> [PondEntry] {
        let calendar = Calendar.current
        func entry(_ ordinal: Int, monthsAgo: Int, day: Int, colorIndex: Int) -> PondEntry? {
            guard let base = calendar.date(byAdding: .month, value: -monthsAgo, to: Date()),
                  let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", ordinal))
            else { return nil }
            var components = calendar.dateComponents([.year, .month], from: base)
            components.day = day
            components.hour = 9
            guard let date = calendar.date(from: components) else { return nil }
            return PondEntry(id: id, completedAt: min(date, Date()), workoutID: id,
                             workoutTitle: "Seeded workout", colorIndex: colorIndex)
        }
        let plan: [(monthsAgo: Int, day: Int, colorIndex: Int)] = [
            (0, 1, 0), (0, 2, 1), (0, 3, 2), (0, 4, 3), (0, 5, 4), (0, 6, 5), (0, 7, 0), (0, 8, 4),
            (3, 2, 1), (3, 9, 4), (3, 15, 0),
        ]
        // Last month gets its own loop so short months still land on valid days.
        let lastMonth: [(day: Int, colorIndex: Int)] = [(3, 2), (8, 0), (14, 5), (20, 1), (25, 3)]
        var result = plan.enumerated().compactMap { index, item in
            entry(index + 1, monthsAgo: item.monthsAgo, day: item.day, colorIndex: item.colorIndex)
        }
        result += lastMonth.enumerated().compactMap { index, item in
            entry(index + 100, monthsAgo: 1, day: item.day, colorIndex: item.colorIndex)
        }
        return result
    }
}
