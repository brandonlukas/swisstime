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

    init(monthKey: MonthKey, entries: [PondEntry], mode: Mode, paused: Bool = false) {
        self.monthKey = monthKey
        self.mode = mode
        self.paused = paused
        self.scene = PondScene(monthKey: monthKey, entries: entries)
    }

    var body: some View {
        if reduceMotion {
            // A single still pose, stable per month.
            Canvas { context, size in
                scene.draw(in: context, size: size,
                           time: Double(monthKey.seed % 997),
                           detail: mode == .hero ? .hero : .full)
            }
        } else {
            TimelineView(.animation(minimumInterval: mode == .hero ? 1.0 / 10.0 : 1.0 / 24.0,
                                    paused: scenePhase != .active || paused)) { timeline in
                Canvas { context, size in
                    scene.draw(in: context, size: size,
                               time: timeline.date.timeIntervalSinceReferenceDate,
                               detail: mode == .hero ? .hero : .full)
                }
            }
        }
    }
}
