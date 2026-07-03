# SwissTime

A deliberately simple workout timer for iOS, in a soft storybook style:
warm paper backgrounds, ink-blue type (New York serif for titles, SF Pro for
everything else), matte cards with feathered shadows, muted natural swatches,
and a full-screen player whose pond-water fill drains downward as the current
exercise counts down.

## Structure

- **Workouts** are **timed** or **untimed** (`WorkoutKind`). A timed workout
  plays in the full-screen player; an untimed one is done at your own pace
  and logged with a "Mark as done" tap.
- Timed workouts hold interval **exercises**: a name, optional instructions,
  a duration, and optional "halfway done" / "5s left" spoken alerts. Untimed
  workouts hold sets × reps exercises with a target rest — the printed
  program, not a schedule.
- The **Sets** tab is a freestanding rest clock for untimed workouts
  (`SetCounterEngine`): pick sets and rest (remembered between launches),
  then the session is a single repeated tap, laid out like a stopwatch —
  Lap fills the clock with your rest, the water drains as it counts down,
  one beep marks zero, and the clock runs into the negative until the next
  Lap. No speech, no pause; the last Lap ("Done") exits. The Live Activity
  shows the rest countdown (its skip button doubles as Lap).
- Data is persisted as JSON in the app's Documents directory
  (`WorkoutStore.swift` → `workouts.json`, `PondStore.swift` → `pond.json`).

## The pond

Finishing a workout — playing a timed one to the end, or marking an untimed
one as done — adds one creature
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

Each pond entry can carry a journal note ("new PR, felt strong") — offered at
the completion ceremony, added or edited later by tapping an entry in the
Logbook.

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

- `-autoPlayFirstWorkout` — jump straight into the player for the first timed workout
- `-autoOpenFirstWorkout` / `-autoEditFirstWorkout` — open its detail screen
  (optionally in edit mode)
- `-autoMarkDone` — mark the opened untimed workout as done (completion ceremony)
- `-seedWorkouts` — replace the workout list in-memory with one untimed and
  one timed fake (not persisted by itself)
- `-seedPond` — populate the pond in-memory with fake entries for this month
  and past months (not persisted)
- `-autoOpenPond` — open the fullscreen pond; add `-pondShowPast` to land on
  the newest postcard
- `-autoOpenSets` / `-autoStartSets` — land on the Sets tab (optionally with a
  3-set counter already running); add `-autoAdvanceOnce` to end the first set
  a few seconds in
