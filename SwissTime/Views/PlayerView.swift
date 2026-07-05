import SwiftUI
import UIKit

struct PlayerView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var pond: PondStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine: PlayerEngine
    @State private var confirmEnd = false
    @State private var recordedCompletion = false
    @State private var earnedEntryID: UUID?
    @State private var showingNote = false
    @State private var waterSpring = LevelSpring()
    @State private var barSpring = LevelSpring()
    @State private var waterSurface = WaterSurfaceModel()
    @State private var waterMotion = WaterMotion()
    @State private var dragOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var power = PowerState.shared
    @AppStorage(SettingsKey.waterTilt) private var waterTilt = true

    private var waterPolicy: WaterPolicy {
        WaterPolicy(lowPower: power.lowPower, reduceMotion: reduceMotion,
                    tiltSetting: waterTilt)
    }

    init(workout: Workout) {
        _engine = StateObject(wrappedValue: PlayerEngine(workout: workout))
    }


    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SheetCloseButton { closeTapped() }
                Spacer()
            }
            .padding(20)
            Divider()
            GeometryReader { geo in
                let bottomInset = geo.safeAreaInsets.bottom
                let fullHeight = geo.size.height + bottomInset
                // Each moving piece runs its own clock, so the static chrome
                // (cards, shadows, grain) isn't re-rendered 30 times a second.
                // The timer card is centered in the whole water area,
                // independent of the breadcrumb's height, so it never shifts
                // when the card above it grows or shrinks.
                ZStack {
                    waterLayer(fullHeight: fullHeight)
                    GrainOverlay()
                    edgeSteppers
                    timerCard(side: max(1, min(geo.size.width - 84, 340)))
                    VStack(spacing: 0) {
                        breadcrumb
                            .padding(20)
                        Spacer(minLength: 0)
                        Group {
                            if engine.phase == .finished {
                                // The transport is dead once the workout
                                // ends; its slot becomes the obvious way
                                // out. Undershooting is still covered —
                                // the left edge's double-tap steps back.
                                PrimaryButton(title: "Done",
                                              fill: engine.workout.palette.fill,
                                              textColor: engine.workout.palette.onFill) {
                                    dismiss()
                                }
                            } else {
                                controls
                            }
                        }
                        .padding(20)
                        .padding(.bottom, bottomInset)
                        .animation(.easeInOut(duration: 0.25),
                                   value: engine.phase == .finished)
                    }
                }
                .frame(width: geo.size.width, height: fullHeight)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        // Pull-to-dismiss exists only once the workout is complete;
        // mid-workout the X button (with its confirm) is the only exit.
        // A longer engage distance keeps stray touches near the edge
        // steppers from lifting the page.
        .pullToDismiss(offset: $dragOffset,
                       isEnabled: engine.phase == .finished,
                       minimumDistance: 40) { dismiss() }
        .onAppear {
            engine.start()
            store.markPlayed(engine.workout.id)
            ScreenSleep.hold()
            updateMotionSensor()
            // Debug: end the first set a few seconds in, so command-line
            // verification can screenshot the rest step without touch input.
            // Latched — it must not fire on workouts played by hand later
            // in the same debug-launched process.
            if ProcessInfo.processInfo.arguments.contains("-autoAdvanceOnce"),
               !DebugLaunch.didAutoAdvance {
                DebugLaunch.didAutoAdvance = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                    engine.next()
                }
            }
            if ProcessInfo.processInfo.arguments.contains("-playerPulled") {
                dragOffset = 480
            }
        }
        .onDisappear {
            engine.stopAndTearDown()
            ScreenSleep.release()
            waterMotion.stop()
        }
        // The tilt sensor runs only while someone could see it: not
        // backgrounded/locked (30 Hz motion for a 45-minute locked-screen
        // workout is pure battery), not in Low Power Mode, not finished.
        .onChange(of: scenePhase) { updateMotionSensor() }
        .onChange(of: power.lowPower) { updateMotionSensor() }
        .onChange(of: engine.phase) { updateMotionSensor() }
        .onChange(of: waterTilt) { updateMotionSensor() }
        // Finishing (not just starting) earns a toy in this month's pool.
        .onChange(of: engine.phase) { _, phase in
            guard phase == .finished, !recordedCompletion else { return }
            recordedCompletion = true
            earnedEntryID = pond.record(workout: engine.workout)
        }
        .sheet(isPresented: $showingNote) {
            if let id = earnedEntryID {
                NoteFormView(initial: pond.note(for: id)) { pond.setNote($0, for: id) }
            }
        }
        .sheet(isPresented: $confirmEnd) {
            ActionListSheet(actions: [
                ActionItem(title: "End workout", icon: "xmark", destructive: true, action: {
                    dismiss()
                }),
            ])
        }
    }

    private func updateMotionSensor() {
        let wanted = waterPolicy.tiltEnabled && scenePhase == .active
            && engine.phase != .finished
        if wanted { waterMotion.start() } else { waterMotion.stop() }
    }

    /// Closing mid-workout pauses and asks; a finished workout just closes.
    private func closeTapped() {
        if engine.phase == .finished {
            dismiss()
            return
        }
        if engine.phase == .running || engine.phase == .countdown {
            engine.togglePause()
        }
        confirmEnd = true
    }

    // MARK: - Pieces

    /// Double-tap the screen's FAR edges to step — right skips, left rewinds.
    /// Narrow zones, like the system back-swipe: stepping stays a deliberate
    /// reach for the rim, not something a stray mid-screen tap can trigger.
    /// They sit behind the cards, so no recognizer hangs over the transport
    /// buttons waiting to rule out a second tap — button taps stay instant.
    private var edgeSteppers: some View {
        HStack {
            Color.clear
                .frame(width: 56)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { engine.previous() }
            Spacer(minLength: 0)
            Color.clear
                .frame(width: 56)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    if engine.phase != .finished { engine.next() }
                }
        }
    }

    @ViewBuilder
    private var breadcrumb: some View {
        if engine.index < 0 {
            Text("Workout starting soon...")
                .font(.app(16))
                .frame(maxWidth: .infinity)
                .frame(height: 76)
                .paperCard(opacity: 0.92)
        } else if let step = engine.currentStep {
            HStack(spacing: 12) {
                Text(step.label)
                    .font(.app(15))
                    .frame(minWidth: 30, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    Text(step.exercise.name)
                        .font(.app(16, .medium))
                    if !step.exercise.instructions.isEmpty {
                        Text(step.exercise.instructions)
                            .font(.app(15))
                            .foregroundStyle(Color.ink.opacity(0.55))
                    }
                }
                Spacer(minLength: 8)
                Group {
                    switch step.kind {
                    case .rest:
                        Text("Rest")
                    case .work where step.exercise.mode == .sets:
                        Text("Set \(step.set)/\(step.setCount)")
                    case .work:
                        Text(Format.mmss(step.exercise.duration))
                    }
                }
                .font(.app(16))
                .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .paperCard(opacity: 0.92)
        }
    }

    private var timelinesPaused: Bool {
        engine.phase == .paused || engine.phase == .finished
    }

    /// One 30fps clock drives the waterline mask every frame; the texture's
    /// drift time is quantized to 4Hz and the view marked equatable, so the
    /// expensive blurred layer still re-renders only a few times a second.
    /// (A TimelineView nested inside .mask doesn't reliably drive updates —
    /// the waterline was moving at the slow texture rate, which read as a
    /// delay-then-jump on step transitions.) Not paused on finish so the
    /// water drains out. The surface itself is alive: level from the
    /// spring, slope from gravity, chop from jumps — a crest stroke over
    /// the mask makes the line read as water, not a clip edge.
    private func waterLayer(fullHeight: CGFloat) -> some View {
        // WaterPolicy decides how hard the water works (Low Power halves the
        // clock and texture beat; Reduce Motion flattens the surface) — the
        // level stays truthful either way.
        let policy = waterPolicy
        return TimelineView(.animation(minimumInterval: 1.0 / policy.fps,
                                       paused: engine.phase == .paused)) { timeline in
            let now = timeline.date
            let time = now.timeIntervalSinceReferenceDate
            let target = engine.fraction(at: now)
            let level = fullHeight * waterSpring.advance(toward: target, at: now)
            let surface = waterSurface.advance(
                targetFraction: target,
                gravitySlope: policy.tiltEnabled ? waterMotion.slope : 0,
                at: now, calm: policy.calm)
            let ripple = policy.rippleAmp
            ZStack {
                WaterFill(color: engine.workout.palette.fill,
                          time: (time * policy.textureBeat).rounded() / policy.textureBeat)
                    .equatable()
                    .mask {
                        WaterSurfaceShape(level: level, slope: surface.slope,
                                          chop: surface.chop, time: time,
                                          rippleAmp: ripple)
                    }
                WaterSurfaceCrest(level: level, surface: surface, time: time,
                                  rippleAmp: ripple)
            }
        }
    }

    /// Card chrome stays outside the timeline: the shadowed paper renders
    /// once, only the numerals and captions inside tick at 30fps.
    private func timerCard(side: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.paperCardFill.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.ink.opacity(0.06), lineWidth: 0.5)
                )
                .shadow(color: Color.shade.opacity(0.08), radius: 10, y: 4)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                    paused: timelinesPaused)) { timeline in
                timerContent(now: timeline.date)
            }
        }
        .frame(width: side, height: side)
    }

    private func timerContent(now: Date) -> some View {
        let display = engine.displayTime(at: now)
        let centiseconds = Int(display * 100)
        let minutes = centiseconds / 6000
        let seconds = (centiseconds / 100) % 60
        let fraction = centiseconds % 100
        return VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%d:%02d", minutes, seconds))
                    .font(.app(64, .medium))
                    .monospacedDigit()
                Text(String(format: ".%02d", fraction))
                    .font(.app(24, .medium))
                    .monospacedDigit()
            }
            // Gated on the recorded entry, not just the phase: the entry
            // lands one frame after the phase flips, and rendering before
            // it exists would flash the non-gilded variant on lucky rolls.
            if engine.phase == .finished, let entryID = earnedEntryID {
                VStack(spacing: 8) {
                    let shiny = pond.isShiny(entryID)
                    Text("Complete")
                        .display(15)
                        .foregroundStyle(Color.ink)
                    EarnedToyView(colorIndex: engine.workout.colorIndex, shiny: shiny)
                    EarnedCaption(toy: engine.workout.palette.toy, shiny: shiny)
                    Button {
                        showingNote = true
                    } label: {
                        Text(pond.note(for: entryID).isEmpty
                             ? "Add a note" : "Edit note")
                            .font(.app(13, .medium))
                            .underline()
                            .foregroundStyle(Color.ink.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }
            } else if let step = engine.currentStep, step.exercise.mode == .sets {
                VStack(spacing: 12) {
                    SetDots(step: step)
                    Text("Exercise \(step.number) of \(engine.exerciseCount)")
                        .font(.app(13))
                        .monospacedDigit()
                        .foregroundStyle(Color.ink.opacity(0.55))
                    if engine.phase == .paused {
                        pausedLabel
                    } else {
                        setActionButton(step)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    if engine.steps.count > 1, !engine.hasUntimedSteps {
                        Text("\(Format.mmss(engine.totalRemaining(at: now))) left")
                            .font(.app(14))
                            .monospacedDigit()
                            .foregroundStyle(Color.ink.opacity(0.55))
                    }
                    if engine.phase == .paused {
                        pausedLabel
                    }
                }
            }
        }
    }

    private var pausedLabel: some View {
        Text("PAUSED")
            .font(.app(13, .medium))
            .kerning(2.5)
            .foregroundStyle(Color.ink.opacity(0.55))
    }

    /// The big tap between sets: end the untimed set, or cut rest short.
    private func setActionButton(_ step: PlayerEngine.Step) -> some View {
        Button {
            engine.next()
        } label: {
            Text(step.kind == .work ? "End set \(step.set)" : "Start set \(step.set + 1)")
                .font(.app(16, .medium))
                .foregroundStyle(engine.workout.palette.onFill)
                .padding(.horizontal, 28)
                .frame(height: 46)
                .inkButton(engine.workout.palette.fill)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var controls: some View {
        HStack {
            controlButton("backward.end", enabled: true) {
                engine.previous()
            }
            Spacer()
            controlButton(
                engine.phase == .running || engine.phase == .countdown ? "pause" : "play",
                enabled: engine.phase != .finished
            ) {
                engine.togglePause()
            }
            Spacer()
            controlButton("forward.end", enabled: engine.phase != .finished) {
                engine.next()
            }
        }
        .padding(.horizontal, 32)
        .frame(height: 64)
        .paperCard(opacity: 0.92)
        .overlay(alignment: .topLeading) {
            // Springs toward the overall fraction, so skips and step changes
            // glide instead of jumping. Not paused on finish so it can land.
            GeometryReader { geo in
                TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                        paused: engine.phase == .paused)) { timeline in
                    Rectangle()
                        .fill(Color.ink)
                        .frame(width: max(0, geo.size.width * barSpring.advance(
                            toward: engine.overallFraction(at: timeline.date),
                            at: timeline.date)), height: 3)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func controlButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(Color.primary.opacity(enabled ? 1 : 0.3))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!enabled)
    }
}

/// One dot per set: filled when done, ringed while underway, faint ahead.
/// During rest the just-finished set reads as done.
private struct SetDots: View {
    let step: PlayerEngine.Step

    var body: some View {
        HStack(spacing: 9) {
            ForEach(1...step.setCount, id: \.self) { set in
                let done = set < step.set || (set == step.set && step.kind == .rest)
                let current = set == step.set && step.kind == .work
                Circle()
                    .fill(done ? Color.ink : Color.ink.opacity(current ? 0 : 0.15))
                    .overlay {
                        if current {
                            Circle().stroke(Color.ink, lineWidth: 1.5)
                        }
                    }
                    .frame(width: 10, height: 10)
            }
        }
    }
}
