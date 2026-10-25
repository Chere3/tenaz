# 07 - Competitor teardown and evidence of effectiveness

Date: 2026-10-22. Scope: language-learning apps relevant to a B1+ adult who needs work-meeting English and benefits from ADHD-friendly design in a deliberately intrusive Mac app.

## 0. How to read this report

- Every non-obvious claim has a URL. [unverified] means I could not confirm it from a primary or at least independent source in this session. Search snippets were my only access for several items (I did not open full papers), so figures are "as reported by the cited page".
- Vendor-funded studies are labelled as such. Almost every "efficacy study" in this market is vendor-sponsored, tests beginners, and has no randomized control group. Treat them as weak evidence of "it does not hurt", not evidence of "it works better than alternatives".
- Honest headline: **no app in this list has independent, controlled evidence of taking an adult from B1 to B2/C1 or of improving real work-meeting performance.** The best-evidenced mechanisms are not brands; they are practice testing and spacing (Dunlosky 2013, Cepeda 2008), high-coverage input (Nation 2006), and talking with a responsive interlocutor (human or AI). Tenaz should be built on mechanisms, not on copying a brand.

## 1. Cross-cutting evidence that frames everything

| Mechanism | Evidence | Implication for Tenaz |
|---|---|---|
| Practice testing + distributed practice are the two top-rated study techniques; highlighting, rereading, summarising rated low | Dunlosky et al. 2013 review of 10 techniques, via [APS summary](https://www.psychologicalscience.org/news/releases/which-study-strategies-make-the-grade.html) | Every Tenaz interaction should be retrieval (recall, produce), never passive display. "Big words on screen" must be a retrieval prompt, not a poster. |
| Optimal spacing gap shrinks as a share of the retention interval: ~20-40% of a 1-week test delay, ~5-10% of a 1-year delay (1,350+ participants) | Cepeda, Vul, Rohrer, Wixted, Pashler 2008, [PDF](https://www.evullab.org/pdf/CepedaVulRohrerWixtedPashler-PS-2008.pdf) | Schedule by target date (e.g. "meeting vocabulary needed in 3 weeks"), not just fixed intervals. Supports FSRS with a desired-retention dial. |
| FSRS beats SM-2 on predicting recall; reported savings 20-30% fewer reviews at 90% retention | Mostly one benchmark of ~700M Anki reviews, reported second-hand ([Diane guide](https://www.diane.app/en/guides/fsrs-vs-sm2), [Migaku](https://migaku.com/blog/language-fun/spaced-repetition-in-2026-what-actually-works-for-language-learners)); no controlled language-learning trial found. Anki ships FSRS since 23.10 (official changelog, 2023-11-01; 23.12 only upgraded it to FSRS 4.5) ([Anki changes](https://changes.ankiweb.net/changes/23.10.html)). [partly unverified: I did not open the Expertium source] | Use FSRS (already in the plan). Do not promise numeric savings. |
| ~8,000-9,000 word families for 98% coverage of written text, 6,000-7,000 for spoken; 95% coverage of TOEFL iBT listening needs ~3,000 families plus proper nouns, 98% needs ~6,000 | Nation 2006 via [Cambridge replication](https://www.cambridge.org/core/journals/language-teaching/article/how-much-vocabulary-is-needed-to-use-english-replication-of-van-zeeland-schmitt-2012-nation-2006-and-cobb-2007/1D217A56A2E0056E67802A6A8360FDDE), [TOEFL iBT listening vocab study](https://jalt-publications.org/tlt/articles/4281-vocabulary-size-required-toefl-ibt-listening-section); van Zeeland & Schmitt 2012 argue 95% may suffice for listening | Vocabulary targets should be frequency-ranked and tied to the learner's own coverage of real texts (meeting transcripts, papers), not an arbitrary word list. |
| Gamification meta-analysis: medium positive effect (g = 0.504, 30 interventions); effect varies with duration/sample; novelty decay is argued from individual studies, not settled | [Bai, Hew et al. 2020](https://www.gbl.uzh.ch/quartz/references/Bai-et-al.-(2020)); Sailer & Homner 2019 found duration non-significant for behavioural outcomes (as cited in [Springer](https://link.springer.com/article/10.1186/s41239-021-00314-6)) | Gamification can raise behaviour (showing up) reliably; it does not by itself raise learning. Design so the reward is tied to retrieval success, not to opening the app. |
| ADHD and L2 learning: evidence is mixed and thin. Meta-analysis shows working-memory deficits in children with ADHD ([PubMed 15782085](https://pubmed.ncbi.nlm.nih.gov/15782085/)); a 2019 study found ADHD children similar to controls on language-learning tasks, with deficits tied to reading disorder ([PMC6811534](https://pmc.ncbi.nlm.nih.gov/articles/PMC6811534)); an adult thesis found no difference on an artificial-language task ([UIC thesis](https://indigo.uic.edu/articles/thesis/Learning_Second_Languages_with_ADHD_The_Role_of_Memory_Systems/27153387)) | Do not assume the learner "cannot learn"; assume the bottleneck is initiation, consistency, and distractibility (behavioural), which is exactly where intrusive scaffolding helps. I found **no** study of gamified apps and adherence in ADHD [unverified]. Tenaz must measure it on the learner. |

## 2. Competitor teardown

Format per app: core loop; what drives learning vs. only engagement; ADHD fit; weaknesses.

### 2.1 Duolingo

**Core loop.** Short gamified lessons (translate, match, listen, speak), XP, daily streak, leagues, hearts/energy, push notifications from the owl mascot. Birdbrain, an adaptive model, picks exercise difficulty; the earlier half-life regression (HLR) model schedules practice ([Settles & Meeder 2016, ACL P16-1174](https://preview.aclanthology.org/landing_page/P16-1174)). Duolingo's own blog reports HLR error "nearly half" that of the Leitner baseline (no exact figure given), and that A/B tests of an HLR-based scheduler raised practice-session retention 9.5%, lessons 1.7%, overall activity 12% ([Duolingo blog](https://blog.duolingo.com/how-we-learn-how-you-learn)); these are company-reported.

**Scale in 2026.** Q2 2026: 58.7M DAU (+23% YoY), 12.7M paid subscribers, retention at record high, driven partly by a one-time "Streak Revival" campaign where 15.4M learners revived streaks ([Pulse 2.0](https://pulse2.com/duolingo-daily-active-users-reach-58-7-million-as-retention-hits-record-84-and-social-accounts-top-1-billion-organic-impressions/)); more than 10M users hold a 365-day streak ([PocketGamer.biz](https://www.pocketgamer.biz/more-than-10-million-duolingo-users-have-a-365-day-streak)). The stock is down roughly 57% over the year on AI-disruption fears and monetization backlash (ads/subscription pushes) ([Motley Fool](https://www.fool.com/investing/2026/03/09/duolingo-stock-is-down-big-this-year-heres-why-thi/), [Slashdot/Barron's](https://tech.slashdot.org/story/26/02/28/2321238/)). Takeaway: streak mechanics demonstrably produce huge daily habits; the business story shows the habit does not guarantee users feel they are learning.

**Evidence of learning.**
- Jiang et al. 2021 (*Foreign Language Annals*): 225 adult beginners using only Duolingo for Spanish/French reached ACTFL Intermediate Low reading and Novice High listening, comparable to the end of the 4th university semester; only reading and listening were tested ([Duolingo press release](https://investors.duolingo.com/news-releases/news-release-details/leading-language-research-journal-publishes-study-showing), [NAU record](https://experts.nau.edu/en/publications/evaluating-the-reading-and-listening-outcomes-of-beginning-level-/)). The first author was a Duolingo employee, and a CALL-EJ review flags selection bias and validity concerns ([CALL-EJ](https://callej.org/index.php/journal/article/download/419/347/1013)).
- A 2024 CALICO study (Jiang et al., Duolingo English courses, A2 basic content, STAMP 4S, reading/listening Intermediate High) ([CALICO](https://journal.equinoxpub.com/Calico/article/view/26704)). Again company-affiliated; and it is about learners of English at low levels.
- Neither speaks to B1 to C1 or to speaking/writing.

**AI-first and Max.** April 2025 "AI-first" memo from CEO von Ahn (phase out contractors for AI-doable work, AI use in hiring/reviews), with user backlash ([Computing](https://www.computing.co.uk/news/2025/ai/duolingo-goes-ai-first-as-it-phases-out-human-contractors), [Campus Technology](https://campustechnology.com/articles/2025/05/06/duolingo-embraces-ai-in-push-for-scalable-learning.aspx?p=1)). Max (about $29.99/mo in US per [Storylearning](https://storylearning.com/duolingo-max-review), price varies) is now differentiated by Roleplay (scripted scenarios with feedback) and Video Call with Lily (open-ended, remembers earlier calls); Explain My Answer became free from Jan 2026 in most courses (same source, secondary). I found no independent outcome data on Video Call or Roleplay. I saw a headline that Max "may be discontinued" ([LongPort](https://longportapp.cn/news/295028818)) but the page loaded empty: [unverified], ignore.

**What drives learning vs engagement.** Learning: retrieval + adaptive repetition of items. Engagement only: streak, XP, leagues, cosmetic rewards, notification guilt. Streak mechanism is loss aversion; critics describe "streak anxiety" where users open the app to avoid loss rather than to learn ([ScreenWise guide](https://screenwiseapp.com/guides/managing-duolingo-streaks-when-gamification-becomes-stressful)), low-quality source, but consistent with the loss-aversion design intent.

**ADHD fit.** Strong on: tiny sessions, instant feedback, external accountability via streak and notifications. Weak on: easy to "game" with low-effort lessons to keep a streak; ADHD users report it builds a habit but is not the best way to actually learn (anecdote, [forum thread](https://scribe.disroot.org/post/2990337)); no ADHD research found [unverified].

**Weaknesses for this learner profile.** Sentence translation and tile-ordering at a B1+ level is far below the learner's needs; little production (free writing/speaking); mostly decontextualised sentences; speaking practice is paywalled; no connection to the learner's real language needs (the learner's workplace meetings); no exam prep at TOEFL/IELTS level for work.

### 2.2 Babbel

**Core loop.** Structured, dialogue-based lessons with grammar notes, review manager (spaced), speech recognition; human-authored curriculum (company claim).

**Evidence.** Michigan State University study led by Shawn Loewen, *Foreign Language Annals*: 85 undergrads, ~12 weeks of Spanish on Babbel; of those who finished (54), nearly all improved in oral proficiency, grammar and/or vocabulary (59% of finishers gained at least one ACTFL oral sublevel; gains correlated with time in app) ([MSU Today](https://msutoday.msu.edu/news/2019/new-study-gives-insight-on-effectiveness-of-language-learning-apps), [Babbel press release](https://babbel.com/press/en-us/releases/2019-01-10-Babbel-SPA-2018-Study.html)). Babbel-sponsored per Babbel's own press release (the MSU article does not name a sponsor); 36% attrition; no control group; beginners. Babbel also cites CUNY and Yale work ([Babbel research](https://uk.babbel.com/why-babbel-works)); I did not verify those.

**Drives learning vs engagement.** Learning: explicit grammar + dialogue + review. Little gamification; engagement relies on the user's own motivation.

**ADHD fit.** Low gamification means low intrusion; no streak pressure beyond reminders. Weak for ADHD initiation.

**Weaknesses.** Course content tops out around B2 and is a general curriculum; no personalisation to the learner's vocabulary; no exam mode. [B2 ceiling: unverified claim from general knowledge.]

### 2.3 Busuu

**Core loop.** Lessons + community feedback on writing/speaking from native speakers + study plans; recognised CEFR-aligned structure.

**Evidence.** 2021 study with 113 Spanish learners, 2 months, minimum 2 h/week; all beginners improved on at least one speaking or reading test, 82% of intermediates did; company claims 28-76 hours vs 90-110 for a college semester ([Busuu blog](https://blog.busuu.com/2021-busuu-efficacy-study/)). Earlier 2016 study (CUNY / South Carolina) claimed 22 hours ≈ one college semester ([McGraw-Hill media room](https://mheducation.mediaroom.com/2016-06-07-University-study-finds-measurable-improvement-of-language-skills-after-just-16-hours-of-learning-with-busuu)). Vendor-promoted; no control group visible in these summaries.

**Useful idea.** Human feedback on writing from native speakers is the one thing the AI apps replicate with LLMs; Tenaz can replicate with the local `claude` CLI at zero marginal cost.

**ADHD fit / weaknesses.** Moderate; waiting for community feedback breaks the loop (ADHD users need immediate feedback). General course; not work-focused.

### 2.4 Speak

**Core loop.** Speaking-first: scripted speaking lessons with ASR, AI tutor for open conversation, instant pronunciation/grammar feedback. OpenAI-backed; raised $78M Series C at $1B valuation in Dec 2024, moved to GPT-4 and Whisper in 2023 ([TechCrunch](https://techcrunch.com/2024/12/10/openai-backed-speak-raises-78m-at-1b-valuation-to-help-users-learn-languages-by-talking-out-loud), [TechCrunch 2023](https://techcrunch.com/2023/08/31/openai-backed-language-learning-app-speak-raises-16m-to-expand-to-the-u-s)).

**Evidence.** I found **no** independent outcome study [unverified]; claims of "better learning outcomes" are company statements.

**Reviews.** Competitor-written and thus biased: repetitive at higher levels, scripted flow limits free-form at B1+, weak long-term vocabulary tracking, price about $17.99/mo or $83.99/yr ([Languatalk review](https://languatalk.com/blog/speak-app-review/), [ISSEN comparison](https://www.issen.com/blog/speak-competitors-alternatives/)). Plausible but unverified.

**ADHD fit.** Speaking aloud is active and engaging (good); needs a quiet place (bad in an office). Mac-wise: mobile-first.

**Takeaway.** Production is what B1 users lack; speaking-first is right. But a B1+ user needs open-ended, topic-specific speaking linked to the items they are learning, with memory across sessions.

### 2.5 Praktika, Loora, Talkpal (AI speaking tutors)

- **Praktika:** AI avatar tutors. Reviews on Trustpilot cite placement too easy/hard, repetitive scenarios (shopping), poor voice recognition for some; others praise realistic tutors and free conversation ([Trustpilot](https://www.trustpilot.com/review/praktika.ai?page=6), [Praktika's own review page](https://praktika.ai/speaking-english-praktika-app-review)).
- **Loora:** English-only, long open conversations, instant feedback on grammar/pronunciation/fluency; reviewers note questions can get repetitive and cross-session memory is inconsistent ([Trustpilot](https://it.trustpilot.com/review/loora.com), [ISSEN roundup, competitor](https://www.issen.com/blog/best-ai-apps-for-learning-english-speaking/)).
- **Talkpal:** multi-language AI chat; I found only store listings [unverified quality].
- **Common gap (vendor claim, plausible):** conversation apps lack cross-session memory linked to spaced repetition ([ISSEN](https://www.issen.com/blog/best-ai-apps-for-learning-english-speaking/)). That link is Tenaz's opening: every mistake in conversation becomes an SRS card.
- **Evidence:** none independent found for any of the three [unverified].
- **ADHD fit:** low-friction to start; no structure; easy to "chat" without learning.

### 2.6 ELSA Speak (pronunciation)

**Core loop.** Phoneme-level pronunciation scoring with ASR; short drills; accent-specific.

**Evidence.** Only small studies: Indonesian vocational quasi-experiment with control group (thesis), a 2026 Ecuador thesis with 25 adolescents (self-reported perception), a 2025 Indonesian journal pretest/posttest (results not retrieved) ([UBE thesis](https://dspace.ube.edu.ec/handle/123456789/3751), [UIN Saizu thesis](https://repository.uinsaizu.ac.id/27586)). Weak.

**ADHD / weaknesses.** Great fit for micro-sessions. Does not teach vocabulary or discourse. For the learner (Spanish-L1), the high-value targets are known Spanish-speaker problems (word-final clusters, /ɪ/ vs /i:/, /b/ vs /v/, schwa, stress timing) [from general phonetics; no source fetched, unverified].

### 2.7 LingQ and Readlang (reading input)

**Core loop.** Import or pick text/audio, click unknown words to look up and save them as "LingQs" (flashcards), track known-word count. Philosophy: Krashen's comprehensible/compelling input ([LingQ talk transcript](https://www.lingq.com/en/learn-english-online/courses/540052/cicompelling-or-comprehensible-input-9818606/), [TEFLIN review of extensive reading](https://journal.teflin.org/index.php/journal/article/download/724/315/1643)).

**Evidence.** Krashen's hypothesis is influential but contested; the "flow from interesting input" examples are anecdotal. The solid, usable part is lexical coverage (Nation, above): you need very high known-word coverage for comfortable reading, so a known-word counter that reports coverage of the text is actually actionable. No controlled study of LingQ specifically found [unverified]. Readlang: I did not research it in this session [unverified].

**ADHD fit.** Good: self-chosen content provides interest, tap-to-save is low friction. Risk: reading lots without producing.

**Weakness.** No production, no testing, no accountability. The learner's natural input (work docs, YouTube, papers) is rarely supported.

### 2.8 Anki and Clozemaster (SRS)

- **Anki:** the gold standard scheduler (FSRS since 23.10), infinitely flexible, ugly, no motivation layer. ADHD users commonly abandon decks when review debt snowballs [common knowledge, unverified]. Zero content, zero coaching.
- **Clozemaster:** cloze (fill-in-the-blank) on real sentences, frequency-ordered, aimed at B1-C2; default intervals 5 min, 1 d, 10 d, 30 d, 180 d (reviewer description) ([ActualFluency review](https://actualfluency.com/clozemaster-review), [Clozemaster blog, vendor](https://www.clozemaster.com/blog/?p=7577)). Strength: context sentences with the target word masked, which trains the form-meaning-use mapping. Weakness: sentences from Tatoeba-like corpora are not yours; no productive output.

### 2.9 Memrise and Lingvist

- **Memrise:** video clips of native speakers, SRS, pronunciation, AI chat; beginner-leaning (Clozemaster's comparison claims A1-A2 / ~3,000 words, vendor framing) ([itechguides](https://www.itechguides.com/compare/memrise-vs-lingvist/), [Clozemaster blog](https://www.clozemaster.com/blog/?p=7577)).
- **Lingvist:** adaptive vocabulary-in-sentences with placement test, prioritises words you likely don't know; pricey (about $24.99/mo on one comparison); critics say it teaches "in a vacuum" (no connection to usage) ([FluentU review, competitor](https://www.fluentu.com/blog/lingvist-review/)).
- **Lesson:** adaptive selection of which words to teach based on predicted unknown status is a good idea (placement by sampling the frequency list). Cheap to reproduce with the frequency bands plus FSRS.

### 2.10 Human tutors: Preply and italki

- italki claims 71.6% of Spanish learners improved oral proficiency by at least one CEFR level in two months, citing Queens College (CUNY) and University of South Carolina researchers ([italki blog](https://www.italki.com/en/blog/best-platforms-to-find-a-language-tutor-for-conversation-practice)). That is vendor-reported and I could not confirm control group or journal [unverified]. Preply: no outcome data found.
- Mechanism that is plausible: one-to-one lessons give production time and correction that apps lack. But it costs money per hour and needs scheduling (high friction for ADHD, though external appointments are also a strong commitment device).
- **For Tenaz:** do not replace tutors; add a "book a human tutor" nudge when the AI detects a plateau, and generate a lesson brief from the error log to hand to the tutor. [design idea, not evidence-backed]

### 2.11 Browser and Mac ambient tools

- **Language Reactor** (Chrome only): dual subtitles, pop-up dictionary and word lists on Netflix/YouTube, Anki export; about 2M users, 4.3 stars; Pro tier; no controlled evidence of vocabulary gains; extension-security scan flags broad permissions ([Chrome Web Store](https://chromewebstore.google.com/detail/hoombieeljmmljlkjmnheibnpciblicm), [Wikipedia](https://en.wikipedia.org/wiki/Language_Reactor), [TESL Canada media review 2025](https://teslcanadajournal.ca/index.php/tesl/article/download/1821/1487/6449)). I found nothing on Toucan [unverified]; do not claim anything about it.
- **Migaku**: browser/Anki-based immersion tool; it publishes SRS guidance ([Migaku blog](https://migaku.com/blog/language-fun/spaced-repetition-in-2026-what-actually-works-for-language-learners)). I did not evaluate the product [unverified].
- **Mac ambient vocabulary** (menu bar, wallpaper, screensaver): my searches found **no** established Mac vocabulary-in-menu-bar/wallpaper app; only generic menu bar text tools (Text Menu Bar, CSV import of custom text) and wallpaper managers ([Product Hunt: Text Menu Bar](https://www.producthunt.com/products/text-menu-bar/makers)). Either the niche is empty or my search is weak; treat "the niche is empty" as [unverified] but plausible. Passive ambient display is also the weakest learning mechanism (display ≠ retrieval), so the gap is real but the old approach is not the answer; the answer is ambient **retrieval prompts**.

## 3. Cross-app synthesis

| Axis | Best of market | Gap |
|---|---|---|
| Habit formation | Duolingo (streaks, push) | Habit is decoupled from learning quality; streak can be farmed |
| Scheduling | Anki FSRS, Duolingo Birdbrain | Anki has no motivation; Duolingo's scheduler is closed and low-level |
| Production | Speak, Praktika, Loora, tutors | Not linked to SRS; scripted at B1+; no memory |
| Input | LingQ, Language Reactor | No accountability or testing |
| Pronunciation | ELSA | Siloed from vocab |
| Exams | none (apps don't do TOEFL/IELTS-style progressive mocks with integrity) | open |
| ADHD | none designed for ADHD with evidence | open |
| Anti-cheating | none | open; only Tenaz + Tivra can do this on the learner's own Mac |

## 4. The 15 most important gaps Tenaz should fill

1. **Retrieval over display.** Competitors show; Tenaz must always ask. Every on-screen word is a prompt with a required answer (Dunlosky 2013).
2. **Work-English targeting.** No app tunes to the user's real meetings. Tenaz ingests the learner's own material (meeting notes, work documents the learner pastes, YouTube transcripts) and prioritises words by frequency and personal need. Keep it local; respect confidentiality: never ingest company-confidential text without an explicit user action.
3. **B1 to C1 production.** Apps are beginner-heavy. Tenaz builds paraphrase, summarise-my-day, and explain-to-a-colleague tasks, graded for cohesion and accuracy (typical B1 weak spots).
4. **Conversation to SRS loop.** AI speaking apps lack persistent linkage to spaced repetition ([ISSEN, vendor claim](https://www.issen.com/blog/best-ai-apps-for-learning-english-speaking/)). Every error found in a Claude-reviewed paragraph becomes a card targeting that error pattern.
5. **Un-farmable streaks.** Duolingo streaks can be kept with trivial lessons. Tenaz's streak must require a minimum number of successful retrievals plus one production item (a "quality streak").
6. **Initiation help for ADHD.** Competitors wait for the user to open the app; the ADHD failure point is starting. Tenaz comes to the user (menu-bar, post-wake panel, between-task prompts) at times the learner chooses, with a 30-second "minimum viable session" so starting costs nothing.
7. **Debt-proof review queue.** Anki's snowball is the classic abandonment cause. Tenaz caps daily load, auto-postpones with an explicit "debt amnesty" and always presents the top-N highest-value cards; never shows a number like "1,243 due".
8. **Exam realism with integrity.** No app offers TOEFL-style sectioned mock exams that the learner cannot cheat on. Tenaz runs full-screen exam mode with Tivra signalling (read-only) that no AI/chat app was used; log the integrity result with the score. (Tivra is read-only; consume its state, do not modify it.)
9. **Honest progress measurement.** Vendor studies are beginner, no control, vendor-sponsored. Tenaz keeps a held-out benchmark: every 2-4 weeks, a fixed-format test (new items never trained) so improvement is not just memorising the deck. Report with uncertainty.
10. **Pronunciation tied to the learner's vocabulary.** ELSA is siloed. Tenaz checks the pronunciation of the learner's own deck words and the learner's Spanish-L1 error classes (Section 2.6; macOS speech recognition for on-device scoring, to be validated by another research doc).
11. **Listening at meeting speed.** Apps use slow, clean audio. Tenaz trains with accented and fast speech (e.g. clips of the learner's own recorded meetings, if they choose, or public talks) and measures comprehension vs. 95%/98% coverage thresholds (Nation).
12. **Commitment device the learner controls.** Duolingo's guilt is the vendor's. Tenaz lets the learner pre-commit to stakes (loss of mascot health/XP, Tivra blocking of selected apps) with escape hatches (DECISIONS.md rule 2). Streak anxiety is a known risk of loss-aversion mechanics, so punishments should be bounded and recoverable.
13. **Context switching awareness.** No competitor knows the learner is in a meeting or deep work. Tenaz must suppress itself during meetings (calendar + Tivra), and move reviews to natural boundaries. This is also a hard safety rule.
14. **Zero marginal AI cost and privacy.** Speak/Praktika/Loora charge about $18-30/month and send audio to the cloud. Tenaz uses the local `claude` CLI under the learner's subscription and keeps data local (DECISIONS.md).
15. **Mascot and identity that grows with real competence.** Duolingo's owl is a notification device; mascot growth is tied to XP. Tenaz ties mascot growth to measured competence (CEFR-aligned held-out benchmark), so a high-level mascot means real progress.

## 5. The 10 features worth copying (and what to change)

| # | Feature (source) | Change for Tenaz |
|---|---|---|
| 1 | **Streak + loss aversion** (Duolingo) | Quality-gated streak (min successful retrievals + 1 production). Add "freeze" tokens earned by perfect days; auto-protected during travel/illness and meetings. Never let a missed day wipe long-term progress; a weekly view, not only a daily one. |
| 2 | **Adaptive difficulty model** (Duolingo Birdbrain / HLR, [Settles & Meeder](https://preview.aclanthology.org/landing_page/P16-1174)) | Use FSRS instead; tune desired retention per item class (survival vocabulary for next week's meeting = 95%, long-tail = 85%). Show the learner why a card appeared. |
| 3 | **Cloze on real sentences** (Clozemaster) | Generate sentences from the learner's own context via Claude; mask the target; require typing (not choosing) for productive recall; accept near-misses with a hint. |
| 4 | **Tap-to-save unknown words from real text** (LingQ, Language Reactor) | A global hotkey/service on macOS: select any English text anywhere, press a key, get a gloss and a saved card with source context. Report text coverage (known-word %) against Nation's 95/98% targets. |
| 5 | **Roleplay + follow-up memory** (Duolingo Video Call/Lily, Loora) | Meeting-simulation roleplays (stand-up update, disagreeing politely, asking for clarification) with a persistent memory file; end every call with 5 auto-extracted cards. Text first; voice later. |
| 6 | **Phoneme-level pronunciation feedback** (ELSA) | Limit to the 6-8 highest-yield error classes for Spanish speakers and to words they are actually learning; do not chase a "score". |
| 7 | **Native-speaker-style writing feedback** (Busuu) | Immediate Claude review of the learner's daily paragraph: 3 corrections maximum (the most pattern-level ones), a rewrite, and a card per recurring pattern. Immediate beats community latency for ADHD. |
| 8 | **Leagues / social comparison** (Duolingo) | Replace with comparison against their own past self and an optional friend; leaderboards can cause anxiety for some users ([ScreenWise](https://screenwiseapp.com/guides/duolingo-and-gamified-education)). Low priority. |
| 9 | **Placement/adaptive start** (Lingvist) | Sample the frequency bands (1k-10k) to estimate the learner's vocabulary size on day one, then target the 3k-8k band; report estimated coverage. |
| 10 | **Human tutor booking and accountability** (Preply/italki) | Monthly "tutor handoff": auto-generate a one-page brief of recurring errors and target topics they can send to a tutor; an external appointment is a strong commitment device. |

Features not worth copying: hearts/energy that block learning after errors (anti-ADHD and monetisation-driven), notification guilt without off-switch, paywalled core speaking, content scraped without level control.

## 6. Risks and cautions from the competitor landscape

- **Engagement trap.** Duolingo's own 2026 numbers show habit metrics (DAU, streaks) can grow while perceived value and word-of-mouth fall ([Motley Fool](https://www.fool.com/investing/2026/03/09/duolingo-stock-is-down-big-this-year-heres-why-thi/)). Tenaz's success metric should be held-out test performance and meeting performance, not time-in-app or streak length.
- **Punishment can backfire.** Intrusion that causes avoidance (uninstall, kill-switch) is a worse outcome than light engagement. Hence DECISIONS.md: disabled by default, escape hatches. Start with rewards and friction, escalate stakes only with the learner's weekly opt-in. I did not find research on punishment efficacy in ADHD learners [unverified].
- **AI correctness.** LLM feedback can be wrong; Speak-style complaints about leniency in ASR ([Languatalk, unverified Reddit attribution](https://languatalk.com/blog/speak-app-review/)). Tenaz should show the rule, keep a "report wrong correction" button, and prefer deterministic checks (spelling, SRS) wherever possible.
- **Evidence humility.** Because vendor studies are weak, Tenaz should treat itself as an N=1 experiment and log outcomes honestly.

## 7. Open questions for other research tracks

1. Best on-device pronunciation assessment on macOS (Speech framework vs. whisper-based) for phoneme feedback.
2. TOEFL iBT 2026 format details (confirmed: from 21 Jan 2026 Reading and Listening are multistage adaptive, scoring moves to a 1-6 band scale in half-point steps tied to CEFR with 0-120 equivalents reported for two years, and Speaking/Writing have new task types incl. collaborative academic settings; [ETS](https://toeflaccess.ets.org/help/en/articles/11758550-toefl-ibt-updates-coming-january-2026). Section order and test length differ between secondary sources: check ets.org/toefl/ibt/about/content before mirroring) to mirror section structure.
3. ADHD-specific design evidence (task initiation, body doubling, variable reward) beyond language learning.
4. Readlang and Toucan: not researched here.
5. Verify the Jiang 2021 full text and Loewen 2019 full text if Tenaz marketing ever cites them.

## 8. Source quality note

Where I could, I cited primary sources (ACL anthology, Cepeda PDF, Nation via Cambridge, MSU press, company IR). Many other items come from search-result summaries, vendor blogs and competitor review sites; they are flagged as vendor/competitor where applicable. Statements without a URL or marked [unverified] are from general background knowledge and should be confirmed before they drive a design decision.

## Verification

Checked 22 Oct 2026 against primary or near-primary pages. Verdicts: confirmed / corrected / unverifiable.

| # | Claim | Verdict | Source |
|---|---|---|---|
| 1 | Cepeda 2008: 1,350+ participants; optimal gap ~20-40% of a 1-week delay, ~5-10% of a 1-year delay | Confirmed (paper text: 1,354 new subjects; ratios from abstract) | [PubMed 19076480](https://pubmed.ncbi.nlm.nih.gov/19076480/), [PDF](https://www.evullab.org/pdf/CepedaVulRohrerWixtedPashler-PS-2008.pdf) |
| 2 | Anki ships FSRS since 23.12 | Corrected: 23.10 | [Anki 23.10 changes](https://changes.ankiweb.net/changes/23.10.html) |
| 3 | Nation 2006: 8-9k families for 98% written, 6-7k spoken; van Zeeland & Schmitt: 95% may suffice for listening (2-3k families) | Confirmed (abstract) | [Nation 2006 PDF](https://www.wgtn.ac.nz/__data/assets/pdf_file/0018/1626120/2006-How-large-a-vocab.pdf), [Schmitt et al. 2015](https://www.lextutor.ca/cover/papers/schmitt_cobb_etal_2015.pdf) |
| 4 | Bai et al. 2020: g = 0.504, 30 interventions | Confirmed (30 interventions from 24 studies; Educational Research Review 30:100322). Note: duration moderated the effect there, so the file's "novelty decay not settled" framing stands only with Sailer & Homner as counterpoint | [Bai et al. 2020 record](https://www.gbl.uzh.ch/quartz/references/Bai-et-al.-(2020)) |
| 5 | Duolingo Q2 2026: 58.7M DAU (+23%), 12.7M paid subs, 15.4M streaks revived | Confirmed (SEC 8-K shareholder letter indexed) | [SEC 8-K](https://www.sec.gov/Archives/edgar/data/0001562088/000162828026053299/q2fy26duolingo6-30x26share.htm) |
| 6 | Duolingo blog: HLR ~halved error; +9.5% practice sessions, +1.7% lessons, +12% activity | Confirmed with correction: "nearly half" of Leitner, no exact figure; lifts are for the HLR group | [Duolingo blog](https://blog.duolingo.com/how-we-learn-how-you-learn) |
| 7 | Jiang 2021: Intermediate Low reading, Novice High listening, ~4th-semester equivalent, reading/listening only | Confirmed; added n = 225, Foreign Language Annals 54(4) | [NAU record](https://experts.nau.edu/en/publications/evaluating-the-reading-and-listening-outcomes-of-beginning-level-/) |
| 8 | Babbel/MSU: 85 students, 54 finished, 12 weeks | Confirmed. Sponsorship: not stated by MSU; Babbel press release asserted, so label kept as Babbel-sponsored per Babbel | [MSU Today](https://msutoday.msu.edu/news/2019/new-study-gives-insight-on-effectiveness-of-language-learning-apps) |
| 9 | Speak: $78M Series C at $1B, Dec 2024 | Confirmed (10 Dec 2024, Accel-led) | [Speak](https://speak.com/blog/series-c), [TechCrunch](https://techcrunch.com/2024/12/10/openai-backed-speak-raises-78m-at-1b-valuation-to-help-users-learn-languages-by-talking-out-loud) |
| 10 | TOEFL iBT changed January 2026 (was [unverified]) | Confirmed: 21 Jan 2026, adaptive R/L, 1-6 scale, revised S/W | [ETS](https://toeflaccess.ets.org/help/en/articles/11758550-toefl-ibt-updates-coming-january-2026) |

Not verified (left as is): Duolingo Max price, Speak price, ELSA studies, italki 71.6%, Clozemaster intervals, stock -57%, Dunlosky ranking (well established, APS page not reopened).

## Gaps found in verification

- Tenaz exam mode should mirror the new TOEFL (adaptive R/L, 1-6 CEFR-tied bands, collaborative academic speaking/writing tasks), not the retired 0-120 four-skill format; IELTS and Cambridge are not covered by this report.
- Section 0 says "tests beginners": Jiang 2021 and Babbel/MSU were both beginner-only and vendor-linked, so nothing here supports claims about B1+ gains; keep the held-out benchmark (gap 9) as the only evidence Tenaz can trust.
- Spacing ratios (Cepeda) come from fact recall, not vocabulary or production tasks; treat as a prior, and let FSRS fit the learner's own data.
- FSRS "20-30% fewer reviews" remains second-hand; do not surface it in the UI.
- Competitor prices and Max/Speak features change often; re-check before any positioning decision.
