# SwissTime

A deliberately simple workout timer for iOS, in Swiss style: Helvetica, black
on white, one accent blue, flat square cards, and a full-screen player whose
blue fill drains downward as the current exercise counts down.

## Structure

- **Workouts** contain a mix of **exercises** and **circuits**; a circuit is a
  named group of exercises repeated for a number of loops.
- Exercises have a name, optional instructions, a duration, and optional
  "halfway done" / "5s left" spoken alerts.
- Data is persisted as JSON in the app's Documents directory
  (`WorkoutStore.swift`).

## Player

`PlayerEngine` flattens a workout into steps (circuits × loops), runs a 5-second
"Workout starting soon" countdown, and tracks time against wall-clock dates so
it stays truthful across background throttling — if steps elapsed while asleep
it skips past them silently.

`AudioManager` speaks announcements (AVSpeechSynthesizer) and plays generated
beeps. Other apps' audio is ducked only while speaking/beeping, then restored.
A silent looping player plus the `audio` background mode keeps the timer running
with the screen off or the app in the background.

## Live Activity

The `SwissTimeWidget` extension renders a lock screen / Dynamic Island Live
Activity with a self-updating countdown and interactive pause/skip buttons.
The buttons are `LiveActivityIntent`s (in `Shared/`, compiled into both
targets) that post notifications the running `PlayerEngine` observes.

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

Launch with the `-autoPlayFirstWorkout` argument to jump straight into the
player for the first workout, `-autoOpenFirstWorkout` to open its detail
screen, or `-autoEditFirstWorkout` to open the detail screen in edit mode
(used for command-line UI verification).
