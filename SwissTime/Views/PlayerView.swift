import SwiftUI
import UIKit

/// Drives a level (waterline, progress bar) with two regimes: while the
/// target creeps with ordinary passage of time it is tracked EXACTLY —
/// linear and truthful — but a discontinuity (new step, skip, finish)
/// engages a spring so the level moves like something with mass instead
/// of snapping. A plain reference — advanced once per timeline frame,
/// its mutations must not invalidate views.
private final class LevelSpring {
    private var value: Double = 0
    private var velocity: Double = 0
    private var lastTime: Date?
    private var springing = false

    func advance(toward target: Double, at now: Date) -> Double {
        // First frame adopts the target outright — the player opens with
        // the level already where it belongs, no entrance animation.
        guard let last = lastTime else {
            lastTime = now
            value = target
            return value
        }
        // Clamped dt keeps the integration stable across dropped frames
        // and prevents a lurch when the timeline resumes after a pause.
        let dt = min(0.1, max(0, now.timeIntervalSince(last)))
        lastTime = now
        // Continuous motion moves well under this between frames; a gap
        // this large in one frame means the target jumped.
        if abs(target - value) > 0.02 { springing = true }
        guard springing else {
            value = target
            return value
        }
        // Slightly underdamped — the water settles with a small swell.
        // Fixed substeps keep the trajectory true when frames drop: one
        // big Euler step through a hitch would leap straight to the target
        // and read as a snap instead of a fill.
        var remaining = dt
        while remaining > 0 {
            let h = min(remaining, 1.0 / 120.0)
            remaining -= h
            velocity += (-90 * (value - target) - 14 * velocity) * h
            value += velocity * h
        }
        if abs(value - target) < 0.0005, abs(velocity) < 0.005 {
            value = target
            velocity = 0
            springing = false
        }
        return value
    }
}

struct PlayerView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var pond: PondStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine: PlayerEngine
    @State private var confirmEnd = false
    @State private var recordedCompletion = false
    @State private var waterSpring = LevelSpring()
    @State private var barSpring = LevelSpring()
    @State private var dragOffset: CGFloat = 0

    init(workout: Workout, startID: UUID? = nil) {
        _engine = StateObject(wrappedValue: PlayerEngine(workout: workout, startID: startID))
    }


    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    closeTapped()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(20)
            Divider()
            GeometryReader { geo in
                let bottomInset = geo.safeAreaInsets.bottom
                let fullHeight = geo.size.height + bottomInset
                // Each moving piece runs its own clock, so the static chrome
                // (cards, shadows, grain) isn't re-rendered 30 times a second.
                ZStack(alignment: .bottom) {
                    waterLayer(fullHeight: fullHeight)
                    GrainOverlay()
                    VStack(spacing: 0) {
                        breadcrumb
                            .padding(20)
                        Spacer(minLength: 0)
                        timerCard(side: max(1, min(geo.size.width - 84, 340)))
                        Spacer(minLength: 0)
                        controls
                            .padding(20)
                            .padding(.bottom, bottomInset)
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(width: geo.size.width, height: fullHeight)
                .ignoresSafeArea(edges: .bottom)
                // Double-tap a side to step, mirroring the transport bar:
                // right skips (until finished), left always goes back.
                // Buttons inside keep priority, so single taps are untouched.
                .onTapGesture(count: 2) { location in
                    if location.x > geo.size.width / 2 {
                        if engine.phase != .finished { engine.next() }
                    } else {
                        engine.previous()
                    }
                }
            }
        }
        // Once finished the page lifts with the pull and the screen behind
        // shows through (the cover backdrop is clear), like the pond. The
        // shadow hangs on the flattened opaque paper only — shadowing the
        // whole hierarchy would make every sublayer cast one, darkening
        // the entire screen.
        .background(
            PaperBackground()
                .compositingGroup()
                .shadow(color: .black.opacity(dragOffset > 0 ? 0.18 : 0), radius: 24, y: -8)
        )
        .offset(y: dragOffset)
        // Swipe left/right to skip between exercises, down to close.
        .gesture(
            DragGesture(minimumDistance: 40)
                .onChanged { value in
                    guard engine.phase == .finished,
                          value.translation.height > abs(value.translation.width) else { return }
                    dragOffset = max(0, value.translation.height)
                }
                .onEnded { value in
                    if dragOffset > 0 {
                        if dragOffset > 120 || value.predictedEndTranslation.height > 300 {
                            dismiss()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                dragOffset = 0
                            }
                        }
                        return
                    }
                    let dx = value.translation.width
                    let dy = value.translation.height
                    if abs(dx) > abs(dy) {
                        if dx < -60 {
                            engine.next()
                        } else if dx > 60 {
                            engine.previous()
                        }
                    } else if dy > 80 {
                        closeTapped()
                    }
                }
        )
        .presentationBackground(.clear)
        .onAppear {
            engine.start()
            store.markPlayed(engine.workout.id)
            UIApplication.shared.isIdleTimerDisabled = true
            // Debug: end the first set a few seconds in, so command-line
            // verification can screenshot the rest step without touch input.
            if ProcessInfo.processInfo.arguments.contains("-autoAdvanceOnce") {
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
            UIApplication.shared.isIdleTimerDisabled = false
        }
        // Finishing (not just starting) earns a creature in this month's pond.
        .onChange(of: engine.phase) { _, phase in
            guard phase == .finished, !recordedCompletion else { return }
            recordedCompletion = true
            pond.record(workout: engine.workout)
        }
        .sheet(isPresented: $confirmEnd) {
            ActionListSheet(actions: [
                ActionItem(title: "End workout", icon: "xmark", destructive: true, action: {
                    dismiss()
                }),
            ])
        }
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

    @ViewBuilder
    private var breadcrumb: some View {
        if engine.index < 0 {
            Text("Workout starting soon...")
                .font(.app(16))
                .frame(maxWidth: .infinity)
                .frame(height: 76)
                .paperCard(opacity: 0.92)
        } else if let step = engine.currentStep {
            VStack(spacing: 0) {
                if let circuitName = step.circuitName {
                    HStack(spacing: 12) {
                        Text("\(step.topNumber).")
                            .font(.app(15))
                            .frame(minWidth: 30, alignment: .leading)
                        Text(circuitName)
                            .font(.app(16, .medium))
                        Spacer(minLength: 8)
                        Text("\(step.loop)/\(step.loopCount)")
                            .font(.app(16))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.ink.opacity(0.04))
                }
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
            }
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
    /// water drains out.
    private func waterLayer(fullHeight: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: engine.phase == .paused)) { timeline in
            let now = timeline.date
            let target = engine.fraction(at: now)
            let level = fullHeight * waterSpring.advance(toward: target, at: now)
            WaterFill(color: engine.workout.palette.fill,
                      time: (now.timeIntervalSinceReferenceDate * 4).rounded() / 4)
                .equatable()
                .mask(alignment: .bottom) {
                    ZStack(alignment: .bottom) {
                        Color.clear
                        VStack(spacing: 0) {
                            LinearGradient(colors: [.clear, .black],
                                           startPoint: .top, endPoint: .bottom)
                                .frame(height: 24)
                            Color.black
                        }
                        .frame(height: max(0, level), alignment: .bottom)
                        .clipped()
                    }
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
                .shadow(color: Color.ink.opacity(0.08), radius: 10, y: 4)
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
            if engine.phase == .finished {
                VStack(spacing: 8) {
                    Text("Complete")
                        .font(.serifApp(20, .semibold))
                        .foregroundStyle(Color.ink)
                    EarnedCreatureView(colorIndex: engine.workout.colorIndex)
                    Text("Added to your \(MonthKey.current.monthName) pond")
                        .font(.app(13))
                        .foregroundStyle(Color.ink.opacity(0.55))
                }
            } else if let step = engine.currentStep, step.exercise.mode == .sets {
                VStack(spacing: 12) {
                    SetDots(step: step)
                    Text(setsCaption(step))
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

    /// "Exercise 3 of 7", plus the rest target while the water rises toward it.
    private func setsCaption(_ step: PlayerEngine.Step) -> String {
        var caption = "Exercise \(step.exerciseOrdinal) of \(engine.exerciseCount)"
        if step.kind == .rest, !step.exercise.restCountsDown {
            caption = "Target \(Format.mmss(step.exercise.restDuration)) · " + caption
        }
        return caption
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
        .buttonStyle(.plain)
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
        .buttonStyle(.plain)
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

/// The earned creature paddles across a little puddle on the finished card
/// and settles with a ripple. Runs its own clock — the player's TimelineView
/// is paused once the workout ends.
private struct EarnedCreatureView: View {
    let colorIndex: Int?
    @State private var appearedAt = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(appearedAt)
                let kind = Palette.creature(for: colorIndex)

                // A soft puddle to arrive in.
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 5))
                    layer.fill(
                        Path(ellipseIn: CGRect(x: 8, y: size.height / 2 - 17,
                                               width: size.width - 16, height: 34)),
                        with: .color(.pondWater.opacity(0.85)))
                }

                let k = min(1, t / 2.5)
                let ease = 1 - pow(1 - k, 3)
                let x = -20 + (size.width / 2 + 20) * ease
                let y = size.height / 2 + sin(t * 1.8) * 1.5
                let pos = CGPoint(x: x, y: y)

                if t > 2.4 {
                    let age = (t - 2.4).truncatingRemainder(dividingBy: 6)
                    if age < 2.2 {
                        let fraction = age / 2.2
                        let radius = 5 + 13 * fraction
                        context.stroke(
                            Path(ellipseIn: CGRect(x: pos.x - radius, y: pos.y - radius,
                                                   width: radius * 2, height: radius * 2)),
                            with: .color(.white.opacity(0.3 * (1 - fraction))),
                            lineWidth: 1)
                    }
                }

                if let style = PondCreatureArt.birdStyle(for: kind) {
                    PondCreatureArt.drawBird(
                        in: context, style: style, at: pos, heading: .zero,
                        wiggle: t * 2.4, wakeOpacity: 0.3 * (1 - k), scale: 0.9)
                } else {
                    PondCreatureArt.drawFish(
                        in: context, kind: kind, at: pos, heading: .zero,
                        tailWiggle: t * 3.2, opacity: 0.75, scale: 0.9)
                }
            }
        }
        .frame(width: 150, height: 56)
    }
}
