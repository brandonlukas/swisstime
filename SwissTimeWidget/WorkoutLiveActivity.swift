import ActivityKit
import SwiftUI
import WidgetKit

private extension Font {
    static func swiss(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("HelveticaNeue", size: size).weight(weight)
    }
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(.white)
                .activitySystemActionForegroundColor(.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stepTitle(context))
                            .font(.swiss(16, .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(context.attributes.workoutTitle)
                            .font(.swiss(13))
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimerText(state: context.state)
                        .font(.swiss(26, .medium))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(width: 88, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        Text("\(context.state.stepIndex + 1)/\(context.state.stepCount)")
                            .font(.swiss(14))
                            .foregroundStyle(.gray)
                            .monospacedDigit()
                        Spacer()
                        if !context.state.finished {
                            Button(intent: TogglePauseIntent()) {
                                Image(systemName: context.state.paused ? "play" : "pause")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 36)
                            }
                            .buttonStyle(.plain)
                            Button(intent: SkipStepIntent()) {
                                Image(systemName: "forward.end")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 36)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.paused ? "pause" : "timer")
                    .foregroundStyle(.white)
            } compactTrailing: {
                TimerText(state: context.state)
                    .font(.swiss(14, .medium))
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
                    .font(.swiss(16, .medium))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                Text(context.attributes.workoutTitle)
                    .font(.swiss(13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            TimerText(state: context.state)
                .font(.swiss(30, .medium))
                .monospacedDigit()
                .foregroundStyle(.black)
            if !context.state.finished {
                Button(intent: TogglePauseIntent()) {
                    Image(systemName: context.state.paused ? "play" : "pause")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(Color(white: 0.95))
                }
                .buttonStyle(.plain)
                Button(intent: SkipStepIntent()) {
                    Image(systemName: "forward.end")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(Color(white: 0.95))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }
}
