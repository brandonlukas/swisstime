import AppIntents
import Foundation

extension Notification.Name {
    static let playerTogglePause = Notification.Name("playerTogglePause")
    static let playerSkipStep = Notification.Name("playerSkipStep")
}

/// Live Activity intents run in the app's process, so a notification
/// reaches the running PlayerEngine directly.
struct TogglePauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause or Resume Workout"

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .playerTogglePause, object: nil)
        }
        return .result()
    }
}

struct SkipStepIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Skip Exercise"

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .playerSkipStep, object: nil)
        }
        return .result()
    }
}
