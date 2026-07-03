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
    @Environment(\.dismiss) private var dismiss
    let workoutID: UUID

    @State private var editing = false
    @State private var sheet: DetailSheet?
    @State private var playing = false
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
                    .font(.serifApp(32, .bold))
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
            if !editing && !workout.items.isEmpty {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    playing = true
                } label: {
                    Text("Play workout")
                        .font(.app(17, .medium))
                        .foregroundStyle(workout.palette.onFill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .inkButton(workout.palette.fill)
                }
                .buttonStyle(PressableButtonStyle())
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
                ExerciseFormView(workoutID: workoutID)
            case .editExercise(let exercise):
                ExerciseFormView(workoutID: workoutID, editingExercise: exercise)
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
               let first = workout.items.first {
                DebugLaunch.didAutoAddItem = true
                sheet = .editExercise(first)
            }
        }
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
                Text(Format.summary(count: workout.items.count, duration: workout.totalDuration))
                    .font(.app(15))
                if workout.items.isEmpty {
                    emptyState
                        .padding(.top, 24)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(workout.items.enumerated()), id: \.element.id) { index, exercise in
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.hairline)
                                    .frame(height: 1)
                            }
                            ExerciseLine(number: "\(index + 1).", exercise: exercise)
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
        VStack(alignment: .leading, spacing: 16) {
            Text("No exercises yet.")
                .font(.app(17, .medium))
            Text("Add timed intervals, or sets with a rest countdown between them.")
                .font(.app(15))
                .foregroundStyle(.secondary)
            Button {
                sheet = .addExercise
            } label: {
                Text("Add exercise")
                    .font(.app(16, .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 48)
                    .inkButton(.ink)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    // MARK: - Edit mode

    private var editList: some View {
        List {
            Section {
                ForEach(workout.items) { exercise in
                    editRow(exercise)
                        .listRowBackground(Color.paperCardFill.opacity(0.7))
                        .listRowSeparatorTint(Color.hairline)
                }
                .onMove { from, to in
                    var updated = workout
                    updated.items.move(fromOffsets: from, toOffset: to)
                    store.update(updated)
                }
                .onDelete { offsets in
                    var updated = workout
                    updated.items.remove(atOffsets: offsets)
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
                .font(.app(15))
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
