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

/// One face of the turning card. Animatable, so `angle` interpolates per
/// frame and each face can decide its visibility from the card's ACTUAL
/// rotation: a hard swap at 90°, when the card is edge-on and either face
/// is a sliver — never a fade that leaks the other side early. With
/// `rotates` off (Reduce Motion) the same angle drives a plain cross-fade.
private struct FlipFace: ViewModifier, Animatable {
    var angle: Double
    let isBack: Bool
    let rotates: Bool

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        content
            // The back is pre-turned so it lands upright at 180.
            .rotation3DEffect(.degrees(rotates ? angle + (isBack ? 180 : 0) : 0),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.3)
            .opacity(faceOpacity)
    }

    private var faceOpacity: Double {
        if rotates {
            return (angle >= 90) == isBack ? 1 : 0
        }
        return isBack ? angle / 180 : 1 - angle / 180
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
            .modifier(FlipFace(angle: flipped ? 180 : 0, isBack: true,
                               rotates: !reduceMotion))
            .accessibilityHidden(!flipped)
            card {
                PondSceneView(monthKey: month, entries: entries, mode: .live,
                              paused: !isVisible || flipped, newIDs: newIDs)
            }
            .modifier(FlipFace(angle: flipped ? 180 : 0, isBack: false,
                               rotates: !reduceMotion))
            .accessibilityHidden(flipped)
        }
        .aspectRatio(0.8, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? .easeInOut(duration: 0.25)
                                : .spring(response: 0.7, dampingFraction: 0.85),
                   value: flipped)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onTapGesture {
            Haptics.selection()
            flipped.toggle()
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
                    flipped = true
                }
            }
        }
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
