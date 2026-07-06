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

private struct PondPage: View {
    let month: MonthKey
    let entries: [PondEntry]
    let isCurrent: Bool
    let hasHistory: Bool
    let isVisible: Bool
    let newIDs: Set<UUID>
    /// The month's ledger is written on the pool floor. Tap the water and
    /// the pool drains to reveal it; tap again and it fills back over.
    @State private var drained = false
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

    /// The calendar is the pool floor; the water is a bottom-anchored mask
    /// over the scene, and draining is one built-in height animation — no
    /// custom animatable machinery, nothing to glitch. A thin crest rides
    /// the falling waterline, the app's signature move. Reduce Motion
    /// swaps the drain for a cross-fade. No hint glyph: the floor can
    /// afford to be a secret.
    private var flipCard: some View {
        ZStack {
            card {
                PoolCalendarView(month: month, entries: entries)
            }
            .rotation3DEffect(.degrees(flipsCards ? (drained ? 0 : -90) : 0),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.3)
            .animation(flipsCards ? (drained ? halfTurn.delay(0.22) : halfTurn) : nil,
                       value: drained)
            .accessibilityHidden(!drained)
            frontFace
                .rotation3DEffect(.degrees(flipsCards ? (drained ? 90 : 0) : 0),
                                  axis: (x: 0, y: 1, z: 0), perspective: 0.3)
                .animation(flipsCards ? (drained ? halfTurn : halfTurn.delay(0.22)) : nil,
                           value: drained)
                .accessibilityHidden(drained)
        }
        .aspectRatio(0.8, contentMode: .fit)
        .frame(maxWidth: .infinity)
        // No clip on the container: each face clips itself BEFORE the 3D
        // rotation, and a container clip shears the projected card flat at
        // the top and bottom mid-turn (the near edge grows past the
        // resting frame under perspective).
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onTapGesture {
            Haptics.selection()
            reveal()
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(drained ? "\(month.monthName) calendar" : "\(month.monthName) pool")
        .accessibilityHint(drained ? "Double tap to refill the pool."
                                   : "Double tap to drain the pool.")
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-pondFlip"),
               isCurrent, !DebugLaunch.didPondFlip {
                DebugLaunch.didPondFlip = true
                // Delayed, so a command-line run films the drain itself.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    reveal()
                }
                // ...and back again, so the return leg gets filmed too.
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                    reveal()
                }
            }
        }
    }

    /// 1 = full pool, 0 = floor showing. Reduce Motion keeps the water
    /// where it is and cross-fades instead.
    private var waterLevel: CGFloat {
        if reduceMotion { return 1 }
        if PondPage.transition == .flip { return 1 }
        return drained ? 0 : 1
    }

    /// Comparison switch while the reveal direction is decided: drain
    /// (water falls to the floor) or flip (two-phase card turn).
    enum RevealStyle { case drain, flip }
    static let transition: RevealStyle = .flip

    /// The pool side. In flip mode it's a full card — chrome rotates with
    /// it, and no mask exists to square off its shadow. In drain mode the
    /// scene rides chromeless under the waterline mask (a mask clips to
    /// its own rectangular bounds, so a shadow under it gets terminated in
    /// hard 90° corners just outside the rounded card — Brandon spotted
    /// the grey edges); the calendar card behind keeps the chrome.
    @ViewBuilder private var frontFace: some View {
        let scene = PondSceneView(monthKey: month, entries: entries, mode: .live,
                                  paused: !isVisible || drained, newIDs: newIDs)
        if flipsCards {
            card { scene }
        } else {
            scene
                .opacity(reduceMotion ? (drained ? 0 : 1) : 1)
                .mask(alignment: .bottom) {
                    GeometryReader { geo in
                        Rectangle()
                            .frame(height: geo.size.height * waterLevel)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .overlay {
                    // The waterline's crest, visible only mid-drain.
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.white.opacity(0.55))
                            .frame(height: 2)
                            .offset(y: geo.size.height * (1 - waterLevel) - 1)
                            .opacity(waterLevel > 0.02 && waterLevel < 0.98 ? 1 : 0)
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
    }

    /// Whether taps turn the card (vs draining the water).
    private var flipsCards: Bool {
        PondPage.transition == .flip && !reduceMotion
    }

    /// One face's share of the turn. The delay swaps sides with the
    /// direction — declared per face in its .animation(value:) modifier,
    /// exactly the community pattern: angles are pure functions of one
    /// state, and no imperative choreography exists to drop a delay (the
    /// withAnimation version did, on the return leg — filmed).
    private var halfTurn: Animation {
        .easeInOut(duration: 0.22)
    }

    private func reveal() {
        if flipsCards {
            drained.toggle()
            return
        }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25)
                                   : .easeInOut(duration: 0.55)) {
            drained.toggle()
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
