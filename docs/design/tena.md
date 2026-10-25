# Tena: mascot guideline (Ink & Smile)

The rules for Tena, the pink axolotl. Every change to her art, poses, crops or palette must follow this file.
It describes what is built on `tena2-a`. Code lives in `Tenaz/Features/Mascot/`. Where this file and the code
disagree, fix one of them in the same change.

Direction: **A (Ink & Smile)** for the look, plus **C's body poses** for the acting. Chosen by the owner, 25 Oct 2026.

## 1. Identity invariants (never change)

1. **Species.** Axolotl. Pink body (#F7A6C1), red gills. She never turns gold, maroon, purple or teal. Recolours are accents only (Elder amber tips).
2. **Gills.** 3 per side, always. Roots sit on the head contour at polar angles 40 / 20 / 2 degrees. Axes at rest are 58 / 30 / 6 degrees above horizontal, so they fan up and back, never straight out. Top frond is longest. Lengths follow 1 : 0.88 : 0.70. Each frond tapers. Filaments sit on the upper edge only, in gill deep, never ink. Roots grow out of the head contour (one outline runs around both).
3. **Head.** Wider than tall. A split superellipse: exponent 2.6 on top, 2.2 below. Widest at the cheek line, 6 u below the centre. Flat top, squared jaw. Never an ellipse.
4. **The smile.** At rest the mouth is a wide, thin, upturned line, 0.60 of head width. It sits 0.22 head heights below the eye line. It survives every stage. It only shrinks for Curious (0.25), Sad (0.30), Asleep (0.20).
5. **Eyes.** Small beads, centred at 0.25 of head width either side of the head centre. Never the centred kawaii placement. Bead is 6.5 x 7 u radius at Juvenile, times the stage `eyeScale`.
6. **Crown mark.** Three mark-pink dots in a shallow arc above and between the eyes, centre dot 10% larger. Present at every stage, the egg shell included. It is her signature.
7. **Light.** Fixed at upper right. Gloss dots and highlights sit upper right and never flip per mood.
8. **No brows.** Brow work is done by upper-lid cuts on the eye (lid cover plus lid angle).
9. **Banned on her:** blush ovals, ground shadow, halo, keyline, dashed or circle frames, emoji props, gradients.

## 2. Construction grid

200 x 200 unit box, origin top-left, y down. Juvenile is the reference. Values are in `TenaBuild` and `TenaRig+Body`.

| Part | Spec |
|---|---|
| Head | centre (100, 80), 124 x 80 |
| Eye line | y = head centre + 2. Eyes at x = 100 +/- 0.25 W |
| Mouth | centre y = eye line + 0.22 H. Open shapes are one 6-point path so every mouth blends into every other |
| Nostrils | two tier-2 dots at +/- 7 u, 8 u below the eye line. Standard and Hero only |
| Crown | three dots above the eyes (see `crown(head:)`) |
| Body | bean, 72 x 52 at Juvenile, tucked under the head. Head and body are **one unioned outline** (no snowman seam) |
| Arms | tubes with an elbow and a 4-lobe hand (3 on buds) |
| Legs | short thighs, 4-toe feet at Standard |
| Tail | leaves the right hip, length 1.0 x body width, fin frill along the top that continues as a dorsal crest |
| Shade | exactly one shape: the head's cast shadow, a crescent under the left jaw (light is upper right). No bands |
| Fit | the rig fits the resting silhouette into the box with a 4 u margin plus ink. One scale per stage, so moods never jump in size |

Stages differ by **proportion, not zoom**.

## 3. Stage table (`TenaBuild.for`)

| # | Stage | Head | Body | Eye scale | Top gill (x W) and shape | Limbs | Tail | Marks |
|---|---|---|---|---|---|---|---|---|
| 0 | Egg | 56 x 36 embryo | 40 x 30 curled | 1.2 | 0.12 nub | none | curled, wraps to the cheek | crown on the shell |
| 1 | Hatchling | 120 x 84 | 50 x 34 | 1.25 | 0.16 nub | none | 0.5 | crown |
| 2 | Larva | 122 x 82 | 58 x 40 | 1.15 | 0.24 tube, 2 notches | front buds | 0.8, dorsal starts | crown |
| 3 | Juvenile | 124 x 80 | 72 x 52 | 1.0 | 0.34 fringe 4 | all | 1.0 + crest | crown |
| 4 | Sub-adult | 126 x 78 | 80 x 60 | 0.92 | 0.40 fringe 5 | all, longer | 1.15, curl | crown + 4 |
| 5 | Adult | 128 x 76 | 86 x 66 | 0.86 | 0.46 fringe 5 | all, longer forearms | 1.3, taller fin | crown + 6 |
| 6 | Elder | as Adult | as Adult | 0.86 | 0.52, swept 8 deg back, fringe 5, **amber tips** | all | 1.3, **amber fin edge** | crown + 6 |
| 7 | Metamorph | 118 x 78 | 88 x 76 | 0.95 | **reabsorbed** to 0.12 nubs | legs x1.3 | 0.8, no fin | crown + 9, deeper pink |

Head-to-body ratio and eye scale fall with age. Limbs, tail and gill complexity grow. Gill shape runs nub, tube, fringe, fringe with amber, nub.

Metamorph eyes are raised 26 u and sit in body-pink **domes** that rise above the head line. The crown dots move up between them. One `eyeDomes` helper serves the upright, bust and asleep figures.

Mouth, eye spacing, crown and gill angles are the same at all 8 stages.

## 4. Silhouette test (run on every pose change)

Render `mascot-qa`. Row "Silhouette, 64 pt, props off" fills every mood solid ink.

1. Every cell reads as an axolotl from the gill fans alone.
2. The 12 moods fall into at least 8 distinct shapes.
3. No two stages share a silhouette.

Known: Asleep draws about 15% smaller than the others at 64 pt because she lies wide.

## 5. Line rules

- Tier 1 = `max(1.4 pt, size x 0.0095)`. No upper cap. It strokes the silhouette, every closed part, the mouth, the lid lines and props. The contour is drawn at 2x tier 1 and half is hidden by the fill.
- Tier 2 = `max(0.9 pt, 0.55 x tier 1)`: finger and toe splits, nostrils, creases. Dropped at Small and Glyph.
- Ink is one solid colour. Never opacity on ink, never grey.
- Round caps and joins everywhere.
- Gill detail (filaments, root bands) is gill deep, never ink.
- Fin ribs, at most 5, are shade pink, never ink.

## 6. Palette (`Palette.paper` / `Palette.nightPress`)

| Role | Token | Light | Dark |
|---|---|---|---|
| Body | `tenaPink` | #F7A6C1 | #F7A6C1 |
| Belly, snout | `tenaBelly` | #FCD3DF | #FCD3DF |
| Shade | `tenaShade` | #E886A8 | #E886A8 |
| Mark (crown, freckles) | `tenaMark` | #E06C98 | #E06C98 |
| Gill | `tenaGill` | #C8352A | #F0583A |
| Gill deep | `tenaGillDeep` | #A82634 | #C8352A |
| Ink | `tenaOutline` | #311228 | #311228 |
| Elder amber | `tenaAmber` | #F4A72A | #F4A72A |
| Highlight, sclera | fixed | #FFF7EE | #FFF7EE |
| Mouth interior | fixed | #7A1F35 | #7A1F35 |
| Tongue | fixed | #F06A86 | #F06A86 |

- Ink is **#311228**, not the first-draft #3A1630. #3A1630 gives only 5.05:1 on Night celebrate. #311228 gives 5.41:1 at worst and 8.96:1 against the pink. The test `tenaContourKeepsItsMarginOnLightFloods` requires at least 5.4:1 on turn, good, fix and celebrate on both sheets, plus Paper's background. Do not weaken it. If you change the ink or a flood, make the test pass.
- Amber must never equal gold (#FFD43B).
- Swap tokens only. No runtime hue maths, except two sanctioned cases below.
- **Warm floods** (`.fix` coral, `.celebrate` orange): the gill fill steps down to gill deep, because #C8352A is only 2.29 and 1.85 there. Set by `warmFlood`.
- **Sick wash:** `fade` 0.35 toward paper (light) or #EEC4C2 (dark). Sick gills first mix 30% toward body pink and lose 15% saturation, so they never go brown or grey.

## 7. Light and dark floods

- **Light floods** (paper, turn, good, fix, celebrate): pink is only 1.0 to 1.8:1 against them. The ink contour carries the silhouette. Never draw her without the outer contour there.
- **Dark floods** (serious, risk, Night): pink is 6.8 to 9.9:1. The pink fill carries her. The ink becomes an internal seam. Draw no keyline and no halo. One `rig.draw` per frame.
- Floating ink marks (the "z", sign text outline) take the belly pink on dark floods.

## 8. Face system

**Fixed, never per mood:** head shape, eye centres and base size, mouth anchor, crown dots, gloss position, gill count and roots.

**Channels a mood may change** (at most 3 away from Neutral, plus a prop):

1. **Eye state.** Beads never change shape. Upper lid cover 0 to 0.7. Lid angle -25 to +25 deg (+ = inner corner down, cross). Lower-lid push 0 to 0.45. Closed `.up` (^ ^) or `.down`. Gaze up to ~0.22 of the eye radius. Bead scale 0.9 to 1.1 only. A stare shrinks the gloss instead. A second small gloss dot makes a wet eye (Sad).
2. **Mouth.** Width 0.20 to 0.62 W (0.66 only at Glyph). Curve -1 to +1. Open 0 to 1 with a filled interior and optional tongue. Skew (one corner higher). Round (D to O), square, wave, offset.
3. **Gill posture.** Lift per frond, spread, stiffness (0 wiggles, 1 rigid), tip curl, left/right asymmetry, length.
4. **Body pose.** Preset, lean (sideways), forward (head drops or lifts), squash.

Gaze is a bead shift plus head tilt.

## 9. The 12 moods (`TenaPose.for`)

Neutral is the baseline. Values are exact; change them only with a reason.

| Mood | Eyes | Mouth | Gills | Body | Prop |
|---|---|---|---|---|---|
| Ecstatic | closed `.up`, thick | open D 0.60, tongue | lift +14, spread 1.1, wiggle 9 | **arms up**, fists beside the cheeks (palm plus three knuckles, no fingers), squash 0.96 x 1.06, hops | none (burst not built) |
| Happy | lid 0, lower lid 0.45 | smile 0.60, curve +0.6 | lift +10 | `.open`: paws open a little at chest height, lean 4 | none |
| Focused | lid 0.4, gaze down 0.15 | flat 0.50 | lift -6, stiffness 0.3 | lean forward: forward 12, lean 7 | headset |
| Curious | lid 0, gaze up-right, near eye x1.1 | small "o" 0.25, offset 0.06 | asymmetry +12 | tilt-reach, lean 6, **tilt 13**, hand at the chin | none |
| Neutral | lid 0.1 | rest 0.60, curve +0.3 | rest fan | sit | none |
| Hungry | lid 0.22, angle -12 (worried), gaze up | wide low oval 0.40, corners down | lift -4 | **press**: both palms flat on the glass, forward 4 | none |
| Nagging | lid 0.3, angle +18 (cross), bead 0.45 (stare) | open squarish 0.50 | lift +12, **rigid** | hold-sign, forward 8 | sign with the due word; **no word: fists held up, elbows out** |
| Sad | lid 0.45, angle -20, gaze down, wet eye | down-curve 0.30 | lift -24, spread 0.9 | slump, squash 1.06 x 0.94 | none. No tear |
| Sick | lid 0.5 / 0.6 (mismatched), flat | wavy 0.40 | lift -24/-28/-33, curl 10, asymmetry -14, length 0.82 | `.hurt`: bandaged left arm cradled across the belly, right arm hangs, lean -7, **tilt -9**, fade 0.35 | bandage on the limb |
| Regenerating | lid 0.25, gaze at the regrowing arm | 0.54, **skew 0.65** (corner tucked up) | lift +4 | `.regrow`: short arm held up and out, lean -4, **tilt -6** | the regrowing limb: length 0.35 + 0.65p, belly pink until p = 1 |
| Proud | lid 0.55, lower lid 0.3 (smug) | smile 0.62, skew +0.3 | lift 12 / 22 / 30, spread 0.85, stiffness 0.5, asymmetry 6: a **tall uneven crown** | `.hips`: elbows out, lean -9, forward -5 | medal (Standard and up) |
| Asleep | closed `.down` | small "o" 0.20 | lift -10, curl 30 | **lying on her belly, chin on folded front paws**, domed back, low crest, hind foot showing, tapered tail trailing with a fin to the tip | one "z" (Standard and up) |

**Distinctness rule (review test).** With props off, at 64 pt in greyscale, these pairs must differ in **at least 2** of {eye state, mouth, body pose, gill posture}: Happy-Neutral, Proud-Happy, Proud-Regenerating, Happy-Regenerating, Hungry-Curious, Nagging-Sick, Sad-Neutral. Keep it that way.

**Limbless stages (Egg, Hatchling, Larva).** Hand poses become gill and head poses. Regenerating regrows the top-left gill. Sick wraps the top-left gill. On the Egg all moods map to eye state plus egg motion; Sick fades.

**Nagging with no word.** The sign card is drawn only when props are on and a word is set. Otherwise she holds up her fists. Today no production view passes `word` to `TenaView` (only snapshots, the QA sheet and the gallery do), so Home, the sidebar and the popover show the fists. Showing the real due word needs the data layer (`TodaySummary`, `PopoverState`) to supply it.

## 10. Size tiers (`TenaRig.lod`)

| Tier | Size | Rules |
|---|---|---|
| Hero | 400 pt and up | full detail: filaments, freckles, fin ribs, props, crescent eye for Happy |
| Standard | 120 to 399 | 4 fingers, 4 toes, fringe, nostrils, props, crescent eye for Happy |
| Small | 56 to 119 (sidebar 64 pt) | no filaments (tubes with 2 notches), no freckles, no nostrils, no tier 2 except 2 finger notches on hands. **Eyes x1.3, face strokes x1.25**, lid cover quantised to 0 / 0.4 / 0.7. Happy keeps the half-moon eye. Props shrink to one silhouette. Body pose is kept: it is the silhouette |
| Glyph | below 56 (list rows, 36 pt) | **bust**: head plus gills, cut at the chin. Head is always 78% of the frame width; the frame crops the fans, the fans never shrink. Eyes x1.4, face strokes x1.4. Lid lines are kept and drawn thicker. Gill lift x1.6, asymmetry x1.5, mouth skew x1.5, curve x1.3, width x1.08 (max 0.66). No props |
| Menu bar | 18 pt | `TenaGlyph`: a solid template head, three tapered fronds per side, face cut out. Every cut-out and frond at least 1.5 pt. States: normal, due (badge at lower right), hungry (fans flared, mouth open), sick (one fan dropped, heavy lids, wavy mouth), asleep (fans curled, closed arcs) |

Not yet checked in a real menu bar.

## 11. Hero crop

One rule for every hero screen: `TenaInk.bottomCut` (used by Home, `BleedTena`, the overlay and onboarding).

1. **Bottom edge** cuts through the hips: 86% of her measured ink height.
2. The cut is also at least **0.35 head heights below the chin**, and at least **4.5% of the window height below her lowest hand**.
3. If the cut would only graze her feet (Neutral's low hands, the hatchling), she is shown **whole, 4.5% above the edge**, with no ground shadow. Asleep always lies whole.
4. **Side edge** may cut gills and the tail. It never cuts a hand, an elbow or her head. If it would, she moves in until her arms are 4.5% of the window from the edge, and shrinks so her far gills stay at least 3% of the width from the text column (`textEdge`).
5. On Home the left edge takes at most 5% of her ink width.
6. **Size.** Side layout (`main-wide`): she fills about 70% of the window height (cap 75%). Her face band is 61 to 72% down. Stacked layout (`home`, `main` at 980 x 1080): about 43 to 45% of the height, face below the text block. Section intro shows her whole at 380 pt. Placement intro is about 45%, limited by the text column.
7. **Face placement.** The face never sits behind the text column or the pill. A clean crop wins over a higher face. (This replaces the old "face 30 to 50% down", which cannot hold together with a hip crop.)
8. **The window edge is the only crop.** Never an inner container edge. The popover draws her whole in the 150 pt card: 166 pt frame, 26 pt past the left window edge, moved in when the edge would reach her head (8 pt clear), shrunk when her far gills come within 6 pt of the text. Exam results and history draw her whole; only the right window edge cuts her gills.
9. **Extras** stay inside her bounds, on the side away from the text. Sparkles never land next to the pill.

## 12. Props

Props are worn objects or actions, never emoji. The whole list: **headset** (Focused), **sign with the word** (Nagging, Fraunces text set by the view), **bandage** (Sick, on the limb, never the forehead), **regrowing limb** (Regenerating), **medal** (Proud, Standard and up), **one "z"** (Asleep, Standard and up). Cosmetics hide in Sick.

Banned: "?", "!" bubbles, sweat drops, plus signs, 4-point sparkles on her, tears, drool, blush.

Props use the line rules and the palette, and sit in a layer over an unchanged base.

## 13. Motion that exists (`TenaRig+Motion`)

All of it is zero at time 0, so snapshots show the resting pose and are identical between runs. Idle runs at up to 30 fps, and stops when hidden, under Reduce Motion, or with `mascotStill`. Jitter is seeded from the mood and stage index, never from string hashes.

- Breath: period 2.8 s times the mood rate.
- Gill wiggle: amplitude per mood, times (1 - stiffness). Quarter-cycle offset per frond, top leads.
- Blink: every 3.2 to 6.0 s with seeded jitter. Close 90 ms, hold 40 ms, open 120 ms. Double blink 15% of the time. Never while Asleep (closed eyes).
- Gaze drift: +/- 0.06 of the eye radius.
- Head sway: 1.5 deg over 5.2 s.
- Ecstatic hops 6 u every 1.4 s, landing squash 1.06 x 0.92 for 80 ms. No other mood bounces. No float, no ground.
- Exactly one rig draw per frame.

## 14. Not built yet

Do not state these as shipped. Build them in a later pass.

- 280 ms ease-out between moods, and prop spring-in. Today a mood change swaps the pose at once.
- Evolution ceremony (1.2 s morph, gills grow last).
- Ecstatic event burst (3 hollow bubble rings, once).
- Hunger rumble ticks at the belly.
- Egg hatch (zigzag crack, lifting cap).
- Elder spectacles.
- A real indigo hero flood and a dark-mode hero check.
- Showing the real due word on Nagging's sign (data layer).
- The idle loop has never been watched running.

## 15. Do / Don't

**Do:** the wide axolotl smile. Lids instead of brows. Body acting first, props second. Tapered, swept gills with a top-long hierarchy. One outline from the unioned silhouette. Line weight that scales with size. Tokens per scheme. Crown dots at every stage. Crops through body mass. Pink at every stage.

**Don't:** disc eyes with star catchlights. Cat ":3" mouths. Floating brow dashes. Blush ovals. Horizontal shade bands (they read as chin, shorts or diaper). Grey or translucent ink. Emoji props. Ground shadows. Keylines or halos on dark floods. Gold or maroon body recolours. Dashed egg rings. The same pose for two moods. Crop lines on hands. Sparkles outside her bounds. Gloss streaks and heavy sticker ink. Drawing the rig more than once per frame.

## 16. Review checklist

1. Silhouette test (section 4) passes.
2. Distinctness pairs (section 9) pass in greyscale at 64 pt.
3. The 36 pt bust reads all 12 moods by eye, mouth and gills.
4. Light floods show an unbroken contour. Dark floods show no keyline.
5. Hero crops obey section 11 on every screen that shows her. No crop touches a hand, an arm or her head.
6. The stages strip shows 8 distinct proportions with the same mouth, crown and gill angles.
7. Snapshots at time 0 are deterministic (two renders, same md5).
8. `swift test` is green, including the contour contrast test.
9. You looked at the renders.

## 17. Render and QA

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate --quiet && xcodebuild -project Tenaz.xcodeproj -scheme Tenaz -configuration Debug -derivedDataPath .derived build
.derived/Build/Products/Debug/TenazDev.app/Contents/MacOS/TenazDev --tenaz-snapshot <name> --out x.png [--dark]
swift test
```

Snapshots (`Tenaz/App/SnapshotRegistry.swift`):

- `mascot-gallery`: 8 stages by 12 moods, light and `--dark`.
- `mascot-qa`: 12 moods on four floods at 64 pt and 36 pt, in colour and in greyscale with props off, the silhouette row, and the menu-bar glyph states.
- `tena-<mood>`: one mood at 520 pt on transparent. `tena-nagging-noword` shows the fists fallback.
- Screens: `home`, `home-risk`, `main`, `main-wide`, `popover`, `review-correct`, `review-checkpoint`, `write-done`, `placement-intro`, `exam-section-intro`, `exam-results`, `gate-unlocked`, `gate-later`, `preannounce`, `onboarding-1-hatched`, `app-icon-<mood>`.

Add new screens in one line in the registry. Check hero crops on both a light and a dark flood.

App icon: `AppIconArt` holds the shared numbers (1.2x the tile, offset (4, 78)). The `tena.png` layer is the `icon-tena-happy` snapshot rotated 8 degrees. Regenerate it when the art changes.

## 18. References

Dribbble shots that shaped the look. All are inspiration, not copies.

- [27553948](https://dribbble.com/shots/27553948): real axolotl anatomy. Small wide-set eyes, near cheek-to-cheek smile, three stalks per side.
- [27647620](https://dribbble.com/shots/27647620): flat tapered gill paddles with comb filaments, fanned 60 / 40 / 15 deg, one flat shade shape.
- [10500275](https://dribbble.com/shots/10500275): warm dark uniform ink with round caps, calm face. The un-kawaii register.
- [3528695](https://dribbble.com/shots/3528695): thin upturned smile, bead eyes with one highlight, darker spot clusters.
- [20636743](https://dribbble.com/shots/20636743): mouth range from huge open to tiny.
- [27304726](https://dribbble.com/shots/27304726): attitude from lid slant, half-lid and arms (Nagging, Proud).
- [27732928](https://dribbble.com/shots/27732928): the Full Bleed framing, character cropped by the frame on a saturated flood.
- [27732932](https://dribbble.com/shots/27732932): "down" states as few changes; a flood swallowing the accent (Sick).
- [22279403](https://dribbble.com/shots/22279403): ruffled gill and fin edges.
- [27288738](https://dribbble.com/shots/27288738): the lifting cap idea for the egg hatch (not built).
