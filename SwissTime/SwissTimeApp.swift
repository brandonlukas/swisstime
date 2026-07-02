import SwiftUI

@main
struct SwissTimeApp: App {
    @StateObject private var store = WorkoutStore()
    @StateObject private var pond = PondStore()

    init() {
        // If the app died mid-workout, its Live Activity is still on the
        // island, frozen on a dead state. No engine is running at launch,
        // so anything alive now is an orphan.
        LiveActivityController.endOrphans()
    }

    var body: some Scene {
        WindowGroup {
            WorkoutListView()
                .environmentObject(store)
                .environmentObject(pond)
                .tint(Color.ink)
                .preferredColorScheme(.light)
        }
    }
}
