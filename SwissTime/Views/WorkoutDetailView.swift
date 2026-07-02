import SwiftUI

enum DetailSheet: Identifiable {
    case addItem(circuitID: UUID?)
    case editExercise(Exercise)
    case editCircuit(Circuit)
    case editWorkout
    case itemActions(WorkoutItem)
    case confirmDelete

    var id: String {
        switch self {
        case .addItem(let circuitID): return "add-\(circuitID?.uuidString ?? "top")"
        case .editExercise(let exercise): return "exercise-\(exercise.id)"
        case .editCircuit(let circuit): return "circuit-\(circuit.id)"
        case .editWorkout: return "workout"
        case .itemActions(let item): return "actions-\(item.id)"
        case .confirmDelete: return "confirm-delete"
        }
    }
}

/// Read mode is the happy path: a clean program you tap to play.
/// Edit mode holds all the building tools: reorder, delete, duplicate, rename.
struct WorkoutDetailView: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    let workoutID: UUID

    @State private var editing = false
    @State private var sheet: DetailSheet?
    @State private var playTarget: PlayTarget?
    /// Set by the delete confirmation; acted on once its sheet is gone,
    /// so the pop-back never races the dismissing sheet.
    @State private var pendingDelete = false

    struct PlayTarget: Identifiable {
        let id = UUID()
        var startID: UUID?
    }

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
                    playTarget = PlayTarget()
                } label: {
                    Text("Play workout")
                        .font(.app(17, .medium))
                        .foregroundStyle(workout.palette.onFill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .inkButton(workout.palette.fill)
                }
                .buttonStyle(.plain)
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
            case .addItem(let circuitID):
                ItemFormView(workoutID: workoutID, circuitID: circuitID)
            case .editExercise(let exercise):
                ItemFormView(workoutID: workoutID, editingExercise: exercise)
            case .editCircuit(let circuit):
                CircuitEditorView(workoutID: workoutID, circuit: circuit)
            case .editWorkout:
                WorkoutFormView(existing: workout)
            case .itemActions(let item):
                ActionListSheet(actions: itemActions(item))
            case .confirmDelete:
                ActionListSheet(actions: [
                    ActionItem(title: "Delete \"\(workout.title)\" forever",
                               icon: "trash", destructive: true) {
                        pendingDelete = true
                    },
                ])
            }
        }
        .fullScreenCover(item: $playTarget) { target in
            PlayerView(workout: workout, startID: target.startID)
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-autoEditFirstWorkout"),
               !DebugLaunch.didAutoEdit {
                DebugLaunch.didAutoEdit = true
                editing = true
            }
        }
    }

    // MARK: - Read mode

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
                    VStack(spacing: 16) {
                        ForEach(Array(workout.items.enumerated()), id: \.element.id) { index, item in
                            ItemCard(item: item, number: index + 1,
                                     onPlayFrom: { startID in
                                         playTarget = PlayTarget(startID: startID)
                                     },
                                     onAddToCircuit: { circuitID in
                                         sheet = .addItem(circuitID: circuitID)
                                     })
                        }
                        addRow
                    }
                    .padding(.top, 24)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .padding(.top, -4)
        }
    }

    private var addRow: some View {
        Button {
            sheet = .addItem(circuitID: nil)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 15))
                Text("Add exercise or circuit")
                    .font(.app(16))
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .paperCard()
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("No exercises yet.")
                .font(.app(17, .medium))
            Text("Add timed exercises, or group them into circuits that repeat.")
                .font(.app(15))
                .foregroundStyle(.secondary)
            Button {
                sheet = .addItem(circuitID: nil)
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
                ForEach(workout.items) { item in
                    editRow(item)
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
                    sheet = .addItem(circuitID: nil)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.system(size: 15))
                        Text("Add exercise or circuit")
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

    private func editRow(_ item: WorkoutItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                switch item {
                case .exercise(let exercise):
                    Text(exercise.name)
                        .font(.app(16, .medium))
                    if !exercise.instructions.isEmpty {
                        Text(exercise.instructions)
                            .font(.app(14))
                            .foregroundStyle(.secondary)
                    }
                case .circuit(let circuit):
                    Text(circuit.name)
                        .font(.app(16, .medium))
                    Text("\(circuit.loops) loop\(circuit.loops == 1 ? "" : "s") · \(circuit.exercises.count) exercise\(circuit.exercises.count == 1 ? "" : "s")")
                        .font(.app(14))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if case .exercise(let exercise) = item {
                Text(exercise.trailingSummary)
                    .font(.app(15))
                    .monospacedDigit()
            }
            // Exercises grow a menu once there's a circuit to move them into.
            if case .exercise = item, !circuits.isEmpty {
                Button {
                    sheet = .itemActions(item)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    var updated = workout
                    updated.duplicateItem(item.id)
                    store.update(updated)
                } label: {
                    Image(systemName: "square.on.square")
                        .font(.system(size: 15))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            switch item {
            case .exercise(let exercise): sheet = .editExercise(exercise)
            case .circuit(let circuit): sheet = .editCircuit(circuit)
            }
        }
    }

    private var circuits: [Circuit] {
        workout.items.compactMap {
            if case .circuit(let circuit) = $0 { return circuit }
            return nil
        }
    }

    private func itemActions(_ item: WorkoutItem) -> [ActionItem] {
        var actions = [
            ActionItem(title: "Duplicate", icon: "square.on.square") {
                var updated = workout
                updated.duplicateItem(item.id)
                store.update(updated)
            },
        ]
        if case .exercise = item {
            for circuit in circuits {
                actions.append(ActionItem(title: "Move into \(circuit.name)",
                                          icon: "arrow.turn.down.right") {
                    var updated = workout
                    updated.moveExercise(item.id, intoCircuit: circuit.id)
                    store.update(updated)
                })
            }
        }
        return actions
    }
}

// MARK: - Read-mode rows

private struct ItemCard: View {
    let item: WorkoutItem
    let number: Int
    /// Called with the id to start playing from.
    let onPlayFrom: (UUID) -> Void
    let onAddToCircuit: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            switch item {
            case .exercise(let exercise):
                ExerciseRow(number: "\(number).", exercise: exercise,
                            onTap: { onPlayFrom(exercise.id) })
            case .circuit(let circuit):
                CircuitHeaderRow(number: "\(number).", circuit: circuit,
                                 onTap: { onPlayFrom(circuit.id) })
                ForEach(Array(circuit.exercises.enumerated()), id: \.element.id) { sub, exercise in
                    Rectangle()
                        .fill(Color.hairline)
                        .frame(height: 1)
                        .padding(.leading, 58)
                    ExerciseRow(number: "\(number).\(sub + 1).", exercise: exercise,
                                onTap: { onPlayFrom(exercise.id) })
                }
                Rectangle()
                    .fill(Color.hairline)
                    .frame(height: 1)
                    .padding(.leading, 58)
                Button {
                    onAddToCircuit(circuit.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.system(size: 13))
                            .frame(minWidth: 30, alignment: .leading)
                        Text("Add exercise")
                            .font(.app(15))
                        Spacer()
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .paperCard()
    }
}

struct ExerciseRow: View {
    let number: String
    let exercise: Exercise
    var onTap: (() -> Void)?

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
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}

private struct CircuitHeaderRow: View {
    let number: String
    let circuit: Circuit
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.app(15))
                .frame(minWidth: 30, alignment: .leading)
            Text(circuit.name)
                .font(.app(16, .medium))
            Spacer(minLength: 8)
            Text("\(circuit.loops) loop\(circuit.loops == 1 ? "" : "s")")
                .font(.app(16))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}
