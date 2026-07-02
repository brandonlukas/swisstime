import Foundation
import UIKit

@MainActor
final class PlayerEngine: ObservableObject {
    enum Phase {
        case countdown, running, paused, finished
    }

    struct Step {
        let exercise: Exercise
        let topNumber: Int
        let subNumber: Int?
        let circuitID: UUID?
        let circuitName: String?
        let loop: Int
        let loopCount: Int
        let isLoopStart: Bool

        var label: String {
            if let subNumber { return "\(topNumber).\(subNumber)." }
            return "\(topNumber)."
        }
    }

    let workout: Workout
    let steps: [Step]
    let countdownDuration: TimeInterval = 5

    @Published private(set) var phase: Phase = .countdown
    /// Index into `steps`; -1 while counting down.
    @Published private(set) var index: Int = -1
    @Published private(set) var endDate = Date()
    @Published private(set) var pausedRemaining: TimeInterval = 0

    private let audio = AudioManager()
    private let liveActivity = LiveActivityController()
    private let stepFeedback = UIImpactFeedbackGenerator(style: .medium)
    private var ticker: Timer?
    private var observers: [NSObjectProtocol] = []
    private var halfwayFired = false
    private var fiveSecondsFired = false
    /// First step to run — supports "play from here".
    private let startIndex: Int

    init(workout: Workout, startID: UUID? = nil) {
        self.workout = workout
        let steps = Self.makeSteps(workout)
        self.steps = steps
        if let startID {
            startIndex = steps.firstIndex {
                $0.exercise.id == startID || $0.circuitID == startID
            } ?? 0
        } else {
            startIndex = 0
        }
    }

    var currentStep: Step? {
        steps.indices.contains(index) ? steps[index] : nil
    }

    var currentDuration: TimeInterval {
        index < 0 ? countdownDuration : (currentStep?.exercise.duration ?? 1)
    }

    var totalDuration: TimeInterval {
        steps.reduce(0) { $0 + $1.exercise.duration }
    }

    func remaining(at date: Date) -> TimeInterval {
        switch phase {
        case .paused: return pausedRemaining
        case .finished: return 0
        default: return max(0, endDate.timeIntervalSince(date))
        }
    }

    /// Remaining fraction of the current step — the blue fill drains as time runs down.
    func fraction(at date: Date) -> Double {
        guard phase != .finished, currentDuration > 0 else { return 0 }
        return min(1, max(0, remaining(at: date) / currentDuration))
    }

    /// Elapsed fraction of the whole workout — drives the thin black bar.
    func overallFraction(at date: Date) -> Double {
        guard totalDuration > 0 else { return 0 }
        if phase == .finished { return 1 }
        guard index >= 0 else { return 0 }
        let completed = steps.prefix(index).reduce(0) { $0 + $1.exercise.duration }
        let elapsed = completed + (currentDuration - remaining(at: date))
        return min(1, max(0, elapsed / totalDuration))
    }

    /// Wall-clock time left in the whole workout.
    func totalRemaining(at date: Date) -> TimeInterval {
        totalDuration * (1 - overallFraction(at: date))
    }

    func start() {
        audio.start()
        stepFeedback.prepare()
        phase = .countdown
        index = -1
        endDate = Date().addingTimeInterval(countdownDuration)
        audio.speak("Workout starting soon.")
        liveActivity.start(workoutTitle: workout.title, state: activityState(
            name: "Starting soon", label: ""))
        subscribeToIntents()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(ticker!, forMode: .common)
    }

    func stopAndTearDown() {
        ticker?.invalidate()
        ticker = nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        liveActivity.end(phase == .finished ? activityState() : nil)
        audio.stop()
    }

    func togglePause() {
        switch phase {
        case .running, .countdown:
            pausedRemaining = remaining(at: Date())
            phase = .paused
            audio.setKeepAlive(false)
        case .paused:
            endDate = Date().addingTimeInterval(pausedRemaining)
            phase = index < 0 ? .countdown : .running
            audio.setKeepAlive(true)
        case .finished:
            return
        }
        liveActivity.update(activityState())
    }

    func next() {
        guard phase != .finished else { return }
        advance(to: index < 0 ? startIndex : index + 1)
    }

    func previous() {
        if phase == .finished {
            advance(to: steps.count - 1)
            return
        }
        let elapsed = currentDuration - remaining(at: Date())
        if elapsed > 2 || index <= -1 {
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
        if phase == .paused {
            pausedRemaining = currentDuration
        } else {
            endDate = Date().addingTimeInterval(currentDuration)
        }
        liveActivity.update(activityState())
    }

    /// `overshoot` is how far past the previous step's end we already are —
    /// nonzero after background throttling, so the timeline stays truthful.
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
            } else {
                endDate = Date().addingTimeInterval(countdownDuration)
            }
            liveActivity.update(activityState(name: "Starting soon", label: ""))
            return
        }
        let duration = steps[newIndex].exercise.duration
        if !wasPaused, overshoot >= duration {
            // This whole step elapsed while we were asleep; skip it silently.
            index = newIndex
            advance(to: newIndex + 1, overshoot: overshoot - duration)
            return
        }
        index = newIndex
        phase = wasPaused ? .paused : .running
        if wasPaused {
            pausedRemaining = duration
        } else {
            endDate = Date().addingTimeInterval(duration - overshoot)
            // Don't fire alerts whose moment already passed while asleep.
            let remainingNow = duration - overshoot
            if remainingNow <= duration / 2 { halfwayFired = true }
            if remainingNow <= 5 { fiveSecondsFired = true }
        }
        if wasFinished {
            audio.setKeepAlive(true)
        }
        liveActivity.update(activityState())
        announce(steps[newIndex])
    }

    private func announce(_ step: Step) {
        stepFeedback.impactOccurred()
        audio.playBeep()
        var parts: [String] = []
        if step.isLoopStart, let circuitName = step.circuitName {
            parts.append(step.loopCount > 1
                ? "\(circuitName), round \(step.loop) of \(step.loopCount)."
                : "\(circuitName).")
        }
        parts.append("\(step.exercise.name).")
        if !step.exercise.instructions.isEmpty {
            parts.append("\(step.exercise.instructions).")
        }
        // Interrupt any queued speech so rapid skipping never stacks announcements.
        audio.speak(parts.joined(separator: " "), interrupting: true)
    }

    private func finish() {
        phase = .finished
        index = steps.count - 1
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        audio.setKeepAlive(false)
        audio.playDone()
        audio.speak("Workout complete.", interrupting: true)
        liveActivity.update(activityState())
    }

    private func tick() {
        guard phase == .running || phase == .countdown else { return }
        let now = Date()
        let remaining = remaining(at: now)
        if phase == .running, let step = currentStep {
            if step.exercise.halfwayAlert, !halfwayFired, remaining <= step.exercise.duration / 2 {
                halfwayFired = true
                audio.speak("Halfway done.")
            }
            if step.exercise.fiveSecondsAlert, !fiveSecondsFired,
               remaining <= 5, step.exercise.duration > 10 {
                fiveSecondsFired = true
                audio.speak("5 seconds left.")
            }
        }
        if remaining <= 0 {
            advance(to: index < 0 ? startIndex : index + 1,
                    overshoot: max(0, endDate.distance(to: now)))
        }
    }

    private func activityState(name: String? = nil, label: String? = nil)
        -> WorkoutActivityAttributes.ContentState {
        .init(
            exerciseName: name ?? currentStep?.exercise.name ?? "",
            stepLabel: label ?? currentStep?.label ?? "",
            endDate: phase == .paused ? Date().addingTimeInterval(pausedRemaining) : endDate,
            paused: phase == .paused,
            pausedRemaining: pausedRemaining,
            stepIndex: max(0, index),
            stepCount: max(1, steps.count),
            finished: phase == .finished
        )
    }

    private static func makeSteps(_ workout: Workout) -> [Step] {
        var steps: [Step] = []
        for (topIndex, item) in workout.items.enumerated() {
            switch item {
            case .exercise(let exercise):
                steps.append(Step(exercise: exercise, topNumber: topIndex + 1, subNumber: nil,
                                  circuitID: nil, circuitName: nil,
                                  loop: 1, loopCount: 1, isLoopStart: false))
            case .circuit(let circuit):
                guard !circuit.exercises.isEmpty else { continue }
                for loop in 1...max(1, circuit.loops) {
                    for (subIndex, exercise) in circuit.exercises.enumerated() {
                        steps.append(Step(exercise: exercise, topNumber: topIndex + 1,
                                          subNumber: subIndex + 1, circuitID: circuit.id,
                                          circuitName: circuit.name,
                                          loop: loop, loopCount: max(1, circuit.loops),
                                          isLoopStart: subIndex == 0))
                    }
                }
            }
        }
        return steps
    }
}
