import SwiftUI

/// One pool, two temperatures: the ambient hero strip (low fps) and the
/// fullscreen pool — current and past months alike stay alive; an old
/// pool never stops holding its water.
struct PondSceneView: View {
    enum Mode { case hero, live }

    /// Scene layouts are pure functions of their inputs; the cache keeps
    /// parent re-renders (every frame of a pull-to-dismiss drag, times N
    /// month pages) from re-running the seeded placement loops.
    @MainActor
    final class SceneCache {
        private var month: MonthKey?
        private var entries: [PondEntry] = []
        private var newIDs: Set<UUID> = []
        private var built: PondScene?

        func scene(month: MonthKey, entries: [PondEntry],
                   newIDs: Set<UUID>) -> PondScene {
            if let built, month == self.month, entries == self.entries,
               newIDs == self.newIDs {
                return built
            }
            let scene = PondScene(monthKey: month, entries: entries, newIDs: newIDs)
            (self.month, self.entries, self.newIDs, self.built) =
                (month, entries, newIDs, scene)
            return scene
        }
    }

    let monthKey: MonthKey
    let entries: [PondEntry]
    let mode: Mode
    /// Offscreen pools (a covered hero, a non-visible month page) pause
    /// their clocks — the paged TabView keeps neighbors alive, and there's
    /// no reason to animate water nobody can see.
    let paused: Bool
    let newIDs: Set<UUID>

    @State private var cache = SceneCache()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var power = PowerState.shared

    init(monthKey: MonthKey, entries: [PondEntry], mode: Mode, paused: Bool = false,
         newIDs: Set<UUID> = []) {
        self.monthKey = monthKey
        self.entries = entries
        self.mode = mode
        self.paused = paused
        self.newIDs = newIDs
    }

    private var scene: PondScene {
        cache.scene(month: monthKey, entries: entries, newIDs: newIDs)
    }

    var body: some View {
        // The cache-check inside `scene` (an equality scan over `entries`)
        // only needs to run once per body evaluation — hoisted out of the
        // Canvas closures below, which TimelineView invokes independently
        // on every animation frame regardless of whether body re-evaluated.
        let scene = self.scene
        if reduceMotion {
            // A single still pose, stable per month; no glints — a twinkle
            // frozen mid-pulse would stick to its toy.
            Canvas { context, size in
                scene.draw(in: context, size: size,
                           time: Double(monthKey.seed % 997),
                           detail: mode == .hero ? .hero : .full,
                           night: colorScheme == .dark, glints: false)
            }
        } else {
            // The ambient hero idles at 10fps — its drift is slow enough
            // to read fine, and it's on screen whenever the app is — while
            // the fullscreen pool gets the smooth clock. Low Power Mode
            // calms both further.
            let fps: Double = power.lowPower
                ? (mode == .hero ? 6 : 10)
                : (mode == .hero ? 10 : 24)
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
