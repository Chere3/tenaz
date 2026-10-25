# 02 - Gamification and the growing mascot

Date: 2026-10-22. Scope: what the evidence says about gamification, what to copy from Duolingo / Finch / Habitica / Forest, and a concrete mascot system for Tenaz.

Evidence labels: **[verified]** = I opened or got a search result for a source this session. **[secondary]** = only blogs or press repeating a claim. **[unverified]** = from my background knowledge or not found; do not build on it without checking. Research depth was limited (about 10 searches, no full-text paper reads), so treat every effect size as "as reported in the abstract or summary".

---

## 1. What the evidence says (and what it means for Tenaz)

### 1.1 Meta-analyses: gamification works, modestly, and design matters

- **Sailer & Homner (2020), Educational Psychology Review 32:77-112.** Random-effects effects of gamification: cognitive learning outcomes g = .49, motivational g = .36, behavioral g = .25. The cognitive effect held up in the high-rigor subset; motivational and behavioral effects were "less stable". For behavioral outcomes, **game fiction (a story or character) and social interaction were significant moderators**. [verified, search summary] https://opus.bibliothek.uni-augsburg.de/opus4/frontdoor/index/index/docId/109056 and https://gamification-research.org/2019/08/does-gamification-of-learning-work/
  - Implication: the mascot and its story ("fiction") are not decoration. They are one of the few moderators with measured support for behavioral outcomes. Social interaction is limited in a single-user Mac app; see section 5.6 for a cheap substitute.
- **Bai, Hew & Huang (2020), "Does gamification improve student learning outcome?"** 30 interventions from 24 studies, overall medium effect g = 0.504. Effects varied with sample size and **intervention duration**, not with the type of game element. A secondary source cites a language-discipline subgroup of g = 0.377. [verified overall figure; subgroup is secondary] Note: the same authors' ICCE 2019 conference paper (computing education only) reports a different, smaller g = 0.36; do not mix them. https://www.gbl.uzh.ch/quartz/references/Bai-et-al.-(2020) , https://encyclopedia.pub/entry/history/compare_revision/107433/-1
  - Caveat: the Bai summary I got did not confirm the journal. I believe it is Educational Research Review 30, 100322 [still unverified: no source retrieved in the verification pass names the journal].
  - Implication: "which element" matters less than "does the whole system keep the learner practising over time". Choose elements by whether they drive retrieval practice, not by novelty.
- **Hamari, Koivisto & Sarsa (2014), "Does gamification work?"** Literature review: positive effects, but heavily dependent on context and user. Most-tested elements: points, leaderboards, badges. [verified, summary] https://www.lescahiersdelinnovation.com/wp-content/uploads/2019/06/2014-hamari_et_al-does_gamification_work.pdf
- **Mekler et al. (2013 conference / 2017 journal).** In an online image-tagging experiment (2x4 design; the sample size of 295 could not be verified [unverified]), points, levels and leaderboards raised performance but did not change intrinsic motivation, perceived competence or autonomy, and did not undermine them either. Journal version: Computers in Human Behavior 71 (2017), 525-534. [verified in verification pass: https://edoc.unibas.ch/32047/] https://gamification-research.org/2014/08/gamification-absolved-2/ . Sailer et al. (2017) found badges, leaderboards and performance graphs *did* support competence need satisfaction. [secondary, same page]
  - Reading of the whole body: points and badges are cheap "scoreboard" feedback. They help when they communicate **competence** (informational), and are neutral-to-risky when they feel controlling. Design them as feedback ("you mastered 12 words that you used to fail"), not as bribes.

### 1.2 Self-Determination Theory as the design filter

SDT claims three needs: autonomy, competence, relatedness. I did not retrieve Deci, Koestner & Ryan (1999) this session [unverified], but the well-known result is that tangible, expected, contingent rewards can undermine intrinsic motivation while informational feedback does not. Search snippets above (the Mekler discussion) are consistent with "informational feedback does not undermine".

Design rules that follow:

1. **Autonomy.** the learner configures the punishments themselves (already in DECISIONS.md: "intrusive but self-chosen"). Show the learner the rule at the moment it fires ("You chose this on Oct 22"). This is the single most important SDT safeguard for an *intrusive* app.
2. **Competence.** Every reward should say what skill it proves. XP toast = "+18 XP: recalled 'reluctant' after 9 days". Never a bare "Great job".
3. **Relatedness.** The mascot is the relatedness channel (a parasocial companion), plus optional Claude conversation partner. No fake social leaderboards.
4. **Reward the effort-to-competence loop, not time-on-app.** XP paid for correct retrieval of *due* items (FSRS) and for produced language, never for opening the app.

### 1.3 Octalysis: useful as a checklist, weak as evidence

Octalysis has 8 core drives; "White Hat" drives (meaning, accomplishment, creativity/empowerment) are on top, "Black Hat" drives (scarcity, unpredictability, loss/avoidance) on the bottom. [verified, source is Chou's own material] https://yukaichou.com/gamification-framework/ . Chou's claims of academic validation are self-reported [unverified]. Practical use: audit that the mascot system covers drives 1-8 and that Tenaz's deliberately "Black Hat" parts (loss, scarcity, urgency) are balanced by White Hat meaning (identity: "I am becoming someone who can speak up in a meeting").

Mapping used later:

| Drive | Tenaz mechanic |
|---|---|
| 1 Epic meaning | Goal anchored to the learner's real stake (for example English-language work meetings); mascot evolves as CEFR does |
| 2 Accomplishment | XP, levels, achievements, exam bands |
| 3 Creativity | Writing "life paragraph" unlocks; mascot customization |
| 4 Ownership | Mascot, cosmetics, a personal "vocabulary garden" |
| 5 Social influence | Claude-voiced mascot reactions; optional weekly digest to a friend (opt-in, later) |
| 6 Scarcity | Limited-time seasonal cosmetics (use sparingly) |
| 7 Unpredictability | Mystery drops after a session (see 3.3) |
| 8 Loss avoidance | Mascot health, streak, XP at risk |

### 1.4 What moves learning vs what moves engagement

Reasoned synthesis of the sources above, not a single published finding:

- **Moves learning (cognitive g = .49):** things that cause *more or better retrieval and production*: spaced reviews, being forced to write, immediate corrective feedback, difficulty adaptation, exams with real standards. Fiction/story also helps behavior (Sailer & Homner).
- **Moves engagement only:** badges for opening the app, cosmetic-only points, leaderboards against strangers, confetti. They are fine as seasoning but never as the core.
- **Risk:** reward-driven habits replacing real motivation. A diary study of a gamified self-care pet app reported early support turning into reward-driven habits (second-hand via a blog; original not found) [secondary] https://makeheadway.com/blog/finch-app-review/ . For Tenaz: weight rewards toward *skill markers* (mastery counts, exam bands), so the reward points at the thing the learner actually wants.

---

## 2. What to learn from existing products

### 2.1 Duolingo

Verified or semi-verified:
- **Streak Freeze**: lets a learner pause a streak for a day; Duolingo's blog says letting learners equip **two** freezes raised daily active learners by a relative **+0.38%**; reaching a **7-day streak** correlates with being **3.6x** more likely to complete the course (correlational, not causal). [verified, official blog snippet] https://blog.duolingo.com/how-duolingo-streak-builds-habit
- Retention is most fragile in the first 7 days; opt-in streak-length choice gave a sense of ownership [secondary, Lenny's podcast summary] https://lennysnewsletter.com/p/behind-the-product-duolingo-streaks . A streak-saver *notification* was an early big win; the "10-day streak = less churn" insight carried selection bias (admitted in the same summary). https://www.lennysnewsletter.com/i/104096876/the-streak-vector
- A Gardenscapes-style move-counter mechanic yielded no retention gain [secondary, LinkedIn post via search]. Lesson: copying game mechanics does not auto-transfer.
- "Streak wager gave +14% day-7 retention" is from a marketing blog with no method [secondary, do not rely on it]. https://www.strivecloud.io/blog/blog-gamification-examples-boost-user-retention-duolingo
- Leagues: I found **no primary measured effect** [unverified]. Do not assume leagues are a driver; Tenaz is single-player anyway.
- Learning-model side: Duolingo's Birdbrain (2020) personalizes difficulty; A/B tests reported content length +8.9% and time spent +3.1% [secondary, VentureBeat summary] https://venturebeat.com/business/how-duolingo-is-using-ai-to-humanize-virtual-language-lessons . Half-Life Regression (Settles & Meeder, ACL 2016) has open-source code at https://github.com/duolingo/halflife-regression [verified link via a Harvard D3 case study; paper is Settles & Meeder, ACL 2016, pp. 1848-1858, "A Trainable Spaced Repetition Model for Language Learning", https://aclanthology.org/P16-1174/ ; verified].
- Duo "guilt" notifications: I found **no measured effect** [unverified]. Treat as folklore. Tenaz's nag should be measured by the learner's own data (see section 8).

Takeaways:
1. Streaks work as a habit anchor; **forgiveness (freezes) was itself an engagement win**. Tenaz needs freezes even though it is "intrusive".
2. First-week design is a retention lever. Tenaz's first 7 days should be unusually generous (higher XP, guaranteed mascot growth beats).
3. Streak-at-risk notifications are cheap and high-yield; do that before fancy things.

### 2.2 Companion / virtual pet research

- **Fish'n'Steps (Lin et al., 2006).** Daily pedometer steps drive the growth/mood of a virtual fish in a tank; 14-week study, 19 participants; players increased steps or advanced in stages of change. [verified via search summary: 14 weeks, 19 participants; DOI 10.1007/11853565_16, UbiComp 2006. The earlier cdgr.ucsb.edu link was wrong (it points to an unrelated page)]
- **UbiFit Garden (Consolvo et al., CHI 2008).** A glanceable garden on the phone background: flowers grow with activity. The CHI 2008 paper reports a 3-week field trial with 12 participants (verified). A separate, later 3-month field experiment over the 2007/8 winter holidays is the study the press coverage describes (the 28-participant figure was not verified [unverified]). These are two studies, not a conflict. [verified] https://makeabilitylab.cs.washington.edu/media/publications/Consolvo_ActivitySensingInTheWildAFieldTrialOfUbifitGarden_CHI2008.pdf , https://www.sciencedaily.com/releases/2008/11/081119140719.htm
  - Design lesson, important: UbiFit **deliberately did not punish**; the garden did not wither for inactivity [from my memory of the paper, unverified here]. Fish'n'Steps had mood effects. For Tenaz: the *ambient, glanceable* display is the transferable idea (menu bar icon or widget that always shows the mascot's state).
- **Tamagotchi effect / attachment** [unverified; I did not search it]. Assumption: attachment arises from care obligation + visible response. Tenaz's "feed" action = completing due reviews.
- **Finch.** Doing self-care tasks gives energy points, which you spend on pet adventures; the pet gains traits as it grows. [verified, review summary] https://yourstory.com/2022/06/app-review-self-care-pet-finch-gamifies-mental-wellbeing . Finch notably has **no death/punishment**; the pet just waits. (Behavior known from the app; not independently verified this session.) Retention claims on analytics sites are unreliable [unverified].
- **Habitica**: RPG avatar, HP loss for missed dailies. Documented behavior is from memory [unverified]; relevant idea is that HP loss and revival exist as a punishment loop that users sometimes find demotivating.
- **Forest**: tree dies if you leave the app. Documented from memory [unverified]; relevant idea is "loss made visible and cute", and the forest as a cumulative record.
- **Deposit/loss framing evidence is mixed.** Penn (Patel, Volpp) found loss-framed incentives outperformed gain-framed equal incentives in step-count trials; veterans trial (Agarwal et al., JAMA Netw Open 2021): gamification plus loss-framed incentive +1,224 steps/day vs control (adjusted); gamification-only +433 (unadjusted; its significance is not verified [unverified]). Gains were NOT sustained in the 8-week follow-up (incentive arm still about +500, other arm -160, per news coverage). But a 2022 JMIR RCT (de Buisonjé et al., 20-day, 2x2 design; 126 enrolled, effectiveness analysis on far fewer) found deposit contracts *not* significantly better than rewards (14.88 vs 12.13 goal days, P = .17), with lower uptake (62% vs 100%, P < .001). [verified, summaries] https://www.newswise.com/articles/to-encourage-physical-activity-potential-to-lose-a-financial-reward-is-more-effective-than-gaining-one-penn-study-shows , https://pennmedicine.org/news/news-releases/2021/july/combining-gamification-cash-incentive-increases-veterans-exercise , https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11042509/
  - Implication: loss framing is plausible but not guaranteed. Make it **endowed** (start each day with points/health you can lose) and **opt-in per rule**, so the learner can drop rules that do not work for them.

---

## 3. Mechanics toolbox (decisions)

### 3.1 Achievement taxonomy

Five types, each doing a different job:
1. **Progress** (cumulative counts: words, days, minutes). Steady feedback, lowest value per unit.
2. **Mastery** (skill thresholds: exam bands, retention rates). Highest learning value; use these for evolution gates.
3. **Discovery** (try a feature, a genre, a new text type). Pushes breadth.
4. **Streak/consistency** (days, weeks). Habit anchor, always with forgiveness.
5. **Hidden** (surprises). Unpredictability; keep to about 15% of the list.

### 3.2 Reward schedules

- **Fixed ratio** for core XP: every correct retrieval = XP. Predictable, trust-building.
- **Variable ratio** only on cosmetic/flavor rewards: a "mystery drop" with about 25% probability after a completed session (coins, a cosmetic shard, a mascot voice line). Disclose the odds in settings (autonomy; avoids dark-pattern feel).
- **No variable ratio on anything affecting grades, levels, or evolution.**
- **Anti-farming:** XP per item decays after 2 repeats in a day; written-production XP requires a minimum quality score from Claude (or length plus lexical-variety floor when Claude is unavailable).

### 3.3 XP and level curve

Goal: level feels fast early (first level in one session), slows enough that level 30 is ~6 months of real use.

- `xpToNext(L) = round(60 + 40 * L^1.4)` for level L to L+1 (L starts at 1).
  - L1: 100, L5: 441, L10: 1,065, L20: 2,712, L30: 4,738.
  - Cumulative to level 30 (sum for L = 1..29): about 57,900 XP (earlier draft said 65,000, which was wrong). At about 350-450 XP/day (a good day), that is ~4.3-5.5 months. [recomputed in verification pass; calibrate with real data after 2 weeks]
- XP sources (per event): due review recalled `10 * difficulty(1.0-1.6)`; failed review that is then corrected same session `+3` (rewards recovery); sentence written `15-40` by quality; exam section `100-300` by band; daily quest `50-150`.
- **Level never decreases.** Punishment hits *mascot health and coins*, not level. Loss of earned level is the classic quit trigger.
- Prestige: after level 50, "Seasons" reset cosmetic progress for a title, never the CEFR-linked evolution.

### 3.4 Cosmetic economy

- Currency: **Scales** (earned: about 1 per 10 XP, plus quest bonuses). One currency only.
- Sinks: hats, backgrounds, voice packs, accessory slots (about 60 items at launch is too many; ship 12).
- Soft punishment: a missed day costs a small number of Scales ("medicine"), floor at 0, never negative.
- **No real money, no premium currency.** (Single-user local app; also removes dark-pattern risk.)
- Items are *identity* items (a headset for "meeting mode", a hard hat for "grammar repair week"), tying cosmetics to the learner's actual goals.

---

## 4. Mascot system for Tenaz

### 4.1 Three concept options

| Option | Concept | Pros | Cons |
|---|---|---|---|
| A. **Ajolote (axolotl), "Tena"** | Mexican, regenerates lost limbs, stays juvenile (neoteny) unless triggered to metamorphose | Cultural fit for a Mexican-Spanish L1 learner; **regeneration is the perfect narrative for punishment without death**; name "Tenaz" = tenacity; cute at every stage | Few natural "adult" forms, so late stages need invented design (gills become crest, metamorph land form) |
| B. **Drosophila (fruit fly)** | Matches a risograph-fly visual identity (an optional personal theme) | Personal; distinct visual language | Many people find flies unappealing as a daily companion; life-cycle is a 10-day loop, so growth stages are quick |
| C. **Ahuehuete seed to tree** | Plant companion, Forest/Finch-adjacent | Calm, ambient, easy widget; "root = retention" metaphor | Less emotional range, harder for anger/guilt/celebration beats; less "pet" attachment |

**Recommendation: A (axolotl).** Reasons: (1) regeneration gives a built-in, kind punishment mechanic ("injury" heals if the learner does the repair task); (2) maps onto the "never lock the learner out / never death" rule; (3) neoteny gives a clear final evolutionary beat (metamorphosis = C1) that is rare and meaningful; (4) strong Mexican identity at no cost. Keep the fly as a Easter-egg cosmetic (a pet-of-the-pet) to honor option B.

Name: keep "Tena" (short, speakable by TTS, works in English and Spanish).

### 4.2 Growth stages tied to CEFR evidence, not time

Principle: **evolution = evidence gate AND a minimum-time floor** (so it cannot be gamed in one day, and cannot stall because of a bad week: the evidence gate is the only way forward, but time floors prevent skipping). Stage bands are anchored to the CEFR level the learner has *demonstrated* (exam bands plus active-vocabulary mastery), not to XP. CEFR descriptors: Council of Europe CEFR Companion Volume [not fetched this session; unverified details]. TOEFL iBT moved to a 1-6 band scale (0.5 steps) on 21 Jan 2026, aligned to CEFR (5 = C1, 4-4.5 = B2, 3-3.5 = B1, 2-2.5 = A2; overall = average of four sections) [verified in verification pass: https://www.mx.ets.org/content/dam/ets-org/pdfs/toefl/score-scale-update-2026.pdf , https://toeflaccess.ets.org/help/en/articles/11758616-toefl-ibt-score-scale-update-what-you-need-to-know]. Exact CEFR descriptor text still unfetched.

Evidence gates use these measures (all collected locally):
- `M` = number of words with FSRS stability >= 21 days and last 3 recalls correct ("mastered words").
- `E` = latest two exam results' CEFR estimate (both must meet band).
- `W` = writing-quality median of last 10 produced texts (Claude-scored rubric, accuracy/cohesion/range).
- `T` = real days since previous stage (floor).

| # | Stage | CEFR evidence | Gate (all of) | Time floor |
|---|---|---|---|---|
| 0 | **Egg** | none | Onboarding + level paragraph done | 0 |
| 1 | **Hatchling** | A2+/B1- | Placement test done; M >= 100 | 3 days |
| 2 | **Larva** (external gills) | solid B1 | M >= 400; E >= B1 | 3 weeks |
| 3 | **Juvenile** | B1+ (starting baseline) | M >= 900; E >= B1+; W >= B1+ | 6 weeks |
| 4 | **Sub-adult** | B2- | M >= 1,600; E >= B2- on both exams | 8 weeks |
| 5 | **Adult** (full crest) | solid B2 | M >= 2,600; E >= B2; W >= B2; 1 mock-meeting speaking task >= B2 | 10 weeks |
| 6 | **Elder / Golden** | C1- | M >= 3,800; E >= C1-; W >= B2+ | 12 weeks |
| 7 | **Metamorph** (land form, rare) | C1 | M >= 5,000; E >= C1 on two exams; W >= C1 | 12 weeks |

Notes:
- Word counts are placeholders calibrated roughly to the B1-C1 vocabulary ranges used by CEFR-J / Oxford 3000-5000 style lists [unverified]; revisit once the vocab-data doc exists.
- Because the learner already is B1+, the mascot starts as an **Egg that hatches to Juvenile fast** (onboarding sequence: Egg to Hatchling to Larva to Juvenile within the first week, each short, using a "catch-up" animation). This avoids starting a B1+ user as a baby with no way to earn the moment. Narratively: the egg "remembers" its previous life.
- Regression: stages **never** go down. A bad exam only pauses the next gate.
- Evolution ceremony: a deliberate, full-screen but dismissible moment (escape hatch applies). Max 20 s, Esc closes it.

### 4.3 Emotional states driven by behavior

State is the combination of two meters plus context. Meters (0-100):
- **Vitality (health)**: drops with missed due reviews and skipped daily minimum; restored by completing reviews. Never below 15 (it becomes "Sick" at <= 30, but not dead).
- **Spirit (mood)**: raised by correct recalls, writing, quests, variety; decays 6/day if no session.

| State | Trigger | Visual / behavior |
|---|---|---|
| Ecstatic | Perfect session, new best, evolution | Spin, bubbles, voice line |
| Happy | Vitality >= 70, Spirit >= 60 | Idle swim, blinks |
| Focused | During session | Tiny headset, quiet |
| Curious | New word / discovery | Head tilt, ?-bubble |
| Neutral | Default morning | Idle |
| Hungry | Due reviews >= 10 | Taps the glass, stomach rumble |
| Nagging | Due reviews overdue > 24 h | Holds sign with the word; the intrusive overlay persona |
| Sad | Spirit < 30 | Droops, dims colors |
| Sick / Injured | Vitality <= 30 (e.g., 3 missed days) | Bandage on a limb, slower animation; cosmetics hidden (not lost) |
| Regenerating | Repair task in progress | Limb regrowth animation tied to task progress |
| Proud | After heal | Brief celebratory beat |
| Asleep | Night hours / configured quiet hours / in a meeting | Zzz, **never interrupts** (hard rule) |

### 4.4 How punishment manifests (kind but real)

Principles: self-chosen (autonomy); proportional; **reversible within one session**; never touches level, mastered words, or access to the computer.

Ladder (each rung is a toggle, all off by default per DECISIONS.md):
1. **Warning** (due reviews overdue): mascot is Hungry; menu-bar icon pulses.
2. **Soft cost**: Vitality -10 per missed day; Scales -20 (floor 0).
3. **Injury**: after 3 missed days Tena gets an injury (Sick). Cosmetics are hidden, not deleted.
4. **Repair task** (the regeneration): to heal, the learner completes a "penalty task": e.g., 15 reviews with no hints plus a 60-word paragraph about their day. Healing is progressive: each part regrows a limb.
5. **Optional, opt-in**: Tivra blocks chosen fun apps until reviews are done (read-only integration, enforcement stays on Tivra side). Always bypassable via the emergency skip (costs Vitality, not access).
6. **Emergency skip**: always available, costs 1 "Mercy token" (3/month) plus -20 Vitality. Never zero tokens means lockout, because skip works regardless and just costs more.

Rewards ladder: correct recall = Happy beat plus XP; streak milestones = cosmetic; perfect day = mystery drop.

### 4.5 Streaks with forgiveness

- **Daily minimum** (default 5 min or 10 due reviews, configurable).
- **Streak Freeze**: earn 1 per 7 days streak, hold up to 2 (matches the Duolingo variant with two freezes; +0.38% DAU there, small but positive [verified]).
- **Weekly goal streak** in addition to daily: 5 of 7 days counts. Gives a forgiving long-term number, helpful for ADHD where all-or-nothing is a known quit trigger [my design reasoning, not sourced].
- Broken streak = "best streak" is preserved forever; the mascot says "we go again" (no shaming text).

---

## 5. Achievements (48)

Format: **Name** - unlock condition. Type: P progress, M mastery, D discovery, S streak, H hidden. Rewards: Scales (S) and XP.

### 5.1 First steps (D/P)
1. **Hello, Tena** (D) - hatch the Egg (finish onboarding).
2. **Say It Out Loud** (D) - first spoken answer graded.
3. **First Blood** (P) - first 10 correct recalls.
4. **Dear Diary** (D) - first life paragraph written to unlock the Mac.
5. **Tool Time** (D) - open all 4 modes (review, write, listen, speak) once.
6. **Exam Day** (D) - complete a first mini-exam.

### 5.2 Vocabulary (P/M)
7. **Hundred Club** (P) - 100 words introduced.
8. **Sticky Notes** (M) - 100 mastered words (FSRS stability >= 21 d).
9. **Five Hundred** (M) - 500 mastered.
10. **Thousand Threads** (M) - 1,000 mastered.
11. **Two Thousand Wings** (M) - 2,000 mastered.
12. **Lexicon** (M) - 5,000 mastered.
13. **Comeback Kid** (M) - recall a word you previously failed 3 times, 30 days later.
14. **Leech Hunter** (M) - clear 10 leech words (failed >= 8 times).
15. **Long Memory** (M) - recall 25 words after > 60 days.
16. **Sniper** (M) - 50 recalls in a row correct.

### 5.3 Writing and speaking (M)
17. **Paragrapher** (P) - 10 paragraphs written.
18. **Storyteller** (M) - a 150-word text scored >= B2 on cohesion.
19. **No Slips** (M) - a 100-word text with zero Claude-flagged grammar errors.
20. **Connector King** (M) - use 5 distinct discourse connectors correctly in one text (however, therefore, whereas...).
21. **Voice Of The Standup** (M) - a 60-second spoken update graded >= B2.
22. **Meeting Ready** (M) - pass a simulated work-meeting speaking task at B2.
23. **Say It Differently** (M) - rewrite your own sentence 3 ways, all accepted (paraphrase).
24. **Register Switch** (D/M) - same message in formal and informal register, both accepted.

### 5.4 Exams (M)
25. **B1 Certified** (M) - two consecutive exams at B1 or above.
26. **B1+ Solid** (M) - two consecutive at B1+.
27. **B2 Gate** (M) - first exam estimate at B2.
28. **B2 Held** (M) - two consecutive at B2.
29. **C1 Horizon** (M) - first exam section at C1.
30. **Clean Room** (M) - finish an exam with Tivra Exam Mode with zero focus violations (anti-AI integrity).
31. **Honest Mark** (M) - finish 5 exams with zero violations.
32. **Stage Fright Slayer** (M) - speaking section above your rolling average three times.

### 5.5 Consistency (S)
33. **Three In A Row** (S) - 3-day streak.
34. **Week One** (S) - 7-day streak.
35. **Fortnight** (S) - 14-day streak.
36. **Month Of Mornings** (S) - 30-day streak.
37. **Hundred** (S) - 100-day streak.
38. **Freeze Frame** (S) - use a Streak Freeze without breaking the streak.
39. **Weekend Warrior** (S) - complete minimum on 4 weekends in a row.
40. **Five Of Seven** (S) - meet the weekly goal 8 weeks in a row.

### 5.6 Growth and the mascot (D/P)
41. **Little Gills** (P) - reach stage Larva.
42. **Coming Of Age** (P) - reach stage Juvenile.
43. **Full Crest** (P) - reach Adult.
44. **Metamorphosis** (M) - reach stage 7.
45. **Regrowth** (P) - heal from an injury through a repair task.
46. **Dressed To Impress** (D) - equip 3 cosmetics at once.
47. **Collector** (P) - own 12 cosmetics.

### 5.7 Hidden (H)
48. **Night Owl** - complete a review between 00:00-04:00 (hidden hint: "Tena is awake too").
49. **Early Axolotl** - session before 07:00 five days in a row.
50. **Phoenix** - recover from a 5+ day absence and finish a week at 5/7.
51. **Rubber Duck** - explain a coding concept in English in a writing task (ties to a developer's work).
52. **Zero Mercy** - complete 30 days without using Mercy tokens.
53. **The Fly** - unlock the Drosophila cosmetic by writing about "my fly" in a paragraph (Easter egg).

Rules: achievements grant Scales and a small XP bonus (about 20-200), never gating anything essential. Hidden ones show as "???" until unlocked. Every unlock is a quiet banner (max 4 s, no focus steal) except evolution.

---

## 6. Daily quests

Three per day, generated each morning from live data; one is always the "core" and cannot be faked (needs FSRS data).

| Slot | Template | Reward |
|---|---|---|
| Core (always) | "Clear your due reviews" (target = min(due, 30)) | 80 XP + 10 Scales |
| Skill (rotates by weakness) | If accuracy is weakest: "Write 60 words about yesterday using past perfect once". If range: "Use 3 words you learned this week". If listening: "Shadow a 1-minute clip, 80% match" | 60-100 XP |
| Stretch (optional, risky) | "Do 10 reviews in under 5 minutes", or "Explain your current work task in English for 45 s" | 120 XP + mystery drop |

Weekly quest: "Meeting prep": a 3-minute spoken summary of the week's work. Chest at 5 of 7 days.

Quest difficulty adapts: if success rate over the last 7 days > 85%, raise targets 10%; < 50%, lower 15% (keeps "flow" band; Birdbrain-style personalization is the model [secondary]).

---

## 7. ADHD-specific cautions for the system

[Design reasoning; I did not research ADHD-specific gamification trials this session, so mark everything below as hypotheses to test in dogfooding.]

- **Immediacy**: feedback within 1 second of an answer; delayed reward does not hold attention.
- **Novelty fatigue**: ADHD users often adopt then abandon. Rotate cosmetics, quest templates and mascot voice lines weekly. Keep a "boredom" signal (declining session length over 5 days) that triggers a new variety bundle.
- **Shame spirals**: all-or-nothing streaks are risky. Hence freezes, weekly streaks, the "we go again" message, and level never decreasing.
- **Time blindness**: show *time remaining* and *items remaining* on every task. Hard cap on on-screen time (already a DECISIONS.md rule).
- **Hyperfocus/meeting protection**: respect calendar and meeting detection; Asleep state during meetings, no overlays.

---

## 8. Measurement (don't trust the literature, measure the learner)

Because Duolingo's guilt notifications and the loss-framing evidence are not conclusive for this specific case, ship with a local-only experiment log:

- Log per rule: fired, dismissed, escaped, led to session within 30 min.
- Weekly review screen: "Which of your punishments worked?" Auto-suggest turning off any rule whose escape rate > 60% for 2 weeks (autonomy).
- Primary outcome: mastered-word growth `M` and exam band, **not** streak length or app opens.

---

## 9. Top decisions

1. **Mascot = axolotl "Tena"**; regeneration is the punishment metaphor; fly as Easter egg.
2. **8 stages (Egg to Metamorph) gated by CEFR evidence (mastered words, two-exam bands, writing score) plus time floors**; stages never regress; the learner fast-tracks through the first four.
3. **Punishment hits Vitality, Scales and cosmetics visibility, never level, never access.** Each rung opt-in; healing needs a repair task (15 no-hint reviews + 60-word paragraph); emergency skip always exists.
4. **XP only for retrieval/production**, anti-farming decay, level formula `xpToNext = 60 + 40*L^1.4`, level never decreases.
5. **Streaks with forgiveness**: daily minimum, up to 2 freezes, weekly 5-of-7 streak.
6. **Variable rewards only on cosmetics** with disclosed odds; no variable reward for anything affecting progress.
7. **53 achievements**, weighted to mastery and exam integrity (Clean Room via Tivra read-only signals).
8. **Instrument everything locally** and let the learner prune rules that fail; do not rely on published effect sizes.

## 10. Open questions for the learner

- Is the axolotl OK (vs fly or tree)? Tena as a name?
- Daily minimum default: 5 minutes or 10 reviews?
- Should the penalty task require Claude to grade the paragraph (needs CLI available), or fall back to length and variety checks?
- Which Tivra block list does the opt-in rung 5 use, and who defines "unfinished"?


## Verification

Pass date 2026-10-22. Ten load-bearing claims checked.

| # | Claim | Verdict | Source |
|---|---|---|---|
| 1 | Sailer & Homner 2020: g = .49 cognitive, .36 motivational, .25 behavioral; EPR 32:77-112 | Confirmed (CIs and k added; behavioral CI [0.04, 0.46]) | https://link.springer.com/article/10.1007/s10648-019-09498-w |
| 2 | Bai, Hew & Huang 2020: 30 interventions / 24 studies, g = 0.504 | Confirmed; journal name remains unverified; ICCE 2019 version has different g = 0.36 | https://www.gbl.uzh.ch/quartz/references/Bai-et-al.-(2020) |
| 3 | Duolingo two freezes +0.38% DAU; 7-day streak 3.6x course completion | Confirmed (correlational) | https://blog.duolingo.com/how-duolingo-streak-builds-habit |
| 4 | Fish'n'Steps 14 weeks, 19 participants | Confirmed; link corrected | DOI 10.1007/11853565_16 |
| 5 | UbiFit Garden 12 participants / 3 weeks, "sources conflict" | Corrected: two separate studies (3-week n=12; later 3-month holiday experiment); 28 unverified | https://makeabilitylab.cs.washington.edu/media/publications/Consolvo_ActivitySensingInTheWildAFieldTrialOfUbifitGarden_CHI2008.pdf |
| 6 | JMIR RCT n=126, uptake 62% vs 100%, deposit not better | Confirmed; added that effectiveness n was smaller, P = .17 | https://pmc.ncbi.nlm.nih.gov/articles/PMC11042509/ |
| 7 | Veterans trial +1,224 vs +433, "significant" | Partly corrected: 1,224 is adjusted vs control; 433 unadjusted, significance unverified; effects faded at follow-up. Primary paper not read (Penn page fetch failed with a certificate error) | https://pennmedicine.org/news/news-releases/2021/july/combining-gamification-cash-incentive-increases-veterans-exercise (via search summaries) |
| 8 | Mekler: 295 participants, performance up, motivation unchanged | Partly confirmed: findings confirmed; N = 295 unverifiable (marked) | https://edoc.unibas.ch/32047/ |
| 9 | HLR paper and duolingo/halflife-regression repo | Confirmed | https://aclanthology.org/P16-1174/ |
| 10 | XP curve: cumulative to level 30 about 65,000 | Corrected to about 57,900 (computed); timeline now ~4.3-5.5 months | local calculation of 60 + 40*L^1.4 |
| + | TOEFL 1-6 scale mapped to CEFR (was unverified) | Confirmed | https://www.mx.ets.org/content/dam/ets-org/pdfs/toefl/score-scale-update-2026.pdf |

Not checked (still unverified): Deci et al. 1999, Octalysis validation claims, Habitica/Forest behavior, Finch no-punishment behavior, CEFR vocabulary-size gates, all ADHD design claims.

## Gaps found in verification

- Incentive effects fade: the veterans trial showed gains mostly vanished after the intervention ended, and the loss-framed arm was cash-based. Tenaz's loss mechanics (mascot health, Scales) are virtual; do not assume the +1,224-step effect transfers. Section 8's local measurement is the real evidence.
- The 3.6x streak figure and +0.38% freeze figure come from Duolingo's own blog (correlational and company-reported); the design should not cite them as causal.
- Stage gates reference "E >= B2" from exam estimates, but TOEFL now reports 1-6 bands in 0.5 steps (4 and 4.5 are both B2); the exam doc should define E using these bands, and the "two consecutive exams" rule should specify whether 4 vs 4.5 differ.
- Weekly 5-of-7 streak and Mercy tokens are untested designs; there is no ADHD-specific gamification evidence in this report, so all of section 7 stays a hypothesis.
- Fish'n'Steps follow-up work reports an unhappy avatar can lead users to quit the app (secondary account [unverified]), which argues for keeping the Sick/Injured state gentle and always paired with a clear repair path.
