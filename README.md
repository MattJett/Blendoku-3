# Blendoku 3

A colour-blending puzzle game for iOS, in the shape of Lonely Few's *Blendoku 2*:
a board of coloured tiles with gaps in it, a tray of loose tiles, and one rule —
every row and column has to read as an even blend from one end to the other.

100 levels, none of them hand-authored. Each one is generated from its own level
number, so level 57 is the same puzzle on every device and every launch, and
nothing has to be downloaded or shipped in the bundle.

## Building

Open `Blendoku3.xcodeproj` in **Xcode 16 or newer** and run. Targets iOS 17.0+;
no packages, no dependencies, no configuration.

The project uses Xcode 16's synchronized file groups, so new files under
`Blendoku3/` join the target automatically. `⌘U` runs the test suite.

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

The bundle identifier is `com.mattjett.blendoku3`. If free provisioning refuses
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
  UI/             theme, animated backdrop, particles, transitions, flow layout
Blendoku3Tests/   colour maths, solver, generation, session, progress
Tools/
  levelcheck/     Python mirror of the generator (design-time only)
  icon/           app-icon generator
```

## Feel

Tiles on the board meet edge to edge — no gap, no outline, no per-tile
highlight — and a tile only rounds a corner where both of its edges are
exposed. A finished run therefore reads as one continuous band of colour with
rounded ends, which is the whole payoff of getting it right. Nothing on the
board is allowed to scale for the same reason: a tile that grew would ride over
its neighbours, so landing and solving are animated with light rather than
motion.

Drag a tile and it lifts above your finger with a shadow; the slot under it
swells and the drop lands with a spring and a tap of haptics. Finishing a board
sends a ripple across it, cell by cell, before the confetti. Screens slide a
short distance rather than the full width, over a backdrop of slow drifting
colour blobs tinted with the level's own palette.

Everything honours **Reduce Motion**, which pauses the backdrop, the confetti and
the looping demos.

## Accessibility

- **Tap-to-place** is a complete alternative to dragging: tap a tile, tap a slot.
- Every tile and slot has a VoiceOver label naming its colour in words
  ("dark vivid teal, row 2, column 3") and its position.
- **Show colour values** prints each tile's hex on it, for anyone who would
  rather read the colours than compare them.
- The game is dark-only and portrait on iPhone by design.

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
