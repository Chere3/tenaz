# 08 - Content, books, listening and open data for Tenaz

Date: 2026-10-22. Audience: a learner at B1+ (fluency ~B2, accuracy ~B1), Spanish L1, software developer, English needed for work meetings.
Honesty note: claims with a URL were checked in this session. Book/podcast levels are editorial estimates unless a source is given; they are marked [est]. Anything not verified is marked [unverified]. Lexile values are deliberately not given per book (see 1.4).

## 0. Decisions in one screen

1. Use a two-lane reading plan: lane A (graded readers, Oxford Bookworms 4-6 / Macmillan Upper / Penguin 4-6) for fluency at ~98% coverage, lane B (authentic tech/science books, ~95% coverage, with a dictionary tap) for stretch. Alternate; never more than one lane B book at a time.
2. Treat 98% coverage as a target, 95% as the floor. The 98% figure is contested (see 1.1), so the app measures it per user instead of trusting it.
3. Tenaz must compute coverage itself: bundle NGSL + a frequency list (SUBTLEX-US or wordfreq-style) and tag every book with a precomputed "% of tokens in the learner's known set". Recommendation = pick books whose coverage for *the learner's* known words is 95-98%.
4. Bundle only clearly licensed data: Tatoeba (CC BY 2.0 FR, attribution), NGSL (CC BY-SA 4.0 - share-alike risk for derived word lists), CMU dict (BSD-like), WikDict/Wiktionary (CC BY-SA), WordNet (permissive, attribution). Treat CEFR-J and SUBTLEX as "ask/verify before bundling" - download at first run instead of shipping.
5. Never bundle book text. Store metadata only (title, author, level, topics, word count, ISBN). Books are bought/borrowed by the learner; Tenaz tracks progress.
6. Meeting-language module is a phrasebank of ~120 functional chunks, taught as chunks (not rules), drilled with FSRS and rehearsed in Claude-driven role-plays (via `claude` CLI, optional).

## 1. Research basis

### 1.1 Lexical coverage
- Nation (2006), "How large a vocabulary is needed for reading and listening?": 98% coverage for unassisted comprehension of written text needs about 8,000-9,000 word families (plus proper nouns; novels 8,000-9,000, e.g. The Great Gatsby 8,000, Turn of the Screw 7,000), spoken English ~6,000-7,000. Verified in the full text of the PDF in the verification pass: https://www.wgtn.ac.nz/__data/assets/pdf_file/0018/1626120/2006-How-large-a-vocab.pdf
- Hu & Nation (2000) found most learners needed ~98% for adequate unassisted comprehension, but n=66 [unverified]. A 2023 replication (Kremmel et al., Language Learning, Sri Lanka; sample size [unverified], earlier draft said 104) questioned a single fixed threshold since question format and text type change the needed coverage; Schmitt, Jiang & Grabe (2011, n=661) found no sharp threshold, a roughly linear relationship, with 98% a sensible target for academic text; Laufer (1989) argued 95%. See https://aila2021.dryfta.com/program/abstract-archive/abstract/public/416/unknown-vocabulary-density-reading-comprehension-and-the-98-coverage-figure-replicating-hu-nation-2000 and https://www.lextutor.ca/cover/papers/schmitt_etal_2011.pdf.
- For listening, van Zeeland & Schmitt (2012) argue 95% may suffice (about 2,000-3,000 families); a TOEFL iBT listening analysis found the first 3,000 families + proper nouns and marginal words for 95%, 6,000 for 98%: https://jalt-publications.org/tlt/articles/4281-vocabulary-size-required-toefl-ibt-listening-section ; overview https://www.cambridge.org/core/journals/language-teaching/article/how-much-vocabulary-is-needed-to-use-english-replication-of-van-zeeland-schmitt-2012-nation-2006-and-cobb-2007/1D217A56A2E0056E67802A6A8360FDDE .
- Design implication: coverage is a continuum. Tenaz shows "comprehension zone" bands: <90% frustration, 90-95% intensive/with help, 95-98% stretch, >=98% fluency reading. Pick the band by task (fluency reading wants >=98%).
- Domain effect (important for developer learners): the learner already knows a lot of tech vocabulary (API, deploy, latency, repository, bug). Generic frequency lists will under-estimate their coverage on tech texts and over-estimate it on literary ones. The known-word set must therefore be user-specific, seeded from their reviews plus a tech-word seed list they can bulk-mark as known.

### 1.2 Extensive reading (ER) and fluency
- Nation & Waring, Teaching Extensive Reading in Another Language (Routledge, 2020): ER material should have ~2% unknown words and familiar grammar; a speed-reading component is recommended alongside ER (https://www.betterread.com.au/book/teaching-extensive-reading-in-another-language.do).
- Beglar & Hunt: learners reading >200,000 words, mostly simplified text up to 1,600 headwords, had the biggest fluency gains over an academic year (via the search summary of the Nation/Waring literature; primary not opened - [unverified] exact citation details).
- Reading-rate targets of ~150-250 wpm and "1 million words/year" are commonly cited in ER circles, but I could not confirm them to a primary source this session: [unverified]. Tenaz should therefore measure the learner's own wpm and use a relative target: raise by ~10% per month on a book at >=98% coverage, ceiling ~200-250 wpm for comprehension >=75%.
- Practical Tenaz mechanic: a "read-timer" in the book tracker. The learner logs pages/minutes or pastes a 300-word passage in the in-app reader (public-domain/own texts only) -> wpm; a 3-question check -> comprehension. Only wpm with comprehension >=70% counts.
- ER volume goal for ADHD: small, daily, visible. Default 15 min/day (~2,500-3,500 words at 170-230 wpm), displayed as "words read this month" streak that feeds the mascot. [design, no study cited]

### 1.3 Graded reader series and CEFR
Verified facts:
- Oxford Bookworms headwords/CEFR (approximate bands): Starter 250 A1; L1 400 A1/A2; L2 700 A2/B1; L3 1,000 B1; L4 1,400 B1/B2; L5 1,800 B2; L6 2,500 B2/C1. Source: Tri-C library guide https://libguides.tri-c.edu/eslreaders/obl and https://www.oupjapan.co.jp/en/gradedreaders/bookworms.shtml (OUP itself does not publish CEFR bands per stage; bands are third-party approximations).
- Macmillan Readers: Starter 300, Beginner 600, Elementary 1,100, Pre-Intermediate 1,400, Intermediate 1,600, Upper 2,200 headwords (six levels; older guides list five and omit Pre-Int). Tri-C chart: Intermediate B1/B2, Upper B2; ERF chart maps Elem A2, Pre-Int A2/B1, Int B1, Upper Int B2 (sources differ on Intermediate). Source: https://libguides.tri-c.edu/eslreaders/mr Sources: search summary above and https://er-central.com/ERF/ERF_levels.htm .
- Penguin Readers: levels Easystarts, 1-6; Cambridge English Readers: Starters, 1-6 (ERF chart: https://er-central.com/ERF/ERF_levels.htm). Per-level headword counts and CEFR for Penguin/Cambridge: [unverified]. Common convention is Penguin L4 ~ B1/B2, L5 ~ B2, L6 ~ B2/C1 [est].
- The Extensive Reading Foundation levels chart is the cross-publisher reference. Tenaz should store each reader as `series`, `series_level`, `headwords`, `cefr_band`.
- Graded readers top out at ~B2/C1 (2,200-2,500 headwords). For the learner (goal C1), graded readers are a bridge to ~B2; after that, use authentic books (below).

### 1.4 Lexile and CEFR
- There is no official universal Lexile-to-CEFR table. MetaMetrics derived correspondences from nine English tests whose publishers had each done their own CEFR standard-setting, so values vary by test: https://www2.metametricsinc.com/hubfs/Aligning-the-Lexile-Framework-to-the-CEFR-Research-Brief.pdf. Example: Aptis B1 ~805L-985L (teen version); Pearson Level 4 readers B1-B2 at 500-850L (publisher-specific): https://metametricsinc.com/wp-content/uploads/2020/02/Intro-R2-with-RW-changes.pdf.
- Lexile measures text difficulty (sentence length + word frequency) and ignores genre, cohesion, cultural knowledge and idiom; CEFR for a text is a human judgment (https://metametricsinc.com/wp-content/uploads/2018/01/CEFR_1.pdf). Adult trade books often have low Lexile but high conceptual difficulty.
- Decision: do not use Lexile as a key. Store CEFR band + own computed metrics (type/token ratio, mean sentence length, % tokens outside the learner's known set). If Lexile is wanted later, it is display-only and labelled "approximate, publisher-specific".

## 2. Curated recommendation list (35 titles)

Method: the level is my estimate from vocabulary and syntax, genre and typical learner reports, not a published CEFR rating, unless "(graded)" where the series publishes a level. All are [est] and must be verified by the coverage pipeline once the learner's known-word set exists. Check availability yourself; I did not verify current editions.
Interest tags: TECH, STARTUP, AI, PSY, SF, BIO, NEURO, SCI, WORK.

### B1+ (fluency reading, 98% target; graded or very plain authentic)
1. Oxford Bookworms Level 4-5 mystery/thriller picks (e.g., Sherlock Holmes adaptations, The Hound of the Baskervilles retelling) - graded, B1/B2, SF/mystery; plain narrative, builds speed. [est]
2. Penguin/Macmillan Upper-level non-fiction biographies: e.g., a Steve Jobs or Bill Gates graded biography if in catalogue - BIO/TECH; check catalogue. [unverified availability]
3. Oxford Bookworms Factfiles (e.g., science/tech topics) - graded non-fiction, B1-B2, SCI.
4. Cambridge Discovery Readers (Upper Intermediate) - graded, B1/B2, mixed non-fiction. [est]
5. The Giver, Lois Lowry - authentic YA, B1+/B2, SF; short sentences, dystopia, 43k words [est].
6. Harry Potter and the Philosopher's Stone, J. K. Rowling - B2-, FANTASY; huge learner community, audiobook available. NGSL covers ~93% of Harry Potter per NGSL site (https://www.newgeneralservicelist.com/new-general-service-list) - decent proxy for B1+/B2 readability.
7. Holes, Louis Sachar - B1+, plain, plotty; good for streak building. [est]
8. Flowers for Algernon, Daniel Keyes - B1+/B2, SF + neuroscience/intelligence theme; the narrator's English literally gets better through the book (nice for a learner). [est]
9. Ender's Game, Orson Scott Card - B2-, SF, strategy/childhood genius, game-like. [est]
10. Who Moved My Cheese?, Spencer Johnson - B1+, WORK parable; very short, workplace vocabulary. [est]

### B2 (stretch with dictionary tap)
11. Ready Player One, Ernest Cline - B2, SF/TECH culture; heavy 80s references (cultural load, not lexical) [est].
12. The Martian, Andy Weir - B2, SF/engineering; programmer-friendly humor, mild swearing, technical problem-solving chunks. [est]
13. Project Hail Mary, Andy Weir - B2, SF/science; same register as The Martian. [est]
14. The Phoenix Project, Gene Kim et al. - B2, TECH/WORK novel about DevOps; exactly the vocabulary of meetings (outage, deployment, stakeholders, escalate). Top pick for work-focused learners. [est]
15. The Goal, Eliyahu Goldratt - B2, WORK novel on constraints; dated style. [est]
16. Atomic Habits, James Clear - B2, PSY/habits; short chapters, clear structure, ideal for ADHD. [est]
17. Deep Work, Cal Newport - B2, PSY/WORK; relevant to attention; mix of concrete and abstract. [est]
18. The Pragmatic Programmer, Hunt & Thomas - B2, TECH; vocabulary the learner half-knows from code, now in prose. [est]
19. The Lean Startup, Eric Ries - B2, STARTUP; business jargon (pivot, runway, iterate). [est]
20. Zero to One, Peter Thiel - B2/B2+, STARTUP; opinionated, short sentences, abstract claims. [est]
21. Educated, Tara Westover - B2, BIO memoir; narrative, emotional, rich non-technical vocabulary. [est]
22. Surely You're Joking, Mr. Feynman!, Richard Feynman - B2, BIO/SCI; anecdotal, spoken register. [est]

### B2+ (near-authentic, abstract)
23. Shoe Dog, Phil Knight - B2+, BIO/STARTUP founder memoir; business vocabulary and conversational voice. [est]
24. Steve Jobs, Walter Isaacson - B2+/C1-, BIO/TECH; long; read in chunks. [est]
25. Hackers & Painters / Paul Graham essays - B2+, TECH/STARTUP; essays freely online at paulgraham.com - perfect for in-app short reads. [est]
26. Thinking, Fast and Slow, Daniel Kahneman - B2+/C1-, PSY; dense, key vocabulary reusable in discussion (bias, heuristic). [est]
27. Why We Sleep, Matthew Walker - B2+, NEURO/SCI; popular science with cited studies. [est]
28. Behave / Brain-ADHD-adjacent: Driven to Distraction, Hallowell & Ratey - B2+, PSY/ADHD; personally relevant, motivating. [est]
29. The Innovators, Walter Isaacson - B2+, BIO/TECH history. [est]
30. Superintelligence-lite: Life 3.0, Max Tegmark - B2+/C1-, AI; for meetings on AI. [est]
31. The Hard Thing About Hard Things, Ben Horowitz - B2+, STARTUP/WORK; frank, idiomatic, management language. [est]

### C1 (target)
32. Sapiens, Yuval Noah Harari - C1-, SCI/history; abstract nominalizations; excellent for accuracy/cohesion practice. [est]
33. Gödel, Escher, Bach, Hofstadter - C1+/C2, AI/COGSCI; aspirational, not a first C1 book. [est]
34. Range or The Idea Factory - C1-, WORK/TECH history. [unverified titles' fit]
35. Co-Intelligence, Ethan Mollick - B2+/C1-, AI/WORK; recent, practical. [est]
36. The Alignment Problem, Brian Christian - C1, AI; dense. [est]
37. Superforecasting, Tetlock & Gardner - C1-, PSY. [est]

Selection logic per band: B1+ should hit ~98% known; B2 ~95-97%; B2+ ~93-95% with tap; C1 intentionally ~90-93% for short sessions only. Audiobook + text together ("immersion reading") is allowed for lane B because it raises effective comprehension; evidence for assisted reading is mixed [unverified].

## 3. Listening: podcasts and YouTube (comprehensible input ladder)

Verified (from learner-podcast roundups https://plainenglish.com/?p=12457, https://www.fluentu.com/blog/english/learn-esl-english-podcasts/): BBC 6 Minute English (short, vocab list + transcript, intermediate), All Ears English (intermediate-advanced, American English, professional/social skills), Better @ English (intermediate+, transcripts and notes), Plain English (current events, slow-ish authentic). Whether the tech shows below publish transcripts: [unverified] - check each site.

| Level | Show | Why |
|---|---|---|
| B1+ | BBC 6 Minute English | 6 min, transcript, native speakers at slow-ish rate; also BBC Learning English "English at Work" [est] |
| B1+ | All Ears English | American; includes business/meeting expressions |
| B1+/B2 | Better @ English | Transcripts and vocabulary notes |
| B2 | Syntax (web dev), JS Party, Changelog | Tech register the learner needs; fast, informal; transcripts on sites [unverified] |
| B2 | The Daily / NPR Short Wave / Planet Money | Clear studio speech; official transcripts available [unverified] |
| B2+ | Software Engineering Daily, Hanselminutes | Interview style, technical depth [unverified transcripts] |
| B2+/C1 | Lex Fridman Podcast | Long-form AI/science, full transcripts on site [unverified]; very hard for beginners |
| C1 | Huberman Lab, Acquired | Neuroscience / startup case studies; dense, long |
| YouTube B1+ | Rachel's English, English with Lucy, Speak English with Vanessa | accent/phrases; business English playlists |
| YouTube B2 | Fireship (fast, tech), Veritasium, Kurzgesagt, CGP Grey | Visual support lowers load; closed captions human-edited on most |
| YouTube B2+/C1 | Computerphile, Lex clips, Y Combinator talks, Google/Apple developer talks | Real meetings/talks register |

Mechanics for Tenaz (feasible natively): for each episode store `{url, level, minutes, topic, hasTranscript, accent}`. Listening task = 3 min clip, listen, shadow one sentence aloud, mark unknown words -> deck. Transcripts are fetched by the learner (or YouTube captions via their own tools); Tenaz does not redistribute them. Cite listening threshold: 95% suffices for listening per van Zeeland & Schmitt (link in 1.1), so allow harder audio than text.

## 4. Business-English meeting phrasebank (seed deck, ~120 chunks; sample below)

Delivery: chunks with 3 variants by register (casual team standup / formal stakeholder / written Slack). All are my own compilations from common business-English practice; no single source. [est]

- Opening / status: "Quick update on...", "Here's where we are on...", "We're on track / a bit behind / blocked on...", "The main thing to flag is...", "Last week I finished X; this week I'm working on Y; I'm blocked by Z."
- Agreeing: "That makes sense.", "I'm on board with that.", "Fair point.", "I agree, and I'd add that...", "Sounds good to me."
- Disagreeing politely: "I see where you're coming from, but...", "I'm not sure that would work because...", "Could we look at it another way?", "I have a slightly different take.", "My concern is that..."
- Interrupting: "Sorry to jump in, but...", "Can I add something here?", "Just a quick point on that.", "May I finish my point?" (to be interrupted less).
- Clarifying: "Just to make sure I understand, you're saying...", "Could you say that again?", "What do you mean by...?", "Do you mean X or Y?", "Let me rephrase that."
- Buying time: "Let me think about that.", "Good question, let me get back to you after checking.", "I don't have the number at hand; I'll follow up by email."
- Presenting: "Let me walk you through...", "As you can see on this slide...", "To sum up...", "The key takeaway is...", "Any questions so far?"
- Closing / action items: "So the next steps are...", "Who can take that on?", "I'll send a summary after this call.", "Let's circle back on this next week."
- Repair when lost (for a non-native speaker, highest value): "I lost you at...", "Could you slow down a little?", "Could you share your screen / paste it in the chat?"

Why chunks: The learner's profile is fluent-but-inaccurate, so formulaic sequences give accurate production under time pressure. Drill method: cloze in the deck, then a Claude-driven role-play ("you are the Product Owner, I report status, disagree with me once") run through the `claude` CLI; transcript gets graded on accuracy/cohesion. Role-play is optional and the phrasebank works fully offline.

## 5. Open data Tenaz can bundle

| Resource | Use in Tenaz | License | Source / format | Notes |
|---|---|---|---|---|
| Tatoeba sentences | example sentences, listening, cloze | CC BY 2.0 FR (a subset CC0); audio varies per contributor, reuse only if license field set | https://downloads.tatoeba.org/exports/ weekly (Saturdays 06:30 UTC); TSV: `sentences`: id, lang, text; `links`: id, translation_id; `tags`; `sentences_with_audio` (id, audio id, user, license, attribution URL) | Per https://tatoeba.org/en/downloads. Attribute Tatoeba contributors. Prefer the CC0 export when it covers needs. Do not bundle audio unless license is explicit. |
| NGSL 1.2 (2,809 words) | core vocabulary levels, coverage computing | CC BY-SA 4.0 (other permissions via charlie-browne.com) | https://www.newgeneralservicelist.com/new-general-service-list : `/s/NGSL_12_stats.csv`, lemmatized teaching/research CSVs, English definitions xlsx; also NGSL-S supplementary 52 words | ~92% general English coverage; 93% Harry Potter, 94% TOEIC, 95% TV (same page). ShareAlike: derived word-list files must stay CC BY-SA; app code can stay separate if lists are separate data files. |
| SUBTLEX-US | spoken-frequency ranks | OSF page says "Other"; wordfreq notice says Brysbaert allowed any-purpose redistribution of the SUBTLEX lists with credit (that notice covers -CH/-DE/-NL; US is indirect) | https://osf.io/djpqz ; https://github.com/words/subtlex-word-frequencies (wrapper) | [unverified] for redistribution of US list. Safer: download at first run or ask Brysbaert. Cite Brysbaert & New 2009 (Behav Res Methods 41, 977-990). |
| CMU Pronouncing Dictionary | IPA/ARPAbet for pronunciation drills | Copyright CMU; "research and commercial use completely unrestricted"; credit CMU on redistribution | https://github.com/cmusphinx/cmudict `cmudict.dict` | Per repository README (fetched). US pronunciation only. |
| WikDict (en-es) | offline bilingual lookup | CC BY-SA 4.0 data (from Wiktionary via DBnary); code MIT | https://www.wikdict.com/page/about ; en-es at /en-es/ ; downloads at /page/download (formats not confirmed - typically SQLite) [unverified format] | Attribute Wiktionary/DBnary. |
| Wiktionary (raw) | definitions, IPA, etymology | CC BY-SA (and GFDL) | Kaikki.org Wiktextract JSON dumps [unverified URL, verify] | Heavier; use WikDict for size. |
| FreeDict eng-spa | offline bilingual | GPL typically [unverified]; site fetch failed (certificate error) | https://freedict.org/ (TEI/StarDict/dict.org) | GPL is risky for bundling; use only if license verified. WikDict preferred. |
| Princeton WordNet 3.0/3.1 | synonyms, senses | Permissive (attribution, copyright notice kept) - license page returned 403 so [unverified] this session; widely known as BSD-like | https://wordnet.princeton.edu/ | Verify text before shipping; OMW republishes it. |
| Open Multilingual Wordnet | Spanish senses linked to English | "Open: freely used, modified, shared for any purpose"; cite individual wordnets and Bond & Paik 2012; per-wordnet licenses differ and I did not confirm the Spanish one | https://omwn.org/ ; browse licenses at https://cygnet.maudslay.eu ; source https://github.com/omwn/omwn.github.io | Check Spanish (MCR) license text before bundling. [unverified] |
| CEFR-J Wordlist (v1.5/1.6) | CEFR level per word (A1-B2) | Dataset free for research and commercial use with citation per Open Language Profiles repo; exact text on cefr-j.org not seen | https://github.com/openlanguageprofiles/olp-en-cefrj ; https://cefr-j.org (official) | Cite: "The CEFR-J Wordlist Version 1.5, compiled by Yukio Tono, Tokyo University of Foreign Studies." Stops at B2; supplement with NGSL/Oxford-free lists for C1. [unverified] license text |

Not to bundle: Oxford 3000/5000 (Oxford copyright), Cambridge English Vocabulary Profile data (terms restrict redistribution) [unverified], any book text beyond public-domain, YouTube/podcast transcripts.

Bundling plan: ship a SQLite file `tenaz-data.sqlite` built by a script in the repo (`scripts/build-data.sh`) that downloads sources on the dev machine, records source URL, version/date and licence in a `sources` table, and shows an in-app "Credits & licences" screen (attribution is required by CC BY and CC BY-SA). Keep CC BY-SA data in separate tables/files from original app content to contain share-alike.

## 6. Recommendation engine

### 6.1 Inputs
- `level`: estimated CEFR as a number (B1+ = 3.5, B2 = 4.0, C1 = 5.0), updated from exam and review performance.
- `known_set`: lemma set + per-lemma retrievability from FSRS (Tenaz already plans FSRS).
- `interests`: weighted tags (TECH 1.0, AI 0.9, STARTUP 0.8, PSY 0.7, NEURO 0.7, SF 0.6, BIO 0.6...) editable, plus implicit weights from finished/abandoned items.
- `reading_wpm`, `comprehension_pct` (section 1.2).
- `history`: finished/abandoned/in progress books, with dates, rating 1-5, abandonment page.
- `time_budget_today` (minutes) and `meeting_calendar_hint` (optional: a technical meeting tomorrow -> boost phrasebank and relevant podcast). Calendar read is optional and local.

### 6.2 Item catalogue
`Item { id, type: book|podcast|video|article, title, cefr_band, topics[], words|minutes, coverage_profile: {pct_known per band} (precomputed for books if text is available to the learner locally), genre, lane: A|B, accent, hasTranscript }`.
Coverage is computed on the learner's machine from a text the learner owns (an ePub they loaded) and stored; the app never ships the text.

### 6.3 Scoring
score = 0.35 * fit + 0.25 * interest + 0.15 * novelty + 0.15 * goal + 0.10 * momentum - penalties
- fit = 1 - |coverage - target| / 0.08, clipped to [0,1]; target = 0.98 lane A, 0.95 lane B; for items without a coverage profile use band distance |level - item_level| (ideal 0 for A, +0.5 for B).
- interest = dot(interest weights, topics) normalised.
- novelty = 1 if new genre/author vs last 3 items, else 0.3.
- goal = overlap of item topics with "work-meeting" tags (workplace, DevOps, product, incident, standup).
- momentum = item length fit (finish within 2-3 weeks at current wpm and time budget): lengthDays = words / (wpm * minutes_per_day).
- penalties: abandoned same author -0.3; length > 6 weeks -0.3; lane B already in progress -1 (one at a time).
- Output: ranked list; show top 3 with a one-line "why" built from template (e.g., "You know ~96% of the words; it's about startups; 9 days at your pace.").

### 6.4 Adaptive loop
- Level update: finished book with comprehension >=75% and pace >= target -> raise reading level by 0.1; abandoned at coverage <92% -> lower band for that lane by 0.1 and recompute.
- Abandonment is data, not failure: Tenaz asks "Too hard / boring / no time?" (1 tap) and adjusts accordingly. This respects the "never lock the learner out" principle: no penalty for abandoning a book, only for skipping the daily review (per DECISIONS.md the punishments are self-chosen commitment devices).
- Cold start (day 1): the assumed B1+ starting level, interest seed above, 5 books suggested from section 2 B1+/B2 groups, and a 300-word sample read to measure wpm.

### 6.5 Explainability and ADHD fit
Always one primary recommendation plus two alternates (reduces choice paralysis); "start with 5 minutes" button; show finish-time estimate in days, not pages.

## 7. "Knowledge recommendations" feature

Goal: connect English practice to things worth knowing (a stated learner wish: "recommendations of books and knowledge").
- Source of knowledge items: curated JSON in the repo: ~200 short "knowledge cards" in English across TECH, AI, PSY, NEURO, STARTUP (e.g., "What is technical debt", "Dunning-Kruger", "How spaced repetition works"), each 120-200 words written at B1+/B2 and tagged with target vocabulary. Written by Claude via CLI with a human-curated quality check; no scraped text.
- Daily "Brain bite": one card, read aloud/shown big, 3 target words auto-added to the deck, 1 question that requires the learner to use a word in a sentence about their own work (ties to the unlock-writing mechanic).
- Link outward: each card ends with "Go deeper" -> a book/podcast from the catalogue (section 2/3) that best matches the topic and the learner's level (reuses the scoring in 6.3). This is the discovery channel for the books.
- Freshness: weekly "tech news in plain English" = the learner-selected RSS (e.g., Hacker News front page, Ars Technica) -> Claude rewrites the headline + 3 sentences at the learner's level, flagged as simplified. Rewriting is for private study only; keep source link and do not redistribute.
- Quality gates: reject cards with >5% words outside level+1, verified by the coverage tool; mark Claude-generated facts "check source" because LLM facts can be wrong [no external source needed, standard caveat].

## 8. Implementation notes for the Swift code (TenazCore)

- `LexicalCoverage` service: tokenise (NLTokenizer), lemmatise (NaturalLanguage `NLTagger` `.lemma`), compare to `known_set`; returns % known and unknown list sorted by frequency.
- Data layer: SQLite via GRDB or SwiftData [decision for the engineering doc]; tables `lemma`, `frequency`, `cefr`, `sentence`, `translation`, `source`, `catalogue_item`, `reading_log`.
- Book intake: user adds ePub/PDF/plain text path; Tenaz parses locally (ePub unzip + XHTML strip); text never leaves the Mac. For Claude features send only short excerpts through the CLI, with `ANTHROPIC_API_KEY` removed, per DECISIONS.md.
- Tests: golden-file tests for coverage, scoring monotonicity (higher interest -> higher score at equal fit), and cold-start list determinism.

## 9. Open questions / things to verify before relying on this
1. Exact CEFR/headword table for Penguin Readers and Cambridge English Readers (publisher sites or the Meiji chart https://www.meiji.ac.jp/library/search/6t5h7p00002jyih0-att/HP_readinglevelchart_2.pdf).
2. Licence text of CEFR-J on cefr-j.org, Spanish wordnet inside OMW, FreeDict en-spa, SUBTLEX-US.
3. Whether the listed tech podcasts publish full transcripts.
4. Primary sources for reading-rate targets (Nation & Waring chapter on fluency) and for Beglar & Hunt.
5. Every book level in section 2 is an estimate until measured with the learner's coverage tool.
6. Present availability/editions of each title (not checked).

## 10. Sources fetched this session
- Tatoeba downloads: https://tatoeba.org/en/downloads
- NGSL: https://www.newgeneralservicelist.com/new-general-service-list
- WikDict: https://www.wikdict.com/page/about
- CMU dict: https://github.com/cmusphinx/cmudict
- OMW: https://omwn.org/
- ERF levels: https://er-central.com/ERF/ERF_levels.htm
- Nation 2006: https://www.wgtn.ac.nz/__data/assets/pdf_file/0018/1626120/2006-How-large-a-vocab.pdf
- Lexile/CEFR: https://www2.metametricsinc.com/hubfs/Aligning-the-Lexile-Framework-to-the-CEFR-Research-Brief.pdf
- CEFR-J (secondary): https://github.com/openlanguageprofiles/olp-en-cefrj
- WordNet licence page returned HTTP 403; FreeDict fetch failed on a certificate error.

## Verification
Checked 2026-10-22 against primary pages. Verdicts: C = confirmed, X = corrected, U = unverifiable.

| # | Claim | Verdict | Source |
|---|---|---|---|
| 1 | Nation 2006: 98% needs 8-9k families (written), 6-7k (spoken) | C. Corrected detail: it is "plus proper nouns", novels 8-9k not flat 9k; earlier note said only abstract seen, full PDF now read | https://www.wgtn.ac.nz/__data/assets/pdf_file/0018/1626120/2006-How-large-a-vocab.pdf |
| 2 | Schmitt, Jiang & Grabe 2011: n=661, roughly linear, no threshold, 98% sensible for academic text | C | https://experts.nau.edu/en/publications/the-percentage-of-words-known-in-a-text-and-reading-comprehension/ |
| 3 | Kremmel et al. 2023 replication had 104 learners | U. Replication exists (Sri Lanka, Language Learning 2023) and questions a single threshold; n not found. Marked [unverified] | https://www.uibk.ac.at/de/ifd/sprachen/aktuelles/unbekanntes-vokabular/ |
| 4 | Hu & Nation 2000 n=66 | U (not checked) | none |
| 5 | TOEFL iBT listening: 3,000 families for 95%, 6,000 for 98% | C (3,000 includes proper nouns and marginal words) | https://jalt-publications.org/tlt/articles/4281-vocabulary-size-required-toefl-ibt-listening-section |
| 6 | Oxford Bookworms headwords/CEFR table | C (all seven rows match; third-party bands) | https://libguides.tri-c.edu/eslreaders/obl |
| 7 | Macmillan Readers headwords | X. Missing Pre-Intermediate 1,400; Intermediate is B1/B2 in Tri-C | https://libguides.tri-c.edu/eslreaders/mr |
| 8 | NGSL 1.2: 2,809 words, CC BY-SA 4.0, ~92% general, 93% Harry Potter, 94% TOEIC, 95% TV | C | https://www.newgeneralservicelist.com/new-general-service-list |
| 9 | Tatoeba: CC BY 2.0 FR, CC0 subset, weekly Saturday 06:30 UTC, TSV columns, audio license per contributor | C | https://tatoeba.org/en/downloads |
| 10 | CMU dict: unrestricted use, credit requested; WikDict data CC BY-SA, code MIT | C. CMU credit is a request ("we request"), not a strict condition; copyright 1993-2014 | https://github.com/cmusphinx/cmudict ; https://www.wikdict.com/page/about |

Not re-checked (remain [unverified] as in the text): WordNet license, SUBTLEX-US redistribution, CEFR-J license, OMW Spanish license, Lexile figures, podcast transcripts.

## Gaps found in verification
- The coverage thresholds (98%/95%) are for word families; Tenaz computes on lemmas via NLTagger, which counts fewer variants as known, so coverage will read lower than literature figures. Calibrate the bands or use a family-grouping step.
- Proper nouns: Nation's figures are "plus proper nouns". The LexicalCoverage service should treat capitalised names as known, or coverage is understated for novels.
- CC BY-SA NGSL and Wiktionary data bundled in one `tenaz-data.sqlite` may make the whole database share-alike; ship separate files (the plan says separate tables, separate files is safer).
- The Tatoeba main export is CC BY 2.0 FR, requiring per-contributor attribution, which in-app credits must cover; the CC0 export avoids this.
- Macmillan/Bookworms CEFR bands are third-party and differ by source; store them as ranges, not single values.
