# 03. Learning science for Tenaz: adult L2 acquisition for a Spanish-speaking B1+ learner (target B2, then C1, for work meetings)

Date: 2026-10-22. Scope: design decisions and implementable mechanics, not an essay.

Evidence legend. **[V]** = verified this session against a fetched page or search result (URL given). **[M]** = from my background knowledge of the literature, NOT re-verified this session; check before relying on exact numbers. **[unverified]** = could not confirm. Search-tool access in this session was limited (US-only search, several queries returned off-topic pages), so a lot of the classic-paper detail is [M]. Section 12 lists what to re-verify first.

---

## 0. Executive summary (the decisions that matter)

1. **Retrieval, not exposure, is the core loop.** Tenaz should force active recall (typing, speaking) of items on an FSRS schedule. Exposure (reading/listening) feeds the deck but never counts as "practice done." [M: Karpicke & Roediger 2008; Rowland 2014 meta-analysis; see Section 2]
2. **Use FSRS-6 via the MIT-licensed `open-spaced-repetition/swift-fsrs`**, default parameters at first, desired retention ~0.90 (0.85 for the long tail of low-value items), optimize weights on-device after ~1,000 reviews. [V: swift-fsrs README says "A Swift implementation of FSRS-6.0", MIT: https://github.com/open-spaced-repetition/swift-fsrs]
3. **Vocabulary is the highest-leverage target for B1+ to B2/C1**, but the unit must be the **chunk/collocation and the production of it**, not isolated single words with a Spanish gloss. Spanish speakers have a large cognate advantage and a large false-friend trap; both need explicit decks.
4. **Feedback must prompt self-correction when possible (prompts > recasts) and be delayed/aggregated for writing**, with error categories tracked per learner to personalise L1-Spanish interference drills. [V for Lyster & Saito 2010 direction: https://escholarship.mcgill.ca/downloads/6w924g64b ; M for the rest]
5. **Fluency needs its own track** (4/3/2, repeated speaking, shadowing). Fluency gains from repetition do not automatically transfer to accuracy. [V: 4/3/2 results and limits, see Section 7]
6. **Session budget: ~35 to 45 minutes/day of learning-active time**, split into small blocks aligned with ADHD-friendly attention spans (Section 10). A "minimum viable day" of 8 minutes keeps the streak and the mascot alive.
7. **Anti-cheating exams need an assessment design, not only a Tivra integration** (Section 9): proctored production tasks (speaking, handwritten-style typed writing under lock) plus item types that are hard to outsource to an LLM.

---

## 1. Input: Krashen and the critiques

**What Krashen claimed.** The Input Hypothesis: acquisition happens when learners understand input at "i+1"; conscious learning does not turn into acquisition (the "non-interface" position); output is not necessary. [M]

**Where the evidence stands.**
- Input is necessary and large volumes of meaning-focused input matter, especially for vocabulary and listening. Extensive reading and listening produce incidental vocabulary gains, but gains per word are small, so you need very large volumes. [M: Nation, *Learning Vocabulary in Another Language*; Webb & Chang on graded readers]
- Input alone is insufficient for accuracy. Canadian French immersion students had comprehension and fluency but persistent grammatical errors, which motivated Swain's Output Hypothesis. [M: Swain 1985]
- The strong "no interface" claim is not supported by the instructional literature: explicit instruction yields durable gains, and effects are larger for explicit than implicit instruction in the major meta-analysis. [M: Norris & Ortega 2000, Spada & Tomita 2010]
- A pragmatic synthesis (Nation's "four strands"): roughly equal time on meaning-focused input, meaning-focused output, language-focused learning (deliberate study), and fluency development. [M: Nation 2007, "The four strands"]

**Decision for Tenaz.**
- Adopt the four-strands budget as the weekly skeleton (Section 10). Input is delivered at "i+1" difficulty using Claude-generated or curated texts matched to the learner's deck: target 95-98% known-word coverage for comfortable reading and about 98% for unassisted reading comprehension. [M: Hu & Nation 2000; Laufer; Schmitt, Jiang & Grabe 2011 put the threshold nearer 98% for good comprehension]
- Do not rely on "just watch Netflix". The app measures **unknown-word density** of every passage and refuses to present a text above the learner's tolerance without glosses.

## 2. Output, interaction, noticing

- **Output hypothesis (Swain).** Producing language forces syntactic processing, lets the learner notice gaps ("I can't say what I mean"), test hypotheses, and reflect. [M]
- **Interaction hypothesis (Long).** Negotiation of meaning (clarification requests, confirmation checks) makes input comprehensible and draws attention to form. [M]
- **Noticing (Schmidt).** Learners acquire only what they consciously notice. [M]
- **Skill acquisition / automatization** (DeKeyser): declarative knowledge becomes procedural only through repeated, contextually appropriate practice. Explains why drills of production, not recognition, matter for meetings. [M]

**Decision.** Every day includes *pushed output* with an immediate "noticing" step: after the learner writes or speaks, Tenaz shows the gap between what the learner produced and a target reformulation, and asks them to fix it (see exercise E12, E13).

## 3. Retrieval practice, testing effect, spacing, interleaving, desirable difficulties

**Testing effect.** Retrieving information strengthens memory more than restudying; benefits are largest when retrieval is effortful and followed by feedback. Meta-analytic support exists (Rowland 2014; Adesope, Trevisan & Sundararajan 2017; Schwieren et al. 2017 are cited in a 2018 Educational Psychology Review-type discussion). [V that these meta-analyses exist: https://journals.sagepub.com/doi/10.3102/0034654316689306 (Adesope et al.) and search result summary; effect sizes M]. Karpicke & Roediger 2008 (*Science* 319:966-968) showed that repeated retrieval, not repeated study, drove long-term retention for vocabulary, and that learners misjudged this. [V citation and finding: https://pubmed.ncbi.nlm.nih.gov/18276894/ ; caveat: N was small (40, between-subjects), and a later Psychological Science within-subjects follow-up found restudying also helps once spacing is controlled, so do not claim "restudy is useless", only that retrieval is better]

**Spacing.** Optimal gap depends on the desired retention interval; the optimal gap is a shrinking fraction of the retention interval: about 20-40% of a 1-week test delay, falling to about 5-10% of a 1-year delay (so "10-20%" is only a mid-range rule of thumb). Cepeda, Vul, Rohrer, Wixted & Pashler 2008, *Psychological Science* 19(11):1095-1102, N > 1,350. [V, corrected in verification: https://pubmed.ncbi.nlm.nih.gov/19076480/] Practical consequence: expanding intervals are right, and a scheduler that adapts per card (FSRS) beats fixed schedules.

**Interleaving.** Mixed practice of different categories improves discrimination and transfer, even though it feels harder. Strongest evidence is in math and category learning; for L2 grammar and vocabulary it is promising but thinner. [M: Rohrer & Taylor; Pan 2015 review] Use interleaving across *confusable* items (false friends, prepositions) deliberately, not across everything.

**Desirable difficulties (Bjork).** Conditions that slow apparent progress (spacing, interleaving, retrieval, generation) improve long-term retention. Learners systematically prefer the fluent-feeling but worse option, which is exactly the learner's risk (and why the app must be intrusive about it). [M: Bjork & Bjork]

**Decisions.**
- Typed recall before reveal is mandatory for production cards. "Flip and self-rate" is allowed only for recognition cards and is audited (see Section 11, self-rating honesty).
- Interleave the session: never show more than 3 consecutive cards of the same type or topic.
- Mix new and review in a ratio capped at about 1 new per 4 reviews (tunable) to avoid review debt, the classic failure of Anki users.
- Use generation: before showing a definition, ask the learner to produce their own sentence (the generation effect). [M]

## 4. FSRS (FSRS-6): how it works, parameters, benchmarks, Swift implementation

### 4.1 Model
- **Three state variables per card:** Difficulty D (1-10), Stability S (days for retrievability to fall from 100% to 90%), Retrievability R (probability of recall now). [V: https://github.com/open-spaced-repetition/awesome-fsrs/wiki/The-Algorithm plus search summary]
- **FSRS-6 forgetting curve (power law), verified:**
  `R(t,S) = (1 + factor * t/S)^(-w20)`, `factor = 0.9^(-1/w20) - 1`, chosen so R(S,S) = 90%. [V: awesome-fsrs wiki]
- **21 parameters (w0-w20)**, default list [V: same wiki]:
  `[0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, 0.1666, 0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542]`
  `w20 = 0.1542` is the default curve-shape (decay) parameter, personalised per user in FSRS-6. [V]
- **Same-day (short-term) review stability:** `S' = S * e^(w17 * (G - 3 + w18)) * S^(-w19)`. [V]
- **Initial stability** after the first rating G in {1,2,3,4} = w[G-1]; **difficulty** and **post-review stability** for success/failure follow the FSRS-5 shapes (`S'_success = S * (1 + e^w8 * (11-D) * S^-w9 * (e^(w10*(1-R)) - 1) * hardPenalty * easyBonus)`, lapse formula uses w11-w14). **[M: the fetched page did not show these for FSRS-6; Tenaz does not need to re-implement them because swift-fsrs does.]**
- Next interval for desired retention r: `I = S/factor * (r^(-1/w20) - 1)`, which equals S when r = 0.9. [M, derived from the verified curve; trivial algebra, check by unit test]
- Ratings: Again(1), Hard(2), Good(3), Easy(4).

### 4.2 Benchmarks
- The open-spaced-repetition benchmark has ~727 million reviews from ~10,000 users. FSRS-6 results: Log loss 0.3460, RMSE(bins) 0.0653, AUC 0.7034 without same-day reviews; 0.3842 / 0.0985 / 0.6830 with same-day reviews. Moving-average and FSRS-7 variants and neural nets score better; with same-day reviews FSRS-6 is slightly worse than the AVG baseline (0.3816). [V: https://github.com/open-spaced-repetition/srs-benchmark]
- **FSRS vs SM-2:** the benchmark README page I fetched did not report SM-2 numbers. A secondary summary says FSRS (with defaults only) predicts better than SM-2 for 99.5% of users. [V that the secondary claim exists: https://www.mindomax.com/fsrs-vs-sm2-spaced-repetition-algorithm ; it is a low-quality source, treat as [unverified]] Secondary sources (RemNote help etc.) say 20-30% fewer reviews at equal retention, others say 15-40%; the figure depends on dataset and target retention. [unverified: no primary Anki-manual source retrieved; plan with "roughly 20-30% fewer", not as a guarantee]
- **FSRS-7 exists** (a Haskell port, Aug 2026, 34 weights, two memory traces per card). I found no evidence it has shipped in Anki, and swift-fsrs implements FSRS-6. [V: https://hackage-content.haskell.org/package/haskell-fsrs ; Anki shipping status unverified]

**Consequence.** FSRS is excellent for day-scale review of discrete facts; it is weak for *within-day* learning (same-day AUC below baseline). So Tenaz uses its own **short learning steps** for new cards (Section 11.3) and hands cards to FSRS only after they graduate.

### 4.3 swift-fsrs
- Repo: `open-spaced-repetition/swift-fsrs`. License **MIT**. README: "A Swift implementation of FSRS-6.0"; FSRS-5 supported by passing a 19-element `w`. No GitHub release tag shown (Releases empty), 55 commits. Use by pinning a commit hash in Package.swift. [V: https://github.com/open-spaced-repetition/swift-fsrs]
- API from the README: [V]
  ```swift
  import FSRS
  let v6 = FSRS(parameters: .init(w: FSRSDefaults.defaultWv6))
  let card = FSRSDefaults().createEmptyCard()
  let next = try v6.next(card: card, now: Date(), grade: .good).card
  ```
- Alternative third-party packages found: `bootuz/SwiftFSRS` (claims FSRS-6) and `4rays/swift-fsrs` (MIT). [V existence: https://swiftpackageregistry.com/bootuz/SwiftFSRS , https://swiftpackageregistry.com/4rays/swift-fsrs ; correctness unverified]
- Not verified: Swift 6 strict-concurrency readiness, minimum macOS target, whether it exposes a parameter optimizer (almost certainly not; optimizer is in fsrs-rs, BSD-3-Clause per a search summary [unverified]). **Action:** spike it in TenazCore, check `Sendable` conformance of `Card`/`FSRS`, and wrap it behind a `Scheduler` protocol so it can be swapped for a vendored copy (it is small) if it blocks Swift 6.
- **Optimization:** swift-fsrs does not train weights. Options: (a) defaults forever (fine for the first months), (b) ship `fsrs-rs` CLI/FFI and run it on exported review logs, (c) port a simple gradient fit. Recommend (a), then (b). Keep a full **review log** (card id, timestamp, rating, state, elapsed, duration ms, input mode) from day 1, since that is exactly what any optimizer needs.

## 5. Vocabulary: size, productive vs receptive, chunks

**Size targets.**
- Nation's CEFR mapping suggests about 4,000 words for B2 (2,000-3,000 high-frequency words PLUS 1,000-2,000 relevant technical vocabulary, so the general-vocabulary part is smaller) and 5,000-6,000 for C1 (7,000-9,000 for C2), noting that these are larger than some other proposals (Milton). [V, nuance added in verification: https://wgtn.ac.nz/lals/resources/paul-nations-resources/vocabulary-lists/vocabulary-cefr-and-word-family-size/vocabulary-and-the-cefr-docx]
- Milton: receptive 3,000 most frequent lexemes relates to B1, 5,000 to C1; a Milton & Alexiou table for Greek learners gives XLex bands of roughly 3,250-3,750 (B2) and 3,750-4,500 (C1). Those are lemma/lexeme counts and are not comparable to Nation's family counts. [V: https://www.enl.auth.gr/gala/14th/Papers/English%20papers/Milton&Alexiou.pdf ; no Spanish column found]
- General reading at 98% coverage needs roughly 8,000-9,000 word families (newspapers/novels). [V as a slide-deck attribution to Nation 2006; the number itself is widely cited, M]
- Spanish-speaking learners often have a **productive vocabulary far below receptive** (a Spanish study found productive size under 1,000 words for 10th graders). [V: https://investigacion.unirioja.es/documentos/5c13b27bc8914b6ed377e56e?lang=eu ; different population, only illustrative]
- Receptive size is easier to inflate than productive; for meetings what matters is **fast, accurate retrieval for production** (lexical access speed), not a bigger passive list.

**Decisions.**
- The assumed starting level is B1+. Plan: measure receptive size with a Vocabulary Levels Test-style probe and a productive probe (Lex30-style free association, or the Productive Levels Test) in week 1 and every 8 weeks. [M for the instruments; check for free versions: Nation's site hosts VLT/VST, URL unverified]
- Ordering by **frequency plus work-meeting utility**: first the General Service List/NGSL band 2,000-5,000 words the learner lacks; then the Academic Word List; then a **meeting/business register deck** ("circle back", "bandwidth", "action item", "blocker", "align on", "push back", "roll out"). Source from the learner's own meetings (see Section 11, "capture from life") since personal relevance boosts retention. [M for principles]
- **Cognates:** Spanish-English share a huge Latinate vocabulary (information/información). Treat cognates as *free receptive vocabulary* but drill *pronunciation and stress* (e.g. "development", "comfortable") because those are where errors appear.
- **False friends deck (high priority):** actual/actually, eventually/eventualmente, assist/asistir, library/librería, sensible/sensible, pretend/pretender, realize/realizar, support/soportar, introduce/introducir (people), attend/atender, argument/argumento, constipated/constipado, embarrassed/embarazada, compromise/compromiso, resume/resumir, record/recordar, lecture/lectura, college/colegio, parents/parientes, fabric/fábrica, success/suceso, carpet/carpeta, assume/asumir, eventual. Several matter in workplace talk: "actually", "eventually", "assist", "compromise", "realize", "support". [M: standard contrastive-analysis lists; spot check with a dictionary]

**Lexical chunks and collocations.**
- A large proportion of fluent language is formulaic; collocation knowledge distinguishes advanced from intermediate learners, and learners' errors are often collocational ("make a decision" vs "take a decision", "do a mistake"). [M: Wray; Pawley & Syder; Nation & Webb; Boers & Lindstromberg]
- Spanish speakers typically err in: make/do (hacer), say/tell, take/have/make with nouns, "depend of", "explain me", "discuss about", "emphasize on". [M]
- **Decision:** the card unit is the **chunk with a slot**, e.g. "bring something up in the meeting", "follow up on __", "be responsible for __ing". Production cards ask for the chunk given a Spanish/English situational cue. Collocation cards use cloze + a 4-way minimal-pair choice, and graduate to free production.

**Number of words per week.** Realistically 25-40 new items/week with high retention; at 0.90 retention and a 35-minute budget the review load stabilises at around 60-110 cards/day for a 1,500 to 2,500-card deck. [M, derived from typical FSRS load; calibrate with simulation: write a simulator in TenazCore tests]

## 6. Corrective feedback

- **Lyster & Ranta (1997)** classified teacher feedback: recasts, explicit correction, clarification requests, metalinguistic feedback, elicitation, repetition. Recasts were the most frequent but led to the least immediate learner repair; prompts (clarification request, metalinguistic clue, elicitation, repetition) led to more learner-generated repair. [M]
- **Lyster & Saito (2010, SSLA 32:265-302):** 15 classroom studies, N=827; CF has significant, durable effects; **prompts outperformed recasts**, especially on free-production measures; longer treatments were better; younger learners benefited more than older ones; setting was not significant. [V: https://escholarship.mcgill.ca/downloads/6w924g64b ; effect sizes: secondary source says medium for recasts, large for prompts]
- **Li (2010, Language Learning 60:309-365):** 22 articles + 11 dissertations; overall medium effect for oral CF; I could not retrieve its recasts-vs-prompts breakdown or the finding that explicit CF beat implicit and that effects persist/decay after delay. **[V that it exists and is medium overall: search result; breakdown unverified]**
- **Written CF.** Truscott (1996) argued grammar correction is ineffective or harmful; later meta-analyses (Kang & Han 2015, MLJ 99:1-18, 21 primary studies) found a positive effect on accuracy in new writing. [V citation: https://scinapse.io/papers/2005247852 ; effect size M, I recall medium (g about 0.6) and larger for lower-proficiency/ESL contexts, **unverified**]. Also Karim & Nassaji 2020 (TESOL Quarterly) and Li 2020 (Language Learning) review CF [V existence only]. Unfocused vs focused CF: focused (a few error types at a time) tends to work better. [M: Ellis; Bitchener]
- Direct vs indirect, metalinguistic explanations: direct plus brief explanation helps accuracy of new writing for specific, rule-governed structures (articles) better than indirect coding. [M]

**Decisions for Tenaz (Claude as feedback engine).**
1. **Two-pass feedback.** Pass 1 *prompt*: highlight the span and category ("preposition?") and let the learner self-correct (elicitation/metalinguistic clue). Pass 2 (after the learner tries or after 60 seconds) show the recast + a one-line rule. This is prompt-first, recast-as-backstop.
2. **Focus:** at most 3 error categories per piece; the rest are logged silently in the error profile and surface later in targeted drills (so the learner is not overwhelmed; ADHD-friendly).
3. **Error ledger:** a persistent table (category, example, count, last seen). Each repeated error spawns a production card with *the learner's own mistake as the distractor*.
4. **Delayed re-test:** after a corrected text, ask for a new text 24-48 hours later using the same structures (the testing effect applied to feedback).
5. For speech: transcribe locally (macOS 26 `SpeechAnalyzer`/`SpeechTranscriber` from WWDC25, with `.audioTimeRange` for word timing, needed for WPM/pause metrics; per-word timing on volatile results and on long files was reported inconsistent in Apple forum threads, so test on real recordings and treat as [unverified] until spiked; https://developer.apple.com/videos/play/wwdc2025/277/ , https://origin-devforums.apple.com/forums/thread/794510) and give prompts after the utterance, never mid-sentence.

## 7. Fluency: 4/3/2, task repetition, shadowing

- **4/3/2 (Maurice 1983, Nation 1989):** same talk delivered to three listeners in 4, 3, then 2 minutes. Nation's six advanced ESL learners showed speaking rate increases (one from 86 to 127 wpm), fewer hesitations and repeats; accuracy changed little. [V: search summary of Nation 1989; also https://learnlab.org/research/wiki/index.php/Fostering_fluency_in_second_language_learning ]. De Jong & Perfetti 2011 found sizable fluency gains from repeating; Boers 2014 and Thai & Boers 2016 found gains are fluency, not accuracy; small samples and sparse reliability reporting; Nation measured only within-task fluency. [V: search results above]
- Tenaz adaptation: the "listener" is the app (or a person, optional). Same prompt repeated at 90s, 60s, 40s time limits, auto-measured by speech-to-text: words per minute, pause count and length, filled pauses, type-token ratio, repetitions. Score = improvement on the same topic from run 1 to run 3, plus a **transfer run** on a new topic a day later (the real test).
- **Shadowing:** imitating audio with ~1-2 s lag. Reported benefits for listening and pronunciation/prosody in small studies. I did not retrieve a meta-analysis; **[unverified] effect size**. Use as a cheap, 3-5 minute prosody exercise with a self-recorded compare-waveform, not as a primary learning engine. [M]
- **Planning time & pre-task**: giving 1-2 minutes planning raises fluency and complexity (Ellis 2009). [M]

## 8. Pronunciation and L1 Spanish interference

**Evidence on training.** High Variability Phonetic Training (many speakers, many contexts, with feedback) improves perception and production for difficult L2 contrasts and transfers to new speakers. [M: Logan, Lively & Pisoni 1991; Thomson & Derwing 2015 review on pronunciation instruction effectiveness]. Intelligibility and comprehensibility, not native accent, is the goal (Derwing & Munro). Prioritise features that harm intelligibility: word stress, vowel reduction, certain consonant contrasts, final consonants. [M]

**Spanish-L1 patterns (verified sources are weak; most of this is standard contrastive analysis [M])**

| Area | Pattern | Evidence status |
|---|---|---|
| /b/ vs /v/ | "very" -> "berry", "vote" -> "boat"; Spanish [b] initially, [β] between vowels; fix: upper teeth on lower lip | V: https://pronunciationstudio.com/spanish-speakers-english-pronunciation-errors/ |
| /s/ + consonant onsets | epenthesis: "estudent", "especial", "eskate"; train by holding /s/ and shortening | V: same site and https://pronounce.tv/blog/common-spanish-speaker-pronunciation-mistakes |
| Tense/lax vowels | ship/sheep, full/fool, cat/cut/cot; Spanish has 5 vowels | V (partial): same sources; length contrast M |
| Schwa and vowel reduction | Spanish is syllable-timed, English stress-timed; unstressed vowels are not reduced, giving "robotic" rhythm | V (partial): same sources; M for the timing claim |
| -ed endings | /t/ /d/ /ɪd/ allomorphs ("worked", "played", "needed"); tendency to pronounce "-ed" as /ed/ everywhere or drop it | **[unverified]**, no source found this session; widely taught [M] |
| Final consonants and clusters | "-ths", "-sts", final /d/ /g/ devoiced or dropped | M |
| /h/, /dʒ/, /ʃ/ vs /tʃ/ | "hair" with /x/; "jump" vs "chump"; "sheep"/"cheap" | M |
| Word stress | stress shifts in cognates: "PHOtograph / phoTOgraphy", "deVELop", "CHOcolate"; Spanish stress rules differ | M |
| Sentence stress/intonation | flatter content/function distinction; weak forms ("to", "of", "for") missing | M |

**Grammar/lexis interference [M unless noted]**
- **Articles:** Spanish uses definite articles for generics ("The life is hard", "I like the music") and omits indefinite ones before professions ("He is engineer"). Both errors are very likely in the learner's writing. Target with cloze and "which sentence is wrong" tasks.
- **Prepositions:** depend of, in the Monday/at the weekend, consist of, interested on, married with, arrive to, discuss about, explain me.
- **Verb patterns:** "suggest me", "make me to do", "want that he comes" (want him to come), "enjoy to", gerund vs infinitive after "look forward to", "avoid to".
- **Tense/aspect:** present perfect overuse/underuse; "I am agree"; "I have 20 years"; "since/for"; subjunctive-to-"will" errors in if-clauses ("if I will have").
- **Word order & pro-drop:** missing expletive subjects ("is important" -> "it's important"); adjective-noun order; adverb placement; question formation without do-support.
- **Register:** direct translation of politeness formulas; overuse of "I think that"; missing hedging ("could we perhaps..."), important in meetings.
- **Lexical:** false friends (Section 5).

**Decision.** The error ledger (Section 6) is seeded with these categories as "suspect categories" and is updated by actual errors. Pronunciation drills are chosen from the learner's recorded outputs: Claude receives the STT transcript and phoneme-level confidences if available; automatic scoring via on-device speech recognition confidence is noisy for minimal pairs, so use **minimal-pair perception tests (objective)** plus **self-recording with model comparison (subjective, Claude-assisted)**. Apple's Speech framework gives word confidence but not reliable phoneme scoring [M, **unverified**]; do not claim automated pronunciation grading beyond intelligibility (does the STT recognise the intended word?).

## 9. Workplace English and assessment integrity (the AI-cheating problem)

**Workplace learning.** Language use in meetings is dominated by a small set of functions: opening/closing, agreeing/disagreeing, clarifying, hedging, giving status updates, asking for resources, escalating, summarising decisions. Teach by function ("language functions") with chunk banks. [M: business English literature, e.g. Nickerson; no specific cite verified]. Learning at work needs *just-in-time retrieval support*: pre-meeting 5-minute warm-up of relevant chunks, post-meeting "capture" (the learner types or dictates 3 phrases they wished they had said). Respect DECISIONS.md: **no overlays during meetings**; pre-meeting prompts come from the calendar and are notification-only.

**Why the "exam" must be designed against LLM cheating (learners may cheat with AI).**
- Treat the exam as a closed-book *task design* problem plus *environment control* problem.
- **Environment control (Tivra, read-only integration):** during an exam, require Tivra to report frontmost app and block/flag AI apps and browsers; exam aborts and is scored invalid if a disallowed app is frontmost for more than N seconds. All enforcement stays escape-hatch-safe per DECISIONS.md (the kill-switch ends the exam as void, not as a lockout).
- **Task design** (harder to outsource): spoken tasks recorded live (hard to cheat in real time), writing with keystroke-dynamics telemetry (typing cadence, paste events disabled, revision history, time-on-task), integrated tasks that depend on audio heard once, and *personal-knowledge prompts* ("describe what you did in Tuesday's standup" checked against the learner's own captured logs).
- **Honesty about limits:** a non-sandboxed local app cannot guarantee no AI use (a second device exists). The control is a commitment device, so pair it with a *self-report* ritual and make the cheating penalty visible; do not frame it as proctoring-grade. [design judgment]

**Exam structure** (per DECISIONS.md: TOEFL iBT-style sections). The TOEFL iBT changed from January 2026: Reading and Listening are multistage adaptive, new collaborative-academic task types were added, and scoring is a 1-6 band scale (0.5 steps, CEFR-aligned, overall = average of four sections) with comparable 0-120 scores reported for a two-year transition. [V: https://toeflaccess.ets.org/help/en/articles/11758550-toefl-ibt-updates-coming-january-2026 , https://toeflaccess.ets.org/help/en/articles/11758616-toefl-ibt-score-scale-update-what-you-need-to-know ; the exact 21 Jan start date and exact new task names are from secondary summaries, [unverified]; so Tenaz exams must be "TOEFL-style", not a faithful replica]. IELTS-to-CEFR is only approximate and sources disagree: commonly B2 = 5.5-6.5 and C1 = 7.0-7.5 or 8.0 (some tables put 8.0+ at C2); IELTS.org itself warns the CEFR was never meant for precise equating. [V that sources disagree: https://www.ielts.org/about-ielts/ielts-in-cefr-scale ; use bands as rough targets only]; the Council of Europe CEFR Companion Volume (2020) is the descriptor source. [M]

## 10. Daily and weekly learning loop

### 10.1 Principles
- Short blocks, high novelty, instant feedback (ADHD-friendly), one mandatory "anchor" block at a predictable time, with an 8-minute minimum viable day.
- Stack all four strands weekly; scheduled FSRS reviews are the spine.
- Difficulty ramps by *measured* CEFR-aligned performance, not calendar.

### 10.2 Daily loop (target about 40 min active, in 4-5 blocks)

| # | Block | Min | Time of day | Content |
|---|---|---|---|---|
| 1 | **Wake gate** (opt-in, escape hatch) | 5 | after first unlock | FSRS due reviews, largest leech and leading-edge cards; typed recall |
| 2 | **Micro-reviews** | 2 x 2 | triggered between work tasks (Pomodoro-boundary only, never in a meeting) | 6-10 cards each, a single big word on screen |
| 3 | **Input** | 10 | lunch or commute | one graded text or short audio at i+1 with 6-8 target chunks; comprehension questions; pick up to 5 new cards |
| 4 | **Output** | 10 | afternoon | 1 writing or speaking task (rotates), with prompt-first feedback |
| 5 | **Evening close** | 5 | before shutdown | test-yourself recap of today's new items (the first spaced exposure in the evening), "capture from life" of 3 phrases, mascot feeds |

Minimum viable day (8 min): Block 1 + the evening close. Keeps streak and mascot alive; never a lockout.

### 10.3 Weekly loop
- Mon-Fri: as above, rotating Output between writing, speaking, and pronunciation.
- **Wed:** 4/3/2 speaking session (12 min) + shadowing (5).
- **Sat:** mini-exam (25-30 min): one Reading, one Listening, one Speaking, one Writing task, difficulty adaptive; automated report.
- **Sun (15 min):** error-ledger review, choose next week's focus categories, deck cleanup (leeches).
- **Every 4 weeks:** full section exam; **every 8 weeks:** vocabulary-size probes (receptive + productive). Re-tune new-card rate to maintain load.

### 10.4 Time budget by strand (matches Nation's four strands loosely)
Meaning-focused input 25%, meaning-focused output 25%, language-focused (deliberate vocab/grammar/pronunciation) 25%, fluency 25%; FSRS reviews live inside the language-focused strand, with output and fluency drills feeding new cards.

## 11. Exercise catalog (at least 15), scoring, FSRS integration

### 11.1 Card types in the deck (FSRS-scheduled)

Each *note* (a chunk or word) can generate several *cards*, each scheduled **independently** in FSRS (separate S and D), because recognition and production are different memory traces.

| Card type | Prompt | Answer mode | Auto-score |
|---|---|---|---|
| **R: recognition** | English chunk | choose Spanish meaning / pick the correct usage sentence (MC, 4 options, plausible distractors) | exact; Again if wrong, Good if correct under 6 s, Hard if 6-12 s, no Easy (recognition cap) |
| **C: cloze** | sentence with blank, plus tiny context | typed | normalized string match with lemma/inflection tolerance and accepted-variants list; Claude adjudicates alternatives on mismatch (cached) |
| **L: recall (Spanish cue -> English)** | Spanish gloss / situation | typed | as C |
| **K: collocation** | "make/do/take/have ___ decision" slot or adjective+noun pair | typed or MC | as C |
| **P: production** | situational prompt ("Ask a colleague to review your PR") | typed or spoken sentence using the target chunk | Claude (rubric, below); Good if used correctly and naturally; Hard if used with minor errors; Again if absent/wrong |
| **S: spelling/pronunciation** (optional) | audio | typed word / spoken word | Levenshtein for spelling; STT match for pronunciation (intelligibility only) |

**FSRS integration rules**
1. One `Card` (swift-fsrs) per (note, card type). Persist: `due`, `stability`, `difficulty`, `state`, `lapses`, `reps`, `lastReview`, plus the review log row.
2. **Grade mapping** is deterministic per card type (table above); never ask the learner "how well did you know it?" for production cards (self-rating inflation). For R cards only, optional Hard/Good/Easy self-rating is hidden and replaced by response time.
3. **Learning steps for new cards (own logic, not FSRS):** show -> cued recall at +1 min -> +10 min -> end of day; graduate into FSRS on the first Good. This covers FSRS's weak spot with same-day reviews [V from the benchmark: same-day AUC is below baseline].
4. **Desired retention:** 0.90 default; 0.85 for tail and cognate cards; 0.93 for meeting-critical chunks tagged "must".
5. **Sibling burying:** do not show two cards from the same note on the same day (prevents answer leakage). Interleave across topics.
6. **Leeches:** 6+ lapses -> flag; change mnemonic: add Claude-generated image/example/etymology or Spanish false-friend note, or split the chunk.
7. **Prerequisite ordering:** P card unlocks only after the C or L card for the same note reaches stability >= 7 days (don't ask production on unlearned items).
8. **Load control:** if due > daily cap (e.g. 120), review by oldest overdue and highest-priority; suspend new cards until due < 80 (the app, not the learner, enforces this; the mascot "sleeps" rather than punishing, to avoid a death spiral).
9. **Review log retention:** required for later parameter optimization (Section 4.3); include `duration_ms`, `input_mode` (typed/spoken/MC), `device_time`, and `app_focus_ok` flag (Tivra-confirmed).
10. **Fuzz:** add +-5% interval noise to avoid clumping. [M: Anki does this; swift-fsrs fuzz support unverified]

### 11.2 Exercise types (20)

Scoring key: **A** = fully automatic; **C** = Claude via local `claude` CLI with a rubric (JSON out); **A+C** = auto-gate then Claude.

| # | Exercise | What the learner does | Scoring | Feeds FSRS |
|---|---|---|---|---|
| E1 | **Big-word flash** | A big word/chunk appears; the learner types meaning/translation | A | R/L cards |
| E2 | **Typed recall (ES->EN)** | Spanish cue, types the English chunk | A (string match + variants) | L |
| E3 | **Cloze in context** | Sentence with blank, sometimes 2 blanks | A | C |
| E4 | **Collocation pick/fill** | choose or type correct verb/prep partner (make/do, depend on) | A | K |
| E5 | **False-friend duel** | choose correct word in a sentence between a false friend and the true word | A | R/K |
| E6 | **Preposition/article gap-fill** | targeted at ledger errors | A | C (error cards) |
| E7 | **Error spotting** | find and fix the mistake in a sentence containing a typical Spanish-L1 error | A (exact fix) or A+C | C |
| E8 | **Sentence production with target chunk** | writes 1 sentence on a situation using the chunk | C (rubric: used correctly, natural, grammar) | P |
| E9 | **Unlock paragraph** | writes 3-5 sentences about their life (topic given, 50-80 words) to unlock the gate | A gate (min words, language detection, no paste, uses >= 2 target chunks) then C scoring | P cards for chunks used; ledger |
| E10 | **Reading with questions** | graded text + 4 comprehension questions + vocabulary-in-context | A (MC), C for short answers | new cards from lookups |
| E11 | **Listening dictation / gap-fill** | hears a 10-20 s clip (macOS TTS or recorded), types missing words or whole sentence | A (word error rate) | R/C cards |
| E12 | **Rewrite / reformulation** | rewrite own text after feedback, or paraphrase a formal email more politely | C (similarity + rubric) | ledger, P |
| E13 | **Prompt-first correction loop** | gets highlighted span + category, fixes it, then sees recast + rule | A (match to target) + C | ledger, C cards |
| E14 | **4/3/2 speaking** | records 3 deliveries, shorter each time | A (WPM, pause rate, filled pauses, TTR from STT) | none (fluency metrics) |
| E15 | **Shadowing** | repeats a clip with 1-2 s lag, records | A (STT match to the transcript, timing) | none |
| E16 | **Minimal-pair perception** | hears one word of a pair (very/berry, ship/sheep), picks which | A | S cards for failures |
| E17 | **Say-it test (intelligibility)** | says a target word/chunk; STT must recognise it | A (STT match, confidence) | S |
| E18 | **Meeting role-play** | Claude plays a colleague; the learner answers 4-5 turns (typed or spoken) in a specific function (disagree politely, ask for deadline) | C (rubric: task completion, register, grammar, chunk use) | P, ledger |
| E19 | **Summary writing** | summarize a text/audio in 60-80 words (TOEFL integrated style) | C (content points covered, paraphrase vs copying, grammar) | ledger |
| E20 | **Elicited imitation** | listens to a sentence of increasing length, repeats it from memory | A (STT match proportion) | proxy for proficiency; ledger |
| E21 | **Retell from memory (delayed)** | next-day: retell yesterday's text from memory | C (idea units recalled) | boosts text-derived cards |
| E22 | **Capture from life** | types/dictates 3 phrases they needed in a real meeting | A+C (Claude normalizes, flags L1 errors, builds notes + cards) | new notes |
| E23 | **Exam tasks (TOEFL-style)** | Read, Listen, Speak, Write sections | A for R/L (MC), C for S/W with TOEFL-like rubrics | ledger, level estimate |

**Claude rubric (C scoring)**: single prompt per item type; return JSON: `{scores: {task, language_use, accuracy, naturalness, register}, grade: 1-4, errors: [{span, category, correction, explanation_short}], chunks_used: []}`. Constraints: pass the **learner level** and the **allowed error-category list** for consistency; ask for spans so the UI can highlight them (prompt-first feedback); calibrate with a fixed set of anchor samples per band. LLM scoring reliability for essays is decent but not perfect [M]; store raw output and keep a manual override. Speak scoring uses the STT transcript, so pronunciation is graded only via intelligibility. Claude calls go through `claude -p` with no API key per DECISIONS.md and must degrade gracefully: when unavailable, queue the item and score A-only items immediately.

### 11.3 Level progression (adaptive difficulty)
- Estimate a CEFR-aligned ability per skill with a simple **Elo/IRT-like** rating per item band: raise text difficulty (lexical coverage 98% -> 95% -> 92% known words, longer audio, faster speech, harder tasks) when rolling accuracy over the last 20 items is above 85%; lower when below 60%. [design judgment]
- Gate B2 -> C1 exam content on a specific checklist (descriptor bullets from CEFR 2020) rather than a single score.
- Productive vocabulary and accuracy get dedicated progress bars, since fluency often outruns accuracy at this level.

## 12. Open questions and what to verify first

1. Fetch and read swift-fsrs source: Swift version, `Sendable`, platforms, fuzz, and whether `Card` is Codable (for persistence). [Priority 1]
2. Confirm FSRS-6 stability/difficulty formulas on the awesome-fsrs wiki or fsrs-rs source (the fetched summary omitted them).
3. Confirm Li (2010) recast vs prompt effect sizes and explicit vs implicit; Kang & Han 2015 effect size; shadowing meta-analyses; HVPT effect sizes.
4. Verify the TOEFL iBT 2026 format changes and score-to-CEFR mapping on ets.org; verify IELTS band-to-CEFR on cambridgeenglish.org/britishcouncil.
5. Find Spanish-specific -ed ending evidence and Spanish-L1 article/preposition error studies.
6. Check Apple Speech framework: on-device availability for en-US in macOS 26, confidence values, word timing (needed for WPM/pause metrics).
7. Simulate FSRS load (new/day vs retention vs reviews/day) before fixing defaults.
8. Self-rating honesty: A/B whether typed-recall grading beats self-rating for the learner's retention (log both for the first month).

## 13. Sources

Verified this session:
- swift-fsrs: https://github.com/open-spaced-repetition/swift-fsrs
- FSRS algorithm wiki (FSRS-6 curve, default weights, same-day): https://github.com/open-spaced-repetition/awesome-fsrs/wiki/The-Algorithm
- SRS benchmark: https://github.com/open-spaced-repetition/srs-benchmark
- FSRS-7 Haskell port (existence): https://hackage-content.haskell.org/package/haskell-fsrs
- Lyster & Saito 2010: https://escholarship.mcgill.ca/downloads/6w924g64b
- Nation, vocabulary and CEFR: https://wgtn.ac.nz/lals/resources/paul-nations-resources/vocabulary-lists/vocabulary-cefr-and-word-family-size/vocabulary-and-the-cefr-docx
- Milton & Alexiou: https://www.enl.auth.gr/gala/14th/Papers/English%20papers/Milton&Alexiou.pdf
- 4/3/2 overview: https://learnlab.org/research/wiki/index.php/Fostering_fluency_in_second_language_learning
- Kang & Han 2015: https://scinapse.io/papers/2005247852
- Spanish-speaker pronunciation (weak sources): https://pronunciationstudio.com/spanish-speakers-english-pronunciation-errors/ , https://pronounce.tv/blog/common-spanish-speaker-pronunciation-mistakes
- Testing-effect reviews: https://journals.sagepub.com/doi/10.3102/0034654316689306

Cited from memory (not re-verified): Krashen 1982/1985; Swain 1985; Long 1996; Schmidt 1990; DeKeyser 2007; Karpicke & Roediger 2008; Cepeda et al. 2008; Rowland 2014; Bjork & Bjork; Lyster & Ranta 1997; Li 2010; Truscott 1996; Nation 1989, 2007; De Jong & Perfetti 2011; Logan et al. 1991; Thomson & Derwing 2015; Derwing & Munro; Hu & Nation 2000; Schmitt, Jiang & Grabe 2011; Norris & Ortega 2000.

## Verification

Fact-check pass, 2026-10-22. Ten load-bearing claims checked against web sources.

| # | Claim | Verdict | Source |
|---|---|---|---|
| 1 | swift-fsrs implements FSRS-6.0, MIT, no release tags, v6 API `FSRS(parameters: .init(w: FSRSDefaults.defaultWv6))` | Confirmed. Swift version / platform minimums still not stated in README ([unverified], spike needed) | https://github.com/open-spaced-repetition/swift-fsrs |
| 2 | FSRS-6 curve `(1 + factor*t/S)^(-w20)`, `factor = 0.9^(-1/w20) - 1`, 21 params, default weights list, w20 = 0.1542 | Confirmed (weights list matches exactly) | https://github.com/open-spaced-repetition/awesome-fsrs/wiki/The-Algorithm |
| 3 | Same-day stability `S*e^(w17*(G-3+w18))*S^(-w19)` | Confirmed (new in FSRS-6) | same wiki |
| 4 | FSRS needs 20-30% fewer reviews than SM-2 | Unverifiable at primary level. Secondary sources range 15-40%. Reworded and marked [unverified] | https://help.remnote.com/en/articles/9124137-the-fsrs-spaced-repetition-algorithm |
| 5 | Cepeda 2008 optimal gap = 10-20% of retention interval | Corrected. Paper reports ~20-40% of a 1-week delay down to ~5-10% of a 1-year delay; N > 1,350; Psych Sci 19(11):1095-1102 | https://pubmed.ncbi.nlm.nih.gov/19076480/ |
| 6 | Karpicke & Roediger 2008, Science 319:966-968, retrieval beats restudy | Confirmed, with caveat added (N=40; later within-subjects work shows restudy also helps) | https://pubmed.ncbi.nlm.nih.gov/18276894/ |
| 7 | Lyster & Saito 2010 SSLA 32:265-302, 15 studies, N=827, prompts > recasts, durable effects | Confirmed (N and k in abstract; effect-size labels medium/large via Lyster & Ranta commentary; age moderator only via secondary summary) | https://www.cambridge.org/core/product/4999EE1C8379B2BF026B148EAF373CA1 |
| 8 | Kang & Han 2015 MLJ 99:1-18, 21 primary studies | Confirmed citation and k. Effect size (g about 0.6) remains [unverified] | https://scinapse.io/papers/2005247852 |
| 9 | TOEFL iBT revised Jan 2026: adaptive format, 1-6 scale | Confirmed (was [unverified]). Multistage adaptive Reading/Listening, new task types, 1-6 CEFR-aligned scale, 0-120 shown for 2 years. Exact day and task names [unverified] | https://toeflaccess.ets.org/help/en/articles/11758550-toefl-ibt-updates-coming-january-2026 |
| 10 | Nation: ~4,000 families B2, 5,000-6,000 C1 | Corrected. The 4,000 for B2 includes 1,000-2,000 technical words; C2 = 7,000-9,000. Original said "word families" only | https://wgtn.ac.nz/lals/resources/paul-nations-resources/vocabulary-lists/vocabulary-cefr-and-word-family-size/vocabulary-and-the-cefr-docx |
| 11 | IELTS B2 = 5.5-6.5, C1 = 7.0-8.0 | Corrected. Official body says mapping is approximate; sources disagree (8.0+ sometimes C2) | https://www.ielts.org/about-ielts/ielts-in-cefr-scale |
| 12 | "Apple Speech framework on-device" for STT metrics | Corrected. macOS 26 API is `SpeechAnalyzer`/`SpeechTranscriber`; word timing via `.audioTimeRange`, reported inconsistent in some forum threads; [unverified] until spiked | https://developer.apple.com/videos/play/wwdc2025/277/ |

Not re-checked: the benchmark figures in 4.2 (727M reviews / ~10k users, log loss values). A secondary source quotes ~350M filtered reviews for the benchmark and 727M for default-parameter training, so the two numbers may describe different datasets; re-read the srs-benchmark README before quoting.

## Gaps found in verification

- **swift-fsrs has no release tags and no stated platform/Swift requirements.** Pin a commit hash, vendor a copy (it is small), and check Swift 6 `Sendable` before M1 depends on it. Keep the `Scheduler` protocol wrapper.
- **TOEFL is now adaptive and CEFR-banded (1-6).** The Saturday mini-exam and level-progression logic should use a 1-6/CEFR band output, not the old 0-120 scale, and should not claim to replicate the real test.
- **Speaking metrics depend on SpeechTranscriber word timing, which is not proven reliable.** The 4/3/2 WPM/pause metrics (E14, E15, E20) need an early spike on real recordings, with a fallback of computing WPM from total duration and word count.
- **Retrieval-practice evidence is weaker than the report implied.** Karpicke & Roediger had N=40 and a design later challenged; keep the design on "retrieval plus spacing plus feedback", and do not forbid restudy after feedback.
- **Missing: the Spanish-L1 -ed ending and pronunciation-scoring claims are still uncited**, and the LLM-as-essay-grader reliability claim (Section 11.2) has no source. Before Claude scores exams that gate progression, validate against the learner's own human-rated samples.
