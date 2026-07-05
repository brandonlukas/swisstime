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
    @AppStorage("setCounter.halfway") private var halfway = false
    @AppStorage("setCounter.fiveSeconds") private var fiveSeconds = true
    @AppStorage(SettingsKey.voiceCues) private var voiceCues = true
    /// Held in plain @State — the running child observes it; this view only
    /// cares whether one exists.
    @State private var engine: SetCounterEngine?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(title: "Sets")
                .padding(20)
                .padding(.top, 12)
            if let engine {
                SetCounterRunView(engine: engine, onDone: stop)
            } else {
                configView
            }
        }
        .background(PaperBackground())
        // The launcher deep link: notification when this tab is live,
        // latch when the cold launch builds it a beat after the URL.
        .onReceive(NotificationCenter.default.publisher(for: DeepLink.startSets)) { _ in
            consumePendingStart()
        }
        .onAppear {
            consumePendingStart()
            if ProcessInfo.processInfo.arguments.contains("-autoStartSets"),
               !DebugLaunch.didAutoStartSets {
                DebugLaunch.didAutoStartSets = true
                // Explicit values, so the debug run doesn't overwrite the
                // remembered settings.
                let engine = start(setCount: 3, restDuration: 15,
                                   halfwayCue: true, fiveSecondsCue: true)
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

    /// Reads as a fixed page — the content can't grow — but scrolls if it
    /// must (short devices, accessibility text sizes), so Start is always
    /// reachable. basedOnSize keeps the fixed feel everywhere it fits.
    private var configView: some View {
        ScrollView {
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
                VStack(alignment: .leading, spacing: 10) {
                    CheckboxRow(title: "Announce halfway", isOn: $halfway)
                        .allowsHitTesting(voiceCues)
                        .opacity(voiceCues ? 1 : 0.4)
                    CheckboxRow(title: "Announce 5s left", isOn: $fiveSeconds)
                        .allowsHitTesting(voiceCues)
                        .opacity(voiceCues ? 1 : 0.4)
                    if !voiceCues {
                        // The checkbox routes through the master switch —
                        // a dead control must say who turned it off.
                        Text("Voice cues are off in Settings.")
                            .font(.app(13))
                            .foregroundStyle(.secondary)
                    }
                }
                PrimaryButton(title: "Start") {
                    start(setCount: sets, restDuration: rest,
                          halfwayCue: halfway, fiveSecondsCue: fiveSeconds)
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// A session launched from the lock screen or Control Center uses the
    /// remembered numbers — the whole point is zero configuration. A
    /// session already running is left alone, and a running WORKOUT wins
    /// outright: an accidental launcher press mid-workout must not beep
    /// over the player. The latch is consumed either way.
    private func consumePendingStart() {
        guard DeepLink.pendingSetsStart else { return }
        DeepLink.pendingSetsStart = false
        guard engine == nil, !PlayerEngine.isActive else { return }
        start(setCount: sets, restDuration: rest,
              halfwayCue: halfway, fiveSecondsCue: fiveSeconds)
    }

    @discardableResult
    private func start(setCount: Int, restDuration: TimeInterval,
                       halfwayCue: Bool, fiveSecondsCue: Bool) -> SetCounterEngine {
        Haptics.impact()
        let engine = SetCounterEngine(setCount: setCount, rest: restDuration,
                                      halfwayCue: halfwayCue,
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
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var power = PowerState.shared
    @AppStorage(SettingsKey.waterTilt) private var waterTilt = true

    private var waterPolicy: WaterPolicy {
        WaterPolicy(lowPower: power.lowPower, reduceMotion: reduceMotion,
                    tiltSetting: waterTilt)
    }

    var body: some View {
        GeometryReader { geo in
            // The tab bar floats over the page, so the water runs past it to
            // the physical bottom of the screen; readout and buttons stay in
            // the visible area above.
            let bottomInset = geo.safeAreaInsets.bottom
            let policy = waterPolicy
            TimelineView(.animation(minimumInterval: 1.0 / policy.fps)) { timeline in
                let now = timeline.date
                let time = now.timeIntervalSinceReferenceDate
                let fullHeight = geo.size.height + bottomInset
                let target = engine.fraction(at: now)
                let level = fullHeight * waterSpring.advance(toward: target, at: now)
                let surface = waterSurface.advance(
                    targetFraction: target,
                    gravitySlope: policy.tiltEnabled ? waterMotion.slope : 0,
                    at: now, calm: policy.calm)
                let ripple = policy.rippleAmp
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
                        WaterFill(color: .poolWater,
                                  time: (time * policy.textureBeat).rounded() / policy.textureBeat)
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
        .onAppear { updateMotionSensor() }
        .onDisappear { waterMotion.stop() }
        // The tilt sensor rests whenever nobody could see it move.
        .onChange(of: scenePhase) { updateMotionSensor() }
        .onChange(of: power.lowPower) { updateMotionSensor() }
        .onChange(of: waterTilt) { updateMotionSensor() }
        .onChange(of: engine.finished) { _, finished in
            if finished { onDone() }
        }
    }

    private func updateMotionSensor() {
        let wanted = waterPolicy.tiltEnabled && scenePhase == .active
        if wanted { waterMotion.start() } else { waterMotion.stop() }
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
                .foregroundStyle(filled ? Color.onInk : Color.ink)
                .frame(width: 84, height: 84)
                .background(Circle().fill(filled ? Color.ink : Color.paperCardFill.opacity(0.92)))
                .overlay(Circle().stroke(Color.ink.opacity(filled ? 0 : 0.1), lineWidth: 1))
                .shadow(color: Color.shade.opacity(filled ? 0.15 : 0.08), radius: 8, y: 3)
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
