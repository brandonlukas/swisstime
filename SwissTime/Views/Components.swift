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
                .font(.app(17, .medium))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .inkButton(fill)
        }
        .buttonStyle(PressableButtonStyle())
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
                .font(.app(17, .medium))
            Text(message)
                .font(.app(15))
                .foregroundStyle(.secondary)
            Button(action: action) {
                Text(buttonTitle)
                    .font(.app(16, .medium))
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
