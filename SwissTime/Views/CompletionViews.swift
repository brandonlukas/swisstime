import SwiftUI

/// Identifiable wrapper so a freshly recorded entry can drive a sheet.
struct CompletionCeremony: Identifiable {
    let entryID: UUID
    var id: UUID { entryID }
}

/// The moment an untimed workout is logged: the earned toy drifts in,
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
                .display(20)
                .padding(.top, 30)
                .padding(.bottom, 6)
            Text(workout.title)
                .font(.app(15))
                .foregroundStyle(.secondary)
            EarnedToyView(colorIndex: workout.colorIndex,
                          shiny: pond.isShiny(entryID))
                .padding(.vertical, 10)
            if pond.isShiny(entryID) {
                Text("A gilded \(workout.palette.toy.displayName) — lucky you.")
                    .font(.app(13, .medium))
                    .foregroundStyle(Color.goldDeep)
                    .padding(.bottom, 22)
            } else {
                Text("Afloat in your \(MonthKey.current.monthName) pool")
                    .font(.app(13))
                    .foregroundStyle(Color.ink.opacity(0.55))
                    .padding(.bottom, 22)
            }
            NoteField(text: $note)
                .padding(.horizontal, 20)
            Spacer(minLength: 0)
            PrimaryButton(title: "Done") {
                hideKeyboard()
                dismiss()
            }
            .padding(20)
        }
        .presentationBackground(Color.paper)
        .presentationDetents([.height(450)])
        .presentationDragIndicator(.visible)
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

/// Add or rewrite the journal line on a pool entry, after the fact.
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

/// The earned toy drifts across a strip of tiled pool and settles with a
/// ripple — twinkling, if the roll came up gilded. Runs its own clock —
/// the player's TimelineView is paused once the workout ends.
struct EarnedToyView: View {
    let colorIndex: Int?
    var shiny = false
    @State private var appearedAt = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(appearedAt)
                let kind = Palette.toy(for: colorIndex)

                // A little cut of pool to arrive in.
                let poolRect = CGRect(x: 4, y: 4, width: size.width - 8,
                                      height: size.height - 8)
                let pool = Path(roundedRect: poolRect, cornerRadius: 12,
                                style: .continuous)
                context.fill(pool, with: .color(.poolWater))
                var water = context
                water.clip(to: pool)
                var grid = Path()
                var gx = poolRect.minX
                while gx < poolRect.maxX {
                    gx += 16
                    grid.move(to: CGPoint(x: gx + 1.2 * sin(t * 0.5 + gx / 9),
                                          y: poolRect.minY))
                    grid.addLine(to: CGPoint(x: gx + 1.2 * sin(t * 0.5 + gx / 9 + 1.4),
                                             y: poolRect.maxY))
                }
                grid.move(to: CGPoint(x: poolRect.minX, y: poolRect.midY))
                grid.addLine(to: CGPoint(x: poolRect.maxX, y: poolRect.midY))
                water.stroke(grid, with: .color(.white.opacity(0.13)), lineWidth: 1)
                water.stroke(pool, with: .color(.poolWaterDeep.opacity(0.5)),
                             lineWidth: 1.5)

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
                        water.stroke(
                            Path(ellipseIn: CGRect(x: pos.x - radius, y: pos.y - radius,
                                                   width: radius * 2, height: radius * 2)),
                            with: .color(.white.opacity(0.3 * (1 - fraction))),
                            lineWidth: 1)
                    }
                }

                let rotation: Angle = PoolToyArt.isDirectional(kind)
                    ? .zero : .radians(0.15 * t)
                PoolToyArt.draw(kind, in: water, at: pos, rotation: rotation,
                                wiggle: t * 2.0, scale: 0.8, shiny: shiny)
                if shiny, t > 1.6 {
                    PoolToyArt.drawGlint(in: water, at: pos, time: t + 5.6,
                                         phase: 0, scale: 0.9)
                    PoolToyArt.drawGlint(
                        in: water,
                        at: CGPoint(x: pos.x - 16, y: pos.y + 8),
                        time: t + 2.4, phase: 0, scale: 0.65)
                }
            }
        }
        .frame(width: 150, height: 56)
    }
}
