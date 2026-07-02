import SwiftUI

enum DetailSheet: Identifiable {
    case addItem(circuitID: UUID?)
    case editExercise(Exercise)
    case editCircuit(Circuit)
    case editWorkout

    var id: String {
        switch self {
        case .addItem(let circuitID): return "add-\(circuitID?.uuidString ?? "top")"
        case .editExercise(let exercise): return "exercise-\(exercise.id)"
        case .editCircuit(let circuit): return "circuit-\(circuit.id)"
        case .editWorkout: return "workout"
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
                Text(workout.title)
                    .font(.swiss(32, .bold))
                    .padding(.bottom, 14)
                SwissRule()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            if editing {
                editList
            } else {
                readView
            }
        }
        .background(SwissGlassBackground())
        .safeAreaInset(edge: .bottom) {
            if !editing && !workout.items.isEmpty {
                Button {
                    playTarget = PlayTarget()
                } label: {
                    Text("Play workout")
                        .font(.swiss(17, .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.swissRed)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
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
                        .font(.swiss(17, editing ? .medium : .regular))
                }
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .addItem(let circuitID):
                ItemFormView(workoutID: workoutID, circuitID: circuitID)
            case .editExercise(let exercise):
                ItemFormView(workoutID: workoutID, editingExercise: exercise)
            case .editCircuit(let circuit):
                CircuitEditorView(workoutID: workoutID, circuit: circuit)
            case .editWorkout:
                WorkoutFormView(existing: workout)
            }
        }
        .fullScreenCover(item: $playTarget) { target in
            PlayerView(workout: workout, startID: target.startID)
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-autoEditFirstWorkout") {
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
                        .font(.swiss(15))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 10)
                }
                Text(Format.summary(count: workout.items.count, duration: workout.totalDuration))
                    .font(.swiss(15))
                if workout.items.isEmpty {
                    emptyState
                        .padding(.top, 24)
                } else {
                    VStack(spacing: 16) {
                        ForEach(Array(workout.items.enumerated()), id: \.element.id) { index, item in
                            ItemCard(item: item, number: index + 1) { startID in
                                playTarget = PlayTarget(startID: startID)
                            }
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
                    .font(.swiss(16))
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("No exercises yet.")
                .font(.swiss(17, .medium))
            Text("Add timed exercises, or group them into circuits that repeat.")
                .font(.swiss(15))
                .foregroundStyle(.secondary)
            Button {
                sheet = .addItem(circuitID: nil)
            } label: {
                Text("Add exercise")
                    .font(.swiss(16, .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 48)
                    .background(Color.swissRed)
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
                        .listRowBackground(Rectangle().fill(.regularMaterial))
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
                            .font(.swiss(16))
                    }
                    .foregroundStyle(.secondary)
                }
                .listRowBackground(Rectangle().fill(.regularMaterial))
            }
            Section {
                Button {
                    sheet = .editWorkout
                } label: {
                    Text("Edit title & description")
                        .font(.swiss(16))
                }
                Button(role: .destructive) {
                    store.delete(workoutID)
                    dismiss()
                } label: {
                    Text("Delete workout")
                        .font(.swiss(16))
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
                        .font(.swiss(16, .medium))
                    if !exercise.instructions.isEmpty {
                        Text(exercise.instructions)
                            .font(.swiss(14))
                            .foregroundStyle(.secondary)
                    }
                case .circuit(let circuit):
                    Text(circuit.name)
                        .font(.swiss(16, .medium))
                    Text("\(circuit.loops) loop\(circuit.loops == 1 ? "" : "s") · \(circuit.exercises.count) exercise\(circuit.exercises.count == 1 ? "" : "s")")
                        .font(.swiss(14))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if case .exercise(let exercise) = item {
                Text(Format.mmss(exercise.duration))
                    .font(.swiss(15))
                    .monospacedDigit()
            }
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
        .contentShape(Rectangle())
        .onTapGesture {
            switch item {
            case .exercise(let exercise): sheet = .editExercise(exercise)
            case .circuit(let circuit): sheet = .editCircuit(circuit)
            }
        }
    }
}

// MARK: - Read-mode rows

private struct ItemCard: View {
    let item: WorkoutItem
    let number: Int
    /// Called with the id to start playing from.
    let onPlayFrom: (UUID) -> Void

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
            }
        }
        .glassCard()
    }
}

struct ExerciseRow: View {
    let number: String
    let exercise: Exercise
    var onTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.swiss(15))
                .frame(minWidth: 30, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.swiss(16, .medium))
                if !exercise.instructions.isEmpty {
                    Text(exercise.instructions)
                        .font(.swiss(15))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text(Format.mmss(exercise.duration))
                .font(.swiss(16))
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
                .font(.swiss(15))
                .frame(minWidth: 30, alignment: .leading)
            Text(circuit.name)
                .font(.swiss(16, .medium))
            Spacer(minLength: 8)
            Text("\(circuit.loops) loop\(circuit.loops == 1 ? "" : "s")")
                .font(.swiss(16))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}
