# 11 - Visual and interaction design system for Tenaz

Date: 2026-10-22. Scope: ADHD-first UI research, reference teardown, ONE committed visual direction ("Riso Arcade"), tokens, motion, sound, mascot rendering, wireframes.
Constraints inherited from `DECISIONS.md`: overlays/gates off by default with escape hatches, never lock the learner out, never block a work meeting, Tivra read-only, local data, Swift 6 + SwiftUI/AppKit on macOS 26. Mascot is the axolotl "Tena" (decided in `02-gamification-mascot.md`, section 4.1).
Evidence labels: **[verified]** = I read it this session; **[secondary]** = only a third-party page said it; **[unverified]** = from memory or reasoning, check before relying on it.

---

## 0. Executive summary (the decisions)

1. **Direction: "Riso Arcade".** A two-ink risograph print world (deep indigo + hot orange on warm paper, with a third pink ink reserved for Tena), halftone texture, deliberate mis-registration, a fat characterful display face, and arcade-grade "juice" on every answer. It descends from a warm retro / fat-display direction and a navy + orange risograph plate. It deliberately avoids three rejected directions: cream + serif editorial, dark glow "premium", and light-ribbon 2012 abstracts.
2. **One primary action per screen, always the same shape and place.** Giant answer area, one fat button, everything else collapsed (progressive disclosure). The number of simultaneously visible decisions is capped at 1 primary + 1 escape.
3. **Time is drawn, never only written.** A shrinking ink band (not a digital countdown) for every timed thing; exams show both an elapsed bar and section chips.
4. **Color means state, and only state.** Orange = "do this now", indigo = neutral/ink, green = correct, red = wrong/penalty, pink = Tena. Every state also has a shape/icon and a word, never color alone.
5. **Juice is a budget, not a vibe.** Tiered feedback (S/M/L/XL) with hard limits: max 1.2 s for a routine correct answer, XL (level-ups, evolution) up to 8 s but always dismissible. Reduce Motion replaces movement with a crossfade + color change + sound; nothing flashes more than 3 times per second.
6. **Fonts:** display = **Bricolage Grotesque** (OFL, variable, bundled); UI/body = **SF Pro Rounded** (system, free on Apple platforms); numerals/timers = **SF Pro Rounded tabular**; IPA = system fallback. No dependency on a paid license.
7. **Mascot rendering:** ship v1 as **SwiftUI-native vector (Canvas + TimelineView + keyframeAnimator)**, behind a `MascotRenderer` protocol; move the rich animation set to **Rive** (MIT runtime, state machines, the same approach Duolingo documents) in v2. Reject Lottie.
8. **Glass is used sparingly.** Liquid Glass only for floating controls (menu-bar popover chrome, toolbar). The word overlay, gate and exam are *opaque paper*, because they are content, and because glass over arbitrary desktop windows is the opposite of "one thing to look at".

---

## 1. Research: what actually helps ADHD users in a UI

### 1.1 What the evidence base looks like (honest version)

My searches returned mostly practitioner and vendor writing, very little peer-reviewed UI research. The items below are therefore labelled by strength.

- **Time perception is a core difficulty, so time must be made visible.** One academic-style design write-up cites a meta-analysis finding time-perception difficulties across measurement methods in children/adolescents with ADHD and derives "show elapsed progress next to the clock" ([evalab.artun.ee Dual Timer](https://evalab.artun.ee/dual-timer/)) **[secondary: a student-style design paper citing a meta-analysis; I did not fetch the meta-analysis]**. Practitioner guidance converges: a shrinking ring/band beats a bare number ([Product Hunt maker note](https://www.producthunt.com/p/self-promotion/i-built-a-free-pomodoro-timer-for-adhd-brains)) **[secondary, anecdotal]**.
- **Planner UIs should show the shape of the day, make add/complete one tap, warn before transitions, and help restart instead of shaming a broken streak** ([SwiftUI ADHD planner guide](https://vp0.com/blogs/adhd-daily-routine-planner-ui-swiftui), same search) **[secondary]**. These match the forgiving streak logic already in `02-gamification-mascot.md` section 4.5.
- **Gamification RCT in ADHD children:** an 80-child randomized trial (gamified vs non-gamified app, 8 weeks, immediate feedback + rewards + levels) exists, but the snippet I saw did not include outcomes, and the authors themselves note RCT evidence and long-term maintenance data are limited ([Frontiers in Education 2025](https://www.frontiersin.org/journals/education/articles/10.3389/feduc.2025.1668260/full)) **[verified that it exists; outcomes NOT verified; population is children, the learner is an adult]**.
- **Vendor claims such as "gamified apps retain 48% better"** appear in trade articles without study details ([mfgrobots summary](https://www.mfgrobots.com/Article/mfg/it/47673.html)) **[unverified; do not use as a justification]**.

**Consequence:** the rules below are *design heuristics supported by convergent practice*, not proven effect sizes. The right protection is to instrument Tenaz (local analytics: time-to-first-answer, session abandon rate, overlay dismiss rate) and tune, rather than to trust any one article. Add a "design hypotheses" table to the PLAN when M1 lands.

### 1.2 Rules derived (each one is a testable hypothesis)

| # | Rule | Concrete implementation in Tenaz |
|---|---|---|
| R1 | **Single primary action.** Each screen has exactly one filled, orange, fat button; secondary actions are text buttons in indigo. | `TenazButtonStyle.primary` is the only style with a fill. Lint: a screen test fails if two `.primary` buttons are on screen. |
| R2 | **Progressive disclosure.** Hide hints, translations, etymology, settings behind one "More" affordance. Never show settings in a learning flow. | Word card shows: word, (optional) audio button, answer field. Definition/Spanish gloss appear only after the first attempt or on press of `?`. |
| R3 | **Visible time and progress.** Anything with a duration or a count shows a band or segmented bar. | `InkBand` component (section 4.3); exam sections as chips; session as "7 / 12" segments, not a percentage. |
| R4 | **Start cost near zero.** The first action after any prompt must need no navigation and no typing decision (focus is already in the answer field). | Overlay opens with the text field focused; Return submits; Tab shows hint. |
| R5 | **Transition warnings.** Switching from work to Tenaz is the hard part, so announce it. | Soft "tick" + menu-bar icon pulse 20 s before a scheduled overlay; the overlay itself never appears from nowhere (Section 6.3). |
| R6 | **Immediate, tiered feedback (<100 ms).** Response to input is instantaneous; the *reward* animation can be longer but must not block the next action. | Feedback tiers S/M/L/XL (section 5.4); next card can be advanced before the celebration ends. |
| R7 | **Forgiving failure language.** Wrong answers state the fix, not the verdict. Punishment is configured earlier, calmly, by the learner, never improvised by the UI at the moment of failure. | Wrong = red border + the correct word big + "again in 10 min". No "You failed". |
| R8 | **Low visual noise at rest, loud at event.** The resting state is calm (paper, one ink). Events are loud. This contrast is what makes events register. | Home has one mascot + one button; halftone and mis-registration are used for event states only. |
| R9 | **Escape is always visible.** A visible, labelled way out on every intrusive surface (also required by DECISIONS.md rule 2). | "Skip (costs 20 vitality) - Esc" pill in the bottom-left of overlay and gate, never hidden by animation. |
| R10 | **Variety on a schedule.** Novelty fatigue is a named risk in `02` section 5; the design system must make re-skinning cheap. | Token-driven "seasons" (3 palettes sharing the same semantic roles); mascot cosmetics; weekly rotating overlay layouts. |

---

## 2. Reference teardown (what to steal, what to avoid)

| Reference | What is true (source) | Steal | Avoid |
|---|---|---|---|
| **Tiimo** | Won iPhone App of the Year at the 2025 App Store Awards (winner post dated 19 Nov 2025, updated 4 Dec 2025) and was a 2024 Apple Design Awards finalist in Inclusivity ([Tiimo winner post](https://www.tiimoapp.com/es/resource-hub/tiimo-winner-2025-app-store-awards); [Mjtsai roundup](https://mjtsai.com/blog/2025/12/11/2025-app-store-awards/); [TWiT piece](https://twit.tv/posts/tech/how-tiimo-makes-task-and-time-management-easier-neurodiverse-users)) **[verified via search results; award is the App Store Award, not an Apple Design Award win]**. Visual planner with icons and colors instead of text lists; Apple Watch haptic nudges for time blindness **[secondary]**. | Icon+color blocks for sections; "shape of the day" timeline; haptic-like cues -> on Mac use sound and trackpad haptics (`NSHapticFeedbackManager`, works only on Force Touch trackpads). | Pastel-everything calm: Tenaz needs to be intrusive, so we invert the energy. |
| **Finch** | Self-care pet; bird grows as real tasks are done; "gentle gamification", companionship over rigid routine ([Pratt IxD critique](https://ixd.prattsi.org/author/yiqin-meng); [Foxdata blog](https://foxdata.com/en/blogs/finch-as-app-store-editors-choice-a-self-care-companion/)); App Store Editors' Choice claim comes from a non-Apple blog **[secondary]**; I found no confirmation of an Apple Design Award. | Pet growth tied to real behavior; the pet is the home screen. | The "no consequences" tone is wrong for the learner's brief; we add consequences but keep reversibility. |
| **Duolingo** | Custom typeface **Feather Bold** (Johnson Banks + Fontsmith, 2019) built around the owl's feather form ([Creative Bloq](https://creativebloq.com/news/feather-bold); [Creative Review](https://www.creativereview.co.uk/duolingo-rebrand-johnson-banks/)) **[verified in search results]**; Feather Green `#58CC02` and DIN Next Rounded (Monotype; not plain "DIN Round") for interface text per a design blog ([Made Good Designs](https://madegooddesigns.com/duolingo-brand-guidelines/)) **[secondary]**. Characters are animated in **Rive**: a state machine blends separate body states and mouth states that run in parallel, exported as a single runtime file for engineers; chosen so a limited asset set yields many combinations ([Duolingo blog: world character visemes](https://blog.duolingo.com/world-character-visemes); [Rive case study](https://rive.app/blog/duolingo-s-ai-powered-video-call-brings-lily-to-life)) **[verified in search summaries]**. | The *architecture*: modular body + face parts under a state machine, driven by app inputs (`isThinking`, `mood`, `mouthShape`). A bespoke type voice that comes from the mascot's own shapes. | Looking like Duolingo. Green-on-white, Duo-like bubbly flatness is the generic "language app" look the learner would call template-like. |
| **Headspace** | I did not fetch primary design docs this session. | Flat, warm illustration with squash-and-stretch blobs as emotional carriers **[unverified; from memory]**. | - |
| **Things 3 / Structured / Opal** | Not researched in depth this session **[unverified]**. | Things: one-column, generous spacing, delightful "completion" animation; Structured: timeline of the day in blocks; Opal: focus-session "lock" ceremony. | Things' near-monochrome minimalism: too quiet for the brief. |
| **Not Boring apps** | Not researched this session **[unverified]**. | The idea that a utility can have a physical, tactile personality with custom haptics/sound. | Skeuomorphic overload that costs performance. |
| **Arc** | Not researched this session **[unverified]**. | Confident color-as-identity, bold "space" theming, playful microcopy. | Heavy gradients/blur chrome. |
| **Balatro** | One outside analysis claims layered feedback per scoring event (card animation, rolling counter, screen shake with magnitude tiers, CRT scanlines intensifying while scoring, particles, audio) ([Blake Crosley analysis](https://blakecrosley.com/guides/design/balatro)) **[secondary: the author's reconstruction; thresholds and code are illustrative, not LocalThunk's]**. | The *principle*: shake/size/sound scale with magnitude, so the player reads "how good" before reading the number; a rolling counter. | CRT/scanline skin (its own identity) and anything that makes the screen hard to read. |
| **"Juice it or lose it"** | Jonasson and Purho, 2012: a Breakout prototype is made to feel alive by stacking small effects ([coverage summarized here](https://gamedeveloper.com/business/has-your-game-got-juice-more-)); the talk is the source of the term "juice" in an AAAI paper citing it ([AIIDE paper](https://ojs.aaai.org/index.php/AIIDE/article/download/18889/18654/22655)); critics warn juice for its own sake can distract from the goal and cost immersion **[verified existence and gist; I did not watch the talk]**. | Stacking: every correct answer gets scale pop + particle + sound + counter tick. Each effect alone is small. | Juice on every pixel at every moment: juice must be *proportional to event magnitude* (section 5.4). |
| **Apple Liquid Glass (macOS 26)** | Apple's HIG pages did not render through my fetch tool, so Apple primary text was NOT verified. Third-party summaries agree glass belongs to the functional/navigation layer floating over content, not to content itself; `glassEffect()`, `GlassEffectContainer`, regular vs clear variants, `.interactive()` only on tappable things ([Donny Wals](https://www.donnywals.com/designing-custom-ui-with-liquid-glass-on-ios-26/); [DEV: GlassEffectContainer](https://dev.to/arshtechpro/understanding-glasseffectcontainer-in-ios-26-2n8p)) **[secondary]**. | Use the *system* glass for the popover/toolbar so Tenaz feels native. | Glass for the overlay/gate/exam (see section 3.1). |

TODO for a later pass **[unverified]**: fetch Apple's "Applying Liquid Glass to custom views" and "Materials" and "Motion" HIG pages with a browser tool; Apple's Reduce Motion and Reduce Transparency behavior should be tested on the actual Mac rather than assumed.

---

## 3. The committed direction: Riso Arcade

### 3.1 Concept and why

Tenaz is *printed matter that fights back*. Everything looks like a two-colour risograph sheet (grainy paper, ink that does not quite register, halftone shading), and everything *behaves* like an arcade cabinet (hit-stop, counters, big sound). That tension is the identity: tactile and warm at rest, loud at events.

Why this fits the brief:
- Intrusive but not hostile: the paper look reads as friendly stationery even when it covers the screen.
- Distinct from every language app (green/blue flat vectors) and from the "AI app" look (purple gradients, glass, Inter). Riso is rare in macOS software.
- The look is deliberate: navy + orange riso plate and a warm retro, fat-display look.
- Production-cheap: riso is a *limited-ink* aesthetic, so a small token set and procedural halftone/grain shaders carry it; no illustration pipeline needed to look finished.

### 3.2 Rejected alternatives

**Alternative A: "Cartoon Arcade" (Duolingo-style bright flat vectors, green/blue, bubbly sans).** Rejected: it is exactly the reference everybody will compare us to, it reads as template, and the brand colors already belong to Duolingo ([Made Good Designs](https://madegooddesigns.com/duolingo-brand-guidelines/) lists Feather Green as the brand anchor **[secondary]**). It would make Tenaz "a Duolingo clone for Mac" instead of "a Duolingo that really works".

**Alternative B: "Calm Glass" (Liquid Glass, translucent, soft pastels, Tiimo/Finch-style serenity).** Rejected for three reasons: (1) the product is *intentionally intrusive*, and calm translucency undermines the interruption; (2) glass over arbitrary windows hurts legibility and puts several visual layers in front of an ADHD user at the exact moment we want one; (3) the learner explicitly rejected the dark-premium / glow family and safe editorial defaults. We keep glass only where it is native and helpful (section 6.1).

(Also considered and dropped: "Terminal / CRT retro" - too close to Balatro's identity and bad for long reading; "Brutalist black-and-yellow" - fits intrusive but reads as a warning system and increases anxiety.)

### 3.3 Color tokens (WCAG AA computed)

All contrast ratios below were computed by me with the WCAG relative-luminance formula this session. AA: 4.5:1 for normal text, 3:1 for large text (>=24 px, or >=18.66 px bold) and for UI components/graphics.

**Light ("Paper")**

| Token | Hex | Role | Contrast |
|---|---|---|---|
| `paper` | `#F6EBD3` | background | - |
| `paperDeep` | `#EADBB8` | cards on paper, separators | - |
| `ink` | `#1B1F3B` | primary text | 13.59:1 on paper (AAA) |
| `indigo` | `#1E2A78` | brand ink, secondary text, links | 10.7:1 on paper (AAA) |
| `orange` | `#E8541E` | primary button *fill*, "do now" | 3.1:1 on paper: **fill/large only, never small text** |
| `orangeDeep` | `#B63A0C` | orange when used as text/icon | 4.93:1 on paper (AA) |
| `onOrange` | `#1B1F3B` (ink) | text on orange fill | 4.38:1: passes only as WCAG large text, i.e. >=24 px regular or >=18.66 px (14 pt) **Bold (700)**; buttons therefore use 20 pt **Bold** (semibold does not qualify) [corrected, WCAG 1.4.3 Understanding page] |
| `correct` | `#1A7344` | correct / reward | 4.96:1 on paper (AA) |
| `wrong` | `#C62828` | wrong / penalty | 4.75:1 on paper (AA) |
| `gold` | `#F2B705` | XP, coins, achievements (fill) | ink on gold 8.85:1 |
| `pink` | `#F28BA8` | Tena's body ink [reserved: mascot only] | decorative, no text |

(An earlier green candidate `#1F7A4D` computed 4.49:1 and fails AA by a hair; `#1A7344` replaces it.)

**Dark ("Night press")**: not a black glow theme; it is the same riso sheet printed on dark stock.

| Token | Hex | Role | Contrast |
|---|---|---|---|
| `night` | `#14152B` | background | - |
| `nightCard` | `#1F2142` | cards | - |
| `paperText` | `#F6EBD3` | text | 15.14:1 on night, 13.1:1 on card |
| `orangeLit` | `#FF7A45` | primary fill and text | 6.93:1 on night |
| `goldLit` | `#FFC93C` | XP | 11.67:1 |
| `correctLit` | `#4ADE9A` | correct | 10.42:1 |
| `wrongLit` | `#FF6B6B` | wrong | 6.46:1 |
| `periwinkle` | `#8FA2FF` | secondary ink | 7.49:1 |
| `onLitFill` | `#14152B` | text on lit fills | 6.93 (orange), 10.42 (green), 11.67 (gold), 6.46 (red) |

Rules:
- State is never color alone: correct = green + check glyph + "Correct"; wrong = red + cross glyph + the right answer; due = orange + dot badge. (Color-blind safety: orange/green/red are distinguished by glyph and position. Verify with a simulator pass **[unverified]**.)
- Three seasonal palettes (R10) swap only `orange`/`indigo`/`pink` hues and keep luminance, so contrast stays valid. Add a unit test that recomputes WCAG ratios for every token pair on build (cheap, pure-logic, belongs in `TenazCore`).
- Surfaces use a subtle paper grain and optional halftone; both are disabled when Reduce Transparency/Increase Contrast are on (use the SwiftUI environment values `accessibilityReduceTransparency` and `colorSchemeContrast`).

### 3.4 Typography

| Role | Font | License / availability | Use |
|---|---|---|---|
| **Display** | **Bricolage Grotesque** (ExtraBold 800, width axis condensed to normal, optical size axis) | SIL Open Font License; variable file `BricolageGrotesque[opsz,wdth,wght].ttf` ([listing](https://fontmeme.com/jfont/bricolage-grotesque-font/); repo [ateliertriay/bricolage](https://github.com/ateliertriay/bricolage)) **[verified: repo OFL.txt is SIL OFL 1.1, "Copyright 2022 The Bricolage Grotesque Project Authors", no Reserved Font Name; repo describes wght/wdth/opsz axes; exact variable filename NOT verified, check the `fonts` folder]** | The giant word on the overlay, screen titles, big numbers |
| **UI / body** | **SF Pro Rounded** (`.fontDesign(.rounded)`) | System font; shipped with macOS 26. The system has the files `/System/Library/Fonts/SFNSRounded.ttf` and rounded numeric variants **[verified on macOS 26 via fc-list]**. Using it through `Font` APIs is the supported path. | Buttons, labels, body copy, tabular numerals |
| **Sentences being learned** | SF Pro Rounded Medium, 22-28 pt | as above | Example sentences, writing field |
| **IPA** | system fallback chain (SF Pro covers most IPA symbols [unverified: test `/ˈsɪmpəl/`, `ʃ`, `θ`, `ð`, `ŋ`, `ə`]) | - | Phonetics |

Why not alternatives: **Fredoka** (OFL, [Font Squirrel](https://www.fontsquirrel.com/license/fredoka)) is excellent but is the default "friendly rounded" choice of many kids' apps, which pulls toward the cartoon look we rejected; keep it as the fallback display if Bricolage's width axis misbehaves in CoreText. **Feather Bold / DIN Round** are Duolingo's. **Fraunces/serif** is the cream+serif editorial default the learner rejected.

Type scale (pt, macOS; use Dynamic Type-style relative sizes via `@ScaledMetric`):

| Token | Size / weight | Use |
|---|---|---|
| `word.hero` | 160-220, Bricolage 800 | The overlay word (auto-fits width; min 96) |
| `display.l` | 56, Bricolage 800 | Screen titles, level-up |
| `display.m` | 34, Bricolage 700 | Section headers |
| `title` | 22, SF Rounded Semibold | Card titles |
| `body` | 17, SF Rounded Regular | Body; 1.45 line height |
| `answer` | 28, SF Rounded Medium | Typing field text |
| `label` | 13, SF Rounded Medium | Chips, captions |
| `numeric` | SF Rounded Semibold, `.monospacedDigit()` | Timers, counters |

Rules: max 2 typefaces on a screen; line length <= 62 characters; left-aligned (no justified text); sentence case; 1 emphasized word per sentence maximum (bold or orangeDeep underline, not both). Fonts bundled via `ATSApplicationFontsPath` or `CTFontManagerRegisterFontsForURL` at launch.

### 3.5 Spacing, shape, elevation

- **Grid:** 4-pt base; scale `4, 8, 12, 16, 24, 32, 48, 72`. Screen margins 32 on windows, 24 in popover. Comfortable density by default (no tiny hit targets: min interactive size 44x44 pt even on Mac pointer).
- **Shapes:** "cut paper": radius `14` (controls), `28` (cards), `999` (chips and the main button). Cards have a **hard offset shadow** (x=0,y=6, no blur, in `ink` at 100%) rather than soft blur: this is the print/sticker signature, it reads as depth at a glance, and it is cheap to render.
- **Outline:** 3 pt `ink` stroke on primary surfaces (sticker edge). Secondary surfaces: no stroke.
- **Mis-registration:** a second ink layer (orange) offset by (3,3) pt behind the display word and key shapes. Static on resting screens; animates on events (jitter of the offset by up to 6 pt over 180 ms). Disabled when Reduce Motion is on (becomes static offset).
- **Texture:** one tileable grain PNG at 6% opacity + halftone via a Metal `colorEffect` shader (or `Canvas` dots) for the mascot shading. Budget: texture must never exceed 2 ms/frame on an M1 (measure in Instruments **[unverified target]**).
- **Layering:** 3 elevation levels: `flat` (page), `card` (offset shadow), `pop` (offset shadow + 4 pt translate on hover/press).

---

## 4. Components

### 4.1 Primary button ("Fat button")
Pill, orange fill, ink 3 pt stroke, hard shadow, 20 pt Bold (700) label (needed for the 4.38:1 ink-on-orange pair to count as large text). Hover: shadow offset 8, translate -2. Press: shadow collapses to 0, translate +6 (feels like pressing a physical key) over a 70 ms critically damped spring, trackpad light haptic. Keyboard focus ring = 4 pt indigo outline, always visible. Disabled state = paperDeep fill + dashed outline (never just lower opacity).

### 4.2 Answer field
Large (28 pt) single underline field, always focused, caret thick (3 pt) in orange. Live feedback is *never* red while typing (avoid anxiety); validation only on Return. Shake (4 pt, 2 cycles, 160 ms) on wrong; none in Reduce Motion (use border color + glyph).

### 4.3 InkBand (time/progress)
A horizontal band that drains like ink running out, with a notch every minute for exams. Colour shifts indigo -> orange -> orangeDeep in the last 25% / 10% (plus a tick sound at 10 s). Always paired with a tabular-digit readout for people who want numbers. Reduce Motion: the band still drains (it is information, not decoration) but at a stepped rate once per second.

### 4.4 Chips and badges
Pill, 13 pt label, glyph + word. States: idle (paperDeep), active (indigo fill, paper text), done (green + check), locked (dashed outline).

### 4.5 Toasts
Corner stickers that peel in (scale 0.9 -> 1, rotate -2deg -> 0) for XP (+10), coin, streak; auto-dismiss 2.5 s; pointer hover pauses; max 2 stacked (queue the rest).

---

## 5. Motion, juice and sound

### 5.1 Principles
1. **Motion carries meaning**: it signals state change, reward or consequence; ambient loops are tiny and pausable.
2. **Fast in, slow out**: input response <100 ms; celebrations ramp after.
3. **Never block**: no celebration prevents the next action (R6), except the evolution ceremony, which is still dismissible with Esc.
4. **Budget**: at rest, <=1 ambient animation per screen (Tena's breathing). Everything else is event-driven.

### 5.2 Spring tokens (SwiftUI)
SwiftUI's `.spring(duration:bounce:)` (iOS 17+/macOS 14+) and presets `.smooth`, `.snappy`, `.bouncy` are the implementation basis **[spring(duration:bounce:) macOS 14+ confirmed via search; Apple page text did not render]**.

| Token | Definition | Use |
|---|---|---|
| `motion.tap` | `.spring(duration: 0.18, bounce: 0.0)` | Button press, selection |
| `motion.settle` | `.spring(duration: 0.35, bounce: 0.15)` | Card appear, panel change |
| `motion.pop` | `.spring(duration: 0.45, bounce: 0.45)` | Correct-answer scale pop, badges |
| `motion.slam` | `.spring(duration: 0.30, bounce: 0.30)` + 3 ms hit-stop | Word enters the overlay, penalty hit |
| `motion.float` | `.easeInOut(duration: 2.8).repeatForever` (amplitude 4 pt) | Tena idle breathing |
| `motion.reduced` | `.easeOut(duration: 0.20)` crossfade only | Every token under Reduce Motion |

Implementation: one `Motion` enum that reads `@Environment(\.accessibilityReduceMotion)` and returns either the spring or `motion.reduced`. Rule from Apple's guidance as relayed by the fetch tool (page text did not load, so this is a paraphrase **[unverified]**): respect Reduce Motion with gentler alternatives such as crossfades, and avoid rapid flashing (WCAG 2.3.1: no more than three flashes in any one-second period, or below the general/red flash thresholds [verified: https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html]).

### 5.3 Hit-stop and screen shake (borrowed from game feel)
- **Hit-stop**: on correct XL events pause UI animation for 40-60 ms before the burst. Implemented by delaying the effect trigger, not by freezing the app.
- **Shake of the window content** (not the window frame) scaled by tier: S 0, M 2 pt, L 4 pt, XL 7 pt, max 2 cycles. Off in Reduce Motion.
- **Score counters** roll digit-by-digit (`contentTransition(.numericText())` in SwiftUI **[API recalled; verify]**).

### 5.4 Feedback tiers

| Tier | Trigger | Visual | Sound | Haptic | Max duration |
|---|---|---|---|---|---|
| **S** | any correct answer | Word turns green with check; +XP sticker; Tena blink | 1 short chime (pitch rises with combo up to 8) | light | 0.6 s |
| **M** | 5-in-a-row, new word learned | Pop scale 1.0 -> 1.15 -> 1, small confetti dots (halftone, 12 particles) | 2-note motif | medium | 1.2 s |
| **L** | session complete, daily goal | Full-card stamp "DONE" slams in; paper confetti 60 particles; Tena Happy spin | 4-note phrase | strong | 3 s |
| **XL** | level-up, evolution, achievement | Full-screen riso flood (indigo -> orange wipe, 600 ms), giant text, Tena large; share-card option | Short theme sting | strong x2 | 8 s, Esc anytime |
| **Penalty** | wrong, missed review, skip | Border red, word shown big in paperDeep with ink strike-through *on the user's wrong answer*, Tena droop; **no shake over M tier, no sirens, no red full-screen flash** | Low soft "thud" (not a buzzer) | one soft tap | 0.8 s |

Variable rewards (cosmetic mystery drops, ~25% after a session, odds disclosed in settings) follow `02-gamification-mascot.md` section 3 and use the L tier "drop" animation.

### 5.5 Sound palette
Principles: very short (80-450 ms), mostly consonant (major pentatonic) for reward, low and dry for penalty, no sustained tones, all sounds mixed at -18 LUFS-ish so they never startle **[target is a design choice, not sourced]**. Master volume follows system output; a separate Tenaz slider; **muted automatically when a call/meeting is detected** (microphone-in-use via CoreAudio `kAudioDevicePropertyDeviceIsRunningSomewhere` **[property exists (FourCC 'gone'); Apple forum reports it fails for Bluetooth mics and cannot separate input from output on combo devices (https://developer.apple.com/forums/thread/741026), so treat it as a best-effort signal and add a calendar/foreground-app check]**, plus the hard rule in DECISIONS.md that nothing interrupts a meeting).

| Event | Sound |
|---|---|
| Key press in answer field | Soft paper-tap (typewriter-lite), pitch +/- 3% randomization to avoid fatigue |
| Correct | Marimba/kalimba pluck, pentatonic degree = combo index (cap at 8 then repeat octave up) |
| Wrong | Muted woodblock "tok" + low sine 90 ms; never a buzzer |
| Timer last 10 s | Tick at 1 Hz, tick-tock at 2 Hz for last 3 s |
| Overlay arrival (L) | Page-flip "whoosh" + stamp |
| Level/evolve | 1.5 s sting, rising arpeggio, bell |
| Tena voice | Short synthesized "blip" phrases, never real speech unless TTS is turned on |

Pipeline: `AVAudioEngine` + preloaded `AVAudioPCMBuffer`s with an `AVAudioUnitSampler`/mixer node, ~30 WAV/CAF samples under 1 MB total; license: record or generate originals (avoid stock-license entanglement). Optional haptics via `NSHapticFeedbackManager.defaultPerformer.perform(.levelChange/.alignment/.generic, performanceTime: .now)` [pattern names confirmed; Apple page text did not render].

---

## 6. The surfaces (look and behavior) with wireframes

### 6.1 Menu bar popover
Native `MenuBarExtra` window style. The popover *chrome* gets system glass automatically (where Apple applies it) while the *content* is paper-opaque inside a card. Menu bar icon: a monochrome Tena head; states encoded by shape not color alone: normal, due (dot), hungry (open mouth), sick (bandage), asleep (closed eyes), plus a tiny due-count.

```
 menu bar:  ... Wi-Fi  Battery  [(o)_(o) 12]  14:32
                                     |
          +-------------------------------------+
          |  Tena - Juvenile        Streak 9    |
          |        ,-.   ,-.                     |
          |       ( o  v  o )   "12 words are   |
          |        `-.___.-'     hungry"        |
          |   Vitality [######----] 62          |
          |   Spirit   [########--] 80          |
          |                                     |
          |  +-------------------------------+  |
          |  |   REVIEW 12 WORDS   (Return)  |  |   <- the ONE primary
          |  +-------------------------------+  |
          |  Write a paragraph   Exam   Quests  |   <- text buttons
          |  ---------------------------------  |
          |  Pause 1 h   Quiet hours   Open app |
          +-------------------------------------+
```

### 6.2 Word overlay ("big words on the screen")
A borderless `NSPanel`, non-activating by default so it does not steal focus from a meeting or typing; shown on the display where the cursor is, never over a full-screen meeting app (hard rule). Looks like a **poster pasted on the desktop**: paper-opaque card covering ~70% of the screen (or a corner "sticker" mode at ~25% for light interruption), 3 pt ink outline, mis-registered orange offset.

Flow: arrival "slam" (`motion.slam`) -> word hero-size -> field -> Return -> feedback tier S -> auto-dismiss after 0.8 s (or next word if the batch is >1).

```
+--------------------------------------------------------------------+
|  [Esc] Skip (-20 vitality)        Word 2 / 5   ####..       00:12  |
|                                                                    |
|                                                                    |
|            R E L I A B L E                  (  ,-.  ,-.  )         |
|        ===================== (offset)          Tena: "Hint?" [?]   |
|            /rɪˈlaɪəbəl/    (speaker)                               |
|                                                                    |
|        Type the Spanish meaning or use it in a sentence:           |
|        _______________________________________                    |
|                                                                    |
|            +-------------------------+                            |
|            |      CHECK  (Return)    |                            |
|            +-------------------------+                            |
|  (kill switch: Cmd+Opt+Esc closes all Tenaz overlays)              |
+--------------------------------------------------------------------+
```
Design notes: the word auto-fits (`word.hero` shrinks to fit, minimum 96 pt); the escape and kill-switch hints are always visible (R9); the remaining time is an InkBand; hint/definition appear on `?` only (R2). Corner-sticker mode: 360x200 pt card, bottom-right, slides in with `motion.settle`, no sound.

### 6.3 Unlock gate (after unlock/wake)
A full-screen panel above other windows. Per DECISIONS.md it is NOT a security boundary and never touches the macOS login. Look: *a blank notebook page*. Left: Tena + prompt; center: writing field. Requirement can be "write N words" or "write about X" (prompts generated via Claude CLI, with a canned fallback when offline). A segmented counter ("23 / 40 words") fills as the learner types (R3); the gate opens when met, with an L tier stamp. Pre-announcement: R5 says the menu-bar icon pulses and a soft tick plays 20 s before a scheduled gate; the gate is **never** shown if a meeting app has the camera/mic active **[detection method to confirm in the platform research]**.

```
+--------------------------------------------------------------------+
|  [Esc x2] Emergency skip (-20 vitality, 1 Mercy token)    Max 5 min |
|                                                                    |
|   (  ,-.  ,-.  )   "Welcome back. Tell me about your                |
|   (  o   o  )       morning in English. 40 words."                  |
|                                                                    |
|   +------------------------------------------------------------+   |
|   | I woke up late and then I had to reply to some emails      |   |
|   | before the stand-up, which was ____|                        |   |
|   +------------------------------------------------------------+   |
|                                                                    |
|   Words  [####################..................]  23 / 40        |
|   Tip: one connector word makes it sound B2:  however, although    |
|                                                                    |
|                       +--------------------+                       |
|                       |  UNLOCK (disabled) |   <- fills orange at 40|
|                       +--------------------+                       |
+--------------------------------------------------------------------+
```
Note the max on-screen time (DECISIONS.md rule 2) is shown as a visible band and auto-dismisses with the mascot saying "we'll finish later" (and a cost), not an abrupt vanish.

### 6.4 Exam screen
Calm, quiet mode: this is the one place the intrusive chrome retreats. Paper background, no mascot motion (a still Tena in the corner), no sounds except the timer ticks in the last 10 s. TOEFL-like structure of sections is defined elsewhere; here only the layout. Two-column reading layout; top section chips; InkBand for section time; question navigator; and a persistent **integrity indicator** showing Tivra status, so the anti-cheat is honest and visible rather than a hidden surveillance feeling.

```
+--------------------------------------------------------------------+
| [Reading*] [Listening] [Speaking] [Writing]      Section  18:42 ####|
+------------------------------------+-------------------------------+
|  Passage (scrolls)                 |  Q 7 / 20                     |
|                                    |  According to paragraph 3,... |
|  The bioluminescence of ...        |   (A) ....                    |
|  ...                               |   (B) ....                    |
|                                    |   (C) ....                    |
|                                    |   (D) ....                    |
|                                    |                               |
|                                    |  [ Previous ]   [ Next (Ret) ]|
+------------------------------------+-------------------------------+
| Tivra: focus lock ON  - other apps hidden - AI tools blocked        |
| Question map: [1][2][3][4][5][6][7*][8][9] ...                       |
+--------------------------------------------------------------------+
```
Exams never use the penalty tier mid-test (no feedback until the end; sound off) because feedback during assessment changes behavior and invalidates the measurement; XL celebration only on the results screen. The integrity bar is read-only information from Tivra's MCP (DECISIONS.md rule 3).

### 6.5 Mascot home
The main window. Tena fills the center on a "stage" (a riso-printed aquarium cutaway), the day's one primary action sits under it, and daily quests are a collapsed strip (R2). Backgrounds change with time of day and season (R10).

```
+--------------------------------------------------------------------+
|  Tenaz                                  Streak 9    Coins 340   [=]|
|                                                                    |
|          .~~~ ~~  ~~~  ~~.   (aquarium, halftone water)            |
|         |       ,-.  ,-.   |                                       |
|         |      ( o  ~  o )  |   Level: Juvenile (B1+)  -> Sub-adult |
|         |       `--. .--'   |   Next: 1,600 mastered words          |
|         |  <><   TENA  <>< |   [#########-------] 912 / 1,600      |
|         '~~~~~~~~~~~~~~~~~~~'                                       |
|                                                                    |
|     Vitality [######----]   Spirit [########--]                    |
|                                                                    |
|          +------------------------------------+                    |
|          |   START TODAY'S SESSION  (Return)  |                    |
|          +------------------------------------+                    |
|   Quests (3)  v      Exam      Achievements      Shop              |
+--------------------------------------------------------------------+
```

### 6.6 Achievements
Shelf of **stamps** (like passport/riso postage stamps): earned = color stamp with date, locked = dashed outline with silhouette and a visible progress meter (R3). Rarity is the stamp border (single, double, serrated). Sorted by "closest to unlock" first so there is always a next goal (short feedback loop). New stamp = XL tier but only for rarity >= double; ordinary stamps are M tier.

```
+--------------------------------------------------------------------+
|  Achievements                  27 / 120        [Closest] Rarity Type|
|                                                                    |
|  CLOSEST TO UNLOCK                                                 |
|  +---------+ +---------+ +---------+                               |
|  | 7-DAY   | | 100     | | FIRST   |                               |
|  | STREAK  | | WORDS   | | EXAM    |                               |
|  | [#####- ]| | [####-- ]| | [#----- ]|                              |
|  |  6 / 7  | |  88/100 | |  0 / 1   |                              |
|  +---------+ +---------+ +---------+                               |
|  EARNED                                                            |
|  [stamp] [stamp] [stamp] [stamp] [stamp] [stamp]                   |
|   Hatched  First   Night   Meeting  ...                            |
|            100     owl     ready                                   |
+--------------------------------------------------------------------+
```

### 6.7 Penalty and recovery states (visual language)
Penalties are **a visual state of Tena and the paper**, never of the user's computer, consistent with `02` section 4.4.
- **Warning**: menu-bar icon pulses 1 Hz max, Tena "Hungry" taps the aquarium glass.
- **Soft cost**: scale bars lose width with a snip-cut animation; numbers roll down in red.
- **Injured**: halftone gray desaturates the stage (color drains to a single ink), cosmetics hidden; a bandage. The UI chrome stays readable.
- **Repair**: progress shown as a regrowing limb (each completed repair step reveals one more limb piece); finishing it triggers the Proud beat (tier L).
- **Skip**: a plain, honest confirmation (no guilt copy), cost shown before confirming.

---

## 7. Mascot: art style and native animation

### 7.1 Art style
Tena the axolotl as a **riso-printed spot-color creature**: flat pink body (ink `pink`), indigo outline at 3 pt, orange blush and gill stalks, halftone belly shading, and a slight mis-registration of the pink layer against the outline (the same 3 pt offset as the type). Silhouette rule: readable at 18 pt in the menu bar as a single-color glyph. Eight growth stages (`02` section 4.2) share one rig; later stages add gill-crest size, markings, and (final) the metamorph land form. Facial range = eyes (open/blink/droop/closed/sparkle), brows (2), mouth (8 mouth shapes incl. open/neutral/smile/sad/O).

### 7.2 Rendering options compared

| Option | Verdict |
|---|---|
| **SwiftUI Canvas + TimelineView + `keyframeAnimator`** | **v1 choice.** Zero dependencies, Swift 6-clean, easy to hit the reduce-motion rules, trivially vector-crisp at any size, and good enough for a modular rig (body, tail, gills, 2 eyes, mouth). Cost: you hand-author paths in code or SVG-to-`Path`, and complex blends are manual. |
| **Rive runtime for Apple** | **v2 choice for the full performance set.** The runtime is MIT licensed (`rive-app/rive-ios`, license file begins "MIT License, Copyright (c) 2020 Rive") **[verified]**; docs list macOS 13.1+ and SwiftUI representables, and the legacy `RiveViewModel` API is being replaced by a `File`/`Rive` based API in the 6.x runtime ([Rive Apple docs](https://rive.app/docs/runtimes/apple/apple); [migration guide](https://rive.app/docs/runtimes/apple/migrating-from-legacy)) **[verified via search results; pick the current API when adopting]**. State machines + inputs are what Duolingo describes ([Duolingo blog](https://blog.duolingo.com/world-character-visemes)). Cost: the *editor* is a separate product (Rive's pricing/free tier: **[unverified]**), art is authored outside Xcode, and a binary `.riv` asset must be versioned. |
| **Lottie** | Rejected: animations are timeline playback of pre-baked clips, so mood blending (hungry while talking while blinking) multiplies assets; no state machine; Rive covers the same ground better. |
| **SF Symbols effects (`symbolEffect`)** | Use for UI glyphs only (bounce on the due badge, pulse for the menu-bar icon). Not for the mascot (no character shapes). |
| **SpriteKit / SceneKit** | Reject: heavier, aging, and nothing here needs a game loop beyond Canvas. |

### 7.3 Architecture
```swift
// TenazCore (pure logic): decides WHAT Tena feels
struct MascotState: Equatable, Sendable {
    var mood: Mood          // ecstatic, happy, focused, curious, neutral, hungry, nagging, sad, sick, regenerating, proud, asleep
    var stage: Stage        // egg ... metamorph
    var cosmetics: [CosmeticID]
    var mouth: MouthShape?  // set while TTS speaks
}

// Tenaz (UI): decides HOW it is drawn
protocol MascotRenderer { associatedtype Body: View; func body(for: MascotState) -> Body }
// v1: CanvasMascot (SwiftUI). v2: RiveMascot, same inputs mapped to state machine inputs.
```
Mood -> animation mapping follows the state table in `02` section 4.3; cross-fades between moods use `motion.settle`; idle breathing uses `motion.float`; blinks fire on a randomized 2.5-6 s timer. Rendering cost control: pause `TimelineView` when the window is not visible (`scenePhase`/occlusion) and run at 30 fps unless an event animation is active **[a design choice; measure]**.

Lip sync (when TTS is on): drive `mouth` from phoneme timing; the cheap fallback is amplitude-based opening from `AVAudioEngine` tap RMS. Duolingo's own viseme set is not public to my knowledge; the DEV Community "15-20 visemes" figure came from third-party Rive-agency posts and is **[unverified]**; start with 6 mouth shapes.

---

## 8. Accessibility and safety of the design

- **Reduce Motion** (`accessibilityReduceMotion`): all springs -> `motion.reduced`; no shake, no wipe flood, no particle motion (particles replaced by a static halftone burst); InkBand steps once per second.
- **Reduce Transparency / Increase Contrast**: remove grain/halftone textures, strengthen outlines to 4 pt, use solid fills.
- **Photosensitivity**: no flashes above 3 per second; no full-screen saturated red/white strobing; the XL "flood" is a single wipe, not an oscillation. Provide a settings toggle "Calm celebrations".
- **Keyboard-first**: every flow works with Return/Esc/Tab; the global kill switch hotkey is shown on every intrusive surface.
- **VoiceOver**: word, phonetics, timer, and feedback are real labeled elements; feedback is announced via `AccessibilityNotification.Announcement` **[verified: macOS 14.0+, WWDC23 10036]**, not only visual.
- **Cognitive**: plain verbs, one idea per sentence, Spanish gloss available (the learner's L1) behind `?` in learning flows, never in exams.
- **Overstimulation guard** (ADHD can also mean sensory overload): a "Quiet mode" that disables sound, particles, halftone, and shake in one switch; the app auto-enters it during meetings and quiet hours.
- **Dark patterns check**: variable rewards with disclosed odds; no fake urgency timers except those the learner configured; all penalties reversible (aligned with DECISIONS.md).

---

## 9. Implementation checklist (design tokens -> code)

1. `TenazDesign` Swift package (no dependency on app code): `Color` assets with light/dark sets from section 3.3; `Font` helpers; `Motion` enum; `Spacing`, `Radius`; `TenazButtonStyle`, `InkBand`, `Sticker`, `Chip`.
2. Unit tests in `TenazCore`/`TenazDesign`: (a) every foreground/background token pair meets its declared WCAG ratio (computed, so seasonal palettes cannot silently regress); (b) at most one `.primary` per screen via snapshot of the view tree; (c) `Motion` returns `reduced` when the environment flag is set.
3. Preview catalogue (a Gallery window in debug builds) showing every token, tier, and state: needed because the identity relies on details that code review cannot judge.
4. Fonts: add Bricolage Grotesque variable TTF + OFL.txt to resources; confirm license text from the upstream repo before the first public build.
5. Sound: author the ~30-sample set; keep a `SoundPalette.swift` map event -> asset -> tier.
6. Mascot v1: Canvas rig with 12 mood poses; keep a `MascotGallery` preview; plan the Rive port after the M2 milestone.
7. Instrument (local only): time-to-first-answer, overlay dismiss/skip rate, session abandon rate, so that rules R1-R10 can be validated rather than assumed.

---

## 10. Open questions for the learner

1. **Direction sign-off**: Riso Arcade (navy/orange/pink on paper) vs. the two rejected alternatives. This is the highest-leverage choice; the rest follows from it.
2. **Display font**: Bricolage Grotesque is a characterful grotesque, not a "fat groovy" retro display face. If the learner wants that exact flavor, candidates need a visual test (a browser type specimen) before committing **[unverified: I did not render any specimen this session]**.
3. **Sound**: on by default (with auto-mute in meetings) or off by default? I recommend on, at low volume, because audio is a large share of the "juice".
4. **Penalty tone**: the Penalty tier is deliberately gentle (thud, droop). If the learner wants something harsher, the lever is Tena's expression and the cost shown, not red flashes.
5. **Rive editor**: acceptable to author the v2 mascot in an external SaaS editor? If not, stay on Canvas permanently.

---

## Sources

- Tiimo App Store Award post: https://www.tiimoapp.com/es/resource-hub/tiimo-winner-2025-app-store-awards ; https://mjtsai.com/blog/2025/12/11/2025-app-store-awards/ ; https://twit.tv/posts/tech/how-tiimo-makes-task-and-time-management-easier-neurodiverse-users
- Finch: https://ixd.prattsi.org/author/yiqin-meng ; https://foxdata.com/en/blogs/finch-as-app-store-editors-choice-a-self-care-companion/
- Duolingo: https://blog.duolingo.com/world-character-visemes ; https://rive.app/blog/duolingo-s-ai-powered-video-call-brings-lily-to-life ; https://creativebloq.com/news/feather-bold ; https://www.creativereview.co.uk/duolingo-rebrand-johnson-banks/ ; https://madegooddesigns.com/duolingo-brand-guidelines/
- Rive Apple runtime: https://rive.app/docs/runtimes/apple/apple ; https://rive.app/docs/runtimes/apple/migrating-from-legacy ; license: https://raw.githubusercontent.com/rive-app/rive-ios/main/LICENSE
- Juice / game feel: https://gamedeveloper.com/business/has-your-game-got-juice-more- ; https://ojs.aaai.org/index.php/AIIDE/article/download/18889/18654/22655 ; Balatro analysis https://blakecrosley.com/guides/design/balatro
- Liquid Glass (secondary): https://www.donnywals.com/designing-custom-ui-with-liquid-glass-on-ios-26/ ; https://dev.to/arshtechpro/understanding-glasseffectcontainer-in-ios-26-2n8p
- ADHD design: https://evalab.artun.ee/dual-timer/ ; https://vp0.com/blogs/adhd-daily-routine-planner-ui-swiftui ; https://www.frontiersin.org/journals/education/articles/10.3389/feduc.2025.1668260/full
- Fonts: https://www.fontsquirrel.com/license/fredoka ; https://github.com/ateliertriay/bricolage ; https://fontmeme.com/jfont/bricolage-grotesque-font/
- Local: `DECISIONS.md`, `docs/research/02-gamification-mascot.md`, the design-taste notes.

---

## Verification

Checked 2026-10-22 by a skeptical pass. Verdicts: confirmed / corrected / unverifiable.

| # | Claim | Verdict | Source |
|---|---|---|---|
| 1 | All WCAG contrast ratios in section 3.3 (16 pairs incl. the rejected `#1F7A4D` at 4.49) | **Confirmed**, recomputed with the WCAG luminance formula, all match to 2 decimals | local computation |
| 2 | Ink on orange (4.38:1) is acceptable with "20 px semibold" | **Corrected**: large text needs >=18 pt or >=14 pt **bold**; semibold is not bold. Button spec changed to 20 pt Bold | https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html |
| 3 | Large-text threshold 18.66 px bold | **Confirmed** (14 pt x 1.333 = 18.67 px) | same WCAG page |
| 4 | Max 3 flashes per second (WCAG 2.3.1) | **Confirmed**; link was marked unverified, now verified | https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html |
| 5 | Bricolage Grotesque is SIL OFL, variable with opsz/wdth/wght | **Confirmed** (OFL 1.1, 2022, no RFN). Exact TTF filename **unverifiable** here | https://raw.githubusercontent.com/ateliertriay/bricolage/main/OFL.txt ; https://github.com/ateliertriay/bricolage |
| 6 | Rive iOS runtime is MIT, macOS 13.1+, SwiftUI representables, legacy `RiveViewModel` being replaced | **Confirmed**. Extra: only the new runtime supports VoiceOver semantics | https://raw.githubusercontent.com/rive-app/rive-ios/main/LICENSE ; https://rive.app/docs/runtimes/apple/apple |
| 7 | Tiimo won iPhone App of the Year, 2025 App Store Awards | **Confirmed** (post dated 19 Nov 2025, updated 4 Dec 2025) | https://www.tiimoapp.com/es/resource-hub/tiimo-winner-2025-app-store-awards |
| 8 | Duolingo Feather Bold, Johnson Banks + Fontsmith, 2019; UI font "DIN Round" | **Confirmed** designer/year via search of Monotype/Creative Bloq; UI font **corrected** to DIN Next Rounded (Monotype). `#58CC02` remains secondary | https://creativebloq.com/news/feather-bold ; https://www.monotype.com/resources/duolingo-custom-font-inspired-their-owl-mascot-duo |
| 9 | `kAudioDevicePropertyDeviceIsRunningSomewhere` for meeting detection | **Corrected (caveat added)**: exists, but unreliable for Bluetooth mics and ambiguous on input/output devices | https://developer.apple.com/forums/thread/741026 |
| 10 | `AccessibilityNotification.Announcement`, `.spring(duration:bounce:)`, `NSHapticFeedbackManager` patterns, `glassEffect`/`GlassEffectContainer` (macOS 26), `colorSchemeContrast` | **Confirmed** at name/availability level (macOS 14+, 14+, n/a, 26+, 10.15+). Apple pages mostly did not render, so signatures are from search snippets. `contentTransition(.numericText())` availability **unverifiable** this pass | https://developer.apple.com/documentation/accessibility/accessibilitynotification/announcement/post() ; https://developer.apple.com/documentation/swiftui/glass |
| 11 | `/System/Library/Fonts/SFNSRounded.ttf` exists | **Confirmed** on macOS 26 (system font listing) | system fonts |

Not checked (still [unverified] in text): Frontiers 2025 RCT outcomes, Finch awards, Balatro analysis, Rive pricing, "MenuBarExtra gets system glass automatically" (no source found), Apple HIG Reduce Motion behavior.

## Gaps found in verification

- **Contrast of the mis-registered orange layer and the orange fill against paper is only 3.1:1**: it passes the 3:1 non-text bar by a hair, so the 3 pt ink stroke on primary surfaces (already specified) is load-bearing; do not drop it in Increase Contrast or seasonal palettes (the build-time WCAG test should enforce >=3.0 with a margin).
- **Meeting detection needs a second signal**: the CoreAudio running-somewhere flag misses Bluetooth mics, so DECISIONS.md "never interrupt a meeting" should also use calendar events (EventKit), foreground/full-screen meeting apps, and camera state.
- **Rive new runtime is the only one with VoiceOver semantics**; the "v2 Rive" plan should target the new `File`/`Rive` API, not the legacy `RiveViewModel`.
- **`contentTransition(.numericText())` and `MenuBarExtra` glass behavior on macOS 26 remain untested**: verify on the actual Mac in the M1 spike before relying on them.
- **Font file shipping**: bundle OFL.txt with Bricolage and confirm the variable TTF filename in the repo `fonts` folder; the file name in the report's listing came from a third-party site.
