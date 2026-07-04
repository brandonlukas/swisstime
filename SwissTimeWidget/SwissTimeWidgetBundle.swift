import SwiftUI
import WidgetKit

@main
struct SwissTimeWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
        WeekWidget()
        PoolWidget()
        WeekAccessoryWidget()
        SetsLauncherWidget()
        StartSetsControl()
    }
}
