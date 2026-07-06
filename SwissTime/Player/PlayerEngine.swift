import Foundation
import UIKit

extension Notification.Name {
    /// Posted (synchronously, before the audio session spins up) when a
    /// player begins. The set counter yields on hearing it — two engines
    /// would fight over the Live Activity and the island's skip intent.
    static let playerEngineDidStart = Notification.Name("playerEngineDidStart")
}

@MainActor
final class PlayerEngine: ObservableObject {
    enum Phase {
        case countdown, running, paused, finished
    }

    struct Step {
        enum Kind { case work, rest }

        let exercise: Exercise
        let kind: Kind
        /// 1-based set this step belongs to; a rest follows the set it ends.
        let set: Int
        /// 1-based position of the exercise in the workout, shared by every
        /// set and rest of the same exercise.
        let number: Int

        var setCount: Int {
            exercise.mode == .sets ? max(1, exercise.sets) : 1
        }

        var label: String { "\(number)." }

        /// Fixed length for countdown steps; nil means the clock counts up
        /// (untimed set work — it ends when the user taps).
        var countdownDuration: TimeInterval? {
            switch kind {
            case .work:
                return exercise.mode == .interval ? exercise.duration : nil
            case .rest:
                return exercise.restDuration
            }
        }

        var countsUp: Bool { countdownDuration == nil }
    }

    let workout: Workout
    let steps: [Step]
    let countdownDuration: TimeInterval = 5
    /// Any count-up step switches overall progress from time-based to step-based.
    let hasUntimedSteps: Bool
    let exerciseCount: Int

    @Published private(set) var phase: Phase = .countdown
    /// Actively ticking — running or counting down, not paused or finished.
    var isRunning: Bool { phase == .running || phase == .countdown }
    /// Index into `steps`; -1 while counting down.
    @Published private(set) var index: Int = -1
    /// End of the current countdown step.
    @Published private(set) var endDate = Date()
    /// Start of the current step — the count-up clock's zero.
    @Published private(set) var startDate = Date()
    @Published private(set) var pausedRemaining: TimeInterval = 0
    @Published private(set) var pausedElapsed: TimeInterval = 0

    private let audio = AudioManager()
    private let liveActivity = LiveActivityController()
    private var ticker: Timer?
    private var observers: [NSObjectProtocol] = []
    private var halfwayFired = false
    private var fiveSecondsFired = false

    /// Sum of the timed steps — only meaningful for fully timed workouts.
    let totalDuration: TimeInterval
    /// `completedDurations[i]` is the summed duration of `steps[0..<i]` —
    /// precomputed once so `overallFraction` (polled every water frame for
    /// the whole workout) doesn't re-reduce the prefix from scratch.
    private let completedDurations: [TimeInterval]

    init(workout: Workout) {
        self.workout = workout
        let steps = Self.makeSteps(workout)
        self.steps = steps
        hasUntimedSteps = steps.contains { $0.countsUp }
        exerciseCount = steps.last?.number ?? 0
        var cumulative: [TimeInterval] = []
        cumulative.reserveCapacity(steps.count)
        var running: TimeInterval = 0
        for step in steps {
            cumulative.append(running)
            running += step.countdownDuration ?? 0
        }
        completedDurations = cumulative
        totalDuration = running
        // The water renders before onAppear calls start(); give the countdown
        // a truthful endDate so the pond opens full instead of empty.
        endDate = Date().addingTimeInterval(countdownDuration)
    }

    var currentStep: Step? {
        steps.indices.contains(index) ? steps[index] : nil
    }

    /// Whether the big clock counts up right now.
    var currentCountsUp: Bool {
        phase != .finished && index >= 0 && (currentStep?.countsUp ?? false)
    }

    private var currentCountdownDuration: TimeInterval? {
        index < 0 ? countdownDuration : currentStep?.countdownDuration
    }

    func remaining(at date: Date) -> TimeInterval {
        switch phase {
        case .paused: return pausedRemaining
        case .finished: return 0
        default: return max(0, endDate.timeIntervalSince(date))
        }
    }

    func elapsed(at date: Date) -> TimeInterval {
        switch phase {
        case .paused: return pausedElapsed
        case .finished: return 0
        default: return max(0, date.timeIntervalSince(startDate))
        }
    }

    /// What the big numerals show — counting down or up per step.
    func displayTime(at date: Date) -> TimeInterval {
        currentCountsUp ? elapsed(at: date) : remaining(at: date)
    }

    /// Drives the water: countdown steps (including the pre-workout
    /// countdown) drain as the share of time remaining; untimed set work
    /// is still water.
    func fraction(at date: Date) -> Double {
        guard phase != .finished else { return 0 }
        if let duration = currentCountdownDuration, duration > 0 {
            return min(1, max(0, remaining(at: date) / duration))
        }
        return 0
    }

    /// Elapsed fraction of the whole workout — drives the thin black bar.
    /// Step-based once any step is untimed, since wall-clock is unknowable.
    func overallFraction(at date: Date) -> Double {
        if phase == .finished { return 1 }
        guard index >= 0, !steps.isEmpty else { return 0 }
        if hasUntimedSteps {
            var inStep: Double = 0
            if let duration = currentCountdownDuration, duration > 0 {
                inStep = 1 - min(1, remaining(at: date) / duration)
            }
            return min(1, max(0, (Double(index) + inStep) / Double(steps.count)))
        }
        guard totalDuration > 0 else { return 0 }
        let completed = completedDurations[index]
        let duration = currentCountdownDuration ?? 0
        let elapsed = completed + (duration - remaining(at: date))
        return min(1, max(0, elapsed / totalDuration))
    }

    /// Wall-clock time left in the whole workout (fully timed workouts only).
    func totalRemaining(at date: Date) -> TimeInterval {
        totalDuration * (1 - overallFraction(at: date))
    }

    /// True from start() until teardown. The counter already yields when a
    /// player starts; this is the reverse signal — the Sets launchers
    /// consult it so an accidental Start Sets press can't beep over a
    /// running workout.
    static private(set) var isActive = false

    func start() {
        Self.isActive = true
        NotificationCenter.default.post(name: .playerEngineDidStart, object: self)
        audio.start()
        phase = .countdown
        index = -1
        endDate = Date().addingTimeInterval(countdownDuration)
        startDate = Date()
        audio.speak("Workout starting soon.")
        liveActivity.start(workoutTitle: workout.title, state: activityState(
            name: "Starting soon", label: ""))
        subscribeToIntents()
        // The timer fires on the main run loop; assumeIsolated calls tick()
        // directly instead of hopping through a Task every 50ms.
        let ticker = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(ticker, forMode: .common)
        self.ticker = ticker
    }

    func stopAndTearDown() {
        Self.isActive = false
        ticker?.invalidate()
        ticker = nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        liveActivity.end(phase == .finished ? activityState() : nil)
        audio.stop()
    }

    func togglePause() {
        guard phase != .finished else { return }
        Haptics.lightImpact()
        switch phase {
        case .running, .countdown:
            pausedRemaining = remaining(at: Date())
            pausedElapsed = elapsed(at: Date())
            phase = .paused
            audio.setKeepAlive(false)
        case .paused:
            endDate = Date().addingTimeInterval(pausedRemaining)
            startDate = Date().addingTimeInterval(-pausedElapsed)
            phase = index < 0 ? .countdown : .running
            audio.setKeepAlive(true)
        case .finished:
            return
        }
        liveActivity.update(activityState())
    }

    func next() {
        guard phase != .finished else { return }
        advance(to: index + 1)
    }

    func previous() {
        if phase == .finished {
            advance(to: steps.count - 1)
            return
        }
        let intoStep = currentCountsUp
            ? elapsed(at: Date())
            : (currentCountdownDuration ?? 0) - remaining(at: Date())
        if intoStep > 2 || index <= -1 {
            restartCurrent()
        } else {
            advance(to: index - 1)
        }
    }

    private func subscribeToIntents() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .playerTogglePause, object: nil,
                                            queue: .main) { [weak self] _ in
            Task { @MainActor in self?.togglePause() }
        })
        observers.append(center.addObserver(forName: .playerSkipStep, object: nil,
                                            queue: .main) { [weak self] _ in
            Task { @MainActor in self?.next() }
        })
    }

    private func restartCurrent() {
        halfwayFired = false
        fiveSecondsFired = false
        let duration = currentCountdownDuration ?? 0
        if phase == .paused {
            pausedRemaining = duration
            pausedElapsed = 0
        } else {
            endDate = Date().addingTimeInterval(duration)
            startDate = Date()
        }
        liveActivity.update(activityState())
    }

    /// `overshoot` is how far past the previous step's end we already are —
    /// nonzero after background throttling, so the timeline stays truthful.
    /// Count-up steps never end on their own, so overshoot only chains
    /// through countdown steps.
    private func advance(to newIndex: Int, overshoot: TimeInterval = 0) {
        halfwayFired = false
        fiveSecondsFired = false
        if newIndex >= steps.count {
            finish()
            return
        }
        let wasPaused = phase == .paused
        let wasFinished = phase == .finished
        if newIndex < 0 {
            index = -1
            phase = wasPaused ? .paused : .countdown
            if wasPaused {
                pausedRemaining = countdownDuration
                pausedElapsed = 0
            } else {
                endDate = Date().addingTimeInterval(countdownDuration)
                startDate = Date()
            }
            liveActivity.update(activityState(name: "Starting soon", label: ""))
            return
        }
        let step = steps[newIndex]
        if !wasPaused, let duration = step.countdownDuration, overshoot >= duration {
            // This whole step elapsed while we were asleep; skip it silently.
            index = newIndex
            advance(to: newIndex + 1, overshoot: overshoot - duration)
            return
        }
        index = newIndex
        phase = wasPaused ? .paused : .running
        if wasPaused {
            pausedRemaining = step.countdownDuration ?? 0
            pausedElapsed = 0
        } else {
            startDate = Date().addingTimeInterval(-overshoot)
            if let duration = step.countdownDuration {
                endDate = Date().addingTimeInterval(duration - overshoot)
                // Don't fire alerts whose moment already passed while asleep.
                let remainingNow = duration - overshoot
                if remainingNow <= duration / 2 { halfwayFired = true }
                if remainingNow <= VoiceCueRule.lead { fiveSecondsFired = true }
            }
        }
        if wasFinished {
            audio.setKeepAlive(true)
        }
        liveActivity.update(activityState())
        announce(step)
    }

    private func announce(_ step: Step) {
        // Through Haptics, not a raw generator — the Settings switch and
        // Low Power Mode must reach the player's buzzes too.
        Haptics.impact()
        audio.playBeep()
        var parts: [String] = []
        switch step.kind {
        case .rest:
            parts.append("Rest, \(Int(step.exercise.restDuration)) seconds.")
        case .work:
            if step.exercise.mode == .sets {
                if step.set == 1 {
                    parts.append("\(step.exercise.name).")
                    if let reps = step.exercise.reps {
                        parts.append("\(step.setCount) sets of \(reps).")
                    } else {
                        parts.append("\(step.setCount) sets.")
                    }
                    if !step.exercise.instructions.isEmpty {
                        parts.append("\(step.exercise.instructions).")
                    }
                } else {
                    parts.append("Set \(step.set) of \(step.setCount).")
                }
            } else {
                parts.append("\(step.exercise.name).")
                if !step.exercise.instructions.isEmpty {
                    parts.append("\(step.exercise.instructions).")
                }
            }
        }
        // Interrupt any queued speech so rapid skipping never stacks
        // announcements; the delay clears the 0.15s step beep — a beep the
        // sounds setting may have silenced, in which case speak on time.
        audio.speak(parts.joined(separator: " "), interrupting: true,
                    delay: AppSettings.sounds ? 0.4 : 0)
    }

    private func finish() {
        phase = .finished
        index = steps.count - 1
        Haptics.success()
        audio.setKeepAlive(false)
        audio.playDone()
        // The finish chime runs 0.74s; speak after it rings out — or right
        // away when the sounds setting silenced the chime.
        audio.speak("Workout complete.", interrupting: true,
                    delay: AppSettings.sounds ? 0.9 : 0)
        liveActivity.update(activityState())
    }

    private func tick() {
        guard isRunning else { return }
        let now = Date()
        // Untimed set work never auto-advances; the user ends it with a tap.
        if index >= 0, currentStep?.countsUp == true { return }
        let remaining = remaining(at: now)
        if phase == .running, let step = currentStep,
           let duration = step.countdownDuration {
            // On a step of ten seconds or less, the midpoint IS the
            // five-second mark — the two cues are the same moment. A
            // checked alert (either one) collapses into a single
            // "5 seconds left." there, because a checked box that says
            // nothing reads as broken. Below the speech lead itself
            // there's no moment left worth narrating.
            if step.kind == .work, duration <= VoiceCueRule.minimumSpan,
               duration > VoiceCueRule.lead,
               step.exercise.halfwayAlert || step.exercise.fiveSecondsAlert,
               !fiveSecondsFired, !halfwayFired, remaining <= duration / 2 {
                fiveSecondsFired = true
                halfwayFired = true
                // Cues are clocks, announcements are context: a timed cue
                // queued behind a long announcement plays LATE, and a late
                // clock is a lie. Cues cut in; context yields.
                audio.speak("5 seconds left.", interrupting: true)
            }
            if step.kind == .work, step.exercise.halfwayAlert,
               !halfwayFired, remaining <= duration / 2,
               duration > VoiceCueRule.minimumSpan {
                halfwayFired = true
                audio.speak("Halfway done.", interrupting: true)
            }
            // Rest always warns — it's the get-ready cue before the next set
            // auto-starts; timed work keeps its per-exercise setting.
            if step.kind == .rest || step.exercise.fiveSecondsAlert,
               !fiveSecondsFired, remaining <= VoiceCueRule.lead,
               duration > VoiceCueRule.minimumSpan {
                fiveSecondsFired = true
                audio.speak("5 seconds left.", interrupting: true)
            }
        }
        if remaining <= 0 {
            advance(to: index + 1, overshoot: max(0, endDate.distance(to: now)))
        }
    }

    private func activityState(name: String? = nil, label: String? = nil)
        -> WorkoutActivityAttributes.ContentState {
        let step = currentStep
        var exerciseName = name ?? step?.exercise.name ?? ""
        if name == nil, let step {
            switch step.kind {
            case .rest:
                exerciseName = "Rest · \(step.exercise.name)"
            case .work where step.exercise.mode == .sets:
                exerciseName = "\(step.exercise.name) · set \(step.set)/\(step.setCount)"
            default:
                break
            }
        }
        let countsUp = phase != .finished && index >= 0 && (step?.countsUp ?? false)
        return .init(
            exerciseName: exerciseName,
            stepLabel: label ?? step?.label ?? "",
            endDate: phase == .paused ? Date().addingTimeInterval(pausedRemaining) : endDate,
            paused: phase == .paused,
            pausedRemaining: countsUp ? pausedElapsed : pausedRemaining,
            stepIndex: max(0, (step?.number ?? 1) - 1),
            stepCount: max(1, exerciseCount),
            finished: phase == .finished,
            countsUp: countsUp,
            startDate: startDate
        )
    }

    private static func makeSteps(_ workout: Workout) -> [Step] {
        var steps: [Step] = []
        for (index, exercise) in workout.exercises.enumerated() {
            let setCount = exercise.mode == .sets ? max(1, exercise.sets) : 1
            for set in 1...setCount {
                steps.append(Step(exercise: exercise, kind: .work,
                                  set: set, number: index + 1))
                // No rest after the final set — the next exercise announces itself.
                if exercise.mode == .sets, set < setCount, exercise.restDuration > 0 {
                    steps.append(Step(exercise: exercise, kind: .rest,
                                      set: set, number: index + 1))
                }
            }
        }
        return steps
    }
}
