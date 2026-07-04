import SwiftUI
import UIKit

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

    init() {
        // If the app died mid-workout, its Live Activity is still on the
        // island, frozen on a dead state. No engine is running at launch,
        // so anything alive now is an orphan.
        LiveActivityController.endOrphans()
        // Before any audio player exists: see the comment on warmUpSession —
        // without this, a cold launch's first workout paused background music.
        AudioManager.warmUpSession()
        // The back control is the real system button — native edge-swipe,
        // no gesture patching — with the Swiss arrow in place of the
        // system chevron. Swapped here once, app-wide.
        let arrow = UIImage(systemName: "arrow.left")
        let navBar = UINavigationBarAppearance()
        navBar.setBackIndicatorImage(arrow, transitionMaskImage: arrow)
        UINavigationBar.appearance().standardAppearance = navBar
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
                }
                Tab("Sets", systemImage: "timer", value: AppTab.sets) {
                    SetCounterView()
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
            // swisstime://sets/start — the lock-screen widget door. The
            // Control Center door is StartSetsIntent (Shared/DeepLink.swift),
            // which performs in this process and posts the same request.
            .onOpenURL { url in
                guard url.scheme == "swisstime", url.host == "sets" else { return }
                if url.path == "/start" { DeepLink.requestSetsStart() } else { tab = .sets }
            }
            // A running workout outranks the launchers: consume the ask
            // and stay put rather than flipping tabs under the player.
            .onReceive(NotificationCenter.default.publisher(for: DeepLink.startSets)) { _ in
                guard !PlayerEngine.isActive else {
                    DeepLink.pendingSetsStart = false
                    return
                }
                tab = .sets
            }
            // Activation net, catching both slow doors: a group-defaults
            // flag from an extension-side control press, and a latch set
            // before this view was listening (cold launch).
            .onChange(of: scenePhase, initial: true) { _, new in
                guard new == .active else { return }
                if let defaults = UserDefaults(suiteName: AppGroup.id),
                   defaults.bool(forKey: AppGroup.startSetsFlagKey) {
                    defaults.removeObject(forKey: AppGroup.startSetsFlagKey)
                    DeepLink.requestSetsStart()
                } else if DeepLink.pendingSetsStart {
                    if PlayerEngine.isActive {
                        DeepLink.pendingSetsStart = false
                    } else {
                        tab = .sets
                    }
                }
            }
        }
    }
}
