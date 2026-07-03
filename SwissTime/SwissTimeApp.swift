import SwiftUI

@main
struct SwissTimeApp: App {
    enum AppTab {
        case workouts, sets
    }

    @StateObject private var store = WorkoutStore()
    @StateObject private var pond = PondStore()
    @State private var tab: AppTab

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
                }
                Tab("Sets", systemImage: "timer", value: AppTab.sets) {
                    SetCounterView()
                }
            }
            .environmentObject(store)
            .environmentObject(pond)
            .tint(Color.ink)
        }
    }
}
