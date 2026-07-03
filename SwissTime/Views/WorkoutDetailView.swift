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
                Text(workout.title)
                    .display(24)
                    .padding(.bottom, 14)
                InkRule()
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
                PrimaryButton(title: workout.kind == .timed ? "Play workout" : "Mark as done",
                              fill: workout.palette.fill,
                              textColor: workout.palette.onFill) {
                    if workout.kind == .timed {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        playing = true
                    } else {
                        markDone()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.paper.opacity(0.94))
                .overlay(alignment: .top) { Color.hairline.frame(height: 1) }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { Image(systemName: "arrow.left") }
                    .disabled(editing)
                    .opacity(editing ? 0.3 : 1)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { editing.toggle() }
                } label: {
                    Text(editing ? "Done" : "Edit")
                        .font(.app(17, editing ? .medium : .regular))
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
        }
    }

    /// The untimed completion: they said they did it — toy earned.
    private func markDone() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
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
                        .font(.app(15))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 10)
                }
                Text(workout.summaryLine)
                    .font(.app(15))
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
                Text("Add exercise")
                    .font(.app(16))
                Spacer()
            }
            .foregroundStyle(.secondary)
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
                        Text("Add exercise")
                            .font(.app(16))
                    }
                    .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.paperCardFill.opacity(0.7))
            }
            Section {
                Button {
                    sheet = .editWorkout
                } label: {
                    Text("Edit title & description")
                        .font(.app(16))
                }
                Button(role: .destructive) {
                    sheet = .confirmDelete
                } label: {
                    Text("Delete workout")
                        .font(.app(16))
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
                    .font(.app(16, .medium))
                if !exercise.instructions.isEmpty {
                    Text(exercise.instructions)
                        .font(.app(14))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text(exercise.trailingSummary)
                .font(.app(15))
                .monospacedDigit()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            sheet = .editExercise(exercise)
        }
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
                    .font(.app(16, .medium))
                if !exercise.instructions.isEmpty {
                    Text(exercise.instructions)
                        .font(.app(15))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text(exercise.trailingSummary)
                .font(.app(16))
                .monospacedDigit()
        }
        .padding(.vertical, 18)
    }
}
