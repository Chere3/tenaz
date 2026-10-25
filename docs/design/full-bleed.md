# Full Bleed — the Tenaz design direction (chosen by the learner, 23 Oct 2026)

Replaces "Riso Arcade" (docs/research/11-design-system.md §3), which the learner rejected as "vibecoded".
Chosen from three directions built on a visual review of 122 Dribbble shots; anchors:
dribbble.com/shots/23856674 (one colour per state, giant word), /23424954 (fat retro type is the
question), /27378446 (big mascot, one black pill), /27365833 (streak health drives colour + mood).
The approved HTML mockup: `docs/design/full-bleed-mockup.png`.

## Why the old UI read as vibecoded (do not reintroduce any of these)

1. One surface recipe stamped on everything (3 pt outline + hard offset shadow + same radius), so
   nothing signalled importance.
2. A bento of equal tiles, each with its own "See all →" link: five calls to action fighting the primary.
3. UPPERCASE, wide-tracked micro-labels heading every block (the strongest AI-template tell).
4. The orange misregistration ghost on every title at rest.
5. Colour no longer meant state: orange was the button, labels, checks, meters and title ghosts.
6. Tena framed twice (circle inside a card) at a quarter of the hero: an avatar badge, not a character.
7. Keycaps, pills and chips everywhere at one size.

## The idea

Every screen is one flat field of colour, and **the colour tells you what is happening**:

| Flood (`.flood(_:)`) | Means | Ink on it |
|---|---|---|
| `.turn` yellow | your turn: words due, a question waiting | dark |
| `.good` mint | right answer; everything done today | dark |
| `.fix` coral | wrong: shows the fix, warm, never an alarm | dark |
| `.serious` indigo | placement / monthly exams, writing gate | light |
| `.risk` oxblood | streak about to break, penalty pending | light |
| `.celebrate` tangerine | level-up, evolution only (rare) | dark |
| `nil` / `paperBackground()` | rest screens: achievements, library, settings | dark on paper |

On it: **one hero** (a giant Fraunces number, word or question, 3–4× anything else), **Tena big and
cropped by a window edge** (never framed in a circle or card), and **one ink pill** (`.buttonStyle(.fat)`),
the only filled control on the screen. Everything else is text.

## Rules

- **One flood per screen**, chosen by state, never decoration. Rest screens are paper.
- **One primary action**: the ink pill, with its keycap (`KeyCap("Return")`). Secondary actions are
  text (`.buttonStyle(.ink)`), 16 pt, never filled. No per-section "See all →" links on Home; at most
  one line like "Also today: one sentence · quick check" where each phrase is a link.
- **No cards for grouping.** Separate with space and, for lists, a 1 pt rule of ink at 12 %
  (`Tokens.ink.opacity(0.12)`). The only rounded surface on a flood is the answer sheet (paper,
  radius 24). Lists on rest screens may sit on `Tokens.card` with radius 20, no outline, no shadow.
  `.sticker(...)` now renders a flat fill; remove it wherever it only boxes content.
- **No uppercase tracked labels.** Labels are sentence case, `Typography.label` (14 pt), `Tokens.brand`.
  Remove `.tracking(...)` + ALL-CAPS strings. Drop labels that only restate the obvious.
- **Type**: display = Fraunces 900 SOFT 100 (`Typography.display(size)`, `numberHero` 160,
  `wordHero` 200, `displayL` 64, `prompt` 50, `displayM` 36, `displayS` 26). UI = SF Pro Rounded
  (`title` 22, `body` 18, `label` 14, `caption` 12, `numeric(n)` tabular). What the learner types is always
  sans (`Typography.answer`, use 40–44 pt on the review/exam answer sheet). Max two families.
- **Colour is meaning.** Accent/gold/correct/wrong appear only for their meaning. Body text is
  `Tokens.ink`; secondary is `Tokens.brand`. Never put text in `Tokens.accent` below 24 pt.
- **Tena** (rules in `docs/design/tena.md`; the crop numbers below are superseded by its section 11):
  about 70 % of window height in the side layout (about 45 % stacked), cropped by the bottom or side edge (or whole, clear of the edge, when a cut would only graze her feet), mood matched
  to the flood (turn = happy/curious, good = ecstatic/proud, fix = encouraging/focused, serious =
  focused with headset, risk = nagging/sad, celebrate = ecstatic). Small sizes only in lists and the
  sidebar. Speech = `SpeechBubble` (ink bubble, one line).
- **Progress during a session** = thin segments (ink at 15 % / 100 %, 6 pt tall) along the top;
  streak/XP chips are hidden until after an answer.
- **Time is drawn** (proportional segments) next to the number of minutes.
- **Feedback** = the whole field changes (crossfade 220 ms via `.flood`), then the fix in big type.
  Every state also has a glyph and a word: colour is never the only signal.
- **Decoration only on events**: sunburst rays (ink 7 %) and 4-point sparkles on `.good`/`.celebrate`.
  Grain is already in `.flood`/`paperBackground()`.
- **Dark mode**: floods keep their ink (the modifier flips the scheme inside). Paper screens use Night.
- Keep every accessibility label, keyboard shortcut, `.keyboardShortcut(.defaultAction)`, focus
  behaviour, and self-test hook exactly as they are. This is a visual change, not a behaviour change.

## API (already in the codebase)

- `.flood(.turn)` etc. on the screen's root (fills the window, flips the scheme, crossfades).
- `.paperBackground()` for rest screens.
- `.buttonStyle(.fat)` = ink pill (height 62). Give it a fixed width or let it fill its container.
- `.buttonStyle(.ink)` = text button. `KeyCap("Return")` inherits the text colour at 60 %.
- `Chip`, `MeterCells`, `InkBand`, `BandBadge`, `SpeechBubble`, `Sticker` (toast) are flat now.
- `TenaView(mood:stage:size:)` (see `docs/design/tena.md`); render alone with `--tenaz-snapshot tena-<mood>`.
- Tokens: `paper card ink brand accent accentText correct wrong gold onGold` + `Radius.sheet/card/pill`,
  `Tokens.pillHeight`. Legacy `stroke`/`shadowDepth`/`misregistration` are 0: delete their uses.

## Key layouts

**Home (words due)** — `.flood(.turn)` (mint `.good` when everything is done; `.risk` after 20:00 with
the streak not yet earned). Left ~45 %: Tena ~70 % of window height, cropped through the hips by the bottom edge (`tena.md` §11).
Right: `numberHero` "14", then "words are waiting for you" (22 pt semibold), 40 pt gap, the ink pill
"Review ⏎". Under it one 17 pt line "Also today: one sentence · quick check" (links). Bottom strip,
above a 1.5 pt rule at ink 18 %: three text-only stats, 38 pt Fraunces numerals + 14 pt labels, ~56 pt
apart (streak 4 days · level 3 132/233 xp · band 3.5 B1+). No greeting card, no Tena card, no tiles.

**Review question** — `.flood(.turn)`, no card. Top: 14 thin segments + "esc stop" (14 pt). Prompt in
`Typography.prompt` (50 pt), left-aligned, max width ~760, at ~35 % height; the gap is a 6 pt ink
underline. Spanish gloss hidden behind a small "?" button. Paper answer sheet (radius 24, height 96,
44 pt sans). Bottom-right ink pill "Check ⏎", bottom-left text "I don't know ⌘D".
Right answer → `.good`: "Right!", the word at ~104–120 pt Fraunces, "+12 xp · 5 in a row", pill "Next ⏎",
Tena ecstatic cropped bottom-left with rays. Wrong → `.fix`: the right word big, "again in 10 min".

**Placement intro** — `.flood(.serious)`. Title "Placement test" `displayL`, one body sentence. The 7
sections as one bar of segments with widths ∝ minutes, 12 pt names under each, then "52 min · you can
pause between parts". The pledge is folded into the primary: paper-on-indigo pill "I won't use AI. Start ⏎"
(keep the explicit pledge state the code needs; a checkbox row is fine if the flow requires it).
Tivra + microphone collapse into one 14 pt line at the bottom (keep the "Set up microphone" action
reachable). Tena focused with headset, bottom-right, cropped (`tena.md` §11).

## Verify

Render your screens light and dark: `.derived/Build/Products/Debug/TenazDev.app/Contents/MacOS/TenazDev
--tenaz-snapshot <name> --out x.png [--dark]` and look at them. Run the self-tests that cover your
screens (`scripts/verify.sh` lists them). Nothing may be clipped, overlap, or truncate.
