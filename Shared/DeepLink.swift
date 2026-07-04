import AppIntents
import Foundation

/// Cross-view latch for launcher deep links. The ask can arrive before its
/// destination exists (cold launch from a control), so a request both sets
/// a flag (for views about to be built) and posts a notification (for
/// views already live) — whoever gets there consumes it.
@MainActor
enum DeepLink {
    static let startSets = Notification.Name("SwissTime.startSets")
    static var pendingSetsStart = false

    static func requestSetsStart() {
        pendingSetsStart = true
        NotificationCenter.default.post(name: startSets, object: nil)
    }
}

/// The Control Center button's action. This file lives in Shared/ because
/// controls resolve their intent against the PARENT APP's App Intents
/// metadata, not the extension's — the device log showed siriactionsd
/// looking in com.brandonlukas.swisstime and failing ("action missing" →
/// "Encountered action intent without linkAction"), which is why every
/// extension-only intent pressed dead. Compiled into the app, the intent
/// resolves, the system opens the app, and perform() runs in the app
/// process where it can ask for Sets directly.
struct StartSetsIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Sets"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLink.requestSetsStart()
        return .result()
    }
}
