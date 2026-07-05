import SwiftUI
import UIKit

/// The one big action on a screen — full-width, filled, pressable.
struct PrimaryButton: View {
    let title: String
    var fill: Color = .ink
    var textColor: Color = .onInk
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .appFont(17, .medium)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .inkButton(fill)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// The quieter sibling beside a PrimaryButton — outlined, ink text, same
/// height and radius so a side-by-side pair reads as one control row.
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .appFont(17, .medium)
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.paperCardFill.opacity(0.6)))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.fieldBorder, lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// The poster-caps page title over its rule — every screen's masthead.
struct PageHeader: View {
    let title: String
    var size: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .display(size)
                .padding(.bottom, 14)
            InkRule()
        }
    }
}

/// The sheet-corner X with a full 44 pt target, anchored so the glyph sits
/// where a bare icon would — a lone glyph's transparent pixels don't
/// hit-test, and the glyph alone is far under the minimum tap size.
struct SheetCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44, alignment: .topLeading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// "Nothing here yet": headline, hint, and one compact action.
struct EmptyStateView: View {
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .appFont(17, .medium)
            Text(message)
                .appFont(15)
                .foregroundStyle(Color.inkSecondary)
            Button(action: action) {
                Text(buttonTitle)
                    .appFont(16, .medium)
                    .foregroundStyle(Color.onInk)
                    .padding(.horizontal, 24)
                    .frame(height: 48)
                    .inkButton(.ink)
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, 8)
        }
    }
}

/// Refcounted ownership of the idle timer: the player and the set counter
/// can overlap (starting a workout ends a counter session a beat later),
/// and whoever releases last must not re-enable screen sleep under the
/// session still running.
@MainActor
enum ScreenSleep {
    private static var claims = 0

    static func hold() {
        claims += 1
        UIApplication.shared.isIdleTimerDisabled = true
    }

    static func release() {
        claims = max(0, claims - 1)
        if claims == 0 {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
