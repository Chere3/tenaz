# 04. English exams, CEFR, scoring and the Tenaz exam system

Researched 2026-10-22. Primary sources were fetched and read where possible (ETS blueprint and ETS April 2026 score-scale report, extracted from PDF). Anything from background knowledge, a single third-party blog, or a page I could not open is tagged **[unverified]**. Pages that returned 403 or parse errors: ets.org content page, oxfordlearnersdictionaries.com, rm.coe.int CEFR CV PDF. So exact CEFR CV wording is paraphrased and must be re-checked before it is shown to the user as "official".

---

## 0. TL;DR design decisions

1. **Use the new TOEFL 1-6 band scale (0.5 steps) as Tenaz's single public score scale.** ETS built it to be CEFR-aligned with identical thresholds for all four skills and the overall score, so it doubles as a CEFR meter (4 = B2, 5 = C1, 3 = B1). Keep an internal continuous ability estimate (theta) per skill and map to bands for display.
2. **Model the monthly mock on the real 2026 TOEFL iBT blueprint** (Reading, Listening, Writing, Speaking, about 85 min, two-stage adaptive R/L). It is the only major exam whose official blueprint is public, current, CEFR-tagged per task, and cheap to imitate with an LLM item generator.
3. **Aptis is a candidate exam family** (British Council, CEFR-reported, B1-C2 "Advanced" variant). Tenaz does not need to imitate Aptis, but its **Grammar and Vocabulary component** is worth borrowing because TOEFL 2026 has no explicit grammar/vocab section.
4. **Objective items are scored locally and deterministically** (Swift, no network). **Writing and speaking are graded by `claude -p`** with a CEFR-anchored analytic rubric, per-criterion scoring, a fixed anchor set for calibration, and reported as a band range, not a false-precision point.
5. **LLM graders are good but not trustworthy as sole authority.** Literature says agreement with humans is "moderate to good" (QWK mostly 0.30-0.80) and varies widely. Mitigations: per-criterion prompts, calibration examples, median of N runs, monthly anchor re-grading, and never letting one Claude grade alone cause a demotion.
6. **Level estimation is Bayesian per skill (1PL/Rasch on a grid, EAP).** Item difficulty is seeded from the CEFR tag of the item (word-list level + text readability), then nudged by the learner's own responses. Promotion needs evidence on two separate exams, not one lucky score.
7. **Anti-cheat is detection plus consequence, not prevention.** On a Mac you cannot prevent a second device. Exam mode records the frontmost-app timeline and paste/typing anomalies, uses read-only Tivra data as a second witness, and marks the exam **"unverified"** (excluded from promotion, XP and streak rewards) if anomalies appear. It never locks the learner in, and it pauses automatically for meetings (DECISIONS.md rule 2).
8. **Realistic target.** the learner is B1+ now (TOEFL band about 3.5-4, IELTS about 5.5-6.0 per the tables below). Work-meeting competence is a B2 (4-4.5) target within months and C1 (5) is a longer-term goal. Do not promise C1 on a fixed date. [Judgment, not sourced.]

---

## 1. The exams, as of October 2026

### 1.1 TOEFL iBT (changed 21 January 2026)

**Primary source:** ETS "TOEFL iBT Test: 2026 Update Test Blueprint and Specifications Document" (https://www.ets.org/content/dam/ets-india/pdfs/toefl/toefl-ibt-test-specifications-2026.pdf). Note ETS's own caveat in that file: specs are "subject to minor revisions" until launch. Treat counts as approximate. ETS's help article confirms Reading and Listening became multistage adaptive and the 1-6 scale started January 2026: https://toeflaccess.ets.org/help/en/articles/11758550-toefl-ibt-updates-coming-january-2026

| Section | Task types (items) | Scored by | Est. time |
|---|---|---|---|
| **Reading** (50 items incl. unscored pretest items) | Complete the Words (30 items, a paragraph with partial words; CEFR B1-C1+), Read in Daily Life (5-15, A1-C1), Read an Academic Passage (5-15, B1-C2) | machine | 18-21 min (router 9 min + lower/upper module) |
| **Listening** (47 items) | Listen and Choose a Response (15-19, A1-B2), Listen to a Conversation (10, A2-C1), Listen to an Announcement (6-10, A2-C1), Listen to an Academic Talk (8-16, A2-C2) | machine | 18 min router + 7 min (lower) or 11 min (upper) = 25-29 min. [Corrected: blueprint lists "18 min" in the Router column and 7/11 under Lower/Upper; the section sums then reconcile with the stated 1 h 23 to 1 h 29 total, about 8-9 min being instructions/transitions.] |
| **Writing** (12 items) | Build a Sentence (10 items, 1 point each, machine-scored, A1-C2), Write an Email (1 item, 0-5, B1-C2), Write for an Academic Discussion (1 item, 0-5, B1-C2) | machine + AI | 23 min |
| **Speaking** (11 items) | Listen and Repeat (7 items, 0-5 each), Take an Interview (4 items, 0-5 each) | AI | 8 min |
| **Total** | 120 items (108 machine-scored, 12 AI-scored) | | **1 h 23 min to 1 h 29 min** |

Details worth copying into Tenaz:
- Reading and Listening are **two-stage adaptive**: a router module, then a lower or upper module. Writing and Speaking are linear.
- Reading stimuli: easy texts are 15-50 words; hard texts up to about 200 words; text complexity is calibrated with ETS TextEvaluator (about grade 10-11 medium, 11-12+ high) or Flesch-Kincaid 7.4-10.5 (medium) and 10.5-20 (high). Listening audio goes from utterances of 6 stressed syllables to monologues up to 250 words.
- Speaking timings are not in the blueprint. A third-party guide (goarno.io, **[unverified]**) says Listen and Repeat gets 8/10/12 s per sentence and Take an Interview answers 45 s each with no prep time: https://goarno.io/blog/toefl-speaking-practice-questions-with-answers-toefl-new-format/
- Third-party sources vary on task names and timings (prep-company blogs); I used only the ETS blueprint for the table above.

**Scoring and concordance** (ETS April 2026 report by Papageorgiou, Li, Gu, Barton, "A banded score scale for the TOEFL iBT test", https://www.mx.ets.org/content/dam/ets-org/pdfs/toefl/score-scale-update-2026.pdf):
- Section and overall scores are 1-6 in 0.5 steps. **Overall = the rounded average of the four section scores.**
- The same number means the same CEFR level in every section: **1-1.5 = A1, 2-2.5 = A2, 3-3.5 = B1, 4-4.5 = B2, 5-5.5 = C1, 6 = C2.**
- For two years ETS also reports a comparable 0-120 total.

**Table A. TOEFL 1-6 to the legacy scale and CEFR (ETS Table 6 and 7)**

| Band | Reading 0-30 | Listening 0-30 | Writing 0-30 | Speaking 0-30 | Total 0-120 | CEFR |
|---|---|---|---|---|---|---|
| 6 | 29-30 | 28-30 | 29-30 | 28-30 | 114+ | C2 |
| 5.5 | 27-28 | 26-27 | 27-28 | 27 | 107+ | C1 |
| 5 | 24-26 | 22-25 | 24-26 | 25-26 | 95+ | C1 |
| 4.5 | 22-23 | 20-21 | 21-23 | 23-24 | 86+ | B2 |
| 4 | 18-21 | 17-19 | 17-20 | 20-22 | 72+ | B2 |
| 3.5 | 12-17 | 13-16 | 15-16 | 18-19 | 58+ | B1 |
| 3 | 6-11 | 9-12 | 13-14 | 16-17 | 44+ | B1 |
| 2.5 | 4-5 | 6-8 | 11-12 | 13-15 | 34+ | A2 |
| 2 | 3 | 4-5 | 7-10 | 10-12 | 24+ | A2 |

**Table B. IELTS Academic to TOEFL 1-6 (ETS Table B1; totals are rounded UP to the next half band to avoid false positives)**

| IELTS | TOEFL R | L | W | S | Overall |
|---|---|---|---|---|---|
| 9 | 6 | 6 | 6 | 6 | 6 |
| 8 | 5.5 | 5.5 | 6 | 6 | 6 |
| 7.5 | 5 | 5 | 5.5 | 5 | 5.5 |
| 7 | 4.5 | 5 | 5 | 4.5 | 5 |
| 6.5 | 4 | 4.5 | 4.5 | 4 | 4.5 |
| 6 | 3.5 | 3.5 | 4 | 3.5 | 4 |
| 5.5 | 3.5 | 3 | 3 | 3 | 3.5 |
| 5 | 3 | 2.5 | 2 | 2.5 | 2.5 |

Caveat from the same report: CEFR level agreed for 8 of 11 IELTS half bands; for IELTS 5.5 the claimed CEFR (B2) is B1 by TOEFL. IELTS-CEFR claims are generous. An assumed starting level of "IELTS about 5.5" therefore corresponds to TOEFL overall about 3.5 (B1). That matches the B1+ starting label.

One of the search results (Cialfo blog) gave different 0-120 band cutoffs than ETS (6 = 114-120, 5.5 = 110-113). ETS's own table (above) wins.

### 1.2 TOEFL Essentials
Roughly 90-minute at-home adaptive test; sources conflict on the scale (1-12 vs 1-6 bands) and I found no ETS page confirming current status or CEFR mapping. **[unverified, low priority]**. Not used as a template. Source of conflict: https://prep.yocket.com/toefl/toefl-essentials-test

### 1.3 IELTS Academic / General
- Academic: Listening 30 min (+10 transfer on paper), Reading 60 min (40 questions), Writing 60 min (Task 1 graph/chart description, Task 2 essay), Speaking 11-14 min; total about 2 h 45. Source is a British Council page plus prep blogs: https://britishcouncil.org.tr/en/exam/ielts/format
- Writing and Speaking are marked on four equally weighted criteria (task response/achievement, coherence and cohesion, lexical resource, grammatical range and accuracy; Speaking swaps the first for fluency and coherence plus pronunciation). Names of the four criteria are from background knowledge **[unverified here]**. Listening and Reading are raw score out of 40 converted to bands.
- Reports of 2026 changes (one-skill retake, paper phase-out) are from a single blog **[unverified]**.
- General Training differs in Writing Task 1 (letter) and Reading texts; not needed for Tenaz.
- New ETS/IELTS concordance (Ikeda et al. 2025, IELTS Partnership Research Papers 1/25) exists; ETS used it for Table B. I did not open the original.

### 1.4 Cambridge B2 First (FCE) and C1 Advanced (CAE)
- Official pages: https://www.cambridgeenglish.org/exams-and-tests/qualifications/first/format/ and https://www.cambridgeenglish.org/exams-and-tests/qualifications/advanced/format/
- B2 First Reading and Use of English: 1 h 15. C1 Advanced Reading and Use of English: 1 h 30, 8 parts, 56 questions (official page).
- Four papers each (Reading/UoE, Writing, Listening, Speaking); the `Use of English` parts (multiple-choice cloze, open cloze, word formation, key word transformation) are the most "gradable locally" item types in any exam and fit the learner's known weak area (grammar accuracy). **Paper counts and the key word transformation detail are background knowledge [unverified here].**
- Cambridge English Scale: B1 140-159, B2 160-179, C1 180-199, C2 200-210+ (from Linguaskill/Greenwich page, below).

### 1.5 Linguaskill (Cambridge)
- Adaptive Reading and Listening, plus Writing and Speaking modules; CEFR-reported. Sources conflict: older EF pages say scale 82-180; Wikipedia and a Greenwich College page say the revised scale is 140-210 with B1 140-159, B2 160-179, C1 180-199, C2 200-210. Timings (EF, possibly outdated): R/L 60-85 min adaptive, Writing 45 min, Speaking 15 min / 5 tasks. https://en.wikipedia.org/wiki/Linguaskill https://www.ef.com/wwen/english-tests/cambridge-exams/linguaskill/ **[unverified; no Cambridge primary source opened]**

### 1.6 Duolingo English Test (DET)
- About 1 h total: 5 min intro, 45 min adaptive graded section, 10 min ungraded writing/speaking sample; scores 10-160; subscores Literacy, Comprehension, Conversation, Production; item count not fixed (adaptive stops when confident). Wikipedia plus Duolingo's 2026 teacher guide: https://englishtest-static.duolingo.com/media/resources/DET_Scoring%20Guide%20for%20Teachers%20(2026).pdf
- Relevant design lesson: **variable-length adaptive test that stops on confidence**. Tenaz can copy this for the daily quiz (stop when posterior SD of theta < threshold).
- A third-party table (10-55 beginner, 60-85 intermediate, 90-115 upper-intermediate, 120-160 advanced) is approximate only. Official CEFR table not extracted **[unverified]**.

### 1.7 Pearson PTE Academic
- 10-90 scale. Pearson's CEFR chart (overlapping ranges): A2 about 30-42, B1 36-58, B2 50-75, C1 59-82, C2 76-90. Minimum PTE per IELTS band (Pearson page): 6.0 = 47, 6.5 = 55 (my reading of the snippet; one search summary said 58, so **[unverified exact]**). https://www.pearsonpte.com/pte-academic/scoring/ Format (about 2 h, heavily AI-scored, integrated skills) is background knowledge **[unverified here]**.
- Not a template: integrated tasks like "Repeat Sentence" overlap with TOEFL Listen and Repeat, which Tenaz already includes.

### 1.8 Aptis (British Council)
- **Fit: Aptis** is a CEFR-reported, computer-delivered exam for adults and workplace. Alternatives are IELTS and TOEFL iBT. **Open question: which family to calibrate against.**
- Two variants. **Advanced**: B1-C2, designed to separate C1 and C2. **General**: A1-B2 (with C awarded above B2). Components (Advanced): Grammar and Vocabulary 25 min / 50 items (0-50), Speaking 10 min, Writing 45 min, Listening 30 min (about 28 items), Reading 60 min (4 tasks). Each skill 0-50 mapped to CEFR. https://www.britishcouncil.es/en/exam/aptis/advanced and https://www.britishcouncil.es/en/exam/aptis/general
- **Borrow:** the separate Grammar and Vocabulary component, and per-skill CEFR reporting. The learner's biggest known errors (verb patterns, prepositions, agreement) are grammar-and-vocabulary items.

---

## 2. CEFR Companion Volume (2020): what to use

Official: Council of Europe, CEFR Companion Volume (2020), https://rm.coe.int/common-european-framework-of-reference-for-languages-learning-teaching/16809ea0d4 (could not fetch; 403). Descriptors below are **paraphrased from memory plus the ETS blueprint's own B1-C1 summaries** and must be verified against the CoE PDF before quoting verbatim. They are for rubric anchoring, not for display as official text.

Structure the CV adds that Tenaz should exploit:
- Productive and interactive modes plus **mediation** (new): mediating a text, mediating concepts, mediating communication. For the learner's job (English meetings) the practical mediation skills are "relaying specific information in speech", "processing text in speech" (summarize an article aloud), and "facilitating collaborative interaction" (running a discussion). Source for the three groups: https://www.ecml.at/ECML-Programme/Programme2020-2023/Mediationinteachingandassessment/MediationintheCEFR
- Also in the CV: online interaction, phonology (the CV replaced the old "native-like" idea with intelligibility), and plurilingual scales.

Rubric anchors (paraphrase; B1 / B2 / C1):

| Dimension | B1 | B2 | C1 |
|---|---|---|---|
| Spoken production | connected description of experience, opinions with simple reasons | clear detailed description, develops a point of view with supporting detail | clear, well-structured, extended; rounds off with a conclusion |
| Spoken interaction | can start, maintain, close simple conversations; pauses for planning/repair are noticeable | spontaneous, fluent enough for regular interaction with native speakers without strain | fluent, almost effortless; flexible use of language, hesitation rare |
| Writing | connected text on familiar topics; short essays/reports | clear detailed text; argues for and against; letters/emails with emphasis on significance | well-structured, clear, detailed text; appropriate style; expands and supports points |
| Range/vocabulary | enough to describe unpredictable situations; circumlocution on less familiar topics | broad range, some circumlocution, avoids repetition | broad lexical repertoire, good command of idioms and colloquialisms |
| Accuracy | reasonably accurate in familiar contexts; errors still occur | good grammatical control; occasional slips, no errors that cause misunderstanding | consistent grammatical control of complex language |
| Coherence/cohesion | links short discrete elements into a linear sequence ("and, then, because") | uses a limited number of cohesive devices to link utterances into clear discourse; some "jumpiness" | controlled use of organizational patterns, connectors and cohesive devices |

This table is the backbone of the Claude grading rubric (section 5.2). A typical target profile (range B2-, fluency B2-, accuracy B1, coherence B1) lines up with this: the bottleneck is coherence/cohesion and accuracy, not range.

---

## 3. Automated scoring: what to learn from e-rater, SpeechRater and LLMs

### 3.1 ETS e-rater (writing)
- Feature families per ETS: vocabulary-based content analysis, lexical complexity and diction, **proportion of grammar, usage, mechanics errors** (error count divided by word count), proportion of style comments, **organization and development** (discourse labels such as thesis, main ideas, support, conclusion), and a reward for idiomatic phrasing. About 50+ features overall (older reports). https://www.ets.org/erater/how.html (page title seen in search; detail from the IAEA paper https://www.ets.org:443/content/dam/ets-org/pdfs/e-rater/automated-essay-writing-e-rater-iaea-paper.pdf). Exact current feature list: **[unverified]**.
- **Take-away for Tenaz:** compute simple deterministic surface features locally (word count, type-token ratio, mean sentence length, subordination ratio, connector inventory, repeated-word rate, grammar-error rate from LanguageTool-style rules if added later) and pass them to Claude as context. Use them for sanity gates (too short = auto "off topic/insufficient"), not as the score.

### 3.2 SpeechRater (speaking)
- SpeechRater 5.0 feature classes: pronunciation, prosody, vocabulary, grammar, content, discourse, plus filters for unscorable responses. Scoring TOEFL Practice Online since 2006. https://www.ets.org/research/policy_research_reports/publications/report/2018/jyzm.html and https://www.ets.org/speechrater
- TOEFL Junior report: human-machine r = .81 vs human-human .89 for speaking. https://www.ets.org/research/policy_research_reports/publications/report/2015/jufc.html
- **Take-away:** fluency measures are cheap and objective given word-level timestamps from on-device ASR: speaking rate (words per minute), articulation rate, pause count and mean pause length, mean length of run, filler rate (The learner's "like" every 6-8 words), restart/repetition rate, type-token ratio. Pronunciation cannot be judged by a text-only Claude call. Use ASR word confidence as a weak intelligibility proxy and say so honestly in the UI.

### 3.3 LLMs as raters (recent evidence)
- Meta-analysis of 65 studies (2022-2025): LLM-human agreement "generally moderate to good", QWK values mostly 0.30-0.80 up to 0.91, no pooled estimate computed because indices differ; findings "mixed and inconclusive". https://arxiv.org/abs/2512.14561 (I read the PDF text locally; 65 studies, QWK coded for 38, "moderate to good" per Altman/Landis-Koch bands, max 0.91 Xu et al. 2025; the arXiv abstract alone gives no QWK numbers).
- Yancey, Laflair, Verardi, Burstein (Duolingo), "Rating Short L2 Essays on the CEFR Scale with GPT-4" (BEA 2023): GPT-4 **with calibration examples** performs almost as well as modern automated writing evaluation; agreement varies with the test-taker's first language. https://aclanthology.org/2023.bea-1.49
- arXiv 2502.11368 (2025), nine-criterion analytic scoring of L2 graduate writing: human-human agreement > human-LLM; LLM-LLM agreement highest (models agree with each other more than with people); scoring each criterion separately improved human-LLM agreement vs all at once; LLM scores usually within 1 point of humans. https://arxiv.org/pdf/2502.11368
- Rubric refinement (arXiv 2510.09030): iteratively revising the rubric against human scores raised QWK by up to 0.19 (TOEFL11) and 0.47 (ASAP) with GPT-4.1/Gemini-2.5-Pro/Qwen-3. https://arxiv.org/abs/2510.09030v1
- LCES pairwise comparison (arXiv 2505.08498): zero-shot pairwise ranking with LLMs works on ASAP/TOEFL11 using IELTS band descriptors as the rubric. https://arxiv.org/pdf/2505.08498
- Leniency/severity bias of LLM raters: I did not find a direct source. **[unverified]**; assume possible and test locally (section 5.3).
- **Implication:** a single Claude call is not a calibrated rater. Use (a) per-criterion calls, (b) 2-3 anchor essays in the prompt, (c) median of 3 runs for the monthly mock, (d) a fixed local "anchor set" to detect drift, (e) pairwise comparison against the learner's previous essay for the *progress* signal (relative judgments are more reliable than absolute ones).

---

## 4. Adaptive testing and a simple implementable item-difficulty model

### 4.1 Basics (background knowledge, standard psychometrics **[unverified here, textbook]**)
- **IRT 1PL (Rasch):** P(correct) = 1 / (1 + exp(-(theta - b))). One difficulty parameter b per item, ability theta per person, same scale (logits). Fewer parameters = workable with tiny data (one user).
- **2PL:** adds discrimination a: P = 1 / (1 + exp(-a(theta - b))). **3PL:** adds guessing c (multiple choice, e.g., c = 0.25 for 4 options).
- **CAT:** pick the next item that maximizes Fisher information at the current theta (for 1PL, the item with b closest to theta), update theta, stop on fixed length or posterior SD threshold (DET does variable-length, section 1.6).
- **Multistage test (MST):** fixed router module, then route up or down. The TOEFL 2026 design (section 1.1). **Simpler and more robust than item-level CAT for a single-user app**, since modules can be authored, reviewed and cached in advance.
- ETS built the 1-6 to CEFR mapping by placing field-test item parameters on the legacy scale via IRT (the report's Tables 3-5 list theta values per CEFR level for Reading and Listening). So the "theta to band" mapping idea is legitimate.

### 4.2 Tenaz item difficulty model (implementable)

Represent every objective item with `cefrTarget` (A1 to C2) and numeric difficulty `b`.

Prior: map CEFR to logit: A1 -2.5, A2 -1.5, B1 -0.5, B2 +0.5, C1 +1.5, C2 +2.5 (spacing 1 logit; arbitrary but monotone). Adjust by features:
- vocabulary: +0.3 per 1000-word band above 2k for the rarest content word, capped; word-list level (NGSL band, CEFR-J level, Oxford tag if used) sets the floor
- text: Flesch-Kincaid grade or sentence length, +0.1 per grade above 7 (cf. ETS Reading ranges: FK 7.4-10.5 medium, above 10.5 high)
- audio: speaking rate and speakers count
- item format: guessing floor c = 1/options; cloze typing (Complete the Words) has c about 0
- Claude's own CEFR label of the item at generation time (validated by a second Claude call "what CEFR level is this item?" and discarded if the two disagree by more than one level)

Posterior update (per skill), done on a theta grid of 81 points from -4 to 4 with a prior N(mu0, 1) (mu0 = -0.3, i.e., B1+ from the placement estimate):

```
posterior[t] *= P(response | theta_t, b, c)    // for each answered scored item
theta_hat = sum(theta_t * posterior[t]); sd = sqrt(var)
```

Item difficulty drift: with one user, items cannot be calibrated on a population. Instead keep `b_item = b_prior + delta`, where delta is updated only via a regularized average residual across *repeat exposures of the same item type/skill tag* (not the single item), to avoid fitting noise. Otherwise leave b fixed. Document this as a known approximation. **Anchor items:** a fixed bank of about 60 hand-checked items (10 per CEFR level, spanning skills) used every month to keep the scale stable even as the generator changes.

Band mapping: theta to band by thresholds on the same logit scale (A2/B1 boundary -1.0, B1/B2 0.0, B2/C1 +1.0, C1/C2 +2.0; half-bands interpolated). These are *Tenaz* thresholds, not ETS's; clearly label the result "Tenaz band, TOEFL-style" and show the 1-6 number with a +/- range. Re-anchor when the monthly mock is also graded against a real practice test (see 6.4).

### 4.3 Grading objective items locally
- Multiple choice, multi-select, cloze: exact match / set match.
- Complete the Words: case-insensitive exact on the missing letters, with partial credit disabled (TOEFL gives 1 point per item).
- Build a Sentence: accept any ordering equal to a stored list of valid orders (precomputed at generation time with Claude then checked with a deterministic grammar template; store 1-3 accepted permutations).
- Listen and Repeat: local Word Error Rate (Levenshtein on words) between ASR transcript and target, mapped to 0-5 (0% WER = 5, up to 10% = 4, 20% = 3, 35% = 2, 50% = 1, else 0). Thresholds are mine **[unverified, to calibrate]**.

---

## 5. Vocabulary size and word lists

### 5.1 Vocabulary Size Test (VST)
- Nation and Beglar (2007) VST: 14,000-word version has 140 multiple-choice items, 10 per 1,000-word family level, score x 100 = size estimate; 20,000-word versions have 100 items (5 per level), score x 200. Intended for ordinary non-native learners to advanced; 14K best for advanced learners. Source: Victoria University of Wellington spec page https://www.wgtn.ac.nz/lals/resources/paul-nations-resources/vocabulary-tests/the-vocabulary-size-test/Vocabulary-Size-Test-information-and-specifications.pdf
- I did not verify a 2014 update (Coxhead/Nation/Sasao was suggested in the brief); the 20K versions are Coxhead, Nation and Sasao (2015). **[partially unverified]**
- **Do not copy the VST items** (copyright and usage terms not checked). Instead implement the *design*: sample N words per frequency band from the list, four-option "pick the right definition in a non-defining sentence" items, Claude-generated, validated, scored locally. Use a fast adaptive version: start at 3-4k band, go up/down by band.
- Practical: The learner's expected size is roughly 5-7k word families (B2- range) **[estimate, not measured]**. Run the test once at install for placement and every 3 months after.

### 5.2 Word lists and licenses

| List | Size / levels | License / terms | Use in Tenaz |
|---|---|---|---|
| **NGSL 1.2** (New General Service List) | 2,809 words; about 92% coverage of general English texts | **CC BY-SA 4.0**; extra permissions via charlie-browne.com. https://www.newgeneralservicelist.com/new-general-service-list | Frequency backbone for the vocab-size test and the A2-B2 core. ShareAlike: any *redistributed derivative word list* must also be CC BY-SA; the app's own code is unaffected if the list ships as a separate data file. Not CEFR-tagged. |
| **NAWL 1.2** (New Academic Word List) | academic supplement to NGSL; exact size **[unverified]** | same site, same license family **[verify]** | B2-C1 academic words |
| **CEFR-J Wordlist 1.6** | A1-B2: 7,801 POS-entries, about 6,868 unique headwords (A1 1,068; A2 1,352; B1 2,353; B2 2,692 headwords; by-POS items 1,166/1,411/2,445/2,779; level sums exceed 6,868 because a headword can sit at different levels per POS) | Tokyo University of Foreign Studies (Tono Lab); free for research, education **and commercial use if properly cited** (commercial work involving supervision/services: consult the lab first); derivatives allowed with citation. https://www.cefr-j.org/download.html | **Best fit for CEFR tagging of A1-B2.** Cite in app credits. |
| **Oxford 3000 / 5000** | 3000 = A1-B2; 5000 adds B2-C1 words (OLD descriptions; another OUP post says A1-C2, so check) | (c) Oxford University Press; I found no open license, and OUP has licensed the Oxford 2000 to commercial apps. Official page returned 403. **[unverified]** | Personal local use for tagging seems low risk, but do not bundle in anything distributed; prefer CEFR-J + NGSL. |
| **English Vocabulary Profile (EVP)** | Cambridge, CEFR-tagged by sense, A1-C2 | Proprietary web resource, no license opened **[unverified]** | Manual look-ups only. Do not scrape. |
| **AWL** (Coxhead 2000) | 570 families | free to use for teaching/research per its author **[unverified here]** | Superseded by NAWL for modern academic coverage. |
| **BSL** (Business Service List, Browne/Culligan/Phillips) | business words **[unverified]** | same site family as NGSL **[verify]** | Valuable: The learner's own work meetings. |

Recommendation: ship **CEFR-J (A1-B2) + NGSL/NAWL/BSL for frequency and C1 academic/business**, with one shared `WordEntry { lemma, pos, cefr, band, source }` table and a `LICENSES.md`.

---

## 6. Tenaz exam system specification

Design goals: (1) credible TOEFL/CEFR-like practice; (2) motivating for ADHD (short loops, fast feedback, visible bands); (3) honest about uncertainty; (4) respects DECISIONS.md.

### 6.1 Exam types

| Exam | Cadence | Length | Content | Graded by | Effect |
|---|---|---|---|---|---|
| **Daily Check** | daily, any time | 4-7 min, variable-length, 12-20 items, stops when SD(theta) < 0.35 or 20 items | mix of Complete the Words, Choose a Response (text), Build a Sentence, grammar/vocab cloze (Aptis/Cambridge UoE style), 1 listen-and-repeat | local | XP, streak, mascot mood; feeds theta (weight 0.5) |
| **Weekly Mock** | Sunday (or chosen day) | 35-40 min | router + one module of Reading, one of Listening, 2 Build-a-Sentence sets, 1 Write an Email (10 min), 4 Take an Interview Qs, a 30 s retell (mediation) | local + `claude -p` | achievement progress, theta update (weight 1.0), error deck feed |
| **Monthly Full Mock** | every 4 weeks, in "Exam Mode" | 85-90 min with blueprint structure: Reading 18-21, Listening 25-29 (router 18 + module 7 or 11), Writing 23, Speaking 8 + instructions | full 2026-style test as in table 1.1 plus a Tenaz addition: a 10 min Grammar and Vocabulary block (Aptis-inspired, 50 items, optional to keep length near 100 min if the learner prefers) | local + `claude -p` (3 runs median for AI-scored items) | official "Tenaz band" estimate, promotion eligibility, level-up animation |
| **Placement** (first run only) | once | about 45 min | adaptive vocab-size test, mini-reading, mini-listening, one dictated 2-3 min monologue | local + `claude -p` | initial theta; replaced by monthly mock afterwards |

Rule: **the Monthly Full Mock is the only exam that can move the public band.** Daily and weekly only move the private theta posterior and a *trend arrow*.

### 6.2 Item types (mapped to real exams)

| Tenaz item | Modeled on | Scoring |
|---|---|---|
| Complete the Words | TOEFL Reading | local, exact |
| Read in Daily Life / Academic Passage | TOEFL Reading | local MC |
| Choose a Response (audio) | TOEFL Listening | local MC; audio via AVSpeechSynthesizer or pre-generated TTS (realistic TTS is preferred) |
| Conversation / Announcement / Academic Talk | TOEFL Listening | local MC; transcripts hidden until review |
| Build a Sentence | TOEFL Writing | local, list of accepted orders |
| Grammar and Vocabulary (50 items, 25 min) | Aptis | local |
| Key-word transformation / word formation | Cambridge UoE | local (accepted answer list) |
| Write an Email | TOEFL Writing | Claude, 0-5 |
| Write for an Academic Discussion | TOEFL Writing | Claude, 0-5 |
| Listen and Repeat | TOEFL Speaking | local WER via ASR, 0-5 |
| Take an Interview (45 s) | TOEFL Speaking | ASR transcript + timing features, Claude, 0-5 |
| Retell / summarize aloud (mediation) | CEFR CV mediation (processing text in speech) | ASR + Claude, 0-5 |
| "My life" paragraph | The learner's own request (unlock writing) | Claude, light rubric, feeds Writing theta at low weight |

### 6.3 Pipelines

**Item generation (offline-first, cached).** `claude -p` generates item JSON in batches overnight with a strict schema (type, cefrTarget, stimulus, options, key, accepted answers, estimated word-list levels). Validators in Swift: schema check, one correct key, distractor length parity, banned-pattern checks, word-list coverage (stimulus words at or below target band except the tested words), second-call CEFR verification (discard if >1 level apart). Items are stored in SQLite; exams are assembled from the bank so an exam works with no network and with Claude down (DECISIONS rule 4). Env: remove `ANTHROPIC_API_KEY`, resolve `~/.local/bin/claude`.

**Objective scoring.** Swift, deterministic, unit-tested in `TenazCore`.

**Writing/Speaking grading via Claude CLI.** After the exam is submitted (never during), run one call per criterion:
- Input: task prompt, response text (or ASR transcript with timestamps and metrics), a rubric table (section 2 anchors condensed), 2 anchor responses per band at the candidate's bracket (B1, B2, C1) with their agreed scores, and the instruction to output JSON `{ "criterion": ..., "score": 0-5, "evidence_quotes": [...], "cefr": "B1|B2|..." }`.
- Criteria (writing): task fulfillment (answers the prompt, register), organization and cohesion, grammatical range and accuracy, lexical range and precision. (speaking): delivery/fluency (from local metrics plus transcript), language use, topic development; intelligibility is capped by ASR confidence and labeled "estimate".
- 0-5 matches the ETS per-item maximum (blueprint: Write an Email and Academic Discussion max 5; Listen and Repeat and Take an Interview max 5). I did not find the ETS rubric descriptors; the criteria above are my adaptation of CEFR CV anchors. **[ETS rubric text unverified]**
- Monthly mock: 3 runs, take the median per criterion; if range across runs > 1 point, re-run twice more and flag "low confidence".
- Convert: item score (0-5) to Tenaz item-level theta evidence via a fixed table (0-5 maps to CEFR-ish anchors A1..C2); or treat each AI-scored task as an ordinal partial-credit item (Rasch partial credit) **[advanced; v2]**.
- Output also includes a **feedback list** (max 5 items: the exact quote, the fix, the pattern name), which are written into the learner's error deck (verb patterns, prepositions, agreement, intensifier stacking).

### 6.4 Calibration and quality control for the LLM grader
1. **Anchor set:** 30 writing samples (10 each at roughly B1, B2, C1) and 20 transcribed speaking samples, with target scores set by the learner plus a careful manual pass (or taken from published rater-scored examples such as Cambridge/ETS sample responses, subject to their copyright; store locally only). Re-grade the anchor set monthly and after any CLI/model change. If mean absolute error vs the target > 0.5 points, show a "grader drift" warning and freeze promotion.
2. **Leniency check:** compare mean Claude score on the anchor set vs targets. Subtract a per-criterion offset if systematic (stored as `calibration.json`).
3. **Pairwise progress check:** monthly, ask Claude "which of these two answers to the same prompt is stronger and why" for the new vs previous month's response. Pairwise is more stable than absolute scores (LCES paper).
4. **Real-exam calibration:** once or twice a year, the learner takes an official ETS practice test (TOEFL Practice Online / free ETS sample) or Linguaskill/Aptis. Enter the official band in Tenaz; fit a global offset between Tenaz band and official band. Without this, the "Tenaz band" is a practice indicator, not an equivalent. Say so in the UI.
5. **Human audit:** show the learner the 3 most important rubric quotes with each score, so they can disagree; disagreement logs tune the rubric.

### 6.5 Level estimation and promotion rules

State per skill s in {reading, listening, writing, speaking, grammar-vocab}: posterior over theta (grid). Overall theta = weighted average with TOEFL-like equal weights across the four skills (overall = rounded average of section scores, per ETS).

- **Display:** band = mapping(theta_hat) rounded to 0.5; show uncertainty as "3.5 to 4.0".
- **Provisional level (private):** updated after every exam.
- **Public promotion (e.g., B1+ to B2, band crossing 3.5 to 4):**
  1. Overall posterior P(theta > threshold) >= 0.80 on the two most recent Monthly Mocks, **both verified** (integrity status clean).
  2. No skill more than one band below the target (Weaker accuracy/cohesion will hold the learner back and that is intended: *"balanced B2"*, not "B2 in speaking only").
  3. The anchor-set drift check is green.
  4. At least one Weekly Mock in the same window confirms (theta within 0.4).
- **Demotion:** none for the public band. A bad mock shows "plateau" and prescribes drills. Rationale: ADHD plus loss aversion; also cheap noise protection. A skill that falls 0.5+ below its last good level on two consecutive weekly mocks triggers a "rescue plan", not a status loss.
- **Level names:** public labels follow CEFR (B1+, B2, B2+, C1) matching TOEFL half-bands: 3.5 = B1 high, 4 = B2 low, 4.5 = B2 high, 5 = C1 low. This follows ETS: 4 and 4.5 are both B2.
- **Goals to show the learner:** next milestone: band 4.0 overall with no skill below 3.5. Work-meeting readiness: 4.5 overall, speaking >= 4. These are product judgments, not ETS claims.

### 6.6 Difficulty progression ("exams get harder over time")
- Content tilt: the monthly mock's target mix shifts up by 0.25 band each time the learner's public band rises; stimuli move from FK grade 7-9 toward 11+, listening speed from 140 to 170+ wpm **[my numbers]**, more idioms, more accents (TTS voices), shorter time per item.
- Writing prompts move from personal emails (B1) toward workplace emails with tone constraints (B2: persuade, decline politely, escalate) and academic-discussion posts with a counterargument requirement (B2+/C1).
- Add mediation tasks at B2+ (summarize a short text to a non-English-speaking colleague, run a discussion), because the learner's actual need is meetings at work. (Mediation scales: CEFR CV.)

---

## 7. Anti-cheat requirements for Tivra integration

Constraints from DECISIONS.md: Tivra is **read-only** from Tenaz. Overlays/gates are **off by default**, with escape hatches. Never block a work meeting. Data stays local. Learners may be tempted to cheat with AI. So the goal is **self-binding that is hard to bypass casually**, not a security system against a determined adversary.

### 7.1 What can be detected (macOS, non-sandboxed)
- **Frontmost app and window title timeline** via `NSWorkspace.didActivateApplicationNotification` and the Accessibility API (needs permission; Tenaz already observes the frontmost app per DECISIONS). Tivra's own data (extension-reported domains; note `:4242/events` is an extension-to-app ingest endpoint, not a read API, see 7.3) gives domains (e.g., chatgpt.com, claude.ai, gemini.google.com). Read from Tivra's local data or MCP read-only; treat as a second witness, never a dependency (the exam must still run and record its own timeline if Tivra is down).
- **Paste events:** monitor `NSPasteboard.general.changeCount` plus text-field diffs: any single insertion event > 30 characters that was not typed (compare character count with keystroke count). Flag "paste of N chars at t".
- **Typing dynamics:** characters per keystroke, inter-key interval distribution; sudden fluent perfect paragraphs after silence is a signal. Heuristic only **[unverified effectiveness]**.
- **Focus loss:** window not key for > X s; Mission Control/Spaces switches.
- **AI apps:** app allowlist/denylist (Claude desktop, ChatGPT app, Raycast AI, browsers on AI domains, Terminal running `claude`). Tenaz itself must not be calling Claude during an attempt.
- **Second display/phone:** cannot be detected. Mitigation: webcam is **not** used (privacy, and out of scope). Instead make AI help *less useful*: adaptive items drawn fresh, time limits tuned (TOEFL-like speed), and speaking tasks that require an immediate spoken answer.
- **Dictation:** macOS dictation into an LLM is covered by app/domain checks only.

### 7.2 Policy
1. **Exam Mode is explicit and opt-in per exam.** Before starting, a pre-commitment screen: "I will not use AI, translators, or notes." The commitment is the learner's own (consistent with "punishments are commitment devices the learner configures").
2. **Allowlist during exam:** Tenaz, Tivra (read-only agents), system UI. Everything else in the foreground > 5 s adds a **flag**; > 3 flags or any AI-domain/AI-app foreground > 3 s marks the exam **"unverified"**.
3. **Consequence of unverified:** score is recorded for personal review but **excluded from promotion, XP, streak, achievements**; the mascot gets "worried", not "dead". Optionally a configured penalty task (extra review cards). No lockouts.
4. **Not a lock:** there is always **Abort exam** (Esc held 3 s) and the global kill-switch hotkey from DECISIONS rule 2; aborting scores the attempt 0 for promotion purposes but never traps the learner. Max exam overlay time enforced.
5. **Meeting safety:** if Calendar shows a meeting now, or Zoom/Teams/Meet/Slack Huddle holds audio/camera, the exam refuses to start and an in-progress exam **pauses** (timer stops, not flagged) until the meeting app leaves the foreground. Exam Mode never blocks a work meeting (rule 2).
6. **Integrity log** is human-readable and local: timeline with timestamps, shown after the exam so the learner can contest a false positive ("I switched to Zoom for 4 s"), and false positives tune the thresholds.
7. **Data minimization:** window titles are stored only for flagged intervals, hashed or truncated for others; nothing leaves the Mac. Consistent with Tivra's "local-first, no telemetry".
8. **Post-exam AI grading is allowed** (it is the app, not the test taker).
9. **Honest messaging:** in the UI say "Tenaz can catch common AI shortcuts but it cannot prove you didn't use another device." This avoids a false guarantee.

### 7.3 Tivra integration contract (proposal only; implement in Tenaz, not in Tivra)
- Tenaz reads (read-only): current app/domain stream and recent blocks. **[Corrected]** `:4242/events` is NOT a read interface: per Tivra's `CLAUDE.md` it is the browser-extension to app *ingest* fallback (HMAC-signed POST, 401 on unsigned/stale/replayed; Native Messaging `com.tivra.host` is the production transport). Tenaz must not POST there. The actual read path (Tivra's local store or an MCP surface that is not documented) is not documented in Tivra's `CLAUDE.md` and **[unverified]**. **Any new endpoint (e.g., "exam mode in progress" signal) is a patch proposal in a separate worktree, never installed overnight (DECISIONS rule 3).**
- Optional (proposal): Tivra could temporarily raise its capture detail during exams. Not required for v1.

---

## 8. Data model sketch (for `TenazCore`)

```
Item(id, type, skill, cefrTarget, bPrior, bAdj, guess, stimulusRef, key, acceptedAnswers, tags, source, createdAt, verifiedLevel)
ExamTemplate(kind: daily|weekly|monthly|placement, blueprint: [ModuleSpec])
ExamAttempt(id, kind, startedAt, endedAt, integrity: clean|flagged|unverified, flags[], status)
Response(attemptId, itemId, answer, correct?, latencyMs, scoreRaw, scoreSource: local|claude)
GradeRun(responseId, criterion, score, evidence[], model, runIndex, rubricVersion, calibrationVersion)
SkillState(skill, grid[81] posterior, thetaHat, sd, updatedAt)
BandHistory(date, skill, band, rangeLow, rangeHigh, verifiedOnly)
```

Everything stored in SQLite (GRDB, as in Tivra) under Application Support; no network needed for scoring objective items.

---

## 9. Open questions to flag to the learner

1. Should Tenaz calibrate against **Aptis**? If yes, should the first official calibration test be Aptis Advanced (affordable? price about 135-140 euros in some countries per British Council pages, varies) or free ETS TOEFL practice?
2. Does the work need a certificate, or just meeting fluency? That decides whether to schedule a real exam.
3. Exam length tolerance: full mock 85-100 min once a month, acceptable?
4. Which "anti-cheat" strictness: flag-only, or flag plus penalty task?
5. Does the premise "meetings need C1" hold? Many workplace tasks are B2; C1 is useful for nuanced negotiation. Suggest B2 high (4.5) as the first milestone. [Judgment.]

## 10. Verification status

Verified from primary documents: TOEFL 2026 blueprint (task types, items, timings, 1-6 scale, CEFR mapping, 0-120 mapping, IELTS comparison); ETS April 2026 report; CEFR-J terms; NGSL license; VST design (Wellington spec page, via search summary); Cambridge C1 R&UoE timing (official snippet); Aptis components (British Council snippets).

Not verified or only via search summaries/blogs: Speaking and Writing timing details per task, Linguaskill current scale, DET CEFR table, PTE format, IELTS 2026 changes, Oxford and EVP licenses, NAWL/BSL sizes and licenses, exact CEFR CV descriptor wording, exact e-rater/SpeechRater feature lists, LLM leniency bias, the ETS 0-5 rubric descriptors.

## Sources
- ETS TOEFL iBT 2026 blueprint: https://www.ets.org/content/dam/ets-india/pdfs/toefl/toefl-ibt-test-specifications-2026.pdf
- ETS banded score scale report (Apr 2026): https://www.mx.ets.org/content/dam/ets-org/pdfs/toefl/score-scale-update-2026.pdf
- ETS help: https://toeflaccess.ets.org/help/en/articles/11758550-toefl-ibt-updates-coming-january-2026 and https://toeflaccess.ets.org/help/en/articles/11758616-toefl-ibt-score-scale-update-what-you-need-to-know
- Cambridge: https://www.cambridgeenglish.org/exams-and-tests/qualifications/first/format/ , https://www.cambridgeenglish.org/exams-and-tests/qualifications/advanced/format/
- British Council Aptis: https://www.britishcouncil.es/en/exam/aptis/advanced , https://www.britishcouncil.es/en/exam/aptis/general
- IELTS format: https://britishcouncil.org.tr/en/exam/ielts/format
- Duolingo: https://englishtest-static.duolingo.com/media/resources/DET_Scoring%20Guide%20for%20Teachers%20(2026).pdf
- Pearson PTE: https://www.pearsonpte.com/pte-academic/scoring/
- Linguaskill: https://en.wikipedia.org/wiki/Linguaskill
- VST: https://www.wgtn.ac.nz/lals/resources/paul-nations-resources/vocabulary-tests/the-vocabulary-size-test/Vocabulary-Size-Test-information-and-specifications.pdf
- NGSL: https://www.newgeneralservicelist.com/new-general-service-list
- CEFR-J: https://www.cefr-j.org/download.html
- e-rater: https://www.ets.org:443/content/dam/ets-org/pdfs/e-rater/automated-essay-writing-e-rater-iaea-paper.pdf ; SpeechRater: https://www.ets.org/research/policy_research_reports/publications/report/2018/jyzm.html
- LLM scoring: https://arxiv.org/abs/2512.14561 , https://aclanthology.org/2023.bea-1.49 , https://arxiv.org/pdf/2502.11368 , https://arxiv.org/abs/2510.09030v1 , https://arxiv.org/pdf/2505.08498
- CEFR mediation overview: https://www.ecml.at/ECML-Programme/Programme2020-2023/Mediationinteachingandassessment/MediationintheCEFR

## Verification

Second-pass fact-check, 2026-10-22. Primary PDFs were downloaded and text-extracted (pdftotext), not read through a summarizer.

| # | Claim | Verdict | Source |
|---|---|---|---|
| 1 | TOEFL 2026 structure: 120 items (108 machine, 12 AI), Reading 50 (30 Complete the Words + 20), Listening 47, Writing 12 (10 Build a Sentence + 2), Speaking 11 (7 + 4), two-stage adaptive R/L, linear W/S, max 5 points for AI-scored items | Confirmed | ETS blueprint https://www.ets.org/content/dam/ets-india/pdfs/toefl/toefl-ibt-test-specifications-2026.pdf |
| 2 | TOEFL timings: total 1 h 23 to 1 h 29; Listening "18 min" | Corrected. 18 min is the router; Lower/Upper add 7/11, so Listening is 25-29 min. Reading 18-21, Writing 23, Speaking 8 confirmed | same |
| 3 | 1-6 scale, same number = same CEFR in every section and overall (1-1.5 A1 ... 6 C2); overall = rounded average of sections | Confirmed (Table 7 and text) | ETS score-scale report https://www.mx.ets.org/content/dam/ets-org/pdfs/toefl/score-scale-update-2026.pdf |
| 4 | Table A (band to legacy 0-30 and 0-120) | Confirmed row by row for 6 down to 2 (Table 6) | same |
| 5 | Table B (IELTS to TOEFL 1-6) and "IELTS 5.5 claimed B2 is B1 by TOEFL"; 8 of 11 half bands agree | Confirmed (Table B1, B2). Overall column is rounded UP, which only applies to this comparison | same |
| 6 | NGSL 1.2: 2,809 words, 92%+ coverage, CC BY-SA 4.0 | Confirmed | https://www.newgeneralservicelist.com/new-general-service-list |
| 7 | CEFR-J Wordlist 1.6: 7,801 entries, 6,868 headwords, per-level counts, free incl. commercial with citation | Confirmed; added caveat that per-level figures are headwords and commercial service work should consult the lab | https://www.cefr-j.org/download.html |
| 8 | Cambridge C1 Advanced Reading and Use of English: 1 h 30, 8 parts, 56 questions; Use of English parts incl. key word transformation | Confirmed (upgrades a [unverified] note) | https://www.cambridgeenglish.org/exams-and-tests/qualifications/advanced/format/ |
| 9 | Aptis Advanced: Grammar and Vocabulary 25 min / 50 items, Speaking 10, Writing 45, Listening 30 (about 28 items), Reading 60 | Confirmed via British Council search results (a direct fetch of the page timed out; the 2023 overview PDF is the detailed source) | https://www.britishcouncil.org/sites/default/files/aptis_advanced_test_format_overview_2023.pdf |
| 10 | VST 14k: 140 items, 10 per 1,000 level, score x 100; 20k versions 100 items, x 200 | Confirmed | https://www.wgtn.ac.nz/lals/resources/paul-nations-resources/vocabulary-tests/the-vocabulary-size-test/Vocabulary-Size-Test-information-and-specifications.pdf |
| 11 | LLM-rater literature: 65-study review, QWK mostly 0.30-0.80, max 0.91; Yancey et al. BEA 2023 GPT-4 with calibration near AWE parity, varies by L1 | Confirmed | https://arxiv.org/abs/2512.14561 ; https://aclanthology.org/2023.bea-1.49 |
| 12 | Tivra integration: "events via POST :4242/events" as a second witness | Corrected. It is a signed extension-to-app ingest endpoint, not a read API. Read path remains [unverified] | Tivra `CLAUDE.md` (Extension to app transport) |
| 13 | `claude` CLI at `~/.local/bin/claude` | Confirmed (the native installer symlinks it into a versions folder) | https://code.claude.com/docs/en/setup.md |

## Gaps found in verification

- Listening takes 25-29 min, not 18, so a full mock is about 85-90 min only if instructions fit in the blueprint's 8-9 min slack; budget the monthly mock at 90 min.
- Tivra has no documented read API in its CLAUDE.md. Before building the exam witness, decide whether Tenaz reads Tivra's local database (needs a schema check) or adds a read-only endpoint via a Tivra patch proposal (DECISIONS rule 3). Do not reuse the HMAC ingest endpoint.
- ETS says its Table B1 totals are rounded UP "to minimize false positives". Tenaz's own band display should likewise avoid rounding up, otherwise it overstates level against real exams.
- The ETS banded scale uses theta cut points per CEFR level for Reading/Listening (Tables 4, 5 of the score-scale report); the Tenaz logit thresholds in section 4.2 are invented. Pull the published theta values into the mapping rather than the arbitrary -1/0/+1/+2.
- Pass-through for the 0-5 AI rubrics: the blueprint only confirms max points (5) for AI-scored items; the rubric descriptors are not in the blueprint, so Tenaz's 0-5 anchors remain its own adaptation.
