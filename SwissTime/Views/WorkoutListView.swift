import SwiftUI

struct WorkoutListView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var path: [UUID] = []
    @State private var showingCreate = false
    @State private var playing: Workout?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Workouts")
                        .font(.swiss(32, .bold))
                        .padding(.bottom, 14)
                    SwissRule()
                        .padding(.bottom, 24)
                    if store.workouts.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 16) {
                            ForEach(store.sortedWorkouts) { workout in
                                NavigationLink(value: workout.id) {
                                    WorkoutCard(workout: workout) {
                                        playing = workout
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(SwissGlassBackground())
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
                    defaultColorIndex: store.workouts.count % Color.swissPalette.count,
                    onCreated: { path = [$0] }
                )
            }
            .fullScreenCover(item: $playing) { workout in
                PlayerView(workout: workout)
            }
            .onAppear {
                // Debug hooks for command-line UI verification; each fires once.
                let arguments = ProcessInfo.processInfo.arguments
                if arguments.contains("-autoPlayFirstWorkout"), !DebugLaunch.didAutoPlay {
                    DebugLaunch.didAutoPlay = true
                    playing = store.sortedWorkouts.first
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
                .font(.swiss(17, .medium))
            Text("Create a workout, then fill it with timed exercises and circuits.")
                .font(.swiss(15))
                .foregroundStyle(.secondary)
            Button {
                showingCreate = true
            } label: {
                Text("Create workout")
                    .font(.swiss(16, .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 48)
                    .inkButton(.black)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.top, 8)
    }
}

private struct WorkoutCard: View {
    let workout: Workout
    let onPlay: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(workout.color)
                        .frame(width: 14, height: 14)
                    Text(workout.title)
                        .font(.swiss(20, .bold))
                }
                if !workout.details.isEmpty {
                    Text(workout.details)
                        .font(.swiss(15))
                        .foregroundStyle(.secondary)
                }
                Text(Format.summary(count: workout.items.count, duration: workout.totalDuration))
                    .font(.swiss(15))
                    .padding(.top, 2)
                if let line = Format.withLine(workout.exerciseNames) {
                    Text(line)
                        .font(.swiss(15))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if !workout.items.isEmpty {
                Button(action: onPlay) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .inkButton(workout.color)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard()
    }
}
