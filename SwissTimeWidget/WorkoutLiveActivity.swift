import ActivityKit
import SwiftUI
import WidgetKit

private extension Font {
    static func app(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

}

// Mirrors the app's deck/ink palette — day and night swim — the widget
// target keeps its styling local rather than importing app code.
private extension Color {
    static let stPaper = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.063, green: 0.082, blue: 0.157, alpha: 1)
            : UIColor(red: 0.914, green: 0.929, blue: 0.953, alpha: 1)
    })
    static let stInk = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.902, green: 0.925, blue: 0.969, alpha: 1)
            : UIColor(red: 0.075, green: 0.13, blue: 0.28, alpha: 1)
    })
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(.stPaper)
                .activitySystemActionForegroundColor(.stInk)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stepTitle(context))
                            .font(.app(16, .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(context.attributes.workoutTitle)
                            .font(.app(13))
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimerText(state: context.state)
                        .font(.app(26, .medium))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(width: 88, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        Text("\(context.state.stepIndex + 1)/\(context.state.stepCount)")
                            .font(.app(14))
                            .foregroundStyle(.gray)
                            .monospacedDigit()
                        Spacer()
                        if !context.state.finished {
                            if context.state.showsPause {
                                Button(intent: TogglePauseIntent()) {
                                    Image(systemName: context.state.pauseIcon)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.white)
                                        .frame(width: 44, height: 36)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(context.state.pauseLabel)
                            }
                            Button(intent: SkipStepIntent()) {
                                Image(systemName: "forward.end")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 36)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Next step")
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.paused ? "pause" : "timer")
                    .foregroundStyle(.white)
            } compactTrailing: {
                TimerText(state: context.state)
                    .font(.app(14, .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.white)
            }
        }
    }
}

/// The pause button appears on the island and the lock screen; its face and
/// spoken name must flip together, so both come from here.
private extension WorkoutActivityAttributes.ContentState {
    var pauseIcon: String { paused ? "play" : "pause" }
    var pauseLabel: String { paused ? "Play" : "Pause" }
}

private func stepTitle(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> String {
    let state = context.state
    if state.finished { return "Workout complete" }
    if state.stepLabel.isEmpty { return state.exerciseName }
    return "\(state.stepLabel) \(state.exerciseName)"
}

/// Live countdown while running, static remaining while paused.
private struct TimerText: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        if state.finished {
            Text("0:00")
        } else if state.paused {
            Text(shortTime(state.pausedRemaining))
        } else if state.countsUp {
            Text(timerInterval: state.startDate...state.startDate.addingTimeInterval(6 * 3600),
                 countsDown: false, showsHours: false)
        } else {
            Text(timerInterval: Date()...max(Date(), state.endDate),
                 countsDown: true, showsHours: false)
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(stepTitle(context))
                    .font(.app(16, .semibold))
                    .foregroundStyle(Color.stInk)
                    .lineLimit(1)
                Text(context.attributes.workoutTitle)
                    .font(.app(13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            TimerText(state: context.state)
                .font(.app(30, .medium))
                .monospacedDigit()
                .foregroundStyle(Color.stInk)
            if !context.state.finished {
                if context.state.showsPause {
                    Button(intent: TogglePauseIntent()) {
                        Image(systemName: context.state.pauseIcon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.stInk)
                            .frame(width: 42, height: 42)
                            .background(Color.stInk.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(context.state.pauseLabel)
                }
                Button(intent: SkipStepIntent()) {
                    Image(systemName: "forward.end")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.stInk)
                        .frame(width: 42, height: 42)
                        .background(Color.stInk.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next step")
            }
        }
        .padding(16)
    }
}
