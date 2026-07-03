import ActivityKit
import Foundation

struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var stepLabel: String
        var endDate: Date
        var paused: Bool
        /// While paused: remaining for countdown steps, elapsed for count-up.
        var pausedRemaining: TimeInterval
        var stepIndex: Int
        var stepCount: Int
        var finished: Bool
        /// Untimed sets and count-up rests show a stopwatch, not a countdown.
        var countsUp: Bool = false
        var startDate: Date = Date()
        /// The set counter has no pause — its only control is skip (end set).
        var showsPause: Bool = true
    }

    var workoutTitle: String
}

/// "15:00", "0:05" — shared by app and widget.
func shortTime(_ interval: TimeInterval) -> String {
    let total = Int(interval.rounded())
    return "\(total / 60):" + String(format: "%02d", total % 60)
}
