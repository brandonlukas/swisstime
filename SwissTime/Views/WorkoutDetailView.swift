import SwiftUI

enum DetailSheet: Identifiable {
    case addExercise
    case editExercise(Exercise)
    case editWorkout
    case confirmDelete

    var id: String {
        switch self {
        case .addExercise: return "add"
        case .editExercise(let exercise): return "exercise-\(exercise.id)"
        case .editWorkout: return "workout"
        case .confirmDelete: return "confirm-delete"
        }
    }
}

/// Read mode is the happy path: the program as a printed sheet you glance at,
/// with Play as its only action. Edit mode holds all the building tools:
/// reorder, delete, rename.
struct WorkoutDetailView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var pond: PondStore
    @Environment(\.dismiss) private var dismiss
    let workoutID: UUID
    /// The list owns the navigation path; Start workout pushes the untimed
    /// session as a path element above this screen.
    var startSession: () -> Void = {}

    @State private var editing = false
    @State private var sheet: DetailSheet?
    @State private var playing = false
    @State private var ceremony: CompletionCeremony?
    /// Set by the delete confirmation; acted on once its sheet is gone,
    /// so the pop-back never races the dismissing sheet.
    @State private var pendingDelete = false

    private var workout: Workout {
        store.workout(workoutID) ?? Workout(title: "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Circle()
                    .fill(workout.palette.fill)
                    .frame(width: 16, height: 16)
                    .padding(.bottom, 10)
                PageHeader(title: workout.title, size: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            if editing {
                editList
            } else {
                readView
            }
        }
        .background(PaperBackground())
        .safeAreaInset(edge: .bottom) {
            if !editing && !workout.exercises.isEmpty {
                Group {
                    if workout.kind == .timed {
                        PrimaryButton(title: "Play workout",
                                      fill: workout.palette.fill,
                                      textColor: workout.palette.onFill) {
                            Haptics.impact()
                            playing = true
                        }
                    } else {
                        // Side by side — stacked at accessibility sizes,
                        // where two half-width buttons can't hold their
                        // words. Walking through the session is the primary
                        // act; logging an off-book day stays one tap away.
                        AdaptiveRow {
                            SecondaryButton(title: "Mark as done") {
                                markDone()
                            }
                            PrimaryButton(title: "Start workout",
                                          fill: workout.palette.fill,
                                          textColor: workout.palette.onFill) {
                                Haptics.impact()
                                startSession()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.paper.opacity(0.94))
                .overlay(alignment: .top) { Color.hairline.frame(height: 1) }
            }
        }
        // The system back button (restyled to the Swiss arrow in
        // SwissTimeApp) keeps the native edge-swipe. Hidden mid-edit so
        // leaving always goes through Done — hiding it also disables the
        // swipe, matching the lockout.
        .navigationBarBackButtonHidden(editing)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { editing.toggle() }
                } label: {
                    Text(editing ? "Done" : "Edit")
                        .appFont(17, editing ? .medium : .regular)
                }
            }
        }
        .sheet(item: $sheet, onDismiss: {
            if pendingDelete {
                pendingDelete = false
                store.delete(workoutID)
                dismiss()
            }
        }) { sheet in
            switch sheet {
            case .addExercise:
                ExerciseFormView(workoutID: workoutID, kind: workout.kind)
            case .editExercise(let exercise):
                ExerciseFormView(workoutID: workoutID, kind: workout.kind,
                                 editingExercise: exercise)
            case .editWorkout:
                WorkoutFormView(existing: workout)
            case .confirmDelete:
                ActionListSheet(actions: [
                    ActionItem(title: "Delete \"\(workout.title)\" forever",
                               icon: "trash", destructive: true) {
                        pendingDelete = true
                    },
                ])
            }
        }
        .fullScreenCover(isPresented: $playing) {
            PlayerView(workout: workout)
        }
        // However the ceremony ends — Done or a swipe — the workout is
        // logged and this screen's job is over; return to the list.
        .sheet(item: $ceremony, onDismiss: { dismiss() }) { ceremony in
            CompletionCeremonyView(workout: workout, entryID: ceremony.entryID)
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-autoEditFirstWorkout"),
               !DebugLaunch.didAutoEdit {
                DebugLaunch.didAutoEdit = true
                editing = true
            }
            if ProcessInfo.processInfo.arguments.contains("-autoAddItem"),
               !DebugLaunch.didAutoAddItem {
                DebugLaunch.didAutoAddItem = true
                sheet = .addExercise
            }
            if ProcessInfo.processInfo.arguments.contains("-autoEditWorkout"),
               !DebugLaunch.didAutoEditWorkout {
                DebugLaunch.didAutoEditWorkout = true
                sheet = .editWorkout
            }
            if ProcessInfo.processInfo.arguments.contains("-autoEditFirstExercise"),
               !DebugLaunch.didAutoAddItem,
               let first = workout.exercises.first {
                DebugLaunch.didAutoAddItem = true
                sheet = .editExercise(first)
            }
            if ProcessInfo.processInfo.arguments.contains("-autoMarkDone"),
               !DebugLaunch.didAutoMarkDone,
               workout.kind == .untimed, !workout.exercises.isEmpty {
                DebugLaunch.didAutoMarkDone = true
                markDone()
            }
            if ProcessInfo.processInfo.arguments.contains("-autoStartUntimed"),
               !DebugLaunch.didAutoStartUntimed,
               workout.kind == .untimed, !workout.exercises.isEmpty {
                DebugLaunch.didAutoStartUntimed = true
                startSession()
            }
        }
    }

    /// The untimed completion: they said they did it — toy earned. Any
    /// half-ticked session state is spent by the completion too: the next
    /// Start workout begins fresh.
    private func markDone() {
        Haptics.success()
        UntimedProgress.clear(workoutID)
        store.markPlayed(workoutID)
        ceremony = CompletionCeremony(entryID: pond.record(workout: workout))
    }

    // MARK: - Read mode

    /// A quiet program sheet: numbered lines and hairlines, nothing pressable
    /// but the add row — cards would advertise taps the rows don't have.
    private var readView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !workout.details.isEmpty {
                    Text(workout.details)
                        .appFont(15)
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.bottom, 10)
                }
                Text(workout.summaryLine)
                    .appFont(15)
                if workout.exercises.isEmpty {
                    emptyState
                        .padding(.top, 24)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.hairline)
                                    .frame(height: 1)
                            }
                            ExerciseLine(number: String(format: "%02d", index + 1),
                                         exercise: exercise)
                        }
                        Rectangle()
                            .fill(Color.hairline)
                            .frame(height: 1)
                        addRow
                    }
                    .padding(.top, 12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .padding(.top, -4)
        }
    }

    private var addRow: some View {
        Button {
            sheet = .addExercise
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 15))
                    .frame(minWidth: 30, alignment: .leading)
                    .accessibilityHidden(true)
                Text("Add exercise")
                    .appFont(16)
                Spacer()
            }
            .foregroundStyle(Color.inkSecondary)
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        EmptyStateView(
            title: "No exercises yet.",
            message: workout.kind == .timed
                ? "Add timed intervals — each announces itself and counts down."
                : "Write the program: exercises with sets and reps.",
            buttonTitle: "Add exercise"
        ) {
            sheet = .addExercise
        }
    }

    // MARK: - Edit mode

    private var editList: some View {
        List {
            Section {
                ForEach(workout.exercises) { exercise in
                    editRow(exercise)
                        .listRowBackground(Color.paperCardFill.opacity(0.7))
                        .listRowSeparatorTint(Color.hairline)
                }
                .onMove { from, to in
                    var updated = workout
                    updated.exercises.move(fromOffsets: from, toOffset: to)
                    store.update(updated)
                }
                .onDelete { offsets in
                    var updated = workout
                    updated.exercises.remove(atOffsets: offsets)
                    store.update(updated)
                }
                Button {
                    sheet = .addExercise
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.system(size: 15))
                            .accessibilityHidden(true)
                        Text("Add exercise")
                            .appFont(16)
                    }
                    .foregroundStyle(Color.inkSecondary)
                }
                .listRowBackground(Color.paperCardFill.opacity(0.7))
            }
            Section {
                Button {
                    sheet = .editWorkout
                } label: {
                    Text("Edit title & description")
                        .appFont(16)
                }
                Button(role: .destructive) {
                    sheet = .confirmDelete
                } label: {
                    Text("Delete workout")
                        .appFont(16)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(Color.hairline)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
    }

    private func editRow(_ exercise: Exercise) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .appFont(16, .medium)
                if !exercise.instructions.isEmpty {
                    Text(exercise.instructions)
                        .appFont(14)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            Spacer(minLength: 8)
            Text(exercise.trailingSummary)
                .appFont(15)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            sheet = .editExercise(exercise)
        }
        // A gesture, not a Button — edit mode would swallow a Button's tap.
        // The trait tells VoiceOver the row acts; double-tap lands in the
        // gesture like any tap.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the exercise editor.")
    }
}

/// One line of the program sheet — purely informational, no gestures.
private struct ExerciseLine: View {
    let number: String
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .overline(12)
                .foregroundStyle(Color.periwinkle)
                .frame(minWidth: 30, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .appFont(16, .medium)
                if !exercise.instructions.isEmpty {
                    Text(exercise.instructions)
                        .appFont(15)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            Spacer(minLength: 8)
            Text(exercise.trailingSummary)
                .appFont(16)
                .monospacedDigit()
        }
        .padding(.vertical, 18)
    }
}
