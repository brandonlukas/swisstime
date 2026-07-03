import SwiftUI

struct WorkoutListView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var pond: PondStore
    @State private var path: [UUID] = []
    @State private var showingCreate = false
    @State private var showingPond = false
    @State private var showingSettings = false
    @State private var playing: Workout?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        showingPond = true
                    } label: {
                        // The hero rests while anything hides it: the pool
                        // cover, the player, or a pushed detail screen
                        // (whose own Play cover this list can't see).
                        PondHeroCard(entries: pond.entries(in: .current),
                                     paused: showingPond || playing != nil
                                         || !path.isEmpty,
                                     newIDs: pond.newEntryIDs)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 24)
                    PageHeader(title: "Workouts")
                        .padding(.bottom, 24)
                    if store.workouts.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 16) {
                            // The play button overlays the link as a SIBLING:
                            // a button nested inside the link's label has to
                            // wait out gesture disambiguation, which made
                            // starting a workout feel laggy.
                            ForEach(store.sortedWorkouts) { workout in
                                NavigationLink(value: workout.id) {
                                    WorkoutCard(workout: workout)
                                }
                                .buttonStyle(.plain)
                                .overlay(alignment: .trailing) {
                                    if workout.kind == .timed, !workout.exercises.isEmpty {
                                        Button {
                                            Haptics.impact()
                                            playing = workout
                                        } label: {
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(workout.palette.onFill)
                                                .frame(width: 52, height: 52)
                                                .inkButton(workout.palette.fill)
                                        }
                                        .buttonStyle(PressableButtonStyle())
                                        .padding(.trailing, 20)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(PaperBackground())
            .navigationDestination(for: UUID.self) { id in
                WorkoutDetailView(workoutID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreate) {
                // Creating a workout drops you straight into it to add exercises;
                // the default swatch rotates through the palette.
                WorkoutFormView(
                    defaultColorIndex: store.workouts.count % Palette.all.count,
                    onCreated: { path = [$0] }
                )
            }
            .fullScreenCover(item: $playing) { workout in
                PlayerView(workout: workout)
            }
            .fullScreenCover(isPresented: $showingPond) {
                PondView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onAppear {
                // Debug hooks for command-line UI verification; each fires once.
                let arguments = ProcessInfo.processInfo.arguments
                if arguments.contains("-autoPlayFirstWorkout"), !DebugLaunch.didAutoPlay {
                    DebugLaunch.didAutoPlay = true
                    playing = store.sortedWorkouts.first { $0.kind == .timed }
                } else if arguments.contains("-autoOpenPond"), !DebugLaunch.didAutoOpenPond {
                    DebugLaunch.didAutoOpenPond = true
                    showingPond = true
                } else if arguments.contains("-autoOpenSettings"), !DebugLaunch.didAutoOpenSettings {
                    DebugLaunch.didAutoOpenSettings = true
                    showingSettings = true
                } else if arguments.contains("-autoOpenFirstWorkout")
                            || arguments.contains("-autoEditFirstWorkout"),
                          !DebugLaunch.didAutoOpen,
                          let first = store.sortedWorkouts.first {
                    DebugLaunch.didAutoOpen = true
                    path = [first.id]
                }
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            title: "No workouts yet.",
            message: "Create a workout — timed ones play with voice cues, untimed ones you log when they're done.",
            buttonTitle: "Create workout"
        ) {
            showingCreate = true
        }
        .padding(.top, 8)
    }
}

/// The live pool strip: this month's toys at a glance, tap for the full pool.
private struct PondHeroCard: View {
    let entries: [PondEntry]
    let paused: Bool
    let newIDs: Set<UUID>

    var body: some View {
        PondSceneView(monthKey: .current, entries: entries, mode: .hero,
                      paused: paused, newIDs: newIDs)
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottomLeading) {
                Text(MonthKey.current.monthName)
                    .display(13, .bold)
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 26)
                    .padding(.bottom, 23)
            }
            .overlay(alignment: .bottomTrailing) {
                if !entries.isEmpty {
                    Text("\(entries.count) afloat")
                        .overline(11, .medium)
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.horizontal, 26)
                        .padding(.bottom, 24)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .paperCard(24)
    }
}

private struct WorkoutCard: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(workout.palette.fill)
                    .frame(width: 14, height: 14)
                Text(workout.title)
                    .font(.app(18, .semibold))
            }
            if !workout.details.isEmpty {
                Text(workout.details)
                    .font(.app(15))
                    .foregroundStyle(.secondary)
            }
            Text(workout.summaryLine)
                .font(.app(15))
                .padding(.top, 2)
            if let line = Format.withLine(workout.exerciseNames) {
                Text(line)
                    .font(.app(15))
                    .foregroundStyle(.secondary)
            }
        }
        // Clears the play button that overlays the card's trailing edge.
        .padding(.trailing, workout.kind == .timed && !workout.exercises.isEmpty ? 68 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .paperCard()
    }
}
