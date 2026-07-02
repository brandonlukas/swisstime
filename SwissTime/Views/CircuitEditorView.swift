import SwiftUI

/// Edits a circuit in one place: name, loops, and its exercises
/// (tap to edit, drag to reorder, minus to delete, plus to add).
struct CircuitEditorView: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    let workoutID: UUID
    let circuitID: UUID

    @State private var name: String
    @State private var loops: Int
    @State private var addingExercise = false
    @State private var editingExercise: Exercise?
    @State private var actionExercise: Exercise?

    init(workoutID: UUID, circuit: Circuit) {
        self.workoutID = workoutID
        self.circuitID = circuit.id
        _name = State(initialValue: circuit.name)
        _loops = State(initialValue: circuit.loops)
    }

    private var circuit: Circuit? {
        guard let workout = store.workout(workoutID) else { return nil }
        for item in workout.items {
            if case .circuit(let circuit) = item, circuit.id == circuitID {
                return circuit
            }
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .medium))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(20)
            Divider()
            List {
                Section {
                    LabeledField(label: "Name", placeholder: "Circuit name", text: $name)
                    PickerField(label: "Number of loops", options: Array(1...12),
                                display: { "\($0)" }, selection: $loops)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.paper)
                .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
                Section {
                    ForEach(circuit?.exercises ?? []) { exercise in
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
                            Button {
                                actionExercise = exercise
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 15))
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.plain)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editingExercise = exercise }
                        .listRowBackground(Color.card)
                        .listRowSeparatorTint(Color.hairline)
                    }
                    .onMove { from, to in
                        mutateCircuit { $0.exercises.move(fromOffsets: from, toOffset: to) }
                    }
                    .onDelete { offsets in
                        mutateCircuit { $0.exercises.remove(atOffsets: offsets) }
                    }
                    Button {
                        addingExercise = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus")
                                .font(.system(size: 15))
                            Text("Add exercise")
                                .font(.app(16))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.card)
                } header: {
                    Text("Exercises")
                        .font(.app(17, .medium))
                        .foregroundStyle(Color.ink)
                        .textCase(nil)
                        .padding(.leading, 4)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
            Divider()
            Button {
                mutateCircuit {
                    $0.name = name.trimmed
                    $0.loops = loops
                }
                dismiss()
            } label: {
                Text("Save circuit")
                    .font(.app(17, .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .inkButton(name.trimmed.isEmpty
                               ? Color.ink.opacity(0.25) : Color.ink)
            }
            .buttonStyle(.plain)
            .disabled(name.trimmed.isEmpty)
            .padding(20)
        }
        .background(Color.paper.ignoresSafeArea())
        .preferredColorScheme(.light)
        .sheet(isPresented: $addingExercise) {
            ItemFormView(workoutID: workoutID, circuitID: circuitID)
        }
        .sheet(item: $editingExercise) { exercise in
            ItemFormView(workoutID: workoutID, editingExercise: exercise)
        }
        .sheet(item: $actionExercise) { exercise in
            ActionListSheet(actions: [
                ActionItem(title: "Duplicate", icon: "square.on.square") {
                    guard var workout = store.workout(workoutID) else { return }
                    workout.duplicateItem(exercise.id)
                    store.update(workout)
                },
                ActionItem(title: "Move out of circuit", icon: "arrow.uturn.up") {
                    guard var workout = store.workout(workoutID) else { return }
                    workout.moveExerciseOutOfCircuit(exercise.id)
                    store.update(workout)
                },
            ])
        }
    }

    private func mutateCircuit(_ transform: (inout Circuit) -> Void) {
        guard var workout = store.workout(workoutID), var circuit else { return }
        transform(&circuit)
        workout.update(circuit: circuit)
        store.update(workout)
    }
}
