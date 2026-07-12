# The Lido design language

Lido is a municipal pool. Everything in the app — every color, sentence,
toy, and spring — should feel like a clear morning at a public lido:
orderly, sunlit, a little deadpan, quietly glad you came. This document
is the intent behind the system. The code (`Theme.swift`, `Palette.swift`,
`PoolToyArt`) is the implementation of record; when the two disagree,
fix one of them.

## Identity

- **Celebration, not guilt.** Lido keeps a record, never a score. A
  finished workout drops a toy in the pool; a missed day is simply water.
  Nothing counts streaks, nothing nags, nothing is ever red because you
  rested. Heavy months earn things (a grander pool); light months lose
  nothing.
- **The record is a place, not a chart.** Progress renders as somewhere
  you'd want to be — a pool with your toys afloat — not as graphs,
  percentages, or rings to close.
- **Interaction minimalism.** The fewest taps that honestly do the job.
  One primary action per screen. Settings are remembered, never re-asked.
- **The workout is the product.** Timed workouts run hands-free with
  voice; untimed ones stay out of the way at the gym. No social features,
  no rep counting, no start-workout widgets — workouts happen at the gym,
  not on the home screen.
- **Free, complete, quiet.** No IAP, no accounts, no server. A shared
  workout travels inside the link itself, friend to friend.

## Color

Two kinds of color, never confused:

- **Chrome is ink.** All text, buttons, and structure use `ink` (deep
  pool-water navy; pale in the dark) on `paper` (natatorium off-white;
  blue-black deck at night). Secondary text is ink at 66% (`inkSecondary`),
  rules at 10% (`hairline`) — both answer Increase Contrast automatically
  via `inkOpacity`.
- **Color is data.** The six-swatch palette exists only to mean something:
  each workout owns one water tone, and each tone owns a pool toy —
  Shallow/ring, Pool/duck, Deep/orca, Chlorine/beach ball,
  Periwinkle/flamingo, Midnight/lilo. Palette indices are stable forever;
  files depend on them.

Rules that follow:

- **Red is destructive only** (`signalRed`). Never an accent, never urgency.
- **Gold is luck.** The gilded pearl-and-gold colorway marks the 1-in-20
  shiny toy and nothing else.
- **Night Swim lifts, never repaints.** Dark mode is the same pool after
  dark: surfaces go deck-at-night, swatches keep their hue with more
  light — and toy vinyl never changes. A duck is yellow at midnight too.

## Typography

SF Pro only, in four registered voices (all Dynamic Type–aware via a
scaled 100 pt reference):

| Voice | What it is | Where |
|---|---|---|
| `display` | Poster caps: expanded, heavy, uppercase, tracked +5% | Mastheads ("JULY"), month names |
| `appFont` | Body curve, plain SF Pro | Everything that reads |
| `readoutFont` | Damped `.largeTitle` curve | Timer numerals only |
| `overline` | Small tracked uppercase tag | Index numbers ("01"), month labels |

Page titles sit over an `InkRule` — the Swiss masthead. Anything that
counts (timers, sets, "4 × 8") is `monospacedDigit` so it never jitters.
Fewer sizes is quieter; add a size only when a screen genuinely needs a
new rank.

## Surfaces

The app is printed matter on a pool deck: `paper` ground with static
grain (a photograph, not a fill), `paperCard` postcards in continuous
rounded rectangles, hairlines instead of boxes. Program sheets read as
print — numbered lines separated by hairlines, and nothing looks
pressable unless it is (cards advertise taps; rows don't). The pool card
is literally a postcard: the month's ledger is printed on the back.

One scale rule for other media: in the app, the pool is a postcard; in
marketing, it's a poster. Full-bleed water with display caps set on it
(the website's hero) is the same Swiss tradition at poster scale — not
a departure from the language, its other classic use.

## Motion

- **Physically believable, or absent.** Springs over jumps everywhere;
  waterlines track truthfully and spring only when the target jumps. If
  motion can't be believable, it shouldn't exist.
- **The pool is a pure function of time.** No simulation state: any
  frame can be drawn at any t, which is why postcards, the hero strip,
  and Reduce Motion stills can never disagree. Toys drift on slow
  sinusoids; crowded toys jiggle near home (no room in a full pool);
  bumps part toys, they never orbit.
- **Calm is hierarchical.** The hero idles at 10 fps, the fullscreen pool
  at 24, Low Power Mode calms both, and anything unseen is paused. The
  water never demands attention.
- **Reduce Motion gets an equivalent, never an absence.** A crossfade for
  the card flip, a stable still pose for the pool (no glints — a frozen
  twinkle would stick). The feature remains whole.

## Sound & haptics

Audio only when it informs. **Cues are clocks** — "Halfway done.",
"5 seconds left." — and always speak on time, interrupting anything.
**Announcements are context** — names, instructions — and may be clipped
by a clock. A checked box that would say nothing says one honest thing
instead ("5 seconds left." at the midpoint) — silence that reads as
broken is a bug, and so is speech that informs no one. Haptics are taps
at real boundaries: steps change, sets end, workouts finish.

## Writing

The voice is a friendly lifeguard: short declarative sentences, dry
warmth, no exclamation points. Lido is warm toward the swimmer and
silent about their performance — it observes, thanks, and invites; it
never cheers, scolds, or coaches.

The canon, from the app and its release notes:

> "Flat water. Finish a workout and a toy floats in."
> "Past months will collect here."
> "Looks like you needed a bigger pool."
> "A gilded duck — lucky you."
> "Shared with you. Adding it makes it yours to edit."
> "Every day you swam, filled in. A quiet ledger, not a scorecard."
> "Thanks for swimming with us."

Rules visible in those lines:

- **Swim in the metaphor.** Working out is swimming; using Lido is
  being at the pool. Releases "dive deeper," the record is "your
  swimming," and readers are thanked for swimming with us. The metaphor
  is vocabulary, not decoration — but never bend a sentence just to
  wedge a pool word in.
- **Correct by contrast.** The signature shape "X, not Y" says what
  Lido is by naming what it refuses: a ledger, not a scorecard; a
  record, not a score; celebration, not guilt.
- **It's yours.** Second person, possessive: your pool, your month,
  your way. Lido is a place the swimmer owns, not a service they use.
- **Celebrate by observing.** The biggest compliment Lido pays is a
  factual one ("Looks like you needed a bigger pool."). Never "Great
  job!", never emoji, never streak-speak.
- **Two short sentences beat one long one.** State the situation, then
  the mechanism.
- **Empty states are invitations, not apologies.** Say what the space is
  for and how something gets here.
- **Errors are shrugs, not alarms.** "This link doesn't hold a Lido
  workout." — no "Error", no codes, no blame.
- **Voice cues end in periods** and say the time, not encouragement.
- **Release notes are the voice at its warmest**: benefit-first section
  titles ("See your month", "Sounds and feel, your way"), and a
  thank-you to close.

## Illustration

Pool toys from directly above, drawn like a catalog photo: flat vinyl
shapes, one hard afternoon sun shadow (a single world-space direction
that never rotates with the toy), molded details in a darker self-color,
one white catch-light, painted eyes on both sides of the head. Deadpan —
the charm is in the precision, not in expressions.

- **Everything is code-drawn.** Canvas paths, no image assets. If it
  can't be drawn in ~40 lines of paths, it's too fussy for Lido.
- **Grain over water** keeps flat blue from reading as a vector fill.
- **New toys must mean something**: a toy exists only as the face of a
  palette color. Six colors, six toys, until a seventh color earns its
  place.
- Fixtures (ladder, diving board) are chrome and pale planks with the
  same sun — furniture, not characters.

## Accessibility

- **Respond to system signals** — Dynamic Type (every voice scales),
  Reduce Motion, Increase Contrast, Low Power — automatically, without
  in-app duplicates of system settings.
- **Native beats brand when they conflict.** A real `Toggle` with its
  full VoiceOver/Switch Control contract outranks a prettier printed
  checkbox. (Learned once, kept forever.)
- **VoiceOver hears the same app.** Labels read what the screen shows
  ("July pool, 8 afloat"); custom acts live in named actions; two Julys
  never sound alike (past months carry their year).
- **Transparent pixels don't hit-test.** Every button whose label is
  text/glyph over clear space declares a `contentShape`. Check at
  creation time.

## Judging new work

Five questions, in order. A feature that fails one isn't necessarily
wrong — but it owes an explanation.

1. Does it celebrate without ever being able to scold?
2. Is it the fewest taps that honestly do the job?
3. Would it look at home on a printed pool schedule from Zürich?
4. Does the motion happen in water — believable, calm, pausable?
5. Is the copy warm to the swimmer, and silent about their performance?
