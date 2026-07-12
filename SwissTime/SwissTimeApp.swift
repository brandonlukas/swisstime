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
    /// A shared workout that just arrived, waiting on its preview sheet.
    @State private var importedWorkout: Workout?
    /// The link the sheet came from — one tap can knock on two doors,
    /// and only a repeat of the SAME link is a duplicate.
    @State private var importURL: URL?
    @State private var importFailed = false
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

    /// Every door a shared workout arrives through — link open,
    /// browsing activity, the debug hook — ends here. A second
    /// delivery of the SAME link (one tap can knock on two doors) is
    /// one ask; a DIFFERENT link tapped over a stale sheet replaces
    /// it — the user asked for the new one.
    private func receive(link url: URL) {
        guard url != importURL || importedWorkout == nil else { return }
        if let workout = WorkoutLink.workout(from: url) {
            importURL = url
            importedWorkout = workout
        } else {
            importFailed = true
        }
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
                // Universal links (shared workouts) land HERE in the
                // SwiftUI lifecycle — not only in the browsing-activity
                // handler below (kept for deliveries that do take that
                // path). Only workout links are answered; the app stays
                // mute on anything else from the associated domain.
                if WorkoutLink.matches(url) {
                    receive(link: url)
                    return
                }
                guard url.scheme == "swisstime", url.host == "sets" else { return }
                if url.path == "/start" { DeepLink.requestSetsStart() } else { tab = .sets }
            }
            // A tapped workout LINK can also arrive as a browsing
            // activity — same funnel, and `receive` makes a double
            // delivery of one tap harmless.
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let url = activity.webpageURL, WorkoutLink.matches(url) else { return }
                receive(link: url)
            }
            .sheet(item: $importedWorkout) { workout in
                ImportWorkoutView(workout: workout) {
                    store.workouts.append(workout)
                    // Land where the new arrival surfaced — unless a
                    // workout is playing; it outranks the launchers,
                    // same as the Sets deep link below.
                    if !PlayerEngine.isActive {
                        tab = .workouts
                    }
                }
            }
            .alert("Couldn't open that workout", isPresented: $importFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This link doesn't hold a Lido workout.")
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
            // Debug: encode a starter into the real share URL, read it
            // back through the real parser, and show the import sheet —
            // one screenshot vouches for the whole pipe.
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("-autoImportLink"),
                   !DebugLaunch.didAutoImportLink,
                   let starter = WorkoutStore.starterWorkouts().first,
                   let link = WorkoutLink.url(for: starter) {
                    DebugLaunch.didAutoImportLink = true
                    receive(link: link)
                }
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
