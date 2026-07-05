import SwiftUI

/// The untimed walkthrough: the workout's exercises as a grid of tiles, one
/// tap sinking each finished exercise under pool water — the map, where the
/// Sets tab is the clock. No order, no timers, no pressure: tiles toggle
/// freely, the screen is pushed (not modal) so the tab bar stays reachable
/// for timing rests, and progress persists until the workout is finished or
/// every tile is drained by hand.
struct UntimedSessionView: View {
    let workout: Workout
    /// Fired on Finish; the detail view runs the completion ceremony after
    /// this screen pops.
    let onFinish: () -> Void

    @State private var done: Set<UUID>
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(workout: Workout, onFinish: @escaping () -> Void) {
        self.workout = workout
        self.onFinish = onFinish
        _done = State(initialValue: UntimedProgress.load(workout.id))
    }

    private var allDone: Bool {
        !workout.exercises.isEmpty && done.count >= workout.exercises.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tap an exercise when you finish it — any order. The Sets tab times your rests meanwhile.")
                    .appFont(14)
                    .foregroundStyle(Color.inkSecondary)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(workout.exercises) { exercise in
                        ExerciseTile(exercise: exercise,
                                     done: done.contains(exercise.id),
                                     reduceMotion: reduceMotion) {
                            toggle(exercise.id)
                        }
                    }
                }
                Text("\(done.count) of \(workout.exercises.count) done")
                    .appFont(13)
                    .monospacedDigit()
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
            }
            .padding(20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(PaperBackground())
        .navigationTitle(workout.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            // Wakes with the last tile but never fires itself — the finish
            // is the user's moment to take.
            PrimaryButton(title: "Finish workout",
                          fill: allDone ? workout.palette.fill : Color.ink.opacity(0.25),
                          textColor: allDone ? workout.palette.onFill : Color.onInk) {
                UntimedProgress.clear(workout.id)
                onFinish()
                dismiss()
            }
            .disabled(!allDone)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.paper.opacity(0.94))
            .overlay(alignment: .top) { Color.hairline.frame(height: 1) }
        }
    }

    /// Two columns of tiles; one at accessibility sizes, where half-width
    /// can't hold an exercise name.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12),
              count: typeSize.isAccessibilitySize ? 1 : 2)
    }

    private func toggle(_ id: UUID) {
        if done.contains(id) {
            done.remove(id)
            Haptics.selection()
        } else {
            done.insert(id)
            Haptics.impact()
        }
        UntimedProgress.save(workout.id, done: done)
    }
}

/// One exercise as a card: name and sets × reps on paper, and the water
/// rising to submerge it when done — the same physics as the player's
/// clock, no flip to hide the name behind.
private struct ExerciseTile: View {
    let exercise: Exercise
    let done: Bool
    let reduceMotion: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .appFont(15, .semibold)
                    .multilineTextAlignment(.leading)
                Text(setsLine)
                    .appFont(12)
                if !exercise.instructions.isEmpty {
                    Text(exercise.instructions)
                        .appFont(12)
                        .lineLimit(2)
                }
                Spacer(minLength: 10)
            }
            .foregroundStyle(done ? Color.white : Color.ink)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .padding(13)
            .background {
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        Color.paperCardFill
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.white.opacity(0.55))
                                .frame(height: 2.5)
                            Rectangle()
                                .fill(Color.poolWater)
                        }
                        .frame(height: done ? geo.size.height + 3 : 0)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.ink.opacity(0.06), lineWidth: 1))
            .shadow(color: Color.shade.opacity(0.08), radius: 6, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .animation(reduceMotion ? nil
                       : .spring(response: 0.5, dampingFraction: 0.8), value: done)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(exercise.name)
        .accessibilityValue(done ? "Done" : "Not done")
        .accessibilityHint("Double tap to mark \(done ? "not done" : "done").")
    }

    /// "4 × 8", or "3 sets" when reps are unset. Rest never appears here —
    /// untimed exercises don't carry one; the Sets tab times rests live.
    private var setsLine: String {
        if let reps = exercise.reps {
            return "\(exercise.sets) × \(reps)"
        }
        return exercise.sets == 1 ? "1 set" : "\(exercise.sets) sets"
    }
}

/// Which exercises are done, per workout, surviving app switches and
/// relaunches — a gym session outlives the app's time in foreground.
/// Finishing clears it; so does draining every tile by hand.
enum UntimedProgress {
    private static func key(_ id: UUID) -> String { "untimedProgress.\(id.uuidString)" }

    static func load(_ id: UUID) -> Set<UUID> {
        let strings = UserDefaults.standard.stringArray(forKey: key(id)) ?? []
        return Set(strings.compactMap(UUID.init))
    }

    static func save(_ id: UUID, done: Set<UUID>) {
        if done.isEmpty {
            UserDefaults.standard.removeObject(forKey: key(id))
        } else {
            UserDefaults.standard.set(done.map(\.uuidString), forKey: key(id))
        }
    }

    static func clear(_ id: UUID) {
        UserDefaults.standard.removeObject(forKey: key(id))
    }
}
