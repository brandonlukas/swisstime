import SwiftUI
import UIKit

struct PlayerView: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine: PlayerEngine
    @State private var confirmEnd = false

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
                        Rectangle()
                            .fill(Color.swissRed)
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
        .background(SwissGlassBackground())
        .onAppear {
            engine.start()
            store.markPlayed(engine.workout.id)
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            engine.stopAndTearDown()
            UIApplication.shared.isIdleTimerDisabled = false
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
                .font(.swiss(16))
                .frame(maxWidth: .infinity)
                .frame(height: 76)
                .glassCard()
        } else if let step = engine.currentStep {
            VStack(spacing: 0) {
                if let circuitName = step.circuitName {
                    HStack(spacing: 12) {
                        Text("\(step.topNumber).")
                            .font(.swiss(15))
                            .frame(minWidth: 30, alignment: .leading)
                        Text(circuitName)
                            .font(.swiss(16, .medium))
                        Spacer(minLength: 8)
                        Text("\(step.loop)/\(step.loopCount)")
                            .font(.swiss(16))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.4))
                }
                HStack(spacing: 12) {
                    Text(step.label)
                        .font(.swiss(15))
                        .frame(minWidth: 30, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.exercise.name)
                            .font(.swiss(16, .medium))
                        if !step.exercise.instructions.isEmpty {
                            Text(step.exercise.instructions)
                                .font(.swiss(15))
                                .foregroundStyle(Color.black.opacity(0.5))
                        }
                    }
                    Spacer(minLength: 8)
                    Text(Format.mmss(step.exercise.duration))
                        .font(.swiss(16))
                        .monospacedDigit()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .glassCard()
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
                    .font(.swiss(64, .medium))
                    .monospacedDigit()
                Text(String(format: ".%02d", fraction))
                    .font(.swiss(24, .medium))
                    .monospacedDigit()
            }
            if engine.phase == .finished {
                Text("COMPLETE")
                    .font(.swiss(13, .medium))
                    .kerning(2.5)
                    .foregroundStyle(Color.black.opacity(0.5))
            } else {
                VStack(spacing: 10) {
                    if engine.steps.count > 1 {
                        Text("\(Format.mmss(engine.totalRemaining(at: now))) left")
                            .font(.swiss(14))
                            .monospacedDigit()
                            .foregroundStyle(Color.black.opacity(0.5))
                    }
                    if engine.phase == .paused {
                        Text("PAUSED")
                            .font(.swiss(13, .medium))
                            .kerning(2.5)
                            .foregroundStyle(Color.black.opacity(0.5))
                    }
                }
            }
        }
        .frame(width: side, height: side)
        .glassCard()
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
        .glassCard()
        .overlay(alignment: .topLeading) {
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.black)
                    .frame(width: geo.size.width * engine.overallFraction(at: now), height: 3)
            }
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
