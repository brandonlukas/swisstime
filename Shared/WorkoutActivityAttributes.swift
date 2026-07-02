import ActivityKit
import Foundation

struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var stepLabel: String
        var endDate: Date
        var paused: Bool
        var pausedRemaining: TimeInterval
        var stepIndex: Int
        var stepCount: Int
        var finished: Bool
    }

    var workoutTitle: String
}

/// "15:00", "0:05" — shared by app and widget.
func shortTime(_ interval: TimeInterval) -> String {
    let total = Int(interval.rounded())
    return "\(total / 60):" + String(format: "%02d", total % 60)
}
