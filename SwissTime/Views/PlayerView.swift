import SwiftUI
import UIKit

struct PlayerView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var pond: PondStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine: PlayerEngine
    @State private var confirmEnd = false
    @State private var recordedCompletion = false

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
                TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                        paused: engine.phase == .paused || engine.phase == .finished)) { timeline in
                    let now = timeline.date
                    ZStack(alignment: .bottom) {
                        WaterFill(color: engine.workout.palette.fill,
                                  time: now.timeIntervalSinceReferenceDate)
                            .frame(height: fullHeight * engine.fraction(at: now))
                        GrainOverlay()
                        VStack(spacing: 0) {
                            breadcrumb
                                .padding(20)
                            Spacer(minLength: 0)
                            timerCard(now: now, side: min(geo.size.width - 84, 340))
                            Spacer(minLength: 0)
                            controls(now: now)
                                .padding(20)
                                .padding(.bottom, bottomInset)
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .frame(width: geo.size.width, height: fullHeight)
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .background(PaperBackground())
        // Swipe left/right to skip between exercises, down to close.
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
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
        .onAppear {
            engine.start()
            store.markPlayed(engine.workout.id)
            UIApplication.shared.isIdleTimerDisabled = true
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
                    Text(Format.mmss(step.exercise.duration))
                        .font(.app(16))
                        .monospacedDigit()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .paperCard(opacity: 0.92)
        }
    }

    private func timerCard(now: Date, side: CGFloat) -> some View {
        let remaining = engine.remaining(at: now)
        let centiseconds = Int(remaining * 100)
        let minutes = centiseconds / 6000
        let seconds = (centiseconds / 100) % 60
        let fraction = centiseconds % 100
        return VStack(spacing: 12) {
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
            } else {
                VStack(spacing: 10) {
                    if engine.steps.count > 1 {
                        Text("\(Format.mmss(engine.totalRemaining(at: now))) left")
                            .font(.app(14))
                            .monospacedDigit()
                            .foregroundStyle(Color.ink.opacity(0.55))
                    }
                    if engine.phase == .paused {
                        Text("PAUSED")
                            .font(.app(13, .medium))
                            .kerning(2.5)
                            .foregroundStyle(Color.ink.opacity(0.55))
                    }
                }
            }
        }
        .frame(width: side, height: side)
        .paperCard(24, opacity: 0.92)
    }

    private func controls(now: Date) -> some View {
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
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.ink)
                    .frame(width: geo.size.width * engine.overallFraction(at: now), height: 3)
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
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
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
