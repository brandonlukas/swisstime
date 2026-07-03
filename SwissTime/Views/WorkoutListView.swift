import SwiftUI

struct WorkoutListView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var pond: PondStore
    @State private var path: [UUID] = []
    @State private var showingCreate = false
    @State private var showingPond = false
    @State private var playing: Workout?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        showingPond = true
                    } label: {
                        PondHeroCard(entries: pond.entries(in: .current))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 24)
                    Text("Workouts")
                        .font(.serifApp(32, .bold))
                        .padding(.bottom, 14)
                    InkRule()
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
                                    if !workout.items.isEmpty {
                                        Button {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
            .onAppear {
                // Debug hooks for command-line UI verification; each fires once.
                let arguments = ProcessInfo.processInfo.arguments
                if arguments.contains("-autoPlayFirstWorkout"), !DebugLaunch.didAutoPlay {
                    DebugLaunch.didAutoPlay = true
                    playing = store.sortedWorkouts.first
                } else if arguments.contains("-autoOpenPond"), !DebugLaunch.didAutoOpenPond {
                    DebugLaunch.didAutoOpenPond = true
                    showingPond = true
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
        VStack(alignment: .leading, spacing: 16) {
            Text("No workouts yet.")
                .font(.app(17, .medium))
            Text("Create a workout, then fill it with timed exercises and sets.")
                .font(.app(15))
                .foregroundStyle(.secondary)
            Button {
                showingCreate = true
            } label: {
                Text("Create workout")
                    .font(.app(16, .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 48)
                    .inkButton(.ink)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.top, 8)
    }
}

/// The live pond strip: this month's flock at a glance, tap for the full pond.
private struct PondHeroCard: View {
    let entries: [PondEntry]

    var body: some View {
        PondSceneView(monthKey: .current, entries: entries, mode: .hero)
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottomLeading) {
                Text(MonthKey.current.monthName)
                    .font(.serifApp(16, .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
            }
            .overlay(alignment: .bottomTrailing) {
                if !entries.isEmpty {
                    Text("\(entries.count) afloat")
                        .font(.app(12, .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 28)
                        .padding(.bottom, 25)
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
                    .font(.serifApp(20, .semibold))
            }
            if !workout.details.isEmpty {
                Text(workout.details)
                    .font(.app(15))
                    .foregroundStyle(.secondary)
            }
            Text(Format.summary(count: workout.items.count, duration: workout.totalDuration))
                .font(.app(15))
                .padding(.top, 2)
            if let line = Format.withLine(workout.exerciseNames) {
                Text(line)
                    .font(.app(15))
                    .foregroundStyle(.secondary)
            }
        }
        // Clears the play button that overlays the card's trailing edge.
        .padding(.trailing, workout.items.isEmpty ? 0 : 68)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .paperCard()
    }
}
