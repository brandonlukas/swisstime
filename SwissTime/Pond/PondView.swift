import SwiftUI

/// The fullscreen pool: swipe back through past months — every pool stays
/// alive, still drifting whatever it earned.
struct PondView: View {
    @EnvironmentObject private var pond: PondStore
    @Environment(\.dismiss) private var dismiss
    @State private var page: MonthKey = .current
    @State private var showingLog = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        // Both are Set-building scans over every pond entry; hoisted so the
        // ForEach evaluates them once instead of once per rendered page.
        let pages = self.pages
        let newIDs = pond.newEntryIDs
        VStack(spacing: 0) {
            HStack {
                SheetCloseButton { dismiss() }
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
                             hasHistory: pages.count > 1,
                             isVisible: month == page,
                             newIDs: newIDs)
                        .tag(month)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        // Simultaneous, so horizontal drags stay with the month-paging
        // TabView underneath.
        .pullToDismiss(offset: $dragOffset, simultaneous: true) { dismiss() }
        // The visit is over — new arrivals have had their sparkle.
        .onDisappear { pond.markPoolSeen() }
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
}

/// A face's visibility through the flip. The rotation itself is a plain
/// rotation3DEffect — built-in, reliably interpolated — and only this
/// switch needs custom animation: `.rounded()` flips at 0.5, exactly when
/// the card passes edge-on, synchronized because opacity and rotation ride
/// the same curve. With `steps` off (Reduce Motion) the same data is a
/// plain cross-fade.
private struct FaceVisibility: ViewModifier, Animatable {
    var pct: Double
    let steps: Bool

    var animatableData: Double {
        get { pct }
        set { pct = newValue }
    }

    func body(content: Content) -> some View {
        content.opacity(steps ? pct.rounded() : pct)
    }
}

private struct PondPage: View {
    let month: MonthKey
    let entries: [PondEntry]
    let isCurrent: Bool
    let hasHistory: Bool
    let isVisible: Bool
    let newIDs: Set<UUID>
    /// The pool card is a postcard: the month's ledger is written on the
    /// back. Tap anywhere on the water to turn it over.
    @State private var flipped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(isCurrent ? month.monthName : month.title)
                .display(28)
                .padding(.bottom, 8)
            Text(subtitle)
                .appFont(14)
                .foregroundStyle(Color.inkSecondary)
                .padding(.bottom, 20)
            flipCard
            if isCurrent, entries.isEmpty {
                Text("Flat water. Finish a workout and a toy floats in.")
                    .appFont(15)
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.top, 20)
            } else if isCurrent, !hasHistory {
                Text("Past months will collect here.")
                    .appFont(13)
                    .foregroundStyle(Color.inkSecondary.opacity(0.8))
                    .padding(.top, 20)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    /// Front: the pool, toys afloat. Back: the month's calendar. The faces
    /// trade places in a hard switch at the card's edge-on moment — a fade
    /// would show the new face before the turn. No hint glyph: the pool's
    /// calm is the feature, and the back can afford to be a secret.
    private var flipCard: some View {
        ZStack {
            card {
                PoolCalendarView(month: month, entries: entries)
            }
            .modifier(FaceVisibility(pct: flipped ? 1 : 0, steps: !reduceMotion))
            .rotation3DEffect(.degrees(reduceMotion ? 0 : (flipped ? 0 : -180)),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.3)
            .accessibilityHidden(!flipped)
            card {
                PondSceneView(monthKey: month, entries: entries, mode: .live,
                              paused: !isVisible || flipped, newIDs: newIDs)
            }
            .modifier(FaceVisibility(pct: flipped ? 0 : 1, steps: !reduceMotion))
            .rotation3DEffect(.degrees(reduceMotion ? 0 : (flipped ? 180 : 0)),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.3)
            .accessibilityHidden(flipped)
        }
        .aspectRatio(0.8, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        // Explicit withAnimation, not .animation(value:): the implicit
        // modifier animates the built-in rotations but skips the custom
        // FaceVisibility's animatableData, which then steps instantly —
        // both faces swap at the tap and only the rotation plays.
        .onTapGesture {
            Haptics.selection()
            withAnimation(flipAnimation) {
                flipped.toggle()
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(flipped ? "\(month.monthName) calendar" : "\(month.monthName) pool")
        .accessibilityHint("Double tap to flip the pool over.")
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-pondFlip"),
               isCurrent, !DebugLaunch.didPondFlip {
                DebugLaunch.didPondFlip = true
                // Delayed, so a command-line run films the flip itself.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(flipAnimation) {
                        flipped = true
                    }
                }
            }
        }
    }

    private var flipAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.25)
                     : .spring(response: 0.7, dampingFraction: 0.85)
    }

    /// Both sides share the card chrome, so the flip reads as one object.
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .paperCard(26)
            .overlay {
                if !isCurrent {
                    // A quiet frame marks the kept months.
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.ink.opacity(0.16), lineWidth: 1)
                }
            }
    }

    private var subtitle: String {
        if entries.isEmpty { return "No workouts finished yet" }
        return "\(entries.count) workout\(entries.count == 1 ? "" : "s") finished"
    }
}
