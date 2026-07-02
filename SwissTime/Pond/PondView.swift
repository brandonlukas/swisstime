import SwiftUI

/// The fullscreen pond: this month lives and moves; swiping back through
/// past months turns them into kept postcards.
struct PondView: View {
    @EnvironmentObject private var pond: PondStore
    @Environment(\.dismiss) private var dismiss
    @State private var page: MonthKey = .current
    @State private var showingLog = false
    @State private var dragOffset: CGFloat = 0

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
                Button {
                    showingLog = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
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
        // The paper moves with the pull, so the pond lifts like a sheet and
        // the home screen shows through (the cover backdrop is clear). The
        // shadow hangs on the flattened opaque paper only — shadowing the
        // whole hierarchy would make every sublayer cast one, darkening
        // the entire screen.
        .background(
            PaperBackground()
                .compositingGroup()
                .shadow(color: .black.opacity(dragOffset > 0 ? 0.18 : 0), radius: 24, y: -8)
        )
        .offset(y: dragOffset)
        .simultaneousGesture(dismissDrag)
        .presentationBackground(.clear)
        .sheet(isPresented: $showingLog) {
            PondLogView()
        }
        .onAppear {
            // Debug hooks: jump straight to the newest postcard / the logbook.
            if ProcessInfo.processInfo.arguments.contains("-pondShowPast"),
               let past = pond.monthsWithEntries.first {
                page = past
            }
            if ProcessInfo.processInfo.arguments.contains("-pondOpenLog") {
                showingLog = true
            }
            if ProcessInfo.processInfo.arguments.contains("-pondPulled") {
                dragOffset = 480
            }
        }
    }

    private var pages: [MonthKey] {
        [MonthKey.current] + pond.monthsWithEntries
    }

    /// Pull the page down to leave; horizontal drags stay with the
    /// month-paging TabView underneath.
    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard value.translation.height > abs(value.translation.width) else { return }
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                if dragOffset > 0, dragOffset > 120 || value.predictedEndTranslation.height > 300 {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        dragOffset = 0
                    }
                }
            }
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
