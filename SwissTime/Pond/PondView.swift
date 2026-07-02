import SwiftUI

/// The fullscreen pond: this month lives and moves; swiping back through
/// past months turns them into kept postcards.
struct PondView: View {
    @EnvironmentObject private var pond: PondStore
    @Environment(\.dismiss) private var dismiss
    @State private var page: MonthKey = .current

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(20)
            TabView(selection: $page) {
                ForEach(pages, id: \.self) { month in
                    PondPage(month: month,
                             entries: pond.entries(in: month),
                             isCurrent: month == .current,
                             hasHistory: pages.count > 1)
                        .tag(month)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(PaperBackground())
        .onAppear {
            // Debug hook: jump straight to the newest postcard.
            if ProcessInfo.processInfo.arguments.contains("-pondShowPast"),
               let past = pond.monthsWithEntries.first {
                page = past
            }
        }
    }

    private var pages: [MonthKey] {
        [MonthKey.current] + pond.monthsWithEntries
    }
}

private struct PondPage: View {
    let month: MonthKey
    let entries: [PondEntry]
    let isCurrent: Bool
    let hasHistory: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(isCurrent ? month.monthName : month.title)
                .font(.serifApp(30, .semibold))
                .padding(.bottom, 6)
            Text(subtitle)
                .font(.app(14))
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)
            PondSceneView(monthKey: month, entries: entries,
                          mode: isCurrent ? .live : .frozen)
                .aspectRatio(0.8, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .paperCard(26)
                .overlay {
                    if !isCurrent {
                        // Past months read as kept postcards.
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.ink.opacity(0.16), lineWidth: 1)
                    }
                }
            if isCurrent, entries.isEmpty {
                Text("Still water. Finish a workout and a duck moves in.")
                    .font(.app(15))
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)
            } else if isCurrent, !hasHistory {
                Text("Past months will collect here.")
                    .font(.app(13))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .padding(.top, 20)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private var subtitle: String {
        if entries.isEmpty { return "No workouts finished yet" }
        return "\(entries.count) workout\(entries.count == 1 ? "" : "s") finished"
    }
}
