import SwiftUI

@main
struct SwissTimeApp: App {
    @StateObject private var store = WorkoutStore()

    var body: some Scene {
        WindowGroup {
            WorkoutListView()
                .environmentObject(store)
                .tint(.primary)
                .preferredColorScheme(.light)
        }
    }
}
