# Lido

A deliberately simple workout timer for iOS, styled after liminal-pool
posters: flat tiled swimming-pool blues on a cool pale deck, hard afternoon
sun shadows, expanded-caps grotesque titles over hairline rules, and a
full-screen player whose tilt-reactive water drains as the exercise counts
down. Every finished workout drops a toy in your pool.

(The repo, bundle id, and code names still say SwissTime; the product is
Lido. The app ships three code-drawn icons — **The Pool** (a rubber duck on
tiled water, the default), **Deep End** (the pool corner with its ladder),
and **Pool Type** (LIDO in the poster caps) — selectable in Settings, each
with a "night swim" dark variant and a max-contrast tinted one. All are
rendered by `Design/lido_icon.swift`.)

## Structure

- **Workouts** are **timed** or **untimed** (`WorkoutKind`). A timed workout
  plays in the full-screen player. An untimed one gets a **walkthrough**:
  Start lays its exercises out as a grid of tiles, and one tap sinks each
  finished exercise under water in the workout's color — any order, no
  timers, progress persisting across launches until Finish runs the
  ceremony (the Sets tab times rests alongside; the screen is pushed, not
  modal, so the tab bar stays reachable). "Mark as done" remains for
  off-book days.
- **Exercises** carry a per-exercise mode (`Exercise.mode`): **interval**
  (a duration, auto-advancing, hands-free — with optional "halfway done" /
  "5s left" spoken alerts) or **sets** (sets × reps you end with a tap, and
  a rest clock between sets). Untimed workouts hold sets × reps as the
  printed program, not a schedule.
- Spoken cues are clocks, announcements are context: timed cues always
  interrupt whatever is being spoken so they can never arrive late. On steps
  of ten seconds or less the two alerts collapse into a single "5 seconds
  left" at the midpoint (which *is* the five-second mark); the exercise form
  says so when it applies.
- The **Sets** tab is a freestanding rest clock for untimed workouts
  (`SetCounterEngine`): pick sets and rest (remembered between launches),
  then the session is a single repeated tap, laid out like a stopwatch —
  Lap fills the clock with your rest, the water drains as it counts down,
  one beep marks zero, and the clock runs into the negative until the next
  Lap. Optional "Halfway done" / "5 seconds left" voices ride the same
  rules as the player's alerts. The Live Activity shows the rest countdown
  (its skip button doubles as Lap).
- A first launch isn't a blank page: the empty workout list offers three
  curated **starter workouts** (one sets-mode, two timed) that one tap
  adopts into the library, fully editable. The shelf lives only in the
  empty state and retires itself the moment anything exists.
- Data is persisted as JSON in the **App Group container**
  (`group.com.brandonlukas.swisstime` — `workouts.json`, `pond.json`), so
  the widget process can read it; both stores migrate pre-group files out
  of Documents once, and reload widget timelines on every save.

## The pool

Finishing a workout — playing a timed one to the end, or marking an untimed
one as done — floats one toy in this month's pool: an animated, top-down
tiled-water scene (refracting grout, caustics, a chrome ladder) that lives
at the top of the workout list and expands to full screen. The toy is
determined by the workout's palette swatch:

| Swatch | Toy |
|---|---|
| Shallow | swim ring |
| Pool | rubber duck |
| Deep | orca |
| Chlorine | beach ball |
| Periwinkle | flamingo |
| Midnight | lilo |

One finish in twenty comes up **gilded** — a pearl-and-gold colorway of the
earned toy, signaled quietly (a gold ceremony line, an occasional glint, a
thin ring in the logbook). The pool resets monthly; past months stay
swipeable and alive. Tap any pool and the card flips over — the month's
ledger is written on the back: a calendar whose days fill with their
workouts' colors (two workouts split the tile on the diagonal), empty days
staying quiet deck tile. No streaks, no tallies — the ledger celebrates
presence and never advertises absence. Everything is code-drawn (`SwissTime/Pond/`):
`PondScene` precomputes seeded layout and renders motion as a pure function
of time into a `Canvas`, with toys bump-and-sliding via deterministic
relaxation, so the live pool, the hero strip, and past months share one
code path. The player's waterline is a living surface too
(`Views/WaterSurface.swift`): CoreMotion gravity sloshes it, step changes
splash it, Reduce Motion and Low Power calm it.

Each pool entry can carry a journal note ("new PR, felt strong") — offered
at the completion ceremony, edited later in the Logbook.

## Player

`PlayerEngine` flattens a workout into steps, runs a 5-second "Workout
starting soon" countdown, and tracks time against wall-clock dates so it
stays truthful across background throttling — steps that elapsed while
asleep are skipped silently, and cues whose moment passed are never spoken
late. Finishing records a `PondEntry` and the completion card shows the
earned toy paddling in.

`AudioManager` speaks announcements (AVSpeechSynthesizer, with a
user-selectable voice) and plays generated beeps. Other apps' audio is
ducked only while speaking/beeping, then restored; all session calls run on
a serial queue off the main thread. A silent looping player plus the
`audio` background mode keeps the timer running with the screen off — the
point is spoken cues with the phone locked mid-workout.

## Widgets, Live Activity, and doors

The `SwissTimeWidget` extension ships:

- a **Live Activity** (lock screen / Dynamic Island) with a self-updating
  countdown and interactive pause/skip buttons (`LiveActivityIntent`s in
  `Shared/`, posting notifications the running engine observes);
- **home-screen widgets** that show progress, never prompts: *This week*
  (small/medium — done days as squares in their workout's color, an honest
  tally with a unit word so it can't read as a date) and *The pool*
  (small/medium — a still of this month's pool, one dot per toy);
- **lock-screen accessories**: the week as a poster numeral + lettered
  strip, an inline tally, and a *Start Sets* launcher;
- a **Control Center / Action button control** that opens the app with the
  Sets counter armed. Its intent (`StartSetsIntent`) lives in `Shared/`
  because controls resolve their intent against the *parent app's* App
  Intents metadata — extension-only intents render but press dead.

Both launcher doors funnel through `swisstime://sets/start` semantics into
one request (`DeepLink.requestSetsStart()`), consumed by whichever view is
alive to hear it.

## Settings and themes

A gear on the Workouts toolbar opens Settings (a sheet), organized by
quiet overline groups. **Appearance**: the theme (System / Day / **Night
Swim** — a lit-pool dark mode on a blue-black deck) and the app icon, both
picked from preview tiles that show the choice itself. **Sound**: the
voice-cues switch with a collapsible voice picker whose audition rows speak
the actual cue, and a "Beeps and chimes" switch — both off makes a visual
timer, and it's the only mute the app can have, since the background-audio
session ignores the silent switch. **Session**: haptics, water tilt, and
the Live Activity. Low Power Mode automatics stay automatic: the water
calms, the tilt stills, haptics rest.

## Accessibility

The app answers system signals instead of growing parallel toggles.
Dynamic Type scales everything — body text on the `.body` curve, poster
titles and timer numerals on `.largeTitle`'s damped one (a clock grows
without swallowing its screen), half-width rows stacking at accessibility
sizes. The palette answers Increase Contrast (`Color.inkOpacity`: captions,
field borders, and hairlines firm up; defaults already clear 4.5:1). Reduce
Motion calms the water and swaps the pool flip for a cross-fade — the
native sheets already cross-fade under the system's own Prefer Cross-Fade
setting. Controls are the platform's (system switches, real `.disabled`
semantics for assistive input).

VoiceOver names every icon-only control (play/pause/skip, gear, plus,
close, chevrons, swatch checkmarks) instead of leaving a bare glyph to
announce itself, and state rides in the channel that's always spoken: the
voice picker's expanded/collapsed state is an `accessibilityValue`, not a
hint, since VoiceOver users can mute Speak Hints and state can't live only
there. Hints describe outcomes ("Opens the pool.") rather than gestures —
"double tap" isn't how Switch Control or Full Keyboard Access act. The Live
Activity's pause button keeps its icon and its spoken name in lockstep from
one source (`ContentState.pauseIcon`/`pauseLabel`), so the Dynamic Island
and the lock screen can't drift apart.

## Flow

The list is play-first: each timed card has a play button (the play verb
belongs to the player alone — untimed details pair **Start workout** with
**Mark as done** instead), and recently touched workouts — finished or
newly created — sort to the top. The detail screen is read-only until you
tap Edit (the system back button — restyled to the Swiss arrow via
`UINavigationBarAppearance`, native edge-swipe intact — hides while
editing, so leaving always goes through Done).

## App Store

`SwissTime/PrivacyInfo.xcprivacy` declares the UserDefaults required-reason
API and nothing collected; `ITSAppUsesNonExemptEncryption` is false (the
app makes no network connections at all). `docs/` holds the GitHub
Pages–served privacy policy and support pages the listing links to.

## Building

Open `SwissTime.xcodeproj` in Xcode 26+ and run the `SwissTime` scheme
(the widget extension builds and embeds as a dependency), or:

```sh
xcodebuild -project SwissTime.xcodeproj -scheme SwissTime \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Debug launch arguments (used for command-line UI verification; one-shot):

- `-autoPlayFirstWorkout` — jump straight into the player for the first timed workout
- `-autoOpenFirstWorkout` / `-autoEditFirstWorkout` — open its detail screen
  (optionally in edit mode); `-autoEditWorkout`, `-autoEditFirstExercise`,
  `-autoAddItem` open the corresponding sheets from there
- `-autoMarkDone` — mark the opened untimed workout as done (completion ceremony)
- `-autoStartUntimed` — push the untimed walkthrough grid from the opened
  detail; `-autoFinishUntimed` floods it and takes the Finish,
  `-autoDismissCeremony` then exits via the Done button's exact path
- `-autoAdoptFirstSample` — empty library only: adopt the first starter from
  the sample shelf and open its detail
- `-seedWorkouts` / `-seedPond` — replace the library / pool in-memory with
  fakes (seeded runs never persist)
- `-autoOpenPond` — open the fullscreen pool; add `-pondShowPast` to land on
  the newest past month, `-pondOpenLog` for the Logbook, `-pondFlip` to turn
  the pool over to its calendar (and back), `-pondPulled` to freeze a
  pull-to-dismiss mid-drag
- `-autoOpenSets` / `-autoStartSets` — land on the Sets tab (optionally with
  a counter running); add `-autoAdvanceOnce` to end the first set a few
  seconds in
- `-autoOpenSettings` — open Settings; `-autoCycleTheme` walks
  day → system → night for screenshots, `-debugScheme` shows a scheme
  readout, and `-autoPickPoolIcon` / `-autoPickDeepEndIcon` /
  `-autoPickPoolTypeIcon` drive the app-icon switch end to end
