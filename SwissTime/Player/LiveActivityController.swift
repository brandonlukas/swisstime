import ActivityKit
import Foundation

/// Owns the lock screen / Dynamic Island Live Activity for a running workout.
@MainActor
final class LiveActivityController {
    private var activity: Activity<WorkoutActivityAttributes>?

    func start(workoutTitle: String, state: WorkoutActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = WorkoutActivityAttributes(workoutTitle: workoutTitle)
        activity = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: nil)
        )
    }

    func update(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity else { return }
        Task {
            await activity.update(.init(state: state, staleDate: nil))
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
}
