import SwiftUI
import UIKit

/// SwiftUI has no first-class "dismiss keyboard"; resigning first responder
/// through the responder chain drops focus from whichever field holds it.
@MainActor
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil)
}

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
                    hideKeyboard()
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
                // A tap catcher BEHIND the fields: blank-paper taps drop the
                // keyboard, and being a sibling layer (not a wrapping
                // gesture) it can't slow the controls' own touch handling.
                .background(
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { hideKeyboard() }
                )
            }
            .scrollDismissesKeyboard(.immediately)
            Divider()
            Button {
                hideKeyboard()
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
                .submitLabel(.done)
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
            // Opening a picker over the keyboard reads as a mistake — drop it.
            // Simultaneous, so the menu itself opens untouched.
            .simultaneousGesture(TapGesture().onEnded { hideKeyboard() })
        }
    }
}

/// Tappable row of the curated pond swatches, with a living portrait of
/// the creature that color earns.
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
            HStack(spacing: 14) {
                CreaturePortrait(kind: Palette.color(selection).creature)
                    .frame(width: 76, height: 52)
                    .id(Palette.color(selection).creature)
                    .transition(.opacity)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Palette.color(selection).name)
                        .font(.app(16, .medium))
                    Text(Palette.color(selection).creature.pickerLine)
                        .font(.app(15))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 2)
            .animation(.easeInOut(duration: 0.22), value: selection)
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
                        hideKeyboard()
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
                            // The unselected option's fill is clear, and
                            // transparent pixels don't hit-test — the whole
                            // pill must catch the tap, not just the text.
                            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Flips on touch-DOWN, not finger-up — a checkbox should feel like a
/// physical switch, and waiting out a full tap in a scroll view reads as
/// lag. A zero-distance drag is the touch-down hook SwiftUI doesn't offer.
struct CheckboxRow: View {
    let title: String
    @Binding var isOn: Bool
    @State private var touchDown = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isOn ? "checkmark.square" : "square")
                .font(.system(size: 22, weight: .light))
            Text(title)
                .font(.app(17))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !touchDown else { return }
                    touchDown = true
                    isOn.toggle()
                    UISelectionFeedbackGenerator().selectionChanged()
                    hideKeyboard()
                }
                .onEnded { _ in touchDown = false }
        )
    }
}

// MARK: - Workout form

struct WorkoutFormView: View {
    @EnvironmentObject private var store: WorkoutStore
    var existing: Workout?
    var onCreated: ((UUID) -> Void)?

    @State private var title: String
    @State private var details: String
    @State private var kind: WorkoutKind
    @State private var colorIndex: Int

    init(existing: Workout? = nil, defaultColorIndex: Int = 0,
         onCreated: ((UUID) -> Void)? = nil) {
        self.existing = existing
        self.onCreated = onCreated
        _title = State(initialValue: existing?.title ?? "")
        _details = State(initialValue: existing?.details ?? "")
        _kind = State(initialValue: existing?.kind ?? .timed)
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
            VStack(alignment: .leading, spacing: 10) {
                SegmentRow(label: "Type", options: [WorkoutKind.timed, .untimed],
                           display: { $0 == .timed ? "Timed" : "Untimed" },
                           selection: $kind)
                Text(kind == .timed
                     ? "Plays step by step, with a timer and voice cues."
                     : "Done at your own pace, logged with a tap — the Sets tab can count sets and time rest.")
                    .font(.app(14))
                    .foregroundStyle(.secondary)
            }
            ColorPickerRow(selection: $colorIndex)
        }
    }

    private func submit() {
        if let existing, var updated = store.workout(existing.id) {
            updated.title = title.trimmed
            updated.details = details.trimmed
            updated.colorIndex = colorIndex
            if updated.kind != kind {
                updated.kind = kind
                // Exercises follow the workout's kind; a flipped exercise
                // keeps its numbers (sets, duration) for flipping back.
                for index in updated.items.indices {
                    updated.items[index].mode = kind == .timed ? .interval : .sets
                }
            }
            store.update(updated)
        } else {
            var workout = Workout(title: title.trimmed, details: details.trimmed)
            workout.kind = kind
            workout.colorIndex = colorIndex
            store.workouts.append(workout)
            onCreated?(workout.id)
        }
    }
}

// MARK: - Exercise form

struct ExerciseFormView: View {
    @EnvironmentObject private var store: WorkoutStore

    let workoutID: UUID
    /// The workout's kind decides the exercise's shape: timed workouts take
    /// intervals, untimed ones take sets × reps.
    let kind: WorkoutKind
    var editingExercise: Exercise?

    @State private var name: String
    @State private var instructions: String
    @State private var duration: TimeInterval
    @State private var halfway: Bool
    @State private var fiveSeconds: Bool
    @State private var sets: Int
    /// 0 means "not set" — reps are display-only.
    @State private var reps: Int
    @State private var rest: TimeInterval

    init(workoutID: UUID, kind: WorkoutKind, editingExercise: Exercise? = nil) {
        self.workoutID = workoutID
        self.kind = kind
        self.editingExercise = editingExercise
        _name = State(initialValue: editingExercise?.name ?? "")
        _instructions = State(initialValue: editingExercise?.instructions ?? "")
        _duration = State(initialValue: editingExercise?.duration ?? 60)
        _halfway = State(initialValue: editingExercise?.halfwayAlert ?? false)
        _fiveSeconds = State(initialValue: editingExercise?.fiveSecondsAlert ?? true)
        _sets = State(initialValue: editingExercise?.sets ?? 4)
        _reps = State(initialValue: editingExercise?.reps ?? 0)
        _rest = State(initialValue: editingExercise?.restDuration ?? 60)
    }

    private var isEditing: Bool {
        editingExercise != nil
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

    var body: some View {
        SheetScaffold(
            buttonTitle: isEditing ? "Save exercise" : "Create exercise",
            buttonEnabled: !name.trimmed.isEmpty,
            onSubmit: submit
        ) {
            LabeledField(label: "Name", placeholder: "Exercise name", text: $name)
            LabeledField(label: "Instructions", placeholder: "Optional instructions", text: $instructions)
            switch kind {
            case .timed:
                PickerField(label: "Duration", options: durationOptions,
                            display: { Format.mmss($0) }, selection: $duration)
                VStack(alignment: .leading, spacing: 20) {
                    Text("Alerts")
                        .font(.app(17, .medium))
                    CheckboxRow(title: "Halfway done", isOn: $halfway)
                    CheckboxRow(title: "5s left", isOn: $fiveSeconds)
                }
            case .untimed:
                HStack(alignment: .top, spacing: 12) {
                    PickerField(label: "Sets", options: Array(1...12),
                                display: { "\($0)" }, selection: $sets)
                    PickerField(label: "Reps per set", options: [0] + Array(1...50),
                                display: { $0 == 0 ? "Not set" : "\($0)" }, selection: $reps)
                }
                VStack(alignment: .leading, spacing: 10) {
                    PickerField(label: "Rest between sets", options: restOptions,
                                display: { Format.mmss($0) }, selection: $rest)
                    Text("Your target rest, for the record — the Sets tab can time it for you.")
                        .font(.app(14))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func submit() {
        guard var workout = store.workout(workoutID) else { return }
        if var exercise = editingExercise {
            apply(to: &exercise)
            workout.update(exercise: exercise)
        } else {
            var exercise = Exercise(name: name.trimmed)
            apply(to: &exercise)
            workout.items.append(exercise)
        }
        store.update(workout)
    }

    private func apply(to exercise: inout Exercise) {
        exercise.name = name.trimmed
        exercise.instructions = instructions.trimmed
        exercise.mode = kind == .timed ? .interval : .sets
        exercise.duration = duration
        exercise.halfwayAlert = halfway
        exercise.fiveSecondsAlert = fiveSeconds
        exercise.sets = sets
        exercise.reps = reps == 0 ? nil : reps
        exercise.restDuration = rest
    }
}
