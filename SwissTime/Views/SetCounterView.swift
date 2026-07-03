import SwiftUI
import UIKit

/// The Sets tab: a freestanding rest clock for untimed workouts. Pick sets
/// and rest once (remembered between launches), then the whole session is
/// one button: Lap ends a set and fills the clock with your rest, the water
/// drains as it counts down, a single beep marks zero, and the clock keeps
/// counting into the negative until the next Lap. The last Lap drops you
/// back here. No toy — toys are earned by workouts.
struct SetCounterView: View {
    @AppStorage("setCounter.sets") private var sets = 4
    @AppStorage("setCounter.rest") private var rest: TimeInterval = 90
    @AppStorage("setCounter.fiveSeconds") private var fiveSeconds = true
    /// Held in plain @State — the running child observes it; this view only
    /// cares whether one exists.
    @State private var engine: SetCounterEngine?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Sets")
                    .display(26)
                    .padding(.bottom, 14)
                InkRule()
            }
            .padding(20)
            .padding(.top, 12)
            if let engine {
                SetCounterRunView(engine: engine, onDone: stop)
            } else {
                configView
            }
        }
        .background(PaperBackground())
        .preferredColorScheme(.light)
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-autoStartSets"),
               !DebugLaunch.didAutoStartSets {
                DebugLaunch.didAutoStartSets = true
                // Explicit values, so the debug run doesn't overwrite the
                // remembered settings.
                let engine = start(setCount: 3, restDuration: 15,
                                   fiveSecondsCue: true)
                // End the first set a few seconds in, so command-line
                // verification can screenshot the rest countdown without
                // touch input. Scoped to THIS auto-started session — wired
                // into start() it would also fire on sessions the user
                // starts by hand in a debug-launched process.
                if ProcessInfo.processInfo.arguments.contains("-autoAdvanceOnce") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak engine] in
                        engine?.endSet()
                    }
                }
            }
        }
    }

    /// A fixed page, not a scroll view — four elements the user can't add
    /// to have nowhere to scroll.
    private var configView: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Count your sets and time your rest — company for workouts you run yourself.")
                .font(.app(15))
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                PickerField(label: "Sets", options: Array(1...12),
                            display: { "\($0)" }, selection: $sets)
                PickerField(label: "Rest between sets", options: Presets.restDurations,
                            display: { Format.mmss($0) }, selection: $rest)
            }
            Text("Tap Lap when you finish a set — the water fills with your rest, one beep marks zero, and the clock keeps counting past it.")
                .font(.app(14))
                .foregroundStyle(.secondary)
            CheckboxRow(title: "Announce 5s left", isOn: $fiveSeconds)
            PrimaryButton(title: "Start") {
                start(setCount: sets, restDuration: rest,
                      fiveSecondsCue: fiveSeconds)
            }
            .padding(.top, 8)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    @discardableResult
    private func start(setCount: Int, restDuration: TimeInterval,
                       fiveSecondsCue: Bool) -> SetCounterEngine {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let engine = SetCounterEngine(setCount: setCount, rest: restDuration,
                                      fiveSecondsCue: fiveSecondsCue)
        engine.start()
        ScreenSleep.hold()
        self.engine = engine
        return engine
    }

    private func stop() {
        engine?.stopAndTearDown()
        engine = nil
        ScreenSleep.release()
    }
}

/// The running counter, laid out like a stopwatch: bare numerals over the
/// page, set dots beneath, and two round buttons. A child view so the
/// engine can be observed — the parent holds it optionally in @State.
private struct SetCounterRunView: View {
    @ObservedObject var engine: SetCounterEngine
    let onDone: () -> Void
    @State private var waterSpring = LevelSpring()
    @State private var waterSurface = WaterSurfaceModel()
    @State private var waterMotion = WaterMotion()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            // The tab bar floats over the page, so the water runs past it to
            // the physical bottom of the screen; readout and buttons stay in
            // the visible area above.
            let bottomInset = geo.safeAreaInsets.bottom
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let now = timeline.date
                let time = now.timeIntervalSinceReferenceDate
                let fullHeight = geo.size.height + bottomInset
                let target = engine.fraction(at: now)
                let level = fullHeight * waterSpring.advance(toward: target, at: now)
                let surface = waterSurface.advance(
                    targetFraction: target,
                    gravitySlope: reduceMotion ? 0 : waterMotion.slope,
                    at: now)
                let ripple: CGFloat = reduceMotion ? 0 : 1.6
                ZStack {
                    // The readout is drawn twice — ink on the dry page, a
                    // white copy masked to the same waterline as the water —
                    // so the numerals stay legible as the level passes
                    // through them, with no card in the way.
                    readout(at: now)
                        .foregroundStyle(Color.ink)
                    // Full-size frame first: the mask is sized to the view
                    // it clips, and the waterline only lines up if both are
                    // measured against the same space. This copy lives in
                    // the visible area, whose bottom sits `bottomInset`
                    // above the water's — hence the shorter mask.
                    readout(at: now)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .foregroundStyle(.white)
                        .mask {
                            WaterSurfaceShape(level: level - bottomInset,
                                              slope: surface.slope,
                                              chop: surface.chop, time: time,
                                              rippleAmp: ripple)
                        }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .background {
                    ZStack {
                        WaterFill(color: .poolWater, time: (time * 4).rounded() / 4)
                            .equatable()
                            .mask {
                                WaterSurfaceShape(level: level, slope: surface.slope,
                                                  chop: surface.chop, time: time,
                                                  rippleAmp: ripple)
                            }
                        WaterSurfaceCrest(level: level, surface: surface,
                                          time: time, rippleAmp: ripple)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .overlay(alignment: .bottom) {
                buttons
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            if !reduceMotion { waterMotion.start() }
        }
        .onDisappear {
            waterMotion.stop()
        }
        .onChange(of: engine.finished) { _, finished in
            if finished { onDone() }
        }
    }

    /// Numerals, dots, and the set caption — everything that must flip
    /// color at the waterline.
    /// "0:14.83" counting down, then "-0:05.20" past zero.
    private func readout(at now: Date) -> some View {
        let remaining = engine.remaining(at: now)
        let centiseconds = Int((abs(remaining) * 100).rounded(.down))
        let sign = remaining < 0 ? "-" : ""
        return VStack(spacing: 22) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(sign + String(format: "%d:%02d",
                                   centiseconds / 6000, (centiseconds / 100) % 60))
                    .font(.app(88, .light))
                Text(String(format: ".%02d", centiseconds % 100))
                    .font(.app(34, .light))
            }
            .monospacedDigit()
            CounterDots(total: engine.setCount, current: engine.currentSet)
            Text("Set \(engine.currentSet) of \(engine.setCount)")
                .font(.app(15))
                .opacity(0.6)
        }
        .offset(y: -56)
    }

    /// Stopwatch corners: End to bail out, Lap to finish a set — Done once
    /// the final set is underway. End needs no confirm: unlike quitting a
    /// workout mid-sequence, a counter holds no progress worth protecting.
    private var buttons: some View {
        HStack {
            circleButton("End", filled: false, action: onDone)
            Spacer()
            circleButton(engine.currentSet == engine.setCount ? "Done" : "Lap",
                         filled: true) { engine.endSet() }
        }
    }

    private func circleButton(_ title: String, filled: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.app(filled ? 18 : 17, filled ? .medium : .regular))
                .foregroundStyle(filled ? .white : Color.ink)
                .frame(width: 84, height: 84)
                .background(Circle().fill(filled ? Color.ink : Color.paperCardFill.opacity(0.92)))
                .overlay(Circle().stroke(Color.ink.opacity(filled ? 0 : 0.1), lineWidth: 1))
                .shadow(color: Color.ink.opacity(filled ? 0.15 : 0.08), radius: 8, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// One dot per set: filled when ended, ringed for the set underway (and the
/// rest before it), faint ahead. Drawn with the inherited foreground style
/// so the waterline can recolor it.
private struct CounterDots: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 9) {
            ForEach(1...total, id: \.self) { set in
                Circle()
                    .fill(.foreground)
                    .opacity(set < current ? 1 : 0)
                    .overlay {
                        Circle()
                            .stroke(.foreground, lineWidth: 1.5)
                            .opacity(set == current ? 1 : set < current ? 0 : 0.25)
                    }
                    .frame(width: 10, height: 10)
            }
        }
    }
}
