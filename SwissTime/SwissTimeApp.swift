import SwiftUI
import UIKit

/// The floating tab bar can miss a system appearance change that arrives
/// while the app is backgrounded: on return its traitCollection updates but
/// the glass material stays rendered in the old style. Bouncing the bar
/// through an explicit opposite style and back — held for a beat, so the
/// two changes land in separate render transactions — forces the material
/// to re-resolve. Only fired when the appearance actually changed while
/// away, so ordinary foregrounds never see the bounce.
@MainActor
enum TabBarRefresher {
    private static var styleAtBackground: UIUserInterfaceStyle?

    static func noteBackgrounded() {
        styleAtBackground = currentStyle()
    }

    static func kickIfStyleChanged() {
        guard let old = styleAtBackground else { return }
        styleAtBackground = nil
        if old != currentStyle() { kick() }
    }

    private static func currentStyle() -> UIUserInterfaceStyle {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .traitCollection.userInterfaceStyle ?? .unspecified
    }

    /// Drives a momentary tab-bar teardown: hidden for a beat, then back.
    /// The rebuilt bar resolves its glass fresh. Views observe this and
    /// apply `.toolbarVisibility` on the tab contents.
    @MainActor
    final class Nudge: ObservableObject {
        static let shared = Nudge()
        @Published var hidden = false
    }

    static func kick() {
        // Neither trait bounces on the bar nor a full window trait
        // round-trip make the glass re-resolve — its style is baked at
        // build time. Rebuild the bar instead: hide, beat, show.
        Nudge.shared.hidden = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            Nudge.shared.hidden = false
        }
        // Debug: dump every window's view hierarchy so the real class of
        // the floating tab pill can be found from the command line.
        if ProcessInfo.processInfo.arguments.contains("-debugTabBar") {
            var dump = ""
            func walk(_ view: UIView, depth: Int) {
                dump += String(repeating: "  ", count: depth)
                    + String(describing: type(of: view))
                    + " style=\(view.overrideUserInterfaceStyle.rawValue)"
                    + " trait=\(view.traitCollection.userInterfaceStyle.rawValue)\n"
                for subview in view.subviews { walk(subview, depth: depth + 1) }
            }
            for case let windowScene as UIWindowScene in UIApplication.shared.connectedScenes {
                for window in windowScene.windows {
                    dump += "WINDOW \(type(of: window))\n"
                    walk(window, depth: 1)
                }
            }
            let url = FileManager.default.urls(for: .documentDirectory,
                                               in: .userDomainMask)[0]
                .appendingPathComponent("tabbar.txt")
            try? dump.write(to: url, atomically: true, encoding: .utf8)
        }
    }

}

@main
struct SwissTimeApp: App {
    enum AppTab {
        case workouts, sets
    }

    @StateObject private var store = WorkoutStore()
    @StateObject private var pond = PondStore()
    @State private var tab: AppTab
    @AppStorage(SettingsKey.theme) private var theme = ThemeChoice.system.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var tabBarNudge = TabBarRefresher.Nudge.shared

    init() {
        // If the app died mid-workout, its Live Activity is still on the
        // island, frozen on a dead state. No engine is running at launch,
        // so anything alive now is an orphan.
        LiveActivityController.endOrphans()
        // Before any audio player exists: see the comment on warmUpSession —
        // without this, a cold launch's first workout paused background music.
        AudioManager.warmUpSession()
        // Debug: land on the Sets tab for command-line UI verification.
        let arguments = ProcessInfo.processInfo.arguments
        _tab = State(initialValue: arguments.contains("-autoOpenSets")
                     || arguments.contains("-autoStartSets") ? .sets : .workouts)
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $tab) {
                Tab("Workouts", systemImage: "figure.run", value: AppTab.workouts) {
                    WorkoutListView()
                        .toolbarVisibility(tabBarNudge.hidden ? .hidden : .visible,
                                           for: .tabBar)
                }
                Tab("Sets", systemImage: "timer", value: AppTab.sets) {
                    SetCounterView()
                        .toolbarVisibility(tabBarNudge.hidden ? .hidden : .visible,
                                           for: .tabBar)
                }
            }
            .environmentObject(store)
            .environmentObject(pond)
            .tint(Color.ink)
            // Reports the root's resolved scheme for sheets that pin their
            // own (see SystemScheme); with the theme on System this is the
            // live system appearance.
            .background(SchemeReporter())
            // nil follows the system; Day and Night pin it.
            .preferredColorScheme(ThemeChoice(rawValue: theme)?.colorScheme)
            // A backgrounded appearance flip leaves the tab bar's material
            // latched on the old style — detect and re-resolve on return.
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background: TabBarRefresher.noteBackgrounded()
                case .active: TabBarRefresher.kickIfStyleChanged()
                default: break
                }
            }
        }
    }
}
