import SwiftUI

/// One pool, three temperatures: the ambient hero strip (low fps), the
/// fullscreen live pool, and frozen postcards of past months.
struct PondSceneView: View {
    enum Mode { case hero, live, frozen }

    let monthKey: MonthKey
    let mode: Mode
    private let scene: PondScene

    @Environment(\.scenePhase) private var scenePhase

    init(monthKey: MonthKey, entries: [PondEntry], mode: Mode) {
        self.monthKey = monthKey
        self.mode = mode
        self.scene = PondScene(monthKey: monthKey, entries: entries)
    }

    var body: some View {
        switch mode {
        case .frozen:
            // A single still pose, stable per month — no ongoing cost.
            Canvas { context, size in
                scene.draw(in: context, size: size,
                           time: Double(monthKey.seed % 997), detail: .full)
            }
        case .hero, .live:
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
