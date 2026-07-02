import SwiftUI

extension Color {
    /// The single accent — a Swiss "Klein" blue.
    static let swissBlue = Color(red: 0.22, green: 0.23, blue: 0.94)
    /// Flat light-gray card fill.
    static let card = Color(white: 0.965)
    static let fieldBorder = Color(white: 0.85)
    static let hairline = Color(white: 0.88)
}

extension Font {
    /// Helvetica — the Swiss typeface.
    static func swiss(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("HelveticaNeue", size: size).weight(weight)
    }
}

/// The black rule under page titles.
struct SwissRule: View {
    var body: some View {
        Rectangle()
            .fill(Color.black)
            .frame(height: 1)
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum Format {
    /// "15:00", "1:00", "0:05"
    static func mmss(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }

    /// "3 items · 15 min"
    static func summary(count: Int, duration: TimeInterval) -> String {
        let minutes = Int((duration / 60).rounded(.up))
        return "\(count) item\(count == 1 ? "" : "s") · \(minutes) min"
    }

    /// "With 16, Rest, and 20" / "With A, B, C, D, and more"
    static func withLine(_ names: [String]) -> String? {
        guard !names.isEmpty else { return nil }
        if names.count > 4 {
            return "With " + names.prefix(4).joined(separator: ", ") + ", and more"
        }
        if names.count == 1 { return "With \(names[0])" }
        if names.count == 2 { return "With \(names[0]) and \(names[1])" }
        return "With " + names.dropLast().joined(separator: ", ") + ", and \(names.last!)"
    }
}
