import SwiftUI

/// The back of the pool: the month's ledger written on the deck. One rule
/// governs it — celebrate presence, never advertise absence. Done days fill
/// with their workouts' colors (the session grid's language; two workouts
/// split the tile), empty past days are quiet deck tile, future days are
/// barely there, and nothing counts, streaks, or scores.
struct PoolCalendarView: View {
    let month: MonthKey
    let entries: [PondEntry]

    private let calendar = Calendar.current

    var body: some View {
        // No month label back here — the page header directly above the
        // card already says it, on either side of the flip.
        VStack(alignment: .leading, spacing: 0) {
            let colors = dayColors
            let today = todayDay
            Spacer(minLength: 12)
            // One ForEach, one ID namespace: headers, leading blanks, and
            // days all live in the same grid, and colliding Int ids make
            // LazyVGrid silently drop cells.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6),
                                     count: 7), spacing: 6) {
                ForEach(cells) { cell in
                    switch cell.kind {
                    case .header(let symbol):
                        Text(symbol)
                            .appFont(9, .bold)
                            .foregroundStyle(Color.ink.opacity(0.45))
                    case .blank:
                        Color.clear.frame(height: 1)
                    case .day(let day):
                        DayCell(day: day,
                                colors: colors[day] ?? [],
                                isToday: day == today,
                                isFuture: today.map { day > $0 } ?? false)
                    }
                }
            }
            Spacer(minLength: 12)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { DeckTexture() }
    }

    private struct Cell: Identifiable {
        enum Kind {
            case header(String), blank, day(Int)
        }
        let id: Int
        let kind: Kind
    }

    private var cells: [Cell] {
        var cells: [Cell] = []
        for (index, symbol) in weekdaySymbols.enumerated() {
            cells.append(Cell(id: index, kind: .header(symbol)))
        }
        for index in 0..<leadingBlanks {
            cells.append(Cell(id: 100 + index, kind: .blank))
        }
        for day in 1...dayCount {
            cells.append(Cell(id: 200 + day, kind: .day(day)))
        }
        return cells
    }

    /// The colors of each finished workout, by day of the month, in the
    /// order they were finished.
    private var dayColors: [Int: [Color]] {
        var byDay: [Int: [PondEntry]] = [:]
        for entry in entries {
            byDay[calendar.component(.day, from: entry.completedAt), default: []]
                .append(entry)
        }
        return byDay.mapValues { day in
            day.sorted { $0.completedAt < $1.completedAt }
               .map { Palette.color($0.colorIndex).fill }
        }
    }

    /// Today's day number, only when this page is the current month —
    /// past ledgers have no "today", and no future either.
    private var todayDay: Int? {
        month == .current ? calendar.component(.day, from: Date()) : nil
    }

    private var monthStart: Date {
        calendar.date(from: DateComponents(year: month.year, month: month.month,
                                           day: 1)) ?? Date()
    }

    private var dayCount: Int {
        calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    }

    private var leadingBlanks: Int {
        let weekday = calendar.component(.weekday, from: monthStart)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    /// "S M T W T F S", rotated to the locale's first weekday.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
    }
}

/// One day: quiet deck tile until a workout colors it in.
private struct DayCell: View {
    let day: Int
    let colors: [Color]
    let isToday: Bool
    let isFuture: Bool

    var body: some View {
        Text("\(day)")
            .appFont(12, colors.isEmpty ? .regular : .semibold)
            .monospacedDigit()
            .foregroundStyle(numeralColor)
            .frame(maxWidth: .infinity)
            // Taller than wide: the portrait card has height to spend, and
            // the mock's cells read as tiles, not pills.
            .frame(height: 40)
            .background(fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .bottom) {
                if isToday {
                    Capsule()
                        .fill(colors.isEmpty ? Color.ink.opacity(0.5)
                                             : Color.white.opacity(0.8))
                        .frame(width: 12, height: 2)
                        .padding(.bottom, 3)
                }
            }
            .accessibilityLabel(accessibilityText)
    }

    private var numeralColor: Color {
        if !colors.isEmpty { return .white }
        return Color.ink.opacity(isFuture ? 0.25 : 0.5)
    }

    /// One color fills the tile; more split it on the diagonal, a stripe
    /// per workout, hard-edged like the pool's own lane lines.
    private var fill: AnyShapeStyle {
        switch colors.count {
        case 0:
            return AnyShapeStyle(Color(light: Color.white.opacity(0.5),
                                       dark: Color.white.opacity(0.07)))
        case 1:
            return AnyShapeStyle(colors[0])
        default:
            var stops: [Gradient.Stop] = []
            for (index, color) in colors.enumerated() {
                stops.append(.init(color: color, location: Double(index) / Double(colors.count)))
                stops.append(.init(color: color, location: Double(index + 1) / Double(colors.count)))
            }
            return AnyShapeStyle(LinearGradient(stops: stops,
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing))
        }
    }

    private var accessibilityText: String {
        let base = "Day \(day)"
        guard !colors.isEmpty else { return base }
        return "\(base), \(colors.count) workout\(colors.count == 1 ? "" : "s") finished"
    }
}

/// The pool's deck: dry tile with its grout grid — the same surface Deep
/// End stands on.
private struct DeckTexture: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(Color.tileDry))
            let spacing: CGFloat = 42
            var lines = Path()
            var x = spacing
            while x < size.width { lines.move(to: CGPoint(x: x, y: 0))
                lines.addLine(to: CGPoint(x: x, y: size.height)); x += spacing }
            var y = spacing
            while y < size.height { lines.move(to: CGPoint(x: 0, y: y))
                lines.addLine(to: CGPoint(x: size.width, y: y)); y += spacing }
            context.stroke(lines, with: .color(Color.tileGrout.opacity(0.5)),
                           lineWidth: 1)
        }
    }
}
