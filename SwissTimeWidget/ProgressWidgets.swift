import SwiftUI
import WidgetKit
import AppIntents

// Home-screen widgets show PROGRESS, never prompts: the week's tally and
// the month's pool. Workouts happen at the gym, not wherever the phone is —
// so nothing here nags anyone to start one. The only launchers are for
// Sets, the one feature genuinely used on a phone that's already out.
// No widget ticks: state changes only when a workout lands (the stores
// reload timelines on save) or a day boundary passes.

// MARK: - Surfaces (mirrors of Theme.swift's paper and ink)

private extension Color {
    static let wPaper = Color(light: Color(red: 0.914, green: 0.929, blue: 0.953),
                              dark: Color(red: 0.063, green: 0.082, blue: 0.157))
    static let wInk = Color(light: Color(red: 0.075, green: 0.13, blue: 0.28),
                            dark: Color(red: 0.902, green: 0.925, blue: 0.969))
    static let wTile = Color(light: Color(red: 0.76, green: 0.845, blue: 0.915),
                             dark: Color(red: 0.122, green: 0.153, blue: 0.263))
    static let wGrout = Color(light: Color(red: 0.615, green: 0.72, blue: 0.83),
                              dark: Color(red: 0.196, green: 0.235, blue: 0.373))
    static let wGold = Color(red: 0.87, green: 0.70, blue: 0.33)
}

// MARK: - Timeline

struct PoolTimelineEntry: TimelineEntry {
    let date: Date
    let entries: [PondEntry]
}

/// One provider for every progress widget: the pool log, re-read whenever
/// the app saves (stores call reloadAllTimelines) and at each midnight so
/// "this week" rolls over without a workout.
struct PoolProvider: TimelineProvider {
    func placeholder(in context: Context) -> PoolTimelineEntry {
        PoolTimelineEntry(date: Date(), entries: Self.sample())
    }

    func getSnapshot(in context: Context, completion: @escaping (PoolTimelineEntry) -> Void) {
        completion(PoolTimelineEntry(date: Date(),
                                     entries: context.isPreview ? Self.sample() : Self.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PoolTimelineEntry>) -> Void) {
        let now = Date()
        let midnight = Calendar.current.nextDate(after: now,
                                                 matching: DateComponents(hour: 0),
                                                 matchingPolicy: .nextTime) ?? now.addingTimeInterval(86400)
        completion(Timeline(entries: [PoolTimelineEntry(date: now, entries: Self.load())],
                            policy: .after(midnight)))
    }

    static func load() -> [PondEntry] {
        let url = AppGroup.containerURL.appendingPathComponent("pond.json")
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([PondEntry].self, from: data)
        else { return [] }
        return decoded
    }

    /// Gallery previews: a believable week, never real data.
    static func sample() -> [PondEntry] {
        let calendar = Calendar.current
        return [(-1, 3), (-3, 1), (-5, 4)].compactMap { daysAgo, colorIndex in
            guard let date = calendar.date(byAdding: .day, value: daysAgo, to: Date())
            else { return nil }
            return PondEntry(completedAt: date, workoutID: UUID(),
                             workoutTitle: "Workout", colorIndex: colorIndex)
        }
    }
}

// MARK: - Week helpers

/// The current calendar week as day slots: date, done-color, today flag.
private struct WeekDay {
    let letter: String
    let isToday: Bool
    /// The last finished workout's swatch that day, if any.
    let fill: Color?
}

private func weekDays(from entries: [PondEntry], now: Date) -> [WeekDay] {
    let calendar = Calendar.current
    guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
    let symbols = calendar.veryShortStandaloneWeekdaySymbols
    return (0..<7).compactMap { offset in
        guard let day = calendar.date(byAdding: .day, value: offset, to: week.start)
        else { return nil }
        let done = entries
            .filter { calendar.isDate($0.completedAt, inSameDayAs: day) }
            .max { $0.completedAt < $1.completedAt }
        return WeekDay(
            letter: symbols[calendar.component(.weekday, from: day) - 1],
            isToday: calendar.isDate(day, inSameDayAs: now),
            fill: done.map { Palette.color($0.colorIndex).fill }
        )
    }
}

private func weekCount(_ entries: [PondEntry], now: Date) -> Int {
    let calendar = Calendar.current
    guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
    return entries.filter { week.contains($0.completedAt) }.count
}

// MARK: - 02 · This week (medium)

struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.brandonlukas.swisstime.week",
                            provider: PoolProvider()) { entry in
            WeekView(entry: entry)
                .containerBackground(for: .widget) { Color.wPaper }
        }
        .configurationDisplayName("This week")
        .description("The week's workouts, day by day, in their own colors.")
        .supportedFamilies([.systemMedium])
    }
}

private struct WeekView: View {
    let entry: PoolTimelineEntry

    var body: some View {
        let days = weekDays(from: entry.entries, now: entry.date)
        let count = weekCount(entry.entries, now: entry.date)
        HStack(alignment: .bottom, spacing: 22) {
            VStack(alignment: .leading, spacing: 2) {
                Text("This week")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.3)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.wInk.opacity(0.55))
                Spacer(minLength: 0)
                Text("\(count)")
                    .font(.system(size: 64, weight: .light))
                    .monospacedDigit()
                    .foregroundStyle(Color.wInk)
            }
            HStack(alignment: .bottom, spacing: 7) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(day.fill ?? .clear)
                            .overlay {
                                if day.fill == nil {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .strokeBorder(Color.wInk.opacity(0.16))
                                }
                            }
                            .aspectRatio(1, contentMode: .fit)
                        Text(day.letter)
                            .font(.system(size: 9, weight: day.isToday ? .bold : .medium))
                            .foregroundStyle(Color.wInk.opacity(day.isToday ? 0.9 : 0.5))
                    }
                }
            }
        }
    }
}

// MARK: - 03 · The pool (small)

struct PoolWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.brandonlukas.swisstime.pool",
                            provider: PoolProvider()) { entry in
            PoolView(entry: entry)
                .containerBackground(for: .widget) { PoolTiles() }
        }
        .configurationDisplayName("The pool")
        .description("This month's pool — one toy afloat per finished workout.")
        .supportedFamilies([.systemSmall])
    }
}

/// The tiled floor, drawn like PondScene's but still: a photograph of the
/// pool, not the pool itself.
private struct PoolTiles: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(.wTile))
            let step: CGFloat = 22
            var lines = Path()
            var x: CGFloat = step
            while x < size.width { lines.move(to: CGPoint(x: x, y: 0))
                lines.addLine(to: CGPoint(x: x, y: size.height)); x += step }
            var y: CGFloat = step
            while y < size.height { lines.move(to: CGPoint(x: 0, y: y))
                lines.addLine(to: CGPoint(x: size.width, y: y)); y += step }
            context.stroke(lines, with: .color(.wGrout), lineWidth: 1)
        }
    }
}

private struct PoolView: View {
    let entry: PoolTimelineEntry

    var body: some View {
        let month = MonthKey(entry.date)
        let afloat = entry.entries.filter { MonthKey($0.completedAt) == month }
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Each toy drifts to a resting spot seeded by its identity,
                // so the layout is calm and stable between refreshes.
                ForEach(afloat) { toy in
                    var random = SeededRandom(toy.id)
                    let x = CGFloat.random(in: 0.12...0.88, using: &random)
                    let y = CGFloat.random(in: 0.18...0.78, using: &random)
                    let size = CGFloat.random(in: 13...20, using: &random)
                    Circle()
                        .fill(toy.isShiny ? Color.wGold
                                          : Palette.color(toy.colorIndex).fill)
                        .frame(width: size, height: size)
                        .position(x: geo.size.width * x, y: geo.size.height * y)
                        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(month.monthName)
                        .font(.system(size: 10, weight: .semibold))
                        .kerning(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.wInk.opacity(0.65))
                    Spacer(minLength: 0)
                    Text("\(afloat.count)")
                        .font(.system(size: 44, weight: .light))
                        .monospacedDigit()
                        .foregroundStyle(Color.wInk)
                }
            }
        }
    }
}

// MARK: - 06 · At a glance (lock screen)

struct WeekAccessoryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.brandonlukas.swisstime.weekAccessory",
                            provider: PoolProvider()) { entry in
            WeekAccessoryView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("This week")
        .description("The week's tally on the Lock Screen.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

private struct WeekAccessoryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PoolTimelineEntry

    var body: some View {
        let count = weekCount(entry.entries, now: entry.date)
        switch family {
        case .accessoryInline:
            Label("\(count) this week", systemImage: "figure.run")
        case .accessoryCircular:
            VStack(spacing: -2) {
                Text("\(count)")
                    .font(.system(size: 24, weight: .semibold))
                    .monospacedDigit()
                Text("WK")
                    .font(.system(size: 9, weight: .semibold))
                    .opacity(0.6)
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(Array(weekDays(from: entry.entries, now: entry.date).enumerated()),
                            id: \.offset) { _, day in
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(.primary.opacity(day.fill == nil ? 0.25 : 1))
                            .frame(width: 10, height: 10)
                    }
                }
                Text("\(count) this week").font(.system(size: 14, weight: .bold))
                Text("SwissTime").font(.system(size: 11)).opacity(0.6)
            }
        }
    }
}

// MARK: - 05 · Sets, from anywhere

/// The one deep link a launcher needs: the Sets tab with the counter armed.
private let startSetsURL = URL(string: "swisstime://sets/start")!

/// Lock-screen door into Sets — for the bench, where the phone is locked
/// and rest starts NOW, not after a hunt through the home screen.
struct SetsLauncherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.brandonlukas.swisstime.setsLauncher",
                            provider: PoolProvider()) { _ in
            SetsLauncherView()
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(startSetsURL)
        }
        .configurationDisplayName("Start Sets")
        .description("Straight into the rest counter.")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

private struct SetsLauncherView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryInline {
            Label("Start Sets", systemImage: "timer")
        } else {
            VStack(spacing: -1) {
                Image(systemName: "timer").font(.system(size: 22, weight: .medium))
                Text("SETS").font(.system(size: 8, weight: .semibold)).opacity(0.6)
            }
        }
    }
}

/// Control Center / Action button door into the same place.
struct StartSetsControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.brandonlukas.swisstime.startSets") {
            ControlWidgetButton(action: StartSetsIntent()) {
                Label("Start Sets", systemImage: "timer")
            }
        }
        .displayName("Start Sets")
        .description("Open SwissTime with the rest counter armed.")
    }
}

struct StartSetsIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Sets"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(startSetsURL))
    }
}
