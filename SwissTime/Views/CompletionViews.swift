import SwiftUI

/// Identifiable wrapper so a freshly recorded entry can drive a sheet.
struct CompletionCeremony: Identifiable {
    let entryID: UUID
    var id: UUID { entryID }
}

/// The moment an untimed workout is logged: the earned creature paddles in,
/// and there's room — never a demand — for a line about how it went.
struct CompletionCeremonyView: View {
    @EnvironmentObject private var pond: PondStore
    @Environment(\.dismiss) private var dismiss
    let workout: Workout
    let entryID: UUID
    @State private var note = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Complete")
                .font(.serifApp(26, .semibold))
                .padding(.top, 30)
                .padding(.bottom, 4)
            Text(workout.title)
                .font(.app(15))
                .foregroundStyle(.secondary)
            EarnedCreatureView(colorIndex: workout.colorIndex)
                .padding(.vertical, 10)
            Text("Added to your \(MonthKey.current.monthName) pond")
                .font(.app(13))
                .foregroundStyle(Color.ink.opacity(0.55))
                .padding(.bottom, 22)
            NoteField(text: $note)
                .padding(.horizontal, 20)
            Spacer(minLength: 0)
            Button {
                hideKeyboard()
                dismiss()
            } label: {
                Text("Done")
                    .font(.app(17, .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .inkButton(.ink)
            }
            .buttonStyle(.plain)
            .padding(20)
        }
        .presentationBackground(Color.paper)
        .presentationDetents([.height(450)])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.light)
        // Saving on the way out covers Done and a swipe-down alike.
        .onDisappear { pond.setNote(note, for: entryID) }
    }
}

/// The journal line input — bordered like the form fields, grows a few lines.
struct NoteField: View {
    @Binding var text: String
    var placeholder = "How did it go? New PR, felt strong..."
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .font(.app(16))
            .lineLimit(2...5)
            .focused($focused)
            .padding(12)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(focused ? Color.ink : Color.fieldBorder, lineWidth: 1)
            )
    }
}

/// Add or rewrite the journal line on a pond entry, after the fact.
struct NoteFormView: View {
    let initial: String
    let onSave: (String) -> Void
    @State private var text: String

    init(initial: String, onSave: @escaping (String) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _text = State(initialValue: initial)
    }

    var body: some View {
        SheetScaffold(
            buttonTitle: "Save note",
            buttonEnabled: true,
            onSubmit: { onSave(text) }
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Note")
                    .font(.app(17, .medium))
                NoteField(text: $text)
            }
        }
    }
}

/// The earned creature paddles across a little puddle and settles with a
/// ripple. Runs its own clock — the player's TimelineView is paused once
/// the workout ends.
struct EarnedCreatureView: View {
    let colorIndex: Int?
    @State private var appearedAt = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(appearedAt)
                let kind = Palette.creature(for: colorIndex)

                // A soft puddle to arrive in.
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 5))
                    layer.fill(
                        Path(ellipseIn: CGRect(x: 8, y: size.height / 2 - 17,
                                               width: size.width - 16, height: 34)),
                        with: .color(.pondWater.opacity(0.85)))
                }

                let k = min(1, t / 2.5)
                let ease = 1 - pow(1 - k, 3)
                let x = -20 + (size.width / 2 + 20) * ease
                let y = size.height / 2 + sin(t * 1.8) * 1.5
                let pos = CGPoint(x: x, y: y)

                if t > 2.4 {
                    let age = (t - 2.4).truncatingRemainder(dividingBy: 6)
                    if age < 2.2 {
                        let fraction = age / 2.2
                        let radius = 5 + 13 * fraction
                        context.stroke(
                            Path(ellipseIn: CGRect(x: pos.x - radius, y: pos.y - radius,
                                                   width: radius * 2, height: radius * 2)),
                            with: .color(.white.opacity(0.3 * (1 - fraction))),
                            lineWidth: 1)
                    }
                }

                if let style = PondCreatureArt.birdStyle(for: kind) {
                    PondCreatureArt.drawBird(
                        in: context, style: style, at: pos, heading: .zero,
                        wiggle: t * 2.4, wakeOpacity: 0.3 * (1 - k), scale: 0.9)
                } else {
                    PondCreatureArt.drawFish(
                        in: context, kind: kind, at: pos, heading: .zero,
                        tailWiggle: t * 3.2, opacity: 0.75, scale: 0.9)
                }
            }
        }
        .frame(width: 150, height: 56)
    }
}
