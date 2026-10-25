# 01 - ADHD psychology and "intrusive but not abandoned" behavior change

Date: 2026-10-22. Scope: what ADHD research implies for Tenaz (native macOS, intrusive English learning, self-chosen penalties, Tivra anti-cheat).
Method note: findings come from web searches and search-result abstracts, not full-text reads of every paper. Anything I could not confirm against a primary source is marked [unverified]. Effect sizes are quoted as the sources report them. Constraints from `DECISIONS.md` apply throughout: overlays off by default with escape hatches, never lock the learner out or block a work meeting, Tivra read-only, Claude only via the `claude` CLI, data local.

---

## 1. Executive summary (read this if nothing else)

1. The strongest, best-replicated ADHD findings for design are: (a) steep preference for immediate over delayed rewards (delay aversion / discounting), (b) blunted reward anticipation, (c) working-memory and timing deficits, (d) elevated emotion dysregulation. Popular constructs ("interest-based nervous system", "rejection sensitive dysphoria", "body doubling", "hyperfocus") are useful design heuristics but have thin or contested peer-reviewed support. Design with them, but do not make the product depend on any single one.
2. Tenaz's core bet, "intrusive but not abandoned", is supported by commitment-device research only when the commitment is chosen by the user, small enough to be survivable, and repairable after a lapse. The most dangerous failure mode is not weak punishment. It is a broken streak or a punishment spiral that makes the learner uninstall the app. Broken streaks demonstrably reduce later engagement even when the break was outside the person's control (Silverman and Barasch 2023).
3. Rewards must be immediate (seconds), not end-of-week. Penalties must be proportionate, predictable and fast to clear. Variable rewards should be limited to cosmetic surprise, never to progress or access.
4. The proven learning layer is retrieval practice with spacing in very short sessions, delivered in existing idle moments (wait-learning). Intrusiveness should hijack micro-gaps, not meetings or deep work.
5. The target-user profile (young adult, ADHD, a tendency to cheat with AI, B1+) makes the main design risk "gaming the app" and "abandoning after the novelty cliff" rather than "too little pressure". Anti-cheat belongs in exams only; daily practice should be low-stakes so cheating has no payoff.

---

## 2. ADHD psychology: what the evidence supports

Each item has an evidence grade: A = meta-analytic or replicated, B = reasonable empirical support, C = clinical/popular framework with little direct evidence.

### 2.1 Executive function and working memory (A)
- Working memory deficits are a consistent ADHD finding. For children, a meta-analysis (Martinussen et al. 2005) reported verbal storage d = 0.47 and verbal central executive d = 0.43, with larger spatial effects (0.85 and 1.06); Kasper et al. 2012 reported d ~ 0.69-0.74 overall ([search record](https://pubmed.ncbi.nlm.nih.gov/15782085/), secondary summary of Kasper 2012 [unverified in primary]).
- For adults, Alderson, Kasper, Hudec and Patros (Neuropsychology, 2013) is the first adult meta-analysis; a related adult study (n = 37) found deficits in both central executive and storage/rehearsal, with a smaller central-executive effect than in children ([record](https://vufind.lboro.ac.uk/PrimoRecord/cdi_proquest_miscellaneous_1353987286)). The meta-analysis (Neuropsychology 27(3):287-302) pooled 38 studies and reports moderate between-group effects for both phonological and visuospatial WM; a secondary source gives 0.55 verbal and 0.49 visuospatial [unverified in primary] ([record](https://vufind.lboro.ac.uk/PrimoRecord/cdi_proquest_miscellaneous_1353987286)).
- Design consequence: never require holding multiple items or instructions in mind. One question per screen, cues visible while answering, no multi-step menus, drafts auto-saved.

### 2.2 Delay aversion and steep delay discounting (A)
- Sonuga-Barke's dual pathway model separates an executive (inhibition) pathway from a motivational (delay aversion) pathway; both contribute ([Southampton eprints](https://eprints.soton.ac.uk/18285/), [PMC overview](https://pmc.ncbi.nlm.nih.gov/articles/PMC4649931)). Subtype/pathway dissociation is debated.
- A meta-analysis of monetary delay discounting found a medium group difference (d = 0.43, 21 studies), with no significant moderation by sample age (Jackson and MacKillop 2016, Biol Psychiatry CNNI 1(4):316-325, 21 independent investigations / 25 comparisons, N = 3,913, [doi:10.1016/j.bpsc.2016.01.007](https://doi.org/10.1016/j.bpsc.2016.01.007); verified. The PMC5421775 link previously cited here is a different paper and should not be used for this number). A Marx, Hacker, Yu, Cortese and Sonuga-Barke meta-analysis also covers choice-delay vs discounting paradigms ([record](https://eprints.soton.ac.uk/420008)).
- Tripp and Wickens' dopamine transfer deficit hypothesis: reinforcement signals fail to shift to predictive cues, so delayed contingencies bind poorly; "sensitivity to delay of reinforcement appears to be a reliable finding" ([Tripp and Wickens](https://einsteinmed.edu/uploadedFiles/departments/neurology/Divisions/Child_Neurology/Child_Neurology_References/Executive_Fnc/Tripp.ADHD.pdf)). The mechanism is a hypothesis; the behavioral delay sensitivity is the solid part.
- Design consequence: the feedback loop must close within seconds of the answer (sound, haptic-like animation, mascot reaction, XP tick). Long-horizon rewards (C1 in 12 months) need to be broken into daily-visible proxies. Penalties that arrive hours later will not teach.

### 2.3 Reward/dopamine sensitivity (A for neuroimaging, B for behavior)
- Meta-analysis of fMRI: lower ventral striatal activation during reward anticipation in ADHD, medium effect (ES ~0.48) ([Plichta and Scheres, PMC3989497](https://pmc.ncbi.nlm.nih.gov/articles/PMC3989497)). Trait-impulsivity in healthy people shows the opposite direction, so the literature is not simple.
- Design consequence: anticipation is weak, so the app must manufacture visible anticipation (progress bars that nearly fill, the mascot reacting before the answer is revealed, countdown to a reward) and must make the reward itself vivid at delivery.

### 2.4 Time blindness / timing deficits (A for timing deficits, C for the label)
- Meta-analyses find consistent timing deficits in ADHD: children and adolescents perceive time less accurately and precisely (27 studies), and a broader review of 55 studies found a medium discrimination deficit ([ADHD Evidence summary](https://adhdevidence.org/blog/time-blindness-found-to-be-a-consistent-feature-of-adhd), [NYU meta-analysis listing](https://ifp.nyu.edu/2020/meta-analyses-systematic-reviews/1087054720978557/)). "Time blindness" as a Barkley coinage is not a clinical term; I could not confirm the primary attribution [unverified].
- Design consequence: show elapsed and remaining time as a shrinking visual (not a clock number), always show "this takes 20 seconds", and never ask the learner to estimate durations. Tie sessions to external anchors (unlock, wake, app switch, calendar gaps) rather than "remember to study at 6 pm".

### 2.5 Novelty seeking and the "novelty cliff" (B, partly inferential)
- Direct evidence on why ADHD adults abandon apps after 2-3 weeks is weak. I found no peer-reviewed dropout study for gamified adult-ADHD apps; vendor blogs assert high dropout without sources ([search results](https://imaginovation.net/blog/gamification-adhd-apps-user-retention/), unreliable). Treat "2-3 weeks" as a hypothesis to measure in Tenaz, not a fact.
- General gamification literature says effects depend on context, user and "possible novelty effects" ([Hamari, Koivisto and Sarsa 2014](https://www.lescahiersdelinnovation.com/wp-content/uploads/2019/06/2014-hamari_et_al-does_gamification_work.pdf), summary via [Drimify](https://drimify.com/en/resources/gamification-hamari-koivisto-sarsa-review) for the novelty caveat).
- Habit timeline: Lally et al. (2010, n = 96, 84 days) found a median 66 days to reach 95% of each person's own automaticity asymptote, range 18-254 days, from only the 39 participants with good curve fits, and many projections extrapolated beyond the 84 days observed ([BPS Digest](https://bps.org.uk/research-digest/how-form-habit), [Behavioral Scientist](https://www.thebehavioralscientist.com/articles/how-long-to-form-a-habit)). Lally herself says it is highly variable. For an ADHD user, assume longer than the median, so the app must carry the learner through roughly 2-4 months on scaffolding, not habit.
- Design consequence: plan content/mechanic rotation at fixed milestones (e.g., week 2, week 4, week 8, week 12) to pre-empt the cliff: new mascot stage, new exam format, new challenge type, new theme. Keep the core loop (a 20-second retrieval) constant so the habit cue does not change.

### 2.6 Interest-based nervous system (C)
- Dodson's framing (engagement driven by Interest, Novelty, Challenge, Urgency; variants PINCH/INCUP) comes from clinical practice and magazine articles; I found no peer-reviewed test ([overview of sources](https://lifeskillsadvocate.com/blog/interest-based-nervous-system/)). One practitioner warns urgency can push people to manufacture crises.
- Design consequence: use it as a checklist for every mechanic (is it personal, fresh, appropriately hard, or time-bound?), but derive Tenaz's content from the learner's own life (their own paragraphs, their work) because personal relevance is the least risky of the four.

### 2.7 Hyperfocus (B-/C)
- Hyperfocus is plausible but loosely defined: a 2025 integrative review of 10 empirical studies found higher prevalence in ADHD adults and links to perseveration, internet addiction and emotional dysregulation, while concluding knowledge is limited ([PMC12438511](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12438511/)). Ashinoff and Abu-Akel note no consensus definition; one secondary report of a null group difference (Groen et al. 2020) is [unverified] ([Hupfeld PDF](https://www.adhspedia.de/Downloads/studien/Hupfeld_et_al-2018-ADHD_Attention_Deficit_and_Hyperactivity_Disorders.pdf)).
- Design consequence: Tenaz must not fight hyperfocus (the worst intrusion is breaking a deep-work state, which is also when the learner's work matters). Detect and respect it: defer interruptions while Tivra reports a focus session, a meeting, or sustained single-app deep work, and queue the micro-session for the next natural break. Do not use hyperfocus as an engagement target either; endless "just one more" sessions risk the internet-addiction link.

### 2.8 Emotion dysregulation and rejection/criticism sensitivity (A for dysregulation, C for "RSD")
- Emotion dysregulation is common in adult ADHD: a systematic review reports medium-to-large effects and associations with symptom severity and impairment ([PLOS One 2023 via search](https://doi.org/10.1371/journal.pone.0280131)); one secondary source cites g = 1.17 from a 2020 meta-analysis [unverified]; prevalence "up to 70%" appears in [PMC12822938](https://pmc.ncbi.nlm.nih.gov/articles/PMC12822938).
- "Rejection sensitive dysphoria" is not in DSM-5 or ICD-11 and consumer claims (e.g., 98% prevalence) are not peer-reviewed ([overview](https://hsmh.co.uk/?p=13484), low reliability). Treat it as emotional-reactivity-to-criticism, which is well enough supported to justify design caution.
- Design consequence: error feedback must be factual and forward-looking ("Next time: 'depend on', not 'depend of'"), never shaming; the mascot should show disappointment as mild and brief; never use second-person judgment ("You failed again"). A bad day must not produce a worse-looking screen than a good day for longer than a few seconds.

### 2.9 Punishment and reward responsiveness in ADHD (mixed, B-)
- Evidence is contested. Some response-cost studies show performance gains after response cost only for children with ADHD (not controls, possibly because of ceiling effects); positive-punishment studies show increased, not decreased, sensitivity; and the classical theory (Wender, Quay) assumed diminished punishment sensitivity ([Luman et al. and related, via search summary](https://pure.uva.nl/ws/files/1810629/124436_Reward_and_punishment_sensitivity_in_children_with_ADHD.pdf), [Springer 2024](https://link.springer.com/article/10.1007/s10802-024-01238-1)). Most work is in children and task-specific. I found no dedicated meta-analysis of response cost in adults with ADHD.
- Design consequence: response cost (losing something already earned, immediately) is the best-supported penalty form, but evidence is weak enough that Tenaz should log outcomes per penalty type and adapt, and keep penalties small.

### 2.10 Body doubling (C)
- Widely used, but no peer-reviewed controlled trials in ADHD adults; one small VR preprint (12 participants) found faster task completion with a human or AI body double; a descriptive survey of 220 neurodivergent people exists (Eagle and Ringland, ACM TACCESS 2024); a company-linked survey of 117 FLOWN users is not peer-reviewed ([arXiv 2509.12153](https://arxiv.org/pdf/2509.12153), [summary of 117-user survey](https://neurodiversity.org/?p=11449)). A 2026 arXiv preprint on developers with ADHD and copresence exists, but I could not read its findings [unverified] ([arXiv 2609.21254](https://arxiv.org/pdf/2609.21254)).
- Design consequence: the mascot as a light "co-present" companion (sits in a corner of the screen during a session, mirrors pace) is cheap and plausible. Do not market it as evidence-based.

---

## 3. Behavior-change science for "intrusive but not abandoned"

### 3.1 Commitment devices
- Ariely and Wertenbroch (2002, Psychological Science 13(3)) **was retracted on 2 September 2026**. The retraction notice cites a failed replication (Hyndman and Bisin, Psychological Science, online 15 July 2026, [SAGE](https://journals.sagepub.com/doi/full/10.1177/09567976261460772): deadline changes had negligible effect) and two Data Colada posts questioning the data's veracity; Wertenbroch requested the retraction on 23 July ([Retraction Watch](https://retractionwatch.com/2026/09/03/procrastination-study-duke-dan-ariely-psychological-science-data-colada-tampering-retraction/), [Data Colada 138](https://datacolada.org/138)). Do not cite it as support: neither "self-imposed deadlines help" nor "external beats self" is evidenced by it. [Corrected in verification: the earlier text called the direction 'plausible' and did not know of the retraction.]
- Giné, Karlan and Zinman (2010, AEJ: Applied Economics 2(4):213-35, [doi:10.1257/app.2.4.213](https://doi.org/10.1257/app.2.4.213)): CARES savings-forfeiture contract for smoking cessation, about 2,000 smokers in the Philippines; 11% took it up; offered smokers were ~3 percentage points more likely to pass the 6-month test, with effect persisting at 12 months; a large share of takers still failed; the authors note frequent contact with deposit collectors may contribute; Karlan is president of stickK ([paper PDF](https://es.poverty-action.org/sites/default/files/publications/put_your_money_where_your_butt_is.pdf)).
- Larger lesson: uptake is low (11%) and benefits are modest. Selection matters: Beeminder itself warns that competitors' high success rates ignore selection of already-motivated users ([Beeminder blog](https://blog.beeminder.com/smoking)). In stickK data, short-term goals were achieved more than long-term ones ([KAIST analysis](https://ic.kaist.ac.kr/files/papers/lee2021sticky.pdf)).
- Tenaz relevance: The learner is a self-selected volunteer (a favorable case), but ADHD plus a plausible tendency to cheat with AI means a learner may also circumvent the device. Therefore devices must be cheap to honor and expensive to evade, but with an official, honest escape.

### 3.2 Loss aversion, streaks and framing
- Silverman and Barasch (2023, Journal of Consumer Research 49(6)): across 7 studies, an intact logged streak raised later engagement; a broken streak lowered it, even when the break was caused by external events and regardless of streak length; the effect is stronger when the person blames themselves and weaker when they can "repair" the streak ([UDel manuscript](https://udspace.udel.edu/bitstreams/7e3e3b64-8bf2-4527-ac93-94a160358165/download), [Colorado press](https://www.colorado.edu/business/faculty-research/2023/04/19/or-track-how-broken-streaks-affect-consumer-decisions), [Psychology Today](https://www.psychologytoday.com/us/blog/ulterior-motives/202306/how-broken-streaks-sap-motivation)). I read abstracts and press, not the JCR version.
- Separate field work (Gershon, "one sec" app) finds streak feedback can introduce a competing goal (keep the streak) that displaces the original one ([Decision Lab summary](https://thedecisionlab.com/es-ES/insights/consumer-insights/streak-creep-the-perils-of-too-much-gamification)).
- Duolingo's streak and freeze effects are mostly vendor/blog claims with unverified numbers; do not copy percentages ([StriveCloud blog, low reliability](https://www.strivecloud.io/blog/blog-gamification-examples-boost-user-retention-duolingo)).
- Design consequence: use streaks only if there is a repair mechanism (earn-back by extra practice, "recovery day", freezes granted automatically after a hard stretch) and show a weekly "consistency" measure (e.g., 5 of last 7 days) as the headline rather than an all-or-nothing counter.

### 3.3 Overjustification and extrinsic rewards
- Deci, Koestner and Ryan (1999, Psychological Bulletin 125) concluded tangible expected rewards have a substantial undermining effect on intrinsic motivation; this was disputed by Cameron and colleagues ([SAGE](https://journals.sagepub.com/doi/10.3102/00346543071001001), [rebuttal listing](https://scholarhub.vn/publication/:slug/9460423c-1ed9-4760-995d-5dd57e6628aa)). Verified against the paper (128 studies): all tangible rewards d = -0.34 (92 studies); free-choice behavior overall d = -0.40, with engagement-, completion- and performance-contingent rewards -0.40, -0.36, -0.28; positive feedback (verbal rewards) enhanced free-choice behavior d = +0.33 and self-reported interest d = +0.31 ([paper PDF](https://depts.washington.edu/techdocs/papers/deciExtrinsicRewardsAndIntrinsicMotivation99.pdf)). So the old '-0.40 tangible' was a mislabel of the engagement-contingent / free-choice figure, and tangible is -0.34. The rebuttal link above is Cameron, Banko and Pierce 2001 (Review of Educational Research 71(1)), 'The myth continues'.
- Design consequence: reward through competence-feedback (mastery, mascot growth tied to real learned words, level proofs) more than through arbitrary tokens. Do not pay points for mere app-opening. Reward verified retrieval.

### 3.4 Implementation intentions
- Gollwitzer and Sheeran (2006): 94 tests, d = 0.65 on goal attainment; a 2024 synthesis (Sheeran, Listrom and Gollwitzer, European Review of Social Psychology 36(1), [doi:10.1080/10463283.2024.2334563](https://doi.org/10.1080/10463283.2024.2334563)) covers 642 tests (overall effect not retrieved); the 2006 review is Advances in Experimental Social Psychology 38:69-119, d = .65 verified against its abstract ([summary](https://yukaichou.com/behavioral-analysis/implementation-intentions-if-then-planning-gollwitzer/), [642-test note](https://goalsandprogress.com/implementation-intentions-research/)). ADHD-specific: if-then plans helped children with ADHD reach inhibition performance equal to controls on Go/No-Go (Gawrilow and Gollwitzer 2008), and helped with shifting and working-memory tasks (Gawrilow et al. 2011) ([Konstanz](https://www.socmot.uni-konstanz.de/publications/implementation-intentions-facilitate-response-inhibition-adhd-children)). These are small child experiments, not adult app trials.
- Design consequence: onboarding and weekly review should produce explicit if-then plans ("If I unlock my Mac after lunch, then I do my 3 words"), stored in Tenaz and used as cue triggers. Use mental contrasting plus if-then (Gawrilow et al. in Motivation and Emotion, year uncertain 2012/2013).

### 3.5 Variable reward risk
- Variable-ratio schedules underlie loot boxes and are associated with problem behavior, though evidence is correlational and impulsivity may confound ([Parliament report](https://aph.gov.au/Parliamentary_Business/Committees/Senate/Environment_and_Communications/Gamingmicro-transactions/Report/c03), [arXiv 2307.04549](https://arxiv.org/pdf/2307.04549)). I found no evidence on streak or notification rewards in non-gaming apps.
- Since ADHD is linked to impulsivity and delay-aversion, Tenaz should keep surprise to cosmetics, never to progress, and never create a slot-machine loop.

### 3.6 Making penalties self-chosen and proportionate (synthesis, mostly design inference)
Evidence: commitment contracts help modestly and uptake is low when stakes are real (Giné et al.); broken streaks are demotivating (Silverman and Barasch); ADHD emotion dysregulation is high. Together this argues for:
- Pre-commit when calm (onboarding, weekly planning), not in the moment.
- Penalty menu chosen by the learner from small options, each with a "cost ceiling" per day.
- Penalties are lost-earned-things or short tasks, not lockouts. Ceiling: no penalty may exceed ~5 minutes of effort per day or remove access to work apps.
- Immediate, explained, and clearable in one action. After 3 penalties in a day, auto-switch to "recovery mode" (easier items, no further penalty) so one bad day does not snowball.
- A visible, honest escape hatch that costs a small, pre-agreed price, so evasion by force-quit is unnecessary (matches DECISIONS rule 2).

---

## 4. Microlearning and interruption-based learning

- Wait-learning (Cai, Guo, Glass and Miller, CHI 2015): WaitChatter surfaced vocabulary micro-quizzes during waits in instant messaging; a two-week field study with 20 participants had them learn 57 words on average; learners were most receptive right after sending a message; words with errors repeat more ([CHI paper](https://sls.csail.mit.edu/publications/2015/Cai_CHI-2015.pdf), [MIT news](https://www.csail.mit.edu/node/1321), [project page](https://people.csail.mit.edu/ccai/waitchatter)). Verified in the paper: 20 participants (21 recruited, 1 dropped), two weeks, 57 words recalled on average (the paper itself equates this to about four words per day, which is the MIT News figure, not a lower pilot number), about 170 chats per day. Sample is small, university-recruited and non-ADHD.
- Lock-screen and everyday-interaction vocabulary delivery has been studied ([arXiv 2109.07944](https://arxiv.org/pdf/2109.07944), snippet only [details unverified]).
- Spacing beats massing for vocabulary retention in EFL/ESL in a systematic review of 25 studies (2010-2025), though optimal schedules are uncertain and most work uses paired-associate flashcards, with weaker evidence for pronunciation and collocations ([systematic review](https://riset.unisma.ac.id/index.php/JREALL/article/view/25562)). A claim that 3 minutes/day tripled retention (CALICO 2016) is from a search snippet [unverified].
- Design consequence: Tenaz's intrusion unit is a 10-30 second retrieval prompt at a natural boundary (unlock, wake, app switch, end of a Tivra focus block, after sending a message), feeding an FSRS scheduler already planned. Receptivity immediately after an action completes is the best-supported timing.

---

## 5. Design rules for Tenaz (each traced to evidence)

R1. Close every loop within 2 seconds. Correct answers get instant sound/animation/XP; wrong answers get instant, brief correction. (Delay aversion, DTD: 2.2.)
R2. Make the daily task tiny and fixed: 3 items or 60 seconds is "done". Extras are optional bonuses. (Working memory and executive limits 2.1; short-term goals achieved more on stickK, 3.1.)
R3. One decision per screen, cues visible, no recall of instructions. (2.1.)
R4. Trigger by context, not by memory: unlock, wake, app-switch, end-of-focus-block, after message-send. Store an if-then plan for each. (Implementation intentions 3.4; wait-learning 4.)
R5. Never interrupt a meeting, a Tivra focus block, or detected deep work; queue for the next boundary. (Hyperfocus 2.7; DECISIONS rule 2.)
R6. Show time as shrinking bars and name every task's duration up front. (Timing deficits 2.4.)
R7. Manufacture anticipation: partial-progress bars, mascot "wind-up" before reveal, near-complete meters. (Blunted reward anticipation 2.3.)
R8. Use response cost (loss of just-earned points/mascot energy) rather than punitive tasks as the default penalty, with a daily cap, and log what actually changes behavior per penalty type. (2.9 mixed evidence.)
R9. All penalties are chosen by the learner in a calm planning session, and displayed before they apply; changing a penalty takes effect after a 24-hour delay (prevents in-the-moment bargaining). (Commitment devices 3.1; pre-commitment logic.)
R10. Cap penalty load: max ~5 minutes per day; after 3 penalties, enter recovery mode with no further penalties that day. (Streak-break abandonment, emotion dysregulation: 2.8, 3.2.)
R11. Every streak has repair: earn-back by extra practice, auto-freeze after a hard week, and the headline metric is "days practiced in the last 7/30", not a fragile consecutive count. (Silverman and Barasch 3.2.)
R12. Errors are framed as information, never as character judgment; mascot disappointment is mild and under 3 seconds. (Emotion dysregulation, rejection sensitivity 2.8.)
R13. Reward verified retrieval, not presence: no points for opening the app. (Overjustification 3.3.)
R14. Surprise only in cosmetics (mascot accessories, flavor lines), never in progress, access, or penalties; no loot-box-style purchasing or chance meters. (Variable-ratio risk 3.5.)
R15. Pre-schedule novelty: at weeks 2, 4, 8, 12 introduce a new mascot stage, theme, task type or exam section, while the core 20-second loop stays unchanged. (Novelty effects 2.5; Lally variability.)
R16. Plan for a 2-4 month scaffolding horizon, not a 3-week one, and report "habit strength" via a self-rated automaticity question every 2 weeks (as in Lally's measure). (Lally 2010.)
R17. Content comes from the learner's life and work vocabulary (meetings, standups, supply-chain workplace contexts, their own paragraphs), because personal relevance is the least risky "interest" lever. (INS framing, evidence C, 2.6.)
R18. Challenge calibration: keep expected accuracy around 80-90% on daily items so tasks are neither boring nor discouraging. The 85% figure is a common rule of thumb; I did not verify a source for it [unverified]. (Interest/challenge 2.6, emotion 2.8.)
R19. The mascot is also a light body double: a visible companion during sessions and a "co-working" timer during study blocks. Label it as experimental. (Body doubling, evidence C, 2.10.)
R20. Anti-cheat belongs to exams only, via Tivra read-only signals (frontmost app, AI tool windows, clipboard use if available). Daily practice has no cheating payoff, so no surveillance is needed there. An exam that detects a violation pauses and flags it; it does not auto-fail and never locks the machine. (Self-reported cheating tendency; commitment devices work if enforceable, 3.1; DECISIONS rule 3.)
R21. Exam stakes are chosen by the learner in advance (e.g., mascot health loss and a retake scheduled in 48 hours), so a failure is a planned consequence. (Commitment 3.1, 3.6.)
R22. Spaced retrieval (FSRS) is the memory engine; error items return sooner. (Spacing review in 4; WaitChatter repeats missed words.)
R23. Prefer production tasks in short bursts (type a sentence from a prompt) for the "write to unlock" feature, but cap at 1-3 sentences, with a skip that costs a small pre-agreed amount. Long paragraphs are an optional weekly "journal" mode. (Working memory, executive costs 2.1; escape-hatch rule.)
R24. Instrument everything locally: session start/skip/abandon, time-to-first-response, penalty events, escape-hatch use. Review weekly with the learner and auto-suggest loosening if skips rise. (Novelty cliff detection 2.5; local data rule.)
R25. Weekly planning ritual (5 minutes): review the week, adjust penalties and triggers, write one if-then plan. (Implementation intentions, commitment pre-planning, 3.4, 3.6.)
R26. Stay positive on lapses: after 3+ missed days, the first prompt is a "welcome back, here is a 1-minute restart", with all penalties paused. (Silverman and Barasch: repair; emotion dysregulation.)

---

## 6. Mechanics to AVOID (abandonment or harm risks)

1. All-or-nothing streaks with no repair (broken streaks sap later engagement, even for external reasons: 3.2).
2. Large, delayed or unpredictable penalties; penalties applied while the learner is in a meeting or deep work (DECISIONS rule 2, hyperfocus 2.7).
3. Punishment spirals: stacking penalties after missed sessions (emotion dysregulation, 2.8).
4. Shame-based copy or mascot behavior ("You let me down"); guilt-trip notifications.
5. Variable-ratio reward schedules tied to progress or access, loot boxes, and chance-based XP (3.5).
6. Pay-to-skip or monetized streak saving. Not needed; no ethical case here.
7. Points for presence (login bonuses) and heavy extrinsic token inflation (3.3).
8. Multi-step setup flows, long forms, or required recall of rules (2.1). Onboarding is where ADHD users leave first [inference, not tested].
9. Long mandatory sessions or paragraph-length unlock gates by default (executive cost; novelty fatigue).
10. Any gate that cannot be bypassed or that survives a force-quit (violates DECISIONS rule 2).
11. Penalties that can be edited in the moment (bargaining defeats the commitment); also penalties that are impossible to escape and thus provoke deletion.
12. Daily difficulty swings that feel random; unbounded exam difficulty ramps that cause repeated failure (keep a floor of achievable wins).
13. Social comparison leaderboards (likely demotivating for RSD-type reactivity; no direct evidence here [unverified]).
14. Notification spam outside the app's own contextual triggers; do not rely on push for a Mac app that already controls the screen.
15. Treating "interest-based nervous system" or "RSD" as validated science in the UI or marketing (evidence C).
16. Fixed visual patterns that go stale; rotate presentation of the same items (novelty, 2.5).
17. Measuring success by time-in-app; measure retrieval accuracy and days practiced instead (engagement without learning risks the hyperfocus/internet-addiction link, 2.7).

---

## 7. Open questions and suggested experiments (for a learner's own single-user data)

- Does a response-cost penalty or a task penalty reduce skipped sessions more over 4 weeks? (A/B by week, log locally.)
- Which trigger (unlock, app switch, end of focus block) has the highest completion rate and lowest irritation rating?
- Does the weekly consistency metric predict return after a missed day better than a streak counter?
- At what week does skip rate rise (the cliff), and does a scheduled novelty event flatten it?
- Is the learner's "AI cheating" concentrated in production tasks (writing, speaking)? If so, make those proctored by Tivra and keep reading/listening exams lighter.

## 8. Source quality notes
- Strongest: meta-analyses on delay discounting, ventral striatum, timing, working memory; Silverman and Barasch (JCR 2023); Gollwitzer and Sheeran (2006); Giné et al. (AEJ 2010).
- Contested or replication-challenged: Ariely and Wertenbroch 2002 (2026 replication null on Study 2); Lally "66 days" over-generalization; overjustification effect sizes.
- Weak or popular: interest-based nervous system, RSD, body doubling, "time blindness" label, Duolingo percentages, any vendor blog statistic.
- I could not retrieve: adult WM pooled effect (Alderson et al. 2013), Sheeran 2024 overall effect, primary Barkley source, ADHD-specific dropout data for gamified apps.

---

## Verification

Fact-check pass on 2026-10-22. Method: web searches plus direct reads of two primary PDFs (WaitChatter CHI 2015, Deci et al. 1999); the rest verified against abstracts or bibliographic records.

| # | Claim | Verdict | Source |
|---|---|---|---|
| 1 | Silverman and Barasch 2023, JCR 49(6): 7 studies, intact streaks raise later engagement vs broken ones, stronger with self-blame, weaker when repairable | Confirmed (pp. 1095-1117, doi 10.1093/jcr/ucac029). Note: abstract says effect is independent of actual past behavior; the "even when external" wording comes from the press, not the abstract | [UDel repository](https://udspace.udel.edu/items/42ce576b-8e1f-429a-8541-e29e48dbcfbb), [Colorado](https://www.colorado.edu/business/faculty-research/2023/04/19/or-track-how-broken-streaks-affect-consumer-decisions) |
| 2 | Lally 2010: n = 96, 84 days, median 66 days, range 18-254, from 39 good fits | Confirmed in secondary sources (not the original paper); wording corrected to "95% of own asymptote"; 254 is an extrapolation | [BPS Digest](https://bps.org.uk/research-digest/how-form-habit), [Behavioral Scientist](https://www.thebehavioralscientist.com/articles/how-long-to-form-a-habit) |
| 3 | Giné, Karlan, Zinman 2010: ~2,000 smokers, 11% uptake, +3 pp pass rate, persists at 12 months | Confirmed; journal citation added (AEJ Applied 2(4):213-35) | [IPA paper](https://es.poverty-action.org/sites/default/files/publications/put_your_money_where_your_butt_is.pdf), [RePEc](https://econpapers.repec.org/article/aeaaejapp/v_3a2_3ay_3a2010_3ai_3a4_3ap_3a213-35.htm) |
| 4 | Gollwitzer and Sheeran 2006: 94 tests, d = .65; 2024 synthesis 642 tests | Confirmed; 2024 paper identified (European Review of Social Psychology, overall effect still unretrieved) | [Konstanz record](https://kops.uni-konstanz.de/handle/123456789/69905), [2006 abstract](https://www.socmot.uni-konstanz.de/publications/implementation-intentions-and-goal-achievement-meta-analysis-effects-and-processes) |
| 5 | Plichta and Scheres: reduced ventral striatal reward-anticipation activation, ES ~0.48 | Confirmed (pooled d = 0.48, Neurosci Biobehav Rev 38:125-134); authors say studies are too few for firm conclusions | [PMC3989497](https://pmc.ncbi.nlm.nih.gov/articles/PMC3989497) |
| 6 | ADHD delay discounting d = 0.43, 21 studies, no age moderation | Confirmed and attributed to Jackson and MacKillop 2016 (N = 3,913). Wrong PMC link replaced | [Jackson and MacKillop](https://doi.org/10.1016/j.bpsc.2016.01.007) |
| 7 | Martinussen 2005 child WM effect sizes (0.47, 0.43, 0.85, 1.06) | Confirmed (26 studies, JAACAP 44:377-384). Kasper 2012 d ~0.69-0.74 remains [unverified] | [PubMed 15782085](https://pubmed.ncbi.nlm.nih.gov/15782085/) |
| 8 | WaitChatter: 20 participants, 2 weeks, 57 words, most receptive after sending a chat | Confirmed from the paper; "MIT lower figure" was wrong, it is the same ~4 words/day | [CHI 2015 PDF](https://sls.csail.mit.edu/publications/2015/Cai_CHI-2015.pdf) |
| 9 | Ariely and Wertenbroch 2002 deadlines | **Corrected: retracted 2 Sep 2026** (failed replication plus data-tampering analyses). Removed as support | [Retraction Watch](https://retractionwatch.com/2026/09/03/procrastination-study-duke-dan-ariely-psychological-science-data-colada-tampering-retraction/), [Data Colada](https://datacolada.org/138) |
| 10 | Deci, Koestner, Ryan 1999 effect sizes (-0.40 tangible, +0.31 verbal) | **Corrected**: tangible -0.34; -0.40 is free-choice overall / engagement-contingent; verbal +0.33 free-choice, +0.31 self-report. 128 studies confirmed | [Paper PDF](https://depts.washington.edu/techdocs/papers/deciExtrinsicRewardsAndIntrinsicMotivation99.pdf) |

Also: adult WM meta-analysis (Alderson et al. 2013, 38 studies, moderate effects) now confirmed to exist; pooled values remain [unverified]. Not checked this pass: Sonuga-Barke models, hyperfocus review, emotion-dysregulation figures, body-doubling preprints (arXiv 2609.21254 is a plausible September 2026 ID but unread), Hamari et al., Gawrilow studies.

## Gaps found in verification

- Commitment-device evidence is now thinner than the report implied: with Ariely and Wertenbroch retracted, only Giné et al. (modest, one population, confounded by frequent contact) supports financial/self-binding devices. Tenaz's penalty design (R8-R10, R21) is a design inference, not a validated intervention; keep the logging/adaptation loop (R24) as the real safeguard.
- Lally's habit sample was healthy undergraduates doing simple health behaviors, not ADHD adults or cognitive practice; the "2-4 months" horizon (R16) is an assumption, not an ADHD-specific finding.
- No evidence was found on adults with ADHD learning a second language or on gamified apps for them; every ADHD result here concerns attention, reward or memory in general. Treat Tenaz effectiveness as untested and plan to measure it. [inference]
- Effect sizes cited (d = 0.43-0.48 for discounting/striatum, ~0.4-0.5 for verbal WM) are group-mean differences; they do not predict the learner individually, so defaults should be user-tunable.
- Sources on this topic are being revised in 2026 (retractions, replications); before shipping any user-facing claim ("science-backed"), re-verify the specific citation.
