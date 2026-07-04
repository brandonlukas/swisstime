import SwiftUI
import UIKit

// Shared with the widget: the workout swatches are the data colors of the
// whole system, and the home screen must agree with the app on every one.

extension Color {
    /// One palette, two pools: day at the lido and the night swim. Every
    /// surface token resolves per the system appearance; toy vinyl and the
    /// workout swatches stay fixed — a duck is yellow at midnight too.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

/// What floats in for a finished workout of this color.
enum ToyKind {
    case duck, beachBall, ring, orca, flamingo, lilo
}

struct PaletteColor {
    let name: String
    let fill: Color
    /// Legible ink on top of `fill` — the light fills need black.
    let onFill: Color
    let toy: ToyKind
}

/// Six water tones, shallow end to midnight, each tied to a pool toy.
/// Indices are stable — pre-pool files decode and simply adopt the cooler
/// colors. Every fill must survive full-screen in the player with legible
/// text on matte cards over it. At night each swatch lifts like the pool
/// itself: same hue, more light — Midnight especially, which would
/// otherwise sink into the navy cards it sits on.
enum Palette {
    static let all: [PaletteColor] = [
        PaletteColor(name: "Shallow",
                     fill: Color(light: Color(red: 0.47, green: 0.71, blue: 0.87),
                                 dark: Color(red: 0.53, green: 0.76, blue: 0.92)),
                     onFill: .black,
                     toy: .ring),
        PaletteColor(name: "Pool",
                     fill: Color(light: Color(red: 0.20, green: 0.48, blue: 0.79),
                                 dark: Color(red: 0.26, green: 0.56, blue: 0.89)),
                     onFill: .white,
                     toy: .duck),
        PaletteColor(name: "Deep",
                     fill: Color(light: Color(red: 0.10, green: 0.26, blue: 0.52),
                                 dark: Color(red: 0.18, green: 0.37, blue: 0.70)),
                     onFill: .white,
                     toy: .orca),
        PaletteColor(name: "Chlorine",
                     fill: Color(light: Color(red: 0.22, green: 0.56, blue: 0.54),
                                 dark: Color(red: 0.27, green: 0.65, blue: 0.62)),
                     onFill: .white,
                     toy: .beachBall),
        PaletteColor(name: "Periwinkle",
                     fill: Color(light: Color(red: 0.55, green: 0.59, blue: 0.90),
                                 dark: Color(red: 0.63, green: 0.67, blue: 0.97)),
                     onFill: .black,
                     toy: .flamingo),
        PaletteColor(name: "Midnight",
                     fill: Color(light: Color(red: 0.15, green: 0.17, blue: 0.33),
                                 dark: Color(red: 0.31, green: 0.33, blue: 0.56)),
                     onFill: .white,
                     toy: .lilo),
    ]

    static func color(_ index: Int?) -> PaletteColor {
        all[(index ?? 0) % all.count]
    }

    static func toy(for index: Int?) -> ToyKind {
        color(index).toy
    }
}
