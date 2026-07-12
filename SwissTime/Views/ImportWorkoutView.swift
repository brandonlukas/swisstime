import SwiftUI

/// What a shared workout link opens into: the program on approval, one
/// button to take it. Read-only on purpose — it becomes editable the
/// moment it's yours, not before. The workout shown is already the
/// import-ready copy, so this sheet previews exactly what Add appends.
struct ImportWorkoutView: View {
    let workout: Workout
    /// Adoption is the caller's move; this sheet only shows the goods.
    let onAdd: () -> Void

    var body: some View {
        SheetScaffold(buttonTitle: "Add to library", buttonEnabled: true,
                      onSubmit: {
            Haptics.impact()
            onAdd()
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // The import gate guarantees a non-empty title, so the
                // masthead needs no fallback here.
                WorkoutMasthead(workout: workout)
                    .padding(.bottom, 12)
                if !workout.details.isEmpty {
                    Text(workout.details)
                        .appFont(15)
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.bottom, 10)
                }
                Text(workout.kindSummaryLine)
                    .appFont(15)
                VStack(spacing: 0) {
                    ForEach(Array(workout.exercises.enumerated()),
                            id: \.element.id) { index, exercise in
                        if index > 0 {
                            Rectangle()
                                .fill(Color.hairline)
                                .frame(height: 1)
                        }
                        ExerciseLine(number: String(format: "%02d", index + 1),
                                     exercise: exercise)
                    }
                }
                .padding(.top, 12)
                Text("Shared with you. Adding it makes it yours to edit.")
                    .appFont(13)
                    .foregroundStyle(Color.inkSecondary.opacity(0.8))
                    .padding(.top, 16)
            }
        }
    }
}
