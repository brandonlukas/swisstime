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
                SheetCloseButton {
                    hideKeyboard()
                    dismiss()
                }
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
            PrimaryButton(title: buttonTitle,
                          fill: buttonEnabled ? Color.ink : Color.ink.opacity(0.25)) {
                hideKeyboard()
                onSubmit()
                dismiss()
            }
            .disabled(!buttonEnabled)
            .padding(20)
        }
        .background(Color.paper.ignoresSafeArea())
    }
}

struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    /// Hard cap, enforced as typed — titles and names render in cards,
    /// breadcrumbs, and the Live Activity, and unbounded text breaks them.
    var maxLength: Int?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.app(17, .medium))
                Spacer()
                // The cap is silent until it's near — then say where it is,
                // so truncation never reads as a broken keyboard.
                if let maxLength, focused, text.count >= maxLength - 8 {
                    Text("\(text.count)/\(maxLength)")
                        .font(.app(13))
                        .monospacedDigit()
                        .foregroundStyle(text.count >= maxLength
                                         ? Color.signalRed : .secondary)
                }
            }
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
                .onChange(of: text) { _, newValue in
                    if let maxLength, newValue.count > maxLength {
                        text = String(newValue.prefix(maxLength))
                    }
                }
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

/// Tappable row of the curated water swatches, with a living portrait of
/// the pool toy that color earns.
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
                ToyPortrait(kind: Palette.color(selection).toy)
                    .frame(width: 76, height: 52)
                    .id(Palette.color(selection).toy)
                    .transition(.opacity)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Palette.color(selection).name)
                        .font(.app(16, .medium))
                    Text(Palette.color(selection).toy.pickerLine)
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
                        // Eased, so a selection that also restyles the whole
                        // window (the theme control) blends into that change
                        // instead of snapping a beat ahead of it.
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selection = option
                        }
                        hideKeyboard()
                    } label: {
                        Text(display(option))
                            .font(.app(16, selection == option ? .medium : .regular))
                            .foregroundStyle(selection == option ? Color.onInk : Color.ink)
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
                    Haptics.selection()
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
            LabeledField(label: "Title", placeholder: "Title", text: $title,
                         maxLength: 40)
            LabeledField(label: "Description", placeholder: "Optional description",
                         text: $details, maxLength: 120)
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
                for index in updated.exercises.indices {
                    updated.exercises[index].mode = kind == .timed ? .interval : .sets
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

/// New-exercise defaults: each saved exercise becomes the next form's
/// starting point — the numbers this user actually lifts with, not
/// factory settings. Editing an existing exercise never consults these.
enum ExerciseDefaults {
    private static let store = UserDefaults.standard

    static var duration: TimeInterval {
        store.object(forKey: "exercise.lastDuration") as? Double ?? 60
    }
    static var halfway: Bool {
        store.object(forKey: "exercise.lastHalfway") as? Bool ?? false
    }
    static var fiveSeconds: Bool {
        store.object(forKey: "exercise.lastFiveSeconds") as? Bool ?? true
    }
    static var sets: Int {
        store.object(forKey: "exercise.lastSets") as? Int ?? 4
    }
    static var reps: Int {
        store.object(forKey: "exercise.lastReps") as? Int ?? 0
    }

    /// Only the fields the form actually showed — a timed save must not
    /// clobber the remembered sets shape, nor the other way around.
    static func remember(_ exercise: Exercise) {
        switch exercise.mode {
        case .interval:
            store.set(exercise.duration, forKey: "exercise.lastDuration")
            store.set(exercise.halfwayAlert, forKey: "exercise.lastHalfway")
            store.set(exercise.fiveSecondsAlert, forKey: "exercise.lastFiveSeconds")
        case .sets:
            store.set(exercise.sets, forKey: "exercise.lastSets")
            store.set(exercise.reps ?? 0, forKey: "exercise.lastReps")
        }
    }
}

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

    init(workoutID: UUID, kind: WorkoutKind, editingExercise: Exercise? = nil) {
        self.workoutID = workoutID
        self.kind = kind
        self.editingExercise = editingExercise
        _name = State(initialValue: editingExercise?.name ?? "")
        _instructions = State(initialValue: editingExercise?.instructions ?? "")
        _duration = State(initialValue: editingExercise?.duration ?? ExerciseDefaults.duration)
        _halfway = State(initialValue: editingExercise?.halfwayAlert ?? ExerciseDefaults.halfway)
        _fiveSeconds = State(initialValue: editingExercise?.fiveSecondsAlert ?? ExerciseDefaults.fiveSeconds)
        _sets = State(initialValue: editingExercise?.sets ?? ExerciseDefaults.sets)
        // `editingExercise?.reps` can't tell "not editing" from "editing,
        // reps unset" — map keeps an unset 0 from picking up the default.
        _reps = State(initialValue: editingExercise.map { $0.reps ?? 0 } ?? ExerciseDefaults.reps)
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

    var body: some View {
        SheetScaffold(
            buttonTitle: isEditing ? "Save exercise" : "Create exercise",
            buttonEnabled: !name.trimmed.isEmpty,
            onSubmit: submit
        ) {
            LabeledField(label: "Name", placeholder: "Exercise name", text: $name,
                         maxLength: 40)
            LabeledField(label: "Instructions", placeholder: "Optional instructions",
                         text: $instructions, maxLength: 120)
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
                // No rest field: untimed exercises never play, so a target
                // rest would be write-only — the Sets tab times rest live.
                HStack(alignment: .top, spacing: 12) {
                    PickerField(label: "Sets", options: Array(1...12),
                                display: { "\($0)" }, selection: $sets)
                    PickerField(label: "Reps per set", options: [0] + Array(1...50),
                                display: { $0 == 0 ? "Not set" : "\($0)" }, selection: $reps)
                }
            }
        }
    }

    private func submit() {
        guard var workout = store.workout(workoutID) else { return }
        var exercise = editingExercise ?? Exercise(name: name.trimmed)
        apply(to: &exercise)
        if editingExercise != nil {
            workout.update(exercise: exercise)
        } else {
            workout.exercises.append(exercise)
        }
        store.update(workout)
        ExerciseDefaults.remember(exercise)
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
        // restDuration is untouched: the form no longer edits it, and an
        // existing exercise keeps whatever its file already says.
    }
}
