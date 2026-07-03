import SwiftUI
import UIKit

/// The Sets tab: a freestanding rest clock for untimed workouts. Pick sets
/// and rest once (remembered between launches), then the whole session is
/// one button: Lap ends a set and fills the clock with your rest, the water
/// drains as it counts down, a single beep marks zero, and the clock keeps
/// counting into the negative until the next Lap. The last Lap drops you
/// back here. No creature — creatures are earned by workouts.
struct SetCounterView: View {
    @AppStorage("setCounter.sets") private var sets = 4
    @AppStorage("setCounter.rest") private var rest: TimeInterval = 90
    /// Held in plain @State — the running child observes it; this view only
    /// cares whether one exists.
    @State private var engine: SetCounterEngine?

    private let restOptions: [TimeInterval] = [15, 20, 30, 45, 60, 75, 90,
                                               120, 150, 180, 240, 300]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Sets")
                    .font(.serifApp(32, .bold))
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
                let engine = start(setCount: 3, restDuration: 15)
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

    private var configView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Count your sets and time your rest — company for workouts you run yourself.")
                    .font(.app(15))
                    .foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 12) {
                    PickerField(label: "Sets", options: Array(1...12),
                                display: { "\($0)" }, selection: $sets)
                    PickerField(label: "Rest between sets", options: restOptions,
                                display: { Format.mmss($0) }, selection: $rest)
                }
                Text("Tap Lap when you finish a set — the water fills with your rest, one beep marks zero, and the clock keeps counting past it.")
                    .font(.app(14))
                    .foregroundStyle(.secondary)
                Button {
                    start(setCount: sets, restDuration: rest)
                } label: {
                    Text("Start")
                        .font(.app(17, .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .inkButton(.ink)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    @discardableResult
    private func start(setCount: Int, restDuration: TimeInterval) -> SetCounterEngine {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let engine = SetCounterEngine(setCount: setCount, rest: restDuration)
        engine.start()
        UIApplication.shared.isIdleTimerDisabled = true
        self.engine = engine
        return engine
    }

    private func stop() {
        engine?.stopAndTearDown()
        engine = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }
}

/// The running counter, laid out like a stopwatch: bare numerals over the
/// page, set dots beneath, and two round buttons. A child view so the
/// engine can be observed — the parent holds it optionally in @State.
private struct SetCounterRunView: View {
    @ObservedObject var engine: SetCounterEngine
    let onDone: () -> Void
    @State private var confirmEnd = false
    @State private var waterSpring = LevelSpring()

    var body: some View {
        GeometryReader { geo in
            // The tab bar floats over the page, so the water runs past it to
            // the physical bottom of the screen; readout and buttons stay in
            // the visible area above.
            let bottomInset = geo.safeAreaInsets.bottom
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let now = timeline.date
                let fullHeight = geo.size.height + bottomInset
                let level = fullHeight * waterSpring.advance(
                    toward: engine.fraction(at: now), at: now)
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
                        .mask(alignment: .bottom) { waterMask(level: level - bottomInset) }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .background {
                    waterLayer(level: level, now: now)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .overlay(alignment: .bottom) {
                buttons
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
            }
        }
        .onChange(of: engine.finished) { _, finished in
            if finished { onDone() }
        }
        .sheet(isPresented: $confirmEnd) {
            ActionListSheet(actions: [
                ActionItem(title: "End sets", icon: "xmark", destructive: true,
                           action: onDone),
            ])
        }
    }

    private func waterLayer(level: CGFloat, now: Date) -> some View {
        WaterFill(color: .pondWater,
                  time: (now.timeIntervalSinceReferenceDate * 4).rounded() / 4)
            .equatable()
            .mask(alignment: .bottom) { waterMask(level: level) }
    }

    /// The shared waterline: bottom-anchored, soft top edge.
    private func waterMask(level: CGFloat) -> some View {
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
    /// the final set is underway.
    private var buttons: some View {
        HStack {
            Button {
                confirmEnd = true
            } label: {
                Text("End")
                    .font(.app(17))
                    .foregroundStyle(Color.ink)
                    .frame(width: 84, height: 84)
                    .background(Circle().fill(Color.paperCardFill.opacity(0.92)))
                    .overlay(Circle().stroke(Color.ink.opacity(0.1), lineWidth: 1))
                    .shadow(color: Color.ink.opacity(0.08), radius: 8, y: 3)
            }
            .buttonStyle(PressableButtonStyle())
            Spacer()
            Button {
                engine.endSet()
            } label: {
                Text(engine.currentSet == engine.setCount ? "Done" : "Lap")
                    .font(.app(18, .medium))
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
                    .background(Circle().fill(Color.ink))
                    .shadow(color: Color.ink.opacity(0.15), radius: 8, y: 3)
            }
            .buttonStyle(PressableButtonStyle())
        }
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
