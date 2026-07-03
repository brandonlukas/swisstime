import SwiftUI

/// One pool, two temperatures: the ambient hero strip (low fps) and the
/// fullscreen pool — current and past months alike stay alive; an old
/// pool never stops holding its water.
struct PondSceneView: View {
    enum Mode { case hero, live }

    let monthKey: MonthKey
    let mode: Mode
    private let scene: PondScene

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(monthKey: MonthKey, entries: [PondEntry], mode: Mode) {
        self.monthKey = monthKey
        self.mode = mode
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
                                    paused: scenePhase != .active)) { timeline in
                Canvas { context, size in
                    scene.draw(in: context, size: size,
                               time: timeline.date.timeIntervalSinceReferenceDate,
                               detail: mode == .hero ? .hero : .full)
                }
            }
        }
    }
}
