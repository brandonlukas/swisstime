import SwiftUI

/// One pool, two temperatures: the ambient hero strip (low fps) and the
/// fullscreen pool — current and past months alike stay alive; an old
/// pool never stops holding its water.
struct PondSceneView: View {
    enum Mode { case hero, live }

    let monthKey: MonthKey
    let mode: Mode
    /// Offscreen pools (a covered hero, a non-visible month page) pause
    /// their clocks — the paged TabView keeps neighbors alive, and there's
    /// no reason to animate water nobody can see.
    let paused: Bool
    private let scene: PondScene

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var power = PowerState.shared

    init(monthKey: MonthKey, entries: [PondEntry], mode: Mode, paused: Bool = false,
         newIDs: Set<UUID> = []) {
        self.monthKey = monthKey
        self.mode = mode
        self.paused = paused
        self.scene = PondScene(monthKey: monthKey, entries: entries, newIDs: newIDs)
    }

    var body: some View {
        if reduceMotion {
            // A single still pose, stable per month.
            Canvas { context, size in
                scene.draw(in: context, size: size,
                           time: Double(monthKey.seed % 997),
                           detail: mode == .hero ? .hero : .full,
                           night: colorScheme == .dark)
            }
        } else {
            // Low Power Mode calms the water: the pools tick at less than
            // half speed until the battery situation improves.
            let fps: Double = power.lowPower
                ? (mode == .hero ? 8 : 10)
                : (mode == .hero ? 20 : 24)
            TimelineView(.animation(minimumInterval: 1.0 / fps,
                                    paused: scenePhase != .active || paused)) { timeline in
                Canvas { context, size in
                    scene.draw(in: context, size: size,
                               time: timeline.date.timeIntervalSinceReferenceDate,
                               detail: mode == .hero ? .hero : .full,
                               night: colorScheme == .dark)
                }
            }
        }
    }
}
