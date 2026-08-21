# Swatchword

A colour-blending puzzle game for iOS, in the shape of Lonely Few's *Blendoku 2*:
a board of coloured tiles with gaps in it, a tray of loose tiles, and one rule —
every row and column has to read as an even blend from one end to the other.

The bundle identifier is `com.mattjett.swatchword`. The Xcode target and the
source directory are still called `Blendoku3` — that is internal plumbing, and
renaming it churns the project file for no behavioural gain.

100 levels, none of them hand-authored. Each one is generated from its own level
number, so level 57 is the same puzzle on every device and every launch, and
nothing has to be downloaded or shipped in the bundle.

## Building

Open `Blendoku3.xcodeproj` in **Xcode 16 or newer** and run. Targets iOS 17.0+;
no packages, no dependencies, no configuration.

The project uses Xcode 16's synchronized file groups, so new files under
`Blendoku3/` join the target automatically. `⌘U` runs the test suite.

To build and play it on a simulator without opening Xcode:

```sh
Tools/run-simulator.sh            # boot a simulator and play
Tools/run-simulator.sh 42         # open straight into level 42
Tools/run-simulator.sh 42 paper   # ...on the light ground
```

Simulator builds are not code signed, so that route needs nothing from your
Apple ID. Getting it onto real hardware does.

## Getting it onto an iPhone

Apple will not let an app onto a phone unless it is signed by someone, so every
route below ends with *your* Apple ID. A free Apple ID works — the only cost is
that the app stops opening after **7 days** and has to be reinstalled. A paid
Developer Program account ($99/yr) stretches that to a year and unlocks
TestFlight.

**With a Mac — the short way.** Open the project, pick your iPhone from the
device menu, then in *Signing & Capabilities* set Team to your Apple ID and hit
Run. Xcode handles the certificate and the provisioning profile itself. Two
things trip people up the first time:

- On the phone, *Settings → Privacy & Security → Developer Mode* has to be on
  (iOS 16+). The phone reboots when you turn it on.
- The first launch is blocked until you trust the certificate under
  *Settings → General → VPN & Device Management*.

**Without a Mac — sideload the CI build.** Every push builds an unsigned
`.ipa`. Open the run under the repo's *Actions* tab, download the
`Blendoku3-unsigned-ipa` artifact, and install it with
[Sideloadly](https://sideloadly.io) or [AltStore](https://altstore.io) — both
re-sign it with your Apple ID on the way onto the phone. The same Developer
Mode and trust steps above apply.

The bundle identifier is `com.mattjett.swatchword`. If free provisioning refuses
it because someone else has registered it, change
`PRODUCT_BUNDLE_IDENTIFIER` in the project settings to anything unique and try
again.

## How a level is built

The whole game rests on one property: if three tiles sit in a line, the middle
one must be the exact average of its neighbours. Everything else follows.

1. **Colours live in Oklab.** Not sRGB, not HSL — Oklab is close enough to
   perceptually uniform that a straight line through it *looks* like an even
   blend. Every colour in the game is a point in that space.

2. **Each shape gets an affine colour field**, `origin + x·dx + y·dy`. Because
   the field is affine, *any* straight line through it is automatically an
   arithmetic progression. A 4×4 grid is a valid puzzle in both directions
   without a single per-line calculation.

3. **The gamut is the hard part.** sRGB is a squashed, lopsided solid in Oklab —
   a chroma that looks fine at mid-lightness falls straight out of it at the dark
   end. So the generator spends an explicit travel budget (so much lightness, so
   much colour), builds a gradient direction that fits inside it, and then
   bisects for the most chroma the ramp can actually carry. That is why the early
   chapters come out as saturated as the display allows while *Whisper* stays
   near-grey.

4. **Cells are emptied one at a time**, sudoku-style: remove a tile, ask the
   solver whether the puzzle still has exactly one answer, and keep the removal
   only if it does. The solver leans on the fact that an arithmetic progression
   is pinned down by any two of its terms, so knowing two cells in a line
   determines the whole line and the search collapses fast.

5. **Decoys are proved useless.** From level 26 on the tray carries tiles that
   belong nowhere. Each candidate goes back through the solver, so a decoy can
   never quietly create a second solution.

If any of that fails, the attempt is thrown away and another seed is tried — up
to 72 of them. In practice no level needs more than eight.

### The difficulty curve

Ten chapters of ten. Four dials move across them:

| | level 1 | level 100 |
|---|---|---|
| tiles to place | 2 | 14 |
| cells on the board | 3 | ~30 |
| smallest step between neighbouring tiles | 0.21 Oklab | 0.058 Oklab |
| decoy tiles | 0 | 4 |
| independent shapes sharing one tray | 1 | 3–4 |

Board size and colour subtlety are coupled, not independent: a run of *n* tiles
has to cross *n−1* steps of colour space, and there is only so much of it. Long
lines therefore only become possible once the steps have grown fine enough to
afford them — which is also, conveniently, when they become hard.

Every level's palette is centred on its own hue, advanced by the golden angle
(137.5°) per level, so consecutive levels never look alike and the hundred
between them cover the whole wheel.

## Layout

```
Blendoku3/
  Core/
    Color/        Oklab ↔ sRGB, gamut tests, colour naming
    Model/        grid points, puzzles, runs, tiles, chapters
    Generation/   difficulty curve, shapes, colour fields, solver, generator
    Game/         GameSession — placements, validation, hints
    Persistence/  progress and settings
  Features/       Home, Levels, Game, Tutorial, Settings
  UI/             design tokens, primitives, pigment field, transitions, flow layout
Blendoku3Tests/   colour maths, solver, generation, session, progress
Tools/
  levelcheck/     Python mirror of the generator (design-time only)
  icon/           app-icon generator
```

## Feel

**One rule governs the whole design: colour belongs to the puzzle.** The player
is asked to judge one hue against its neighbour all day, and any chrome that is
also saturated poisons that judgement. So the app is achromatic — a warm
near-white page or a near-black one, one ember accent, and nothing else. Every
saturated pixel on screen is either a tile or a bloom of the level's own
palette, blurred past the point of being a shape.

Tiles on the board meet edge to edge — no gap, no outline, no per-tile
highlight — and a tile only rounds a corner where both of its edges are
exposed. A finished run therefore reads as one continuous band of colour with
rounded ends, which is the whole payoff of getting it right. Nothing on the
board is allowed to scale for the same reason: a tile that grew would ride over
its neighbours, so landing and solving are animated with light rather than
motion.

That flush block is the app's signature object, and it repeats: the home
screen's preview strip runs the full width of the device with square ends, and
each chapter in the level list is ten swatches meeting edge to edge rather than
ten buttons that happen to be coloured.

**The chrome has no borders.** Every panel, shelf, button and well is the
*same colour as the ground behind it* — all white on paper, all black on ink —
and is made three-dimensional by nothing but a dark shadow falling one way and a
light one falling the other. `SoftSurface` is the whole system: one shape, one
depth number, and a `pressed` flag that flips the lighting inward instead of
outward, which is what turns a button into a hole. Empty board cells are holes.
Locked levels are holes. A pressed button is a hole. Because a press is the same
two shadows either way, it animates continuously rather than swapping between
two looks.

Nothing is ever painted on a tile face, in any role. On the board that is
because a border or a highlight draws a line between neighbours and turns a
gradient back into a row of swatches. In the tray it is because a tray tile is a
*promise* about what the board will look like, and a white top-light is a lie —
it lifts the swatch a visible step away from the colour that actually lands.
Tray swatches get their separation from a well recessed into the shelf, which
never touches the colour being judged.

Type is a compressed grotesque set in caps: the system face at its narrowest cut
and heaviest weight, which is as close to a brutalist sans as iOS gets without
licensing one — and unlike a bundled font it carries every weight and optical
size, so it scales with Dynamic Type and never falls back. Buttons are rounded
rectangles, not stadiums. Running prose stays sentence case; caps are for
titles, labels and controls, where they are read as shapes rather than
letter by letter.

The wordmark makes the app's own move: `SWATCH` in the black cut running flush
into `WORD` in the thin one, no space and no join drawn, so the boundary is only
a change of weight — the same way two tiles meet on the board.

Instrumentation survives all of this, because it is annotation rather than
decoration: tracked-out micro-caps over a one-pixel rule, monospaced counters
with a caption underneath, four crosshair registration marks locating the board
instead of a box around it. The rule beneath the game header *is* the progress
bar.

Drag a tile and it lifts above your finger, throwing its own colour onto the
page as a glow; the slot under it swells and the drop lands with a spring and a
tap of haptics. Finishing a board sends a ripple across it, cell by cell, and
then a single sculpted panel: the stars are marks in a recessed track, an
unearned one pressed into the panel rather than dimmed, and the palette you just
rebuilt inlaid in a trough as the only colour in the frame. The selection ring is
two strokes, one dark and one light, and carries no hue at all — a tinted ring is
invisible against a tile that happens to share its hue, and on this board that
case comes up constantly.

Screens slide a short distance rather than the full width, over a ground
carrying two or three slow blooms of the level's own palette.

Everything honours **Reduce Motion**, which stills the ground and the looping
demos.

## Accessibility

- **Tap-to-place** is a complete alternative to dragging: tap a tile, tap a slot.
- Every tile and slot has a VoiceOver label naming its colour in words
  ("dark vivid teal, row 2, column 3") and its position.
- **Show colour values** prints each tile's hex on it, for anyone who would
  rather read the colours than compare them.
- **Paper, Ink or System** in Settings. Both grounds are real designs rather
  than a tint flip, and the puzzle colours are legible against either.
- Portrait on iPhone by design.

## Tools

`Tools/levelcheck` is a faithful Python port of the generator. It exists so the
level book can be checked and rendered without Xcode:

```sh
python3 Tools/levelcheck/report.py           # generate all 100, verify uniqueness
python3 Tools/levelcheck/preview.py out.svg  # contact sheet of every level
```

The Swift under `Blendoku3/Core` is the shipping source of truth; the mirror is a
design aid and needs updating alongside it. The same checks it runs are asserted
against the real Swift generator in `Blendoku3Tests/LevelGenerationTests.swift`.

## Tests

`Blendoku3Tests` covers the parts that would fail silently:

- Oklab ↔ sRGB round-trips exactly, and midpoints really are averages.
- All 100 levels generate without hitting the safety net.
- Every level has **exactly one** solution, decoys included.
- Every run in every solution is an even blend to within 1e-9.
- No two tiles on any board are closer than the level's own threshold.
- Every colour is inside the sRGB gamut with room to spare.
- Generation is deterministic, and the whole book builds in well under a second.
- Placing, swapping, hinting, resetting and solving behave as the UI assumes.
