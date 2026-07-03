import Foundation
import UIKit

/// The Sets tab's engine: one continuous clock anchored to `zeroDate`.
/// Ending a set pushes `zeroDate` out by the ideal rest; the clock counts
/// down to it, beeps once as it passes, and keeps counting into the
/// negative — how deep into the next set (or past due) you already are.
/// No speech, no pause, no auto-advance: the only input is "End set",
/// and ending the last one finishes the session outright.
@MainActor
final class SetCounterEngine: ObservableObject {
    let setCount: Int
    let rest: TimeInterval

    /// 1-based set underway — during the rest before it, too.
    @Published private(set) var currentSet = 1
    @Published private(set) var finished = false
    /// The moment the clock reads 0:00.
    private(set) var zeroDate = Date()

    private let audio = AudioManager()
    private let liveActivity = LiveActivityController()
    private let feedback = UIImpactFeedbackGenerator(style: .medium)
    private var ticker: Timer?
    private var observers: [NSObjectProtocol] = []
    /// The opening stretch has no rest to ring out.
    private var beepFired = true
    private var lastEndSet = Date.distantPast

    init(setCount: Int, rest: TimeInterval) {
        self.setCount = max(1, setCount)
        self.rest = max(1, rest)
    }

    /// Seconds until zero — negative once past it.
    func remaining(at date: Date) -> TimeInterval {
        zeroDate.timeIntervalSince(date)
    }

    /// 1 at the top of a rest, 0 at (and past) zero — the water level.
    func fraction(at date: Date) -> Double {
        min(1, max(0, remaining(at: date) / rest))
    }

    func start() {
        audio.start()
        feedback.prepare()
        zeroDate = Date()
        liveActivity.start(workoutTitle: "Sets", state: activityState())
        // The island's skip button is the same tap as "End set".
        observers.append(NotificationCenter.default.addObserver(
            forName: .playerSkipStep, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.endSet() }
        })
        // The audio keepalive holds the app out of suspension, so the beep
        // lands on time with the screen off; assumeIsolated as in the player.
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(ticker!, forMode: .common)
    }

    func stopAndTearDown() {
        ticker?.invalidate()
        ticker = nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        liveActivity.end(nil)
        audio.stop()
    }

    /// The one input.
    func endSet() {
        guard !finished else { return }
        // A stray double-tap shouldn't burn a whole set.
        let now = Date()
        guard now.timeIntervalSince(lastEndSet) > 1 else { return }
        lastEndSet = now
        feedback.impactOccurred()
        if currentSet >= setCount {
            finished = true
            return
        }
        currentSet += 1
        zeroDate = now.addingTimeInterval(rest)
        beepFired = false
        liveActivity.update(activityState())
    }

    private func tick() {
        guard !finished, !beepFired, Date() >= zeroDate else { return }
        beepFired = true
        audio.playBeep()
        // Past zero the island's countdown flips to a stopwatch.
        liveActivity.update(activityState())
    }

    private func activityState() -> WorkoutActivityAttributes.ContentState {
        let overdue = Date() >= zeroDate
        return .init(
            exerciseName: overdue ? "Set \(currentSet)" : "Rest · set \(currentSet) next",
            stepLabel: "",
            endDate: zeroDate,
            paused: false,
            pausedRemaining: 0,
            stepIndex: currentSet - 1,
            stepCount: setCount,
            finished: false,
            countsUp: overdue,
            startDate: zeroDate,
            showsPause: false
        )
    }
}
