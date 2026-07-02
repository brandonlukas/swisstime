import SwiftUI

// MARK: - Building blocks

/// Sheet layout: X to close, content, full-width submit button pinned at the bottom.
struct SheetScaffold<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let buttonTitle: String
    let buttonEnabled: Bool
    let onSubmit: () -> Void
    @ViewBuilder var content: Content

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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            Divider()
            Button {
                onSubmit()
                dismiss()
            } label: {
                Text(buttonTitle)
                    .font(.app(17, .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .inkButton(buttonEnabled ? Color.ink : Color.ink.opacity(0.25))
            }
            .buttonStyle(.plain)
            .disabled(!buttonEnabled)
            .padding(20)
        }
        .background(Color.paper.ignoresSafeArea())
        .preferredColorScheme(.light)
    }
}

struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.app(17, .medium))
            TextField(placeholder, text: $text)
                .font(.app(17))
                .focused($focused)
                .padding(.horizontal, 14)
                .frame(height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(focused ? Color.ink : Color.fieldBorder, lineWidth: 1)
                )
        }
    }
}

struct PickerField<Value: Hashable>: View {
    let label: String
    let options: [Value]
    let display: (Value) -> String
    @Binding var selection: Value

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.app(17, .medium))
            Menu {
                Picker(label, selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(display(option)).tag(option)
                    }
                }
            } label: {
                HStack {
                    Text(display(selection))
                        .font(.app(17))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.fieldBorder, lineWidth: 1)
                )
            }
        }
    }
}

/// Tappable row of the curated pond swatches.
struct ColorPickerRow: View {
    @Binding var selection: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Color")
                .font(.app(17, .medium))
            HStack(spacing: 12) {
                ForEach(Palette.all.indices, id: \.self) { index in
                    Button {
                        selection = index
                    } label: {
                        Circle()
                            .fill(Palette.all[index].fill)
                            .frame(width: 44, height: 44)
                            .overlay {
                                if selection == index {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Palette.all[index].onFill)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Side-by-side choices, all visible — for the forks that reshape the form.
struct SegmentRow<Value: Hashable>: View {
    let label: String
    let options: [Value]
    let display: (Value) -> String
    @Binding var selection: Value

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.app(17, .medium))
            HStack(spacing: 10) {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                    } label: {
                        Text(display(option))
                            .font(.app(16, selection == option ? .medium : .regular))
                            .foregroundStyle(selection == option ? .white : Color.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(
                                selection == option ? Color.ink : .clear,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(selection == option ? Color.ink : Color.fieldBorder,
                                            lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct CheckboxRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isOn ? "checkmark.square" : "square")
                    .font(.system(size: 22, weight: .light))
                Text(title)
                    .font(.app(17))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Workout form

struct WorkoutFormView: View {
    @EnvironmentObject private var store: WorkoutStore
    var existing: Workout?
    var onCreated: ((UUID) -> Void)?

    @State private var title: String
    @State private var details: String
    @State private var colorIndex: Int

    init(existing: Workout? = nil, defaultColorIndex: Int = 0,
         onCreated: ((UUID) -> Void)? = nil) {
        self.existing = existing
        self.onCreated = onCreated
        _title = State(initialValue: existing?.title ?? "")
        _details = State(initialValue: existing?.details ?? "")
        _colorIndex = State(initialValue: existing?.colorIndex ?? defaultColorIndex)
    }

    var body: some View {
        SheetScaffold(
            buttonTitle: existing == nil ? "Create workout" : "Save workout",
            buttonEnabled: !title.trimmed.isEmpty,
            onSubmit: submit
        ) {
            LabeledField(label: "Title", placeholder: "Title", text: $title)
            LabeledField(label: "Description", placeholder: "Optional description", text: $details)
            ColorPickerRow(selection: $colorIndex)
        }
    }

    private func submit() {
        if let existing, var updated = store.workout(existing.id) {
            updated.title = title.trimmed
            updated.details = details.trimmed
            updated.colorIndex = colorIndex
            store.update(updated)
        } else {
            var workout = Workout(title: title.trimmed, details: details.trimmed)
            workout.colorIndex = colorIndex
            store.workouts.append(workout)
            onCreated?(workout.id)
        }
    }
}

// MARK: - Exercise / circuit form

struct ItemFormView: View {
    @EnvironmentObject private var store: WorkoutStore

    let workoutID: UUID
    var circuitID: UUID?
    var editingExercise: Exercise?

    enum Tab { case exercise, circuit }
    @State private var tab: Tab

    @State private var name: String
    @State private var instructions: String
    @State private var mode: ExerciseMode
    @State private var duration: TimeInterval
    @State private var halfway: Bool
    @State private var fiveSeconds: Bool
    @State private var sets: Int
    /// 0 means "not set" — reps are display-only.
    @State private var reps: Int
    @State private var rest: TimeInterval
    @State private var restCountsDown: Bool

    @State private var circuitName: String
    @State private var loops: Int

    init(workoutID: UUID, circuitID: UUID? = nil, editingExercise: Exercise? = nil) {
        self.workoutID = workoutID
        self.circuitID = circuitID
        self.editingExercise = editingExercise
        _tab = State(initialValue: .exercise)
        _name = State(initialValue: editingExercise?.name ?? "")
        _instructions = State(initialValue: editingExercise?.instructions ?? "")
        _mode = State(initialValue: editingExercise?.mode ?? .interval)
        _duration = State(initialValue: editingExercise?.duration ?? 60)
        _halfway = State(initialValue: editingExercise?.halfwayAlert ?? false)
        _fiveSeconds = State(initialValue: editingExercise?.fiveSecondsAlert ?? true)
        _sets = State(initialValue: editingExercise?.sets ?? 4)
        _reps = State(initialValue: editingExercise?.reps ?? 0)
        _rest = State(initialValue: editingExercise?.restDuration ?? 60)
        _restCountsDown = State(initialValue: editingExercise?.restCountsDown ?? false)
        _circuitName = State(initialValue: "")
        _loops = State(initialValue: 3)
    }

    private var isEditing: Bool {
        editingExercise != nil
    }

    private var showsTabs: Bool {
        !isEditing && circuitID == nil
    }

    private var buttonTitle: String {
        switch tab {
        case .exercise: return isEditing ? "Save exercise" : "Create exercise"
        case .circuit: return "Create circuit"
        }
    }

    private var buttonEnabled: Bool {
        switch tab {
        case .exercise: return !name.trimmed.isEmpty
        case .circuit: return !circuitName.trimmed.isEmpty
        }
    }

    private var durationOptions: [TimeInterval] {
        var options: [TimeInterval] = [5, 10, 15, 20, 30, 45, 60, 90, 120, 150, 180,
                                       240, 300, 360, 420, 480, 540, 600, 720, 900,
                                       1200, 1500, 1800]
        if !options.contains(duration) {
            options.append(duration)
            options.sort()
        }
        return options
    }

    private var restOptions: [TimeInterval] {
        var options: [TimeInterval] = [15, 20, 30, 45, 60, 75, 90, 120, 150, 180, 240, 300]
        if !options.contains(rest) {
            options.append(rest)
            options.sort()
        }
        return options
    }

    private var restExplanation: String {
        restCountsDown
            ? "Counts down from \(Format.mmss(rest)) and starts the next set automatically."
            : "Counts up past your \(Format.mmss(rest)) target — a chime marks it, and you start the next set when ready."
    }

    var body: some View {
        SheetScaffold(
            buttonTitle: buttonTitle,
            buttonEnabled: buttonEnabled,
            onSubmit: submit
        ) {
            if showsTabs {
                HStack(spacing: 28) {
                    tabButton("Exercise", .exercise)
                    tabButton("Circuit", .circuit)
                }
                .padding(.bottom, 4)
            }
            switch tab {
            case .exercise:
                LabeledField(label: "Name", placeholder: "Exercise name", text: $name)
                LabeledField(label: "Instructions", placeholder: "Optional instructions", text: $instructions)
                SegmentRow(label: "Type", options: [ExerciseMode.interval, .sets],
                           display: { $0 == .interval ? "Timed" : "Sets" },
                           selection: $mode)
                switch mode {
                case .interval:
                    PickerField(label: "Duration", options: durationOptions,
                                display: { Format.mmss($0) }, selection: $duration)
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Alerts")
                            .font(.app(17, .medium))
                        CheckboxRow(title: "Halfway done", isOn: $halfway)
                        CheckboxRow(title: "5s left", isOn: $fiveSeconds)
                    }
                case .sets:
                    PickerField(label: "Sets", options: Array(1...12),
                                display: { "\($0)" }, selection: $sets)
                    PickerField(label: "Reps per set", options: [0] + Array(1...50),
                                display: { $0 == 0 ? "Not set" : "\($0)" }, selection: $reps)
                    PickerField(label: "Rest between sets", options: restOptions,
                                display: { Format.mmss($0) }, selection: $rest)
                    VStack(alignment: .leading, spacing: 10) {
                        SegmentRow(label: "Rest timer", options: [false, true],
                                   display: { $0 ? "Counts down" : "Counts up" },
                                   selection: $restCountsDown)
                        Text(restExplanation)
                            .font(.app(14))
                            .foregroundStyle(.secondary)
                    }
                }
            case .circuit:
                LabeledField(label: "Name", placeholder: "Circuit name", text: $circuitName)
                PickerField(label: "Number of loops", options: Array(1...12),
                            display: { "\($0)" }, selection: $loops)
            }
        }
    }

    private func tabButton(_ title: String, _ value: Tab) -> some View {
        Button {
            tab = value
        } label: {
            Text(title)
                .font(.app(19, tab == value ? .bold : .regular))
                .foregroundStyle(.primary)
                .padding(.bottom, 6)
                .overlay(alignment: .bottom) {
                    if tab == value {
                        Rectangle()
                            .fill(Color.primary)
                            .frame(height: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func submit() {
        guard var workout = store.workout(workoutID) else { return }
        if var exercise = editingExercise {
            apply(to: &exercise)
            workout.update(exercise: exercise)
        } else if tab == .exercise {
            var exercise = Exercise(name: name.trimmed)
            apply(to: &exercise)
            workout.add(exercise, toCircuit: circuitID)
        } else {
            workout.items.append(.circuit(Circuit(name: circuitName.trimmed, loops: loops)))
        }
        store.update(workout)
    }

    private func apply(to exercise: inout Exercise) {
        exercise.name = name.trimmed
        exercise.instructions = instructions.trimmed
        exercise.mode = mode
        exercise.duration = duration
        exercise.halfwayAlert = halfway
        exercise.fiveSecondsAlert = fiveSeconds
        exercise.sets = sets
        exercise.reps = reps == 0 ? nil : reps
        exercise.restDuration = rest
        exercise.restCountsDown = restCountsDown
    }
}
