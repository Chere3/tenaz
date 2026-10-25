"""P3 listenTalk: 180-250 word spoken lectures, generated (adapted from OpenStax / OneStopEnglish seeds, or from a
business/operations topic matrix).

Commands (run with -I from the tenaz root; there is no network step, seeds come from earlier stages):
  extract --stage .ingest/stage/gen-talk --report .ingest/reports/gen-talk.md [--content Content]
      builds rows.jsonl (scenario rows) and batches/batch-NN.jsonl (25-50 rows each) for the LLM fill.
  emit    --stage .ingest/stage/gen-talk --content Content --report .ingest/reports/gen-talk.md
      reads .ingest/stage/gen-talk/filled/*.jsonl (LLM output, see FILL_SHAPE), shuffles options, validates,
      dedupes and writes Content/items/listen-talk-gen.json and listen-talk-gen-ose.json (+ licenses.json).

Seeds:
  - OpenStax paragraphs with share == "other" (never the 30% completeWords share), further limited to a hash
    bucket 0-4 of 10 so a readAcademic/summary converter can use buckets 5-9. License CC BY 4.0, origin adapted.
  - OneStopEnglish windows not used by complete-words-ose (CC BY-SA 4.0, share-alike -> separate *-ose file).
  - Matrix rows: business / operations topics (TOPICS below), origin generated.

LLM fill row shape (one JSON per line in filled/*.jsonl):
  {"rowId": "...", "title": "...", "script": "...", "questions": [
      {"q": "...", "correct": "...", "distractors": ["...", "...", "..."], "explanation": "..."} x4 ]}
"""
from __future__ import annotations

import argparse
import hashlib
import json
import random
import re
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib import dedupe, emit as emitlib, ids, schema, textnorm  # noqa: E402

SOURCE = "gen-talk"
OUT_GEN = "listen-talk-gen.json"
OUT_OSE = "listen-talk-gen-ose.json"
OPENSTAX_URL = "https://huggingface.co/datasets/HuggingFaceTB/openstax_paragraphs"
OSE_URL = "https://github.com/nishkalavallabhi/OneStopEnglishCorpus"
N_OPENSTAX, N_OSE = 185, 40
PER_BOOK_CAP = {"Biology 2e": 12, "Concepts of Biology": 8}  # biology is plentiful but less useful for the target learner

SENSITIVE = re.compile(
    r"\b(sex|sexual\w*|rape\w*|suicid\w*|genital\w*|porn\w*|abus\w+|assault\w*|molest\w*|kill\w*|murder\w*|cocaine|"
    r"heroin|opioid\w*|addict\w*|racis\w+|slave\w*|genocide|terroris\w+|abortion\w*|weapon\w*|gun|guns|pregnan\w*|"
    r"contracepti\w*|nude|naked|fetus\w*|torture\w*|hitler|nazi\w*|holocaust|embryo\w*|war|wars|dead|death|die|"
    r"drug|drugs|prison\w*|crime\w*|criminal\w*|police|riot\w*|asylum|refugee\w*|religio\w*)\b", re.I)

SETTINGS = ["a university lecture to second-year students", "an in-house training session for new planners",
            "a webinar for supply chain and operations professionals", "a workshop for team leads",
            "a short talk at a company learning day", "a guest lecture in a business course"]
ASIDES = ["a quick personal anecdote (\"I once worked with...\")", "a rhetorical question to the audience",
          "a light, dry joke or understatement", "a short analogy from daily life (cooking, traffic, a supermarket)",
          "a brief correction of a common misunderstanding (\"people often think... but\")",
          "a small digression that the speaker then closes (\"anyway, back to the point\")"]
Q4 = ["inference: what the speaker implies but does not say directly",
      "attitude: the speaker's opinion or feeling about something",
      "organization: how a part of the talk relates to the rest, or what the speaker will probably cover next",
      "implication: what a listener in the audience should do or expect, based on the talk"]
CEFRS = ["B1+"] * 5 + ["B2"] * 6 + ["B2+"] * 4 + ["C1"] * 5  # 25 / 30 / 20 / 25 %

# (key, topic, focus). Each focus is a distinct angle so no two lectures cover the same ground.
TOPICS = [
    # supply chain basics
    ("bullwhip", "The bullwhip effect", "why small changes in retail demand become huge swings upstream, and two practical fixes"),
    ("leadtime-vs-cycle", "Lead time versus cycle time", "people use the two terms loosely; what each one measures and why mixing them causes planning errors"),
    ("safety-stock", "Safety stock", "what it protects against, the trade-off between service level and cash tied up, and why more is not always safer"),
    ("reorder-point", "The reorder point", "how demand during lead time and variability set the trigger, using a simple worked example"),
    ("abc-classification", "ABC classification of inventory", "why 20 percent of items drive most of the value and how that changes how you manage each class"),
    ("dual-sourcing", "Single versus dual sourcing", "cost, risk and relationship trade-offs when depending on one supplier"),
    ("lead-time-variability", "Supplier lead-time variability", "why the average lead time matters less than how unpredictable it is"),
    ("incoterms-risk", "Who owns the risk in transit", "the idea behind delivery terms: the point where responsibility and risk pass from seller to buyer"),
    ("cold-chain", "The cold chain", "keeping temperature-sensitive goods within range from factory to customer, and where it usually breaks"),
    ("lot-traceability", "Batch and lot traceability", "why being able to find exactly where a batch went matters, with a recall-style thought experiment"),
    ("inventory-turns", "Inventory turns", "how to calculate them, what a high or low number can hide, and why comparing across industries misleads"),
    ("days-of-supply", "Days of supply", "turning a stock number into a time number so non-planners understand the risk"),
    ("backorder-stockout", "Backorders versus stockouts", "same shortage, different customer experience, and what each costs"),
    ("vmi", "Vendor-managed inventory", "when letting the supplier manage your stock works and when it only moves the problem"),
    ("risk-mapping", "Mapping supply risk", "ranking suppliers by impact and likelihood rather than by gut feeling"),
    ("end-to-end-visibility", "End-to-end visibility", "why seeing the whole chain matters more than optimising one link"),
    ("transport-modes", "Choosing a transport mode", "air versus sea versus road as a trade-off between cost, speed and reliability"),
    ("customs-delays", "Why shipments get stuck at customs", "the usual causes (paperwork, classification, inspection) and how planners build a buffer"),
    # pharma-flavoured operations
    ("batch-release", "Batch release and quality holds", "why a finished batch cannot ship until quality approves it, and what that does to planning"),
    ("deviations-capa", "Deviations and corrective actions", "what counts as a deviation, why root cause matters more than the quick fix, and how follow-up works"),
    ("fefo-shelf-life", "Shelf life and first-expired-first-out", "why the oldest stock should leave first and how short remaining shelf life affects what you can sell"),
    ("documentation", "\"If it isn't written down, it didn't happen\"", "why regulated industries insist on documentation and how to write a record someone else can trust"),
    ("capacity-bottleneck", "Capacity and bottlenecks in manufacturing", "how one slow step limits a whole plant and why adding capacity elsewhere does nothing"),
    ("allocation-shortage", "Allocating a short product", "fair ways to ration limited supply between customers and how to explain the decision"),
    ("launch-planning", "Planning a product launch", "forecasting with no history, the risk of stocking too much or too little, and staged build-up"),
    ("expiry-writeoff", "Expiry and write-offs", "why stock that expires is a planning failure that shows up months later"),
    ("tech-transfer", "Moving production to a new site", "what has to be proven before the new site is allowed to supply, and how long it really takes"),
    # forecasting
    ("mape-bias", "Forecast accuracy and bias", "the difference between being wrong in both directions and being consistently wrong in one direction"),
    ("forecast-value-add", "Forecast value added", "testing whether each human adjustment actually improves on the statistical forecast"),
    ("moving-average", "Moving averages and exponential smoothing", "how recent data is weighted, in plain language and without formulas"),
    ("seasonality", "Seasonality", "separating a regular yearly pattern from real growth, with a coat-sales or flu-season style example"),
    ("analogue-forecast", "Forecasting a new product with analogues", "borrowing the history of similar products and its limits"),
    ("consensus-forecast", "Building a consensus forecast", "how sales, finance and operations numbers differ and how to reconcile them"),
    ("demand-sensing", "Demand sensing", "using very recent signals to correct a short-term forecast"),
    ("frozen-window", "The frozen horizon", "why you stop changing the plan close to execution, and the cost of changing it anyway"),
    ("outliers-promotions", "Outliers and one-off events", "cleaning history without erasing information that will happen again"),
    ("aggregation-pooling", "Forecasting at the right level", "why a total is easier to forecast than its parts and how to split it back down"),
    ("optimism-bias", "Optimism in sales forecasts", "why targets and forecasts are not the same thing and how to keep them apart"),
    ("probabilistic-forecast", "Forecasting with ranges", "giving a range and a probability instead of a single number, and how that changes inventory decisions"),
    ("intermittent-demand", "Intermittent demand", "items that sell rarely and irregularly, and why normal methods fail"),
    ("shipments-vs-demand", "Shipments are not demand", "forecasting what customers wanted versus what you happened to ship when stock was short"),
    # planning, S&OP
    ("sop-steps", "The sales and operations planning cycle", "the monthly rhythm from data to demand review to supply review to executive decision"),
    ("gap-meeting", "Closing the demand-supply gap", "options when demand exceeds supply: speed up, shift, ration, or change the target"),
    ("mrp-basics", "How material requirements planning works", "turning a demand plan into purchase orders through a bill of materials, in everyday terms"),
    ("scenario-planning", "Scenario planning", "preparing two or three plausible futures instead of betting on one"),
    ("otif", "On time, in full", "how OTIF is measured, why a tough definition can hide good performance, and what to ask before comparing numbers"),
    ("planning-parameters", "Planning parameters that quietly go stale", "lead times, minimum order quantities and lot sizes in the system that no longer match reality"),
    ("master-data", "Master data quality", "how one wrong field in a system creates months of bad orders"),
    ("exec-sop", "Presenting to executives", "what senior leaders need from a planning update: the decision, the risk and the options"),
    # lean
    ("seven-wastes", "The seven wastes", "waiting, overproduction, transport and the rest, and how to spot them in an office process"),
    ("five-s", "5S", "a tidy workplace as the base for everything else in lean"),
    ("kanban", "Kanban", "a pull signal instead of a forecast, and when it works"),
    ("value-stream", "Value stream mapping", "drawing a process to see how little of the elapsed time adds value"),
    ("kaizen", "Kaizen", "small continuous improvements by the people doing the work"),
    ("takt-time", "Takt time", "the pace of customer demand and how it differs from how fast you can work"),
    ("poka-yoke", "Poka-yoke, or mistake-proofing", "designing a process so the error is impossible or obvious"),
    ("gemba", "Go to the gemba", "why managers should see the real place where work happens before deciding"),
    ("jit-tradeoff", "Just-in-time and its fragility", "low stock saves money until something goes wrong"),
    ("theory-constraints", "The theory of constraints", "find the one bottleneck, protect it, and only then improve anything else"),
    ("five-whys", "Asking why five times", "reaching a root cause and not stopping at the first plausible answer"),
    ("smed", "Quick changeovers", "cutting the time to switch a line between products and why that enables smaller batches"),
    ("heijunka", "Levelling the workload", "smoothing production over time instead of following every spike in orders"),
    ("batch-size", "Why small batches flow faster", "a simple envelope-stuffing example of batch size and waiting time"),
    # negotiation
    ("batna", "Your best alternative", "knowing your walk-away option before you start, and how it sets your power"),
    ("anchoring-neg", "Making the first offer", "who should name a number first and how to respond to an extreme opening"),
    ("interests-positions", "Interests behind positions", "asking why a supplier insists on a price before arguing about the price"),
    ("trade-concessions", "Trading rather than conceding", "never giving something without asking for something in return"),
    ("integrative-deal", "Expanding the pie", "finding extra issues (payment terms, volumes, timing) so both sides gain"),
    ("silence-neg", "The power of a pause", "why staying quiet after an offer often works better than talking"),
    ("price-increase", "Responding to a supplier price increase", "questions to ask, evidence to request and options short of accepting"),
    ("saying-no", "Saying no without damaging the relationship", "polite, firm ways to decline and offer an alternative"),
    ("deadlines-neg", "Deadlines in negotiation", "how real and artificial deadlines shape concessions"),
    ("preparing-walkaway", "Preparing for a negotiation", "targets, limits and priorities written down before the meeting"),
    ("emotions-neg", "Emotions at the table", "staying calm when the other side is angry and naming the feeling"),
    ("cross-cultural-neg", "Negotiating across cultures", "directness, hierarchy and time, and why the same sentence lands differently"),
    ("long-term-supplier", "Negotiating with a supplier you need for ten years", "why winning every point can lose the relationship"),
    # behavioural economics
    ("loss-aversion", "Loss aversion", "why losing 100 hurts more than gaining 100 feels good, and how it shapes business decisions"),
    ("anchoring-bias", "Anchoring in estimates", "how an arbitrary first number pulls everyone's estimate towards it"),
    ("sunk-cost", "The sunk cost fallacy", "why teams keep funding a failing project because of what they already spent"),
    ("default-effect", "The power of defaults", "why people accept the pre-selected option, and how designers use that"),
    ("framing", "Framing", "the same facts described as 90 percent success or 10 percent failure"),
    ("planning-fallacy", "The planning fallacy", "why projects take longer than planned and how to correct with outside data"),
    ("status-quo", "Status quo bias", "why change is resisted even when the new option is better"),
    ("confirmation-bias", "Confirmation bias in analysis", "looking for data that supports what we already believe"),
    ("overconfidence", "Overconfidence", "why our ninety percent ranges are usually far too narrow"),
    ("present-bias", "Present bias", "preferring a smaller reward now, and what it means for saving and for fixing process problems"),
    ("choice-overload", "Choice overload", "when more options lead to worse decisions or no decision"),
    ("endowment-effect", "The endowment effect", "valuing what we own more highly than what we could buy, even in a negotiation"),
    ("nudges", "Nudges at work", "small changes in how choices are presented that improve decisions without forbidding anything"),
    ("availability", "The availability heuristic", "judging risk by what comes to mind easily, such as the last big incident"),
    ("herd-behaviour", "Herd behaviour", "why people copy others in markets and in meetings"),
    ("scarcity-mindset", "Scarcity and attention", "how having too little time or money narrows thinking"),
    # meetings, stakeholders, communication
    ("effective-meeting", "Running a meeting that ends on time", "purpose, agenda, owner for each decision and a clear close"),
    ("escalation", "When and how to escalate", "raising a problem early, with facts and options, without blaming anyone"),
    ("stakeholder-map", "Mapping stakeholders", "power and interest, and who needs to hear what"),
    ("status-update", "Writing a status update people read", "lead with the answer, then the risk, then the ask"),
    ("saying-dont-know", "Admitting \"I don't know\" in a meeting", "how to say it credibly and promise a follow-up"),
    ("clarifying-questions", "Asking clarifying questions on a call", "checking you understood without sounding unprepared"),
    ("polite-disagreement", "Disagreeing politely", "phrases and structure for challenging an idea while respecting the person"),
    ("raci", "Who is responsible? RACI", "making roles explicit to avoid both duplicated work and dropped tasks"),
    ("managing-up", "Managing up", "helping your manager decide by giving options and a recommendation"),
    ("async-vs-sync", "Meeting or message?", "choosing between a call and a written update across time zones"),
    ("action-items", "Writing action items", "owner, action, date: and why vague notes mean nothing happens"),
    ("video-call-etiquette", "Speaking up on video calls", "turn-taking, interrupting politely and being heard in a multilingual meeting"),
    ("blameless-review", "Blameless post-mortems", "looking at the system rather than the person after something went wrong"),
    ("handover", "A good handover", "what to document before going on holiday so the team is not blocked"),
    ("giving-feedback", "Giving feedback to a colleague", "specific, timely and about behaviour, with an example"),
    # data, analysis, decisions
    ("data-quality", "Data quality in dashboards", "how missing or duplicated records quietly distort a report"),
    ("goodharts-law", "When a measure becomes a target", "how people optimise the number instead of the goal"),
    ("pareto", "The Pareto principle in problem solving", "fixing the few causes that create most of the problems"),
    ("variability", "Variability is the enemy", "why an average hides the swings that actually cause shortages"),
    ("littles-law", "Little's law", "the link between work in progress, throughput and waiting time, shown with a queue"),
    ("control-chart", "Telling signal from noise", "using a control chart idea to know when a change is real"),
    ("root-cause", "Symptoms versus root causes", "why fixing the symptom brings the problem back"),
    ("make-vs-buy", "Make or buy", "the cost, control and risk factors in the decision"),
    ("total-cost-ownership", "Total cost of ownership", "why the cheapest price is rarely the cheapest option"),
    ("opportunity-cost", "Opportunity cost", "the hidden price of the choice you did not make"),
    ("cost-of-delay", "The cost of delay", "putting a number on waiting, to prioritise projects"),
    ("decision-matrix", "A weighted decision matrix", "scoring options on agreed criteria and what it does and does not prove"),
    ("risk-register", "Keeping a risk register", "likelihood, impact, owner and the action that reduces it"),
    ("change-management", "Why change projects fail", "the people side of rolling out a new tool or process"),
    ("contract-basics", "Reading a supply contract", "the clauses planners should know: volumes, lead times, penalties and force majeure"),
]


def _h(*parts: str) -> int:
    return int(hashlib.sha256("|".join(parts).encode()).hexdigest(), 16)


def _common(key: str) -> dict:
    h = _h("gen-talk", key)
    return {"voice": "female" if h % 2 == 0 else "male", "cefr": CEFRS[(h >> 4) % len(CEFRS)],
            "setting": SETTINGS[(h >> 8) % len(SETTINGS)], "aside": ASIDES[(h >> 12) % len(ASIDES)],
            "q4": Q4[(h >> 16) % len(Q4)]}


def _read(p: Path):
    return [json.loads(l) for l in p.read_text(encoding="utf-8").splitlines() if l.strip()]


def cmd_extract(a):
    stage, content = Path(a.stage), Path(a.content)
    stage.mkdir(parents=True, exist_ok=True)
    rej = Counter()
    idx = dedupe.DedupeIndex.from_content(content, threshold=0.7)
    # the generated output of an earlier run must not dedupe against itself
    for f in (OUT_GEN, OUT_OSE):
        (content / "items" / f).unlink(missing_ok=True)
    idx = dedupe.DedupeIndex.from_content(content, threshold=0.7)
    rows: list[dict] = []

    # ---- OpenStax seeds
    cw_used = set()
    for f in (content / "items").glob("complete-words-openstax.json"):
        cw_used |= {x["sourceId"] for x in json.loads(f.read_text(encoding="utf-8"))}
    ox = _read(Path(a.openstax) / "paragraphs.jsonl")
    pool = []
    for r in ox:
        if r["share"] != "other":
            rej["openstax: completeWords share"] += 1
        elif _h("lt-bucket", r["sourceId"]) % 10 >= 5:
            rej["openstax: hash bucket 5-9 reserved for other converters"] += 1
        elif r["sourceId"] in cw_used:
            rej["openstax: used by completeWords"] += 1
        elif SENSITIVE.search(r["text"]):
            rej["openstax: sensitive word"] += 1
        else:
            pool.append(r)
    pool.sort(key=lambda r: (-(r["boost"] + 0.6 * r["workplace"]), r["sourceId"]))
    per_book, sections = Counter(), set()
    n = 0
    for r in pool:
        if n >= N_OPENSTAX:
            break
        sec = (r["book"], r["chapter"], r["section"])
        if sec in sections:
            rej["openstax: one seed per section"] += 1
            continue
        if per_book[r["book"]] >= PER_BOOK_CAP.get(r["book"], 60):
            rej["openstax: per-book cap"] += 1
            continue
        key = r["sourceId"]
        why = idx.check_and_add("lt-openstax-" + key, r["text"])
        if why:
            rej["openstax: dedupe vs Content/"] += 1
            continue
        sections.add(sec)
        per_book[r["book"]] += 1
        n += 1
        group = "openstax:" + hashlib.sha256(f'{r["book"]}|{r["chapter"]}|{r["section"]}'.encode()).hexdigest()[:10]
        rows.append({"rowId": "openstax-" + key, "kind": "seed", "outFile": OUT_GEN, "source": "openstax",
                     "sourceId": key, "group": group, "origin": "adapted", "license": "CC BY 4.0", "tier": "permissive",
                     "topics": [r["topic"]] + (["workplace"] if r["workplace"] >= 0.15 else []),
                     "seed": {"book": r["book"], "section": r["section"], "text": r["text"]},
                     "topic": r["section"], "focus": None, **_common("openstax-" + key)})

    # ---- OneStopEnglish seeds (share-alike)
    ose_used = set()
    for f in (content / "items").glob("complete-words-ose.json"):
        ose_used |= {x["sourceId"] for x in json.loads(f.read_text(encoding="utf-8"))}
    wins = _read(Path(a.ose) / "windows.jsonl")
    wins.sort(key=lambda r: (-r["workplace"], r["sourceId"]))
    arts, n = set(), 0
    for r in wins:
        if n >= N_OSE:
            break
        if r["sourceId"] in ose_used:
            rej["ose: used by completeWords"] += 1
        elif r["article"] in arts:
            rej["ose: one seed per article"] += 1
        elif SENSITIVE.search(r["text"]):
            rej["ose: sensitive word"] += 1
        elif idx.check_and_add("lt-ose-" + r["sourceId"], r["text"]):
            rej["ose: dedupe vs Content/"] += 1
        else:
            arts.add(r["article"])
            n += 1
            rows.append({"rowId": "ose-" + r["sourceId"], "kind": "seed", "outFile": OUT_OSE, "source": "onestopenglish",
                         "sourceId": r["sourceId"], "group": "ose:" + r["article"], "origin": "adapted",
                         "license": "CC BY-SA 4.0", "tier": "share-alike", "topics": ["news"],
                         "seed": {"book": "OneStopEnglish: " + r["title"], "section": r["title"], "text": r["text"]},
                         "topic": r["title"], "focus": None, **_common("ose-" + r["sourceId"])})

    # ---- matrix rows
    for key, topic, focus in TOPICS:
        why = idx.check_and_add("lt-gen-" + key, f"{topic}. {focus}")
        if why:
            rej["matrix: dedupe vs Content/"] += 1
            continue
        rows.append({"rowId": "gen-" + key, "kind": "matrix", "outFile": OUT_GEN, "source": "gen-talk", "sourceId": key,
                     "group": "gen-talk:" + key, "origin": "generated", "license": "original (generated with Claude)",
                     "tier": "permissive", "seed": None, "topic": topic, "focus": focus,
                     "topics": ["business"] + (["workplace"] if key not in ("loss-aversion",) else []),
                     **_common("gen-" + key)})

    (stage / "rows.jsonl").write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8")
    # batches: homogeneous by kind/outFile, 25-50 rows each, near-even sizes
    bdir = stage / "batches"
    bdir.mkdir(exist_ok=True)
    for f in bdir.glob("batch-*.jsonl"):
        f.unlink()
    groups = [[r for r in rows if r["source"] == "openstax"], [r for r in rows if r["source"] == "onestopenglish"],
              [r for r in rows if r["kind"] == "matrix"]]
    paths, bi = [], 0
    for g in groups:
        if not g:
            continue
        nb = max(1, round(len(g) / 40))
        size = -(-len(g) // nb)
        for s in range(0, len(g), size):
            bi += 1
            p = bdir / f"batch-{bi:02d}.jsonl"
            p.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in g[s:s + size]), encoding="utf-8")
            paths.append((p, len(g[s:s + size])))
    rep = ["# gen-talk (listenTalk) extract report", "", f"Rows: {len(rows)} (openstax {len(groups[0])}, "
           f"onestopenglish {len(groups[1])}, matrix {len(groups[2])})", "", "## Rejects", ""]
    rep += [f"- {k}: {v}" for k, v in rej.most_common()]
    rep += ["", "CEFR: " + str(dict(Counter(r["cefr"] for r in rows))), "Voice: " + str(dict(Counter(r["voice"] for r in rows))),
            "OpenStax per book: " + str(dict(per_book)), "", "## Batches", ""] + [f"- {p} ({n} rows)" for p, n in paths]
    Path(a.report).parent.mkdir(parents=True, exist_ok=True)
    Path(a.report).write_text("\n".join(rep) + "\n", encoding="utf-8")
    print(f"rows {len(rows)}; rejects {dict(rej)}")
    for p, n in paths:
        print(p, n)


def _build_item(row: dict, fill: dict):
    rng = random.Random(_h("opts", row["rowId"]))
    qs = []
    for q in fill["questions"]:
        opts = [q["correct"], *q["distractors"]]
        rng.shuffle(opts)
        qs.append({"q": q["q"], "options": opts, "answer": opts.index(q["correct"]), "explanation": q["explanation"]})
    item = {"id": ids.item_id("listenTalk", {"openstax": "openstax", "onestopenglish": "ose", "gen-talk": "gen"}[row["source"]],
                              row["sourceId"]),
            "type": "listenTalk", "cefr": row["cefr"], "skill": "listening", "title": fill["title"].strip(),
            "voice": row["voice"], "script": re.sub(r"\s+", " ", fill["script"]).strip(), "questions": qs,
            "source": row["source"], "sourceId": row["sourceId"], "license": row["license"], "tier": row["tier"],
            "group": row["group"], "origin": row["origin"], "topics": row["topics"]}
    return item


def cmd_emit(a):
    stage, content = Path(a.stage), Path(a.content)
    rows = {r["rowId"]: r for r in _read(stage / "rows.jsonl")}
    fills = {}
    batch_of = {}
    for f in sorted((stage / "filled").glob("*.jsonl")):
        for x in _read(f):
            fills[x["rowId"]] = x
            batch_of[x["rowId"]] = f.stem
    per_batch, per_batch_rej = Counter(), Counter()
    rej = Counter()
    for f in (OUT_GEN, OUT_OSE):
        (content / "items" / f).unlink(missing_ok=True)
    idx = dedupe.DedupeIndex.from_content(content, threshold=0.7)
    out: dict[str, list] = {OUT_GEN: [], OUT_OSE: []}
    for rid, row in rows.items():
        fill = fills.get(rid)
        if not fill:
            rej["not filled"] += 1
            continue
        b = batch_of[rid]
        per_batch[b] += 1
        try:
            item = _build_item(row, fill)
        except (KeyError, ValueError, TypeError) as e:
            rej[f"bad fill shape: {type(e).__name__}"] += 1
            per_batch_rej[b] += 1
            continue
        probs = schema.problems_item(item)
        if probs:
            rej["schema: " + probs[0][:70]] += 1
            per_batch_rej[b] += 1
            continue
        longest = sum(1 for q in item["questions"]
                      if len(q["options"][q["answer"]]) > max(len(o) for i, o in enumerate(q["options"]) if i != q["answer"]))
        if longest >= 3:
            rej["correct option longest in 3+ of 4 questions"] += 1
            per_batch_rej[b] += 1
            continue
        if idx.check_and_add(item["id"], dedupe.item_text(item)):
            rej["dedupe vs Content/"] += 1
            per_batch_rej[b] += 1
            continue
        out[row["outFile"]].append(item)
    for k in out:
        out[k].sort(key=lambda x: x["id"])
    ent = {}
    if out[OUT_GEN]:
        ent[OUT_GEN] = emitlib.emit(content, "items", OUT_GEN, out[OUT_GEN], source="Tenaz generated talks (OpenStax seeds + business topics)",
                                    url=OPENSTAX_URL, license="CC BY 4.0 (OpenStax-seeded items); matrix items original",
                                    tier="permissive",
                                    attribution="Seeded items adapted from OpenStax, Rice University (CC BY 4.0) via HuggingFaceTB/openstax_paragraphs; "
                                                "lectures and questions written with Claude. Matrix items are original, generated with Claude.")
    if out[OUT_OSE]:
        ent[OUT_OSE] = emitlib.emit(content, "items", OUT_OSE, out[OUT_OSE], source="OneStopEnglish corpus (talks adapted)",
                                    url=OSE_URL, license="CC BY-SA 4.0", tier="share-alike",
                                    attribution="Adapted from the OneStopEnglish corpus (Vajjala and Lucic 2018), CC BY-SA 4.0; "
                                                "talks and questions written with Claude, shared under CC BY-SA 4.0.")
    rp = Path(a.report)
    base = rp.read_text(encoding="utf-8").split("\n## Emit")[0] if rp.exists() else ""
    sec = ["", "## Emit", "", f"Rows {len(rows)}, filled {len(fills)}, emitted gen {len(out[OUT_GEN])}, ose {len(out[OUT_OSE])}", ""]
    sec += [f"- {k}: {v}" for k, v in rej.most_common()]
    sec += ["", "Per-batch reject rate:"] + [f"- {b}: {per_batch_rej[b]}/{per_batch[b]} ({per_batch_rej[b] / per_batch[b]:.0%})" for b in sorted(per_batch)]
    allit = out[OUT_GEN] + out[OUT_OSE]
    sec += ["", "Distributions:", f"- cefr: {dict(Counter(i['cefr'] for i in allit))}", f"- group: {dict(Counter(i['group'].split(':')[0] for i in allit))}",
            f"- origin: {dict(Counter(i['origin'] for i in allit))}", f"- voice: {dict(Counter(i['voice'] for i in allit))}",
            f"- answer index: {dict(Counter(q['answer'] for i in allit for q in i['questions']))}"]
    smp = random.Random(7).sample(allit, min(30, len(allit)))
    sec += ["", "## Sample (30)", ""]
    for i in smp:
        sec += [f"### {i['id']} [{i['cefr']}] {i['title']}", i["script"], ""] + [f"- Q: {q['q']} -> {q['options'][q['answer']]}" for q in i["questions"]] + [""]
    rp.write_text(base.rstrip() + "\n" + "\n".join(sec) + "\n", encoding="utf-8")
    print({k: len(v) for k, v in out.items()}, dict(rej))


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("extract")
    e.add_argument("--stage", default=".ingest/stage/gen-talk")
    e.add_argument("--report", default=".ingest/reports/gen-talk.md")
    e.add_argument("--content", default="Content")
    e.add_argument("--openstax", default=".ingest/stage/openstax")
    e.add_argument("--ose", default=".ingest/stage/onestopenglish")
    m = sub.add_parser("emit")
    m.add_argument("--stage", default=".ingest/stage/gen-talk")
    m.add_argument("--report", default=".ingest/reports/gen-talk.md")
    m.add_argument("--content", default="Content")
    a = ap.parse_args()
    {"extract": cmd_extract, "emit": cmd_emit}[a.cmd](a)


if __name__ == "__main__":
    main()
