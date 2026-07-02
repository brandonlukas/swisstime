import ActivityKit
import Foundation

/// Owns the lock screen / Dynamic Island Live Activity for a running workout.
@MainActor
final class LiveActivityController {
    private var activity: Activity<WorkoutActivityAttributes>?

    func start(workoutTitle: String, state: WorkoutActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Any activity alive right now belongs to a dead engine.
        Self.endOrphans()
        let attributes = WorkoutActivityAttributes(workoutTitle: workoutTitle)
        activity = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: Self.staleDate(for: state))
        )
    }

    func update(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity else { return }
        Task {
            await activity.update(.init(state: state, staleDate: Self.staleDate(for: state)))
        }
    }

    /// Pass a final state to leave it on the lock screen briefly; nil removes it now.
    func end(_ state: WorkoutActivityAttributes.ContentState? = nil) {
        guard let activity else { return }
        self.activity = nil
        Task {
            if let state {
                await activity.end(.init(state: state, staleDate: nil),
                                   dismissalPolicy: .after(.now + 4))
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// An activity only means something while its engine is alive. A force-quit
    /// or crash mid-workout strands the last state on the island — a count-up
    /// step then counts up forever. Swept at app launch and before each start.
    nonisolated static func endOrphans() {
        for orphan in Activity<WorkoutActivityAttributes>.activities {
            Task { await orphan.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// When the engine stops pushing updates, let the system mark the activity
    /// stale: countdown states expire just after they should have advanced;
    /// count-up and paused states after longer than any plausible set or rest.
    private static func staleDate(for state: WorkoutActivityAttributes.ContentState) -> Date {
        if state.countsUp || state.paused {
            return Date().addingTimeInterval(30 * 60)
        }
        return max(state.endDate, Date()).addingTimeInterval(60)
    }
}
