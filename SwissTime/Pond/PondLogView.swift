import SwiftUI

/// The pond's written record: every finished workout by month, newest first.
/// Swiping an entry away strikes it from the record — its creature leaves too.
struct PondLogView: View {
    @EnvironmentObject private var pond: PondStore
    @Environment(\.dismiss) private var dismiss
    @State private var notingEntry: PondEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
            VStack(alignment: .leading, spacing: 0) {
                Text("Logbook")
                    .font(.serifApp(30, .semibold))
                    .padding(.bottom, 6)
                Text("Every finished workout, on the record. Tap an entry to note how it went; swipe one away to strike it — its creature leaves the pond.")
                    .font(.app(14))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 14)
                InkRule()
            }
            .padding(.horizontal, 20)
            if pond.entries.isEmpty {
                Text("Nothing on the record yet.")
                    .font(.app(15))
                    .foregroundStyle(.secondary)
                    .padding(20)
                Spacer(minLength: 0)
            } else {
                List {
                    ForEach(pond.allMonths, id: \.self) { month in
                        let monthEntries = entries(in: month)
                        Section {
                            ForEach(monthEntries) { entry in
                                LogRow(entry: entry)
                                    .contentShape(Rectangle())
                                    .onTapGesture { notingEntry = entry }
                                    .listRowBackground(Color.paperCardFill.opacity(0.7))
                                    .listRowSeparatorTint(Color.hairline)
                            }
                            .onDelete { offsets in
                                for offset in offsets {
                                    pond.remove(monthEntries[offset].id)
                                }
                            }
                        } header: {
                            Text(month.title)
                                .font(.serifApp(18, .semibold))
                                .foregroundStyle(Color.ink)
                                .textCase(nil)
                                .padding(.leading, 4)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(PaperBackground())
        .preferredColorScheme(.light)
        .sheet(item: $notingEntry) { entry in
            NoteFormView(initial: entry.note ?? "") { pond.setNote($0, for: entry.id) }
        }
    }

    private func entries(in month: MonthKey) -> [PondEntry] {
        pond.entries(in: month).sorted { $0.completedAt > $1.completedAt }
    }
}

private struct LogRow: View {
    let entry: PondEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Palette.color(entry.colorIndex).fill)
                    .frame(width: 12, height: 12)
                Text(entry.workoutTitle)
                    .font(.app(16, .medium))
                Spacer(minLength: 8)
                Text(entry.completedAt.formatted(
                    .dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.app(14))
                    .foregroundStyle(.secondary)
            }
            if let note = entry.note, !note.isEmpty {
                Text(note)
                    .font(.serifApp(15))
                    .italic()
                    .foregroundStyle(Color.ink.opacity(0.7))
                    .padding(.leading, 24)
            }
        }
        .padding(.vertical, 4)
    }
}
