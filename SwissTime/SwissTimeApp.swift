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
    /// A shared .lido file that just arrived, waiting on its preview sheet.
    @State private var importedWorkout: Workout?
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
            // File URLs are the other kind of arrival: a shared .lido
            // workout tapped in Messages/Files/AirDrop.
            .onOpenURL { url in
                if url.isFileURL {
                    if let workout = Workout.imported(from: url) {
                        importedWorkout = workout
                    } else {
                        importFailed = true
                    }
                    // The system copied the file into our Inbox
                    // (LSSupportsOpeningDocumentsInPlace is NO), and
                    // cleanup is the app's job — read once, then gone.
                    try? FileManager.default.removeItem(at: url)
                    return
                }
                guard url.scheme == "swisstime", url.host == "sets" else { return }
                if url.path == "/start" { DeepLink.requestSetsStart() } else { tab = .sets }
            }
            // A tapped workout LINK arrives as a browsing activity, not a
            // URL open — same import gate, same sheet as the file path.
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let url = activity.webpageURL else { return }
                if let workout = WorkoutLink.workout(from: url) {
                    importedWorkout = workout
                } else {
                    importFailed = true
                }
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
            .alert("Couldn't read that file", isPresented: $importFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("It doesn't look like a Lido workout.")
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
            // Debug: round-trip a starter through the real export writer
            // and the real file-open decoder, then show the import sheet —
            // one screenshot vouches for the whole pipe.
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("-autoImportWorkout"),
                   !DebugLaunch.didAutoImport,
                   let starter = WorkoutStore.starterWorkouts().first,
                   let url = try? WorkoutFile.write(starter) {
                    DebugLaunch.didAutoImport = true
                    importedWorkout = Workout.imported(from: url)
                    importFailed = importedWorkout == nil
                }
                // Same idea for the link: encode a starter into the real
                // share URL and read it back through the real parser.
                if ProcessInfo.processInfo.arguments.contains("-autoImportLink"),
                   !DebugLaunch.didAutoImportLink,
                   let starter = WorkoutStore.starterWorkouts().first,
                   let link = WorkoutLink.url(for: starter) {
                    DebugLaunch.didAutoImportLink = true
                    importedWorkout = WorkoutLink.workout(from: link)
                    importFailed = importedWorkout == nil
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
