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

extension Color {
    // Surface tokens shared with the widget so the home screen can never
    // drift from the app: the deck, the ink, the pool tile and grout,
    // and the shiny gold. Retune here and both processes follow.

    /// The deck behind every screen: natatorium off-white by day, the
    /// blue-black deck of a night swim after dark.
    static let paper = Color(light: Color(red: 0.914, green: 0.929, blue: 0.953),
                             dark: Color(red: 0.063, green: 0.082, blue: 0.157))

    /// Text and chrome — deep pool-water navy, pale in the dark.
    static let ink = Color(light: Color(red: 0.075, green: 0.13, blue: 0.28),
                           dark: Color(red: 0.902, green: 0.925, blue: 0.969))

    /// The pool floor above the waterline.
    static let tileDry = Color(light: Color(red: 0.76, green: 0.845, blue: 0.915),
                               dark: Color(red: 0.122, green: 0.153, blue: 0.263))
    static let tileGrout = Color(light: Color(red: 0.615, green: 0.72, blue: 0.83),
                                 dark: Color(red: 0.196, green: 0.235, blue: 0.373))

    /// The gilded-toy accent — fixed, like all toy vinyl.
    static let gold = Color(red: 0.87, green: 0.70, blue: 0.33)

    /// Ink at an opacity that answers the system's Increase Contrast
    /// setting — the default look is untouched; users who flip the switch
    /// get firmer text and borders. Shared so widget labels obey the same
    /// contrast rules as the app. Components mirror `ink` above, which a
    /// UIColor provider can't consume as a SwiftUI Color.
    static func inkOpacity(_ normal: CGFloat, highContrast: CGFloat) -> Color {
        Color(uiColor: UIColor { traits in
            let ink = traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.902, green: 0.925, blue: 0.969, alpha: 1)
                : UIColor(red: 0.075, green: 0.13, blue: 0.28, alpha: 1)
            return ink.withAlphaComponent(
                traits.accessibilityContrast == .high ? highContrast : normal)
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
        // Positive modulo: Swift's % preserves sign, and a negative index
        // from a corrupt/hand-edited file would otherwise trap BOTH
        // processes (the widget renders raw decoded pond entries).
        let count = all.count
        return all[(((index ?? 0) % count) + count) % count]
    }

    static func toy(for index: Int?) -> ToyKind {
        color(index).toy
    }
}
