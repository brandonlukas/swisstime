import SwiftUI

@main
struct SwissTimeApp: App {
    @StateObject private var store = WorkoutStore()
    @StateObject private var pond = PondStore()

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
