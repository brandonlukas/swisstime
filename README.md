# SwissTime

A deliberately simple workout timer for iOS, in a soft storybook style:
warm paper backgrounds, ink-blue type (New York serif for titles, SF Pro for
everything else), matte cards with feathered shadows, muted natural swatches,
and a full-screen player whose pond-water fill drains downward as the current
exercise counts down.

## Structure

- **Workouts** contain a mix of **exercises** and **circuits**; a circuit is a
  named group of exercises repeated for a number of loops.
- Exercises have a name, optional instructions, a duration, and optional
  "halfway done" / "5s left" spoken alerts.
- Data is persisted as JSON in the app's Documents directory
  (`WorkoutStore.swift` → `workouts.json`, `PondStore.swift` → `pond.json`).

## The pond

Finishing a workout (reaching the player's `.finished` phase) adds one creature
to this month's pond — an animated, top-down scene of grainy indigo water,
reeds, and cattails that lives at the top of the workout list and expands to
full screen. The creature is determined by the workout's palette swatch:

| Swatch | Creature |
|---|---|
| Reed | white drake |
| Pond | shadow fish (surfaces now and then) |
| Ochre | duckling |
| Clay | koi |
| Mist | grey goose |
| Cattail | hen duck |

The pond resets each month, but history persists: past months are kept as
frozen postcards you can swipe back through in the fullscreen view. All of it
is code-drawn (`SwissTime/Pond/`): `PondScene` precomputes seeded layout
(per-month seed for reeds/water, per-entry seed for each creature's wander) and
renders motion as a pure function of time into a `Canvas`, so the live pond,
the low-fps hero strip, and static postcards share one code path.

## Player

`PlayerEngine` flattens a workout into steps (circuits × loops), runs a 5-second
"Workout starting soon" countdown, and tracks time against wall-clock dates so
it stays truthful across background throttling — if steps elapsed while asleep
it skips past them silently. Finishing records a `PondEntry` and the completion
card shows the earned creature paddling in.

`AudioManager` speaks announcements (AVSpeechSynthesizer) and plays generated
beeps. Other apps' audio is ducked only while speaking/beeping, then restored.
A silent looping player plus the `audio` background mode keeps the timer running
with the screen off or the app in the background.

## Live Activity

The `SwissTimeWidget` extension renders a lock screen / Dynamic Island Live
Activity with a self-updating countdown and interactive pause/skip buttons.
The buttons are `LiveActivityIntent`s (in `Shared/`, compiled into both
targets) that post notifications the running `PlayerEngine` observes. The lock
screen banner matches the app's paper/ink style; the widget keeps its palette
and font helpers local rather than importing app code.

## Flow

The list is play-first: each card has a play button, and recently played
workouts sort to the top. The detail screen is read-only until you tap Edit,
which reveals reorder handles, delete, duplicate, and workout rename/delete;
tapping a row outside edit mode starts the workout from that exercise.

## Building

Open `SwissTime.xcodeproj` in Xcode 16+ and run the `SwissTime` scheme, or:

```sh
xcodebuild -project SwissTime.xcodeproj -scheme SwissTime \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Debug launch arguments (used for command-line UI verification):

- `-autoPlayFirstWorkout` — jump straight into the player for the first workout
- `-autoOpenFirstWorkout` / `-autoEditFirstWorkout` — open its detail screen
  (optionally in edit mode)
- `-seedPond` — populate the pond in-memory with fake entries for this month
  and past months (not persisted)
- `-autoOpenPond` — open the fullscreen pond; add `-pondShowPast` to land on
  the newest postcard
