import Foundation
import UIKit

/// The Sets tab's engine: one continuous clock anchored to `zeroDate`.
/// Ending a set pushes `zeroDate` out by the ideal rest; the clock counts
/// down to it, beeps once as it passes, and keeps counting into the
/// negative — how deep into the next set (or past due) you already are.
/// No pause, no auto-advance: the only input is "End set", and ending the
/// last one finishes the session outright. The optional voices are a
/// "Halfway done" and a "5 seconds left" heads-up before the beep,
/// off-screen warning enough to get back under the bar.
@MainActor
final class SetCounterEngine: ObservableObject {
    let setCount: Int
    let rest: TimeInterval
    let halfwayCue: Bool
    let fiveSecondsCue: Bool

    /// 1-based set underway — during the rest before it, too.
    @Published private(set) var currentSet = 1
    @Published private(set) var finished = false
    /// The moment the clock reads 0:00.
    private(set) var zeroDate = Date()

    private let audio = AudioManager()
    private let liveActivity = LiveActivityController()
    private var ticker: Timer?
    private var observers: [NSObjectProtocol] = []
    /// The opening stretch has no rest to ring out.
    private var beepFired = true
    private var cueFired = true
    private var halfwayFired = true
    private var lastEndSet = Date.distantPast
    private var lastTickAt = Date()

    init(setCount: Int, rest: TimeInterval, halfwayCue: Bool = false,
         fiveSecondsCue: Bool = false) {
        self.setCount = max(1, setCount)
        self.rest = max(1, rest)
        self.halfwayCue = halfwayCue
        self.fiveSecondsCue = fiveSecondsCue
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
        zeroDate = Date()
        liveActivity.start(workoutTitle: "Sets", state: activityState())
        // The island's skip button is the same tap as "End set".
        observers.append(NotificationCenter.default.addObserver(
            forName: .playerSkipStep, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.endSet() }
        })
        // A workout player starting takes over the island and the skip
        // intent; the counter bows out. Delivered synchronously (main
        // thread post, main queue observer), so this teardown lands before
        // the player's audio session activates.
        observers.append(NotificationCenter.default.addObserver(
            forName: .playerEngineDidStart, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.yieldToPlayer() }
        })
        // The audio keepalive holds the app out of suspension, so the beep
        // lands on time with the screen off; assumeIsolated as in the player.
        let ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(ticker, forMode: .common)
        self.ticker = ticker
    }

    /// Safe to call twice — the view tears down an engine that may have
    /// already yielded to a player.
    func stopAndTearDown() {
        ticker?.invalidate()
        ticker = nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        liveActivity.end(nil)
        audio.stop()
    }

    private func yieldToPlayer() {
        guard !finished else { return }
        stopAndTearDown()
        finished = true
    }

    /// The one input.
    func endSet() {
        guard !finished else { return }
        // A stray double-tap shouldn't burn a whole set.
        let now = Date()
        guard now.timeIntervalSince(lastEndSet) > 1 else { return }
        lastEndSet = now
        Haptics.impact()
        if currentSet >= setCount {
            finished = true
            return
        }
        currentSet += 1
        zeroDate = now.addingTimeInterval(rest)
        beepFired = false
        cueFired = false
        halfwayFired = false
        liveActivity.update(activityState())
    }

    private func tick() {
        guard !finished else { return }
        let now = Date()
        let remaining = remaining(at: now)
        // A stalled ticker (audio interruption, suspension) can jump the
        // clock past a cue's moment; latch those before the guards run, so
        // a resume never speaks a burst of stale cues — the player's
        // wake rule ("don't fire alerts whose moment already passed").
        if now.timeIntervalSince(lastTickAt) > 1 {
            if remaining <= rest / 2 { halfwayFired = true }
            if remaining <= VoiceCueRule.lead { cueFired = true }
        }
        lastTickAt = now
        // Same rule as the player's halfway cue; the rest picker starts at
        // 0:15, so the player's short-span merge case can't arise here.
        if halfwayCue, !halfwayFired, !beepFired,
           remaining <= rest / 2, rest > VoiceCueRule.minimumSpan {
            halfwayFired = true
            audio.speak("Halfway done.", interrupting: true)
        }
        // The heads-up, on the same shared rule as the player's.
        if fiveSecondsCue, !cueFired, !beepFired,
           remaining <= VoiceCueRule.lead, rest > VoiceCueRule.minimumSpan {
            cueFired = true
            // Interrupting for the same reason as the player's cues: the
            // heads-up is a clock, and it must not queue behind anything.
            audio.speak("5 seconds left.", interrupting: true)
        }
        guard !beepFired, remaining <= 0 else { return }
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
