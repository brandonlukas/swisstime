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
                .accessibilityLabel("Logbook")
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
                        // Pull-to-dismiss re-renders this body per drag
                        // frame with freshly allocated inputs; content
                        // equality lets every unchanged page skip its whole
                        // subtree — both faces, where SceneCache shields
                        // only the water.
                        .equatable()
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

private struct PondPage: View, Equatable {
    let month: MonthKey
    let entries: [PondEntry]
    let isCurrent: Bool
    let hasHistory: Bool
    let isVisible: Bool
    let newIDs: Set<UUID>

    static func == (a: PondPage, b: PondPage) -> Bool {
        a.month == b.month && a.entries == b.entries
            && a.isCurrent == b.isCurrent && a.hasHistory == b.hasHistory
            && a.isVisible == b.isVisible && a.newIDs == b.newIDs
    }
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

    /// The community two-phase card flip: each face turns only its own
    /// quarter, the delay declared per face and swapping sides with the
    /// direction — the hand-off happens edge-on, where neither face is
    /// visible. Reduce Motion cross-fades instead. No hint glyph: the
    /// back can afford to be a secret.
    private var flipCard: some View {
        ZStack {
            card {
                PoolCalendarView(month: month, entries: entries)
            }
            .rotation3DEffect(.degrees(reduceMotion ? 0 : (flipped ? 0 : -90)),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.3)
            .animation(reduceMotion ? nil
                       : (flipped ? halfTurn.delay(Self.flipHalfDuration) : halfTurn),
                       value: flipped)
            .opacity(reduceMotion && !flipped ? 0 : 1)
            // The Reduce Motion cross-fade is declared here, below the
            // opacity it animates — never left to whoever mutates flipped.
            .animation(reduceMotion ? .easeInOut(duration: 0.25) : nil,
                       value: flipped)
            .accessibilityHidden(!flipped)
            card {
                PondSceneView(monthKey: month, entries: entries, mode: .live,
                              paused: !isVisible || flipped, newIDs: newIDs)
            }
            .rotation3DEffect(.degrees(reduceMotion ? 0 : (flipped ? 90 : 0)),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.3)
            .animation(reduceMotion ? nil
                       : (flipped ? halfTurn : halfTurn.delay(Self.flipHalfDuration)),
                       value: flipped)
            .opacity(reduceMotion && flipped ? 0 : 1)
            .animation(reduceMotion ? .easeInOut(duration: 0.25) : nil,
                       value: flipped)
            .accessibilityHidden(flipped)
        }
        .aspectRatio(0.8, contentMode: .fit)
        .frame(maxWidth: .infinity)
        // No clip on the container: each face clips itself BEFORE the 3D
        // rotation, and a container clip shears the projected card flat at
        // the top and bottom mid-turn (the near edge grows past the
        // resting frame under perspective).
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onTapGesture {
            reveal()
        }
        // Pool up: one button. Calendar up: the day cells stay navigable
        // and the flip lives in the actions rotor — a double-tap on a
        // focused day would otherwise land in the tap gesture and flip
        // the card away mid-read.
        .accessibilityElement(children: flipped ? .contain : .ignore)
        .accessibilityAddTraits(flipped ? [] : .isButton)
        .accessibilityLabel(flipped ? "\(accessibilityMonth) calendar"
                                    : "\(accessibilityMonth) pool")
        .accessibilityHint(flipped ? "" : "Double tap to flip the pool over.")
        .accessibilityAction(named: flipped ? "Flip back to the pool"
                                            : "Flip to the calendar") {
            reveal()
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-pondFlip"),
               isCurrent, !DebugLaunch.didPondFlip {
                DebugLaunch.didPondFlip = true
                // Delayed, so a command-line run films the flip itself.
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

    /// Half the turn: the out-going face's whole animation, and exactly
    /// the delay the in-coming face waits — one constant, so tuning the
    /// speed can never split the edge-on hand-off.
    static let flipHalfDuration: TimeInterval = 0.22

    /// One face's share of the turn. The delay swaps sides with the
    /// direction — declared per face in its .animation(value:) modifier,
    /// exactly the community pattern: angles are pure functions of one
    /// state, and no imperative choreography exists to drop a delay (the
    /// withAnimation version did, on the return leg — filmed).
    private var halfTurn: Animation {
        .easeInOut(duration: Self.flipHalfDuration)
    }

    /// Every animation is declared on the faces; flipping is just a fact.
    private func reveal() {
        Haptics.selection()
        flipped.toggle()
    }

    /// Past pools carry their year — two Julys must not sound alike.
    private var accessibilityMonth: String {
        isCurrent ? month.monthName : month.title
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
