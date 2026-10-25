"""P3 generated workplace dialogues -> listenConversation (no dataset: scenario matrix expansion + LLM fill).

  fetch   -> nothing to download (prints a note)
  extract -> expands the scenario matrix below into rows, dedupes them, writes
             .ingest/stage/gen-dialogue/rows.jsonl, batches/gd-NN.jsonl (25-50 rows each) and
             .ingest/reports/gen-dialogue.md
  emit    -> reads batches/gd-NN.filled.jsonl (LLM output), validates, dedupes at 0.7, writes
             Content/items/listen-conversation-gen.json via lib.emit

Run: uv run --project scripts/ingest python -I scripts/ingest/sources/gen-dialogue.py <cmd>

Matrix: hand-written situations (category, concrete one-line brief) x 3 variants. A variant fixes the
communication channel, who raises the issue, the twist (plot complication), the register, the target level,
the question-kind mix, the two names/voices and three concrete facts (date, quantity, percent...), so that
two rows of the same situation still produce different dialogues.
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
from lib import dedupe, emit as emitlib, ids, schema  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
SRC = "gen-dialogue"
FILENAME = "listen-conversation-gen.json"
CONTENT = ROOT / "Content"

# ---------------------------------------------------------------------------------------------------------
# Situations: (category, key, brief). Roles in the brief are A (raises it / opens) and B (responds).
# No real company or drug names; "the company", "the site", "the product" only.
# ---------------------------------------------------------------------------------------------------------
S = [
    # stand-ups (daily team check-ins)
    ("standup", "su-planning-blockers", "Daily planning stand-up: A reports a blocker (a missing master-data update stops the weekly supply plan), B offers a workaround and says what B is doing today."),
    ("standup", "su-month-end", "Month-end stand-up: two planners compare what is still open for the close (late goods receipts, unconfirmed purchase orders) and agree who chases what."),
    ("standup", "su-sick-cover", "Stand-up where a teammate is sick: A asks B to cover two supplier calls and a report; B has a clash and negotiates which one to take."),
    ("standup", "su-dashboard-fix", "Stand-up with a data analyst: the inventory dashboard showed wrong stock numbers yesterday; A explains the cause and the fix, B asks if the history was corrected."),
    # supplier calls
    ("supplier", "sp-delay-excipient", "A planner calls a supplier contact: a shipment of excipient raw material is five days late; the supplier explains a production issue and proposes a split delivery."),
    ("supplier", "sp-moq-change", "Supplier tells the planner the minimum order quantity is going up; the planner asks for the effective date and tries to keep the old MOQ for one more order."),
    ("supplier", "sp-price-rise", "Account manager of a packaging supplier announces a price increase; the buyer asks for the reasons and for a three-month transition period."),
    ("supplier", "sp-capacity-slot", "Planner asks a contract manufacturer for an extra production slot next month; the contact checks the schedule and offers a later slot with conditions."),
    ("supplier", "sp-doc-missing", "Supplier shipped goods but the certificate of analysis is missing; the receiving planner explains why the goods cannot be released and agrees how to get the document today."),
    ("supplier", "sp-lead-time-update", "Quarterly supplier review call: the supplier reports that the standard lead time moves from 8 to 10 weeks for one component; the planner asks what safety stock that implies."),
    ("supplier", "sp-forecast-share", "The planner shares the new 12-month rolling forecast with a supplier; the supplier says peaks in months 4 and 5 are hard to cover and asks for a firm commitment."),
    ("supplier", "sp-wrong-qty", "The delivery note shows 1,200 units but the purchase order says 1,000; the planner calls the supplier to find out which is right and what to do with the extra."),
    # planning / S&OP meetings
    ("meeting", "mt-sop-gap", "Monthly S&OP pre-meeting: the demand planner shows a gap between demand and supply for one product family; the supply planner proposes two options and asks for the decision."),
    ("meeting", "mt-sop-consensus", "S&OP meeting, A (demand planning) and B (finance): they disagree on an upside scenario for next quarter and agree on a consensus number with a clear assumption."),
    ("meeting", "mt-capacity-vs-demand", "Weekly supply meeting: manufacturing says line 2 is under maintenance for three days; the planner asks what output is lost and which orders move."),
    ("meeting", "mt-launch-readiness", "Launch readiness meeting for a new pack size: the project lead asks for status of artwork, first batch, and logistics; one item is red."),
    ("meeting", "mt-inventory-review", "Inventory review: the supply chain manager asks why safety stock is above target for one item; the planner explains an earlier forecast spike and proposes to burn it down."),
    ("meeting", "mt-action-recap", "Wrap-up at the end of a long meeting: A summarizes decisions, owners and deadlines; B corrects one date and adds a missing action."),
    ("meeting", "mt-run-meeting", "A new meeting chair opens a cross-functional call, checks the agenda order with the participant, and asks to keep the discussion on time because there is a hard stop."),
    ("meeting", "mt-scenario-cost", "Two colleagues weigh expedited air freight versus waiting for sea freight for an urgent order; they compare cost, risk and customer impact and choose."),
    # 1:1s
    ("one-to-one", "oo-weekly-status", "Weekly 1:1: the employee reports progress on three tasks, flags one risk, and asks the manager for a priority call."),
    ("one-to-one", "oo-workload", "The employee tells the manager the workload is too high during quarter close; they review tasks and agree what to drop or delegate."),
    ("one-to-one", "oo-feedback-presentation", "The manager gives feedback after the employee's presentation to senior stakeholders: what worked, one thing to improve (too much detail), and a suggestion for next time."),
    ("one-to-one", "oo-career-step", "The employee asks the manager about a move into a more strategic planning role; the manager explains what skills and visibility are needed and proposes a stretch project."),
    ("one-to-one", "oo-english-confidence", "The employee admits feeling nervous speaking English in big meetings; the manager gives practical tips (send notes before, ask one question per meeting) and offers support."),
    ("one-to-one", "oo-mentor-intro", "First meeting between a mentee and a mentor from another department; they set goals, meeting frequency and what the mentee wants to learn."),
    # onboarding
    ("onboarding", "ob-first-day", "First day: a buddy shows the new planner around, explains the team's tools and the weekly rhythm, and answers questions about lunch and access."),
    ("onboarding", "ob-tools-access", "New joiner and a colleague go through the systems the new person needs (planning tool, shared drive, ticketing) and what to request first."),
    ("onboarding", "ob-explain-terms", "A new joiner asks a colleague to explain internal terms (lead time, safety stock, OTIF, batch release) in plain English during a coffee break."),
    ("onboarding", "ob-first-week-plan", "A manager and a new employee build a 30-day plan: who to meet, what to read, and a first small project to own."),
    ("onboarding", "ob-process-handover", "A departing contractor walks a new team member through a weekly report process: inputs, deadlines, common errors, and who to ask."),
    # IT help desk
    ("it-help", "it-password-lockout", "Help desk call: the employee is locked out after a password change; the agent verifies identity and walks through the reset."),
    ("it-help", "it-vpn-slow", "Remote employee reports the VPN drops during video calls; the agent asks questions, tries a fix and logs a ticket for the network team."),
    ("it-help", "it-excel-macro", "A planner's spreadsheet macro stopped working after an update; the IT support person asks what changed and suggests a temporary workaround while escalating."),
    ("it-help", "it-shared-folder", "An employee cannot open a shared folder; the help desk checks the group membership and explains the approval step needed from the folder owner."),
    ("it-help", "it-new-laptop", "Collecting a new laptop: the IT technician explains data migration, what will be wiped, and when the old laptop must be returned."),
    ("it-help", "it-ticket-status", "An employee follows up on a ticket that has been open for a week; the agent explains the status, priority and what will happen next."),
    # travel booking
    ("travel", "tr-flight-conference", "A colleague books a flight to a supply-chain conference with a travel agent; they compare two options on price and arrival time and deal with the company's booking policy."),
    ("travel", "tr-hotel-site-visit", "Booking a hotel near a supplier's site for a two-night audit visit; the agent suggests a location and the traveller asks about breakfast, distance and cancellation."),
    ("travel", "tr-change-booking", "A traveller must change a train booking because the supplier meeting moved; the agent explains the fee and offers another time."),
    ("travel", "tr-airport-delay", "At the airport: a delayed flight threatens a connection; the traveller talks to a service desk agent to be rebooked and informs the meeting host."),
    ("travel", "tr-expense-report", "An employee asks a finance colleague how to file expenses after a trip: receipts needed, deadline, per-diem rules and one rejected item."),
    # negotiating delivery dates
    ("delivery-date", "dd-split-shipment", "The planner and a supplier negotiate delivery of an order: the customer wants everything by the 15th; the supplier can send 60% by then and the rest later."),
    ("delivery-date", "dd-pull-forward", "An internal customer asks the planner to pull forward a delivery by one week; the planner explains constraints and trades off which other order moves."),
    ("delivery-date", "dd-push-out", "The planner asks a distributor to accept a later delivery date because the warehouse is full; the distributor asks for something in return."),
    ("delivery-date", "dd-confirmed-date", "A customer service rep and a logistics coordinator agree on a firm delivery date for an urgent order after checking transport, customs and production."),
    ("delivery-date", "dd-penalty", "A buyer reminds a supplier of a late-delivery penalty clause; the supplier argues the delay was partly the buyer's late change request and they negotiate."),
    ("delivery-date", "dd-holiday-window", "Planning deliveries around a national holiday: the planner and carrier agree on a delivery window before the holiday and a backup date after."),
    # clarifying forecasts
    ("forecast", "fc-big-jump", "The supply planner asks the demand planner why the forecast for one product jumped 30% in month 3; the answer involves a tender win that is not yet confirmed."),
    ("forecast", "fc-bias", "A forecast accuracy review: A shows consistent over-forecasting for a market; B explains the sales team's habit and they agree on a bias correction."),
    ("forecast", "fc-new-launch", "Two colleagues clarify assumptions for the forecast of a new pack: launch date, uptake curve, and what share replaces the old pack."),
    ("forecast", "fc-units-confusion", "A misunderstanding: the forecast is in packs, but the supplier plan is in units; the two colleagues find the mismatch and agree on a conversion check."),
    ("forecast", "fc-version-control", "Which version of the forecast is the latest? A and B compare two files and a message from the regional team, and decide which to use."),
    ("forecast", "fc-market-input", "A regional sales rep gives input on demand for a market and the demand planner asks for evidence, timing and the risk of the number being too high."),
    ("forecast", "fc-lower-demand", "A stakeholder informs the planner that demand will be 15% lower because a competitor entered the market; the planner asks what to do with orders already placed."),
    # small talk before meetings
    ("small-talk", "st-weekend-trip", "Two colleagues wait for a meeting to start and chat about a weekend trip; they then move to a work topic as others join."),
    ("small-talk", "st-new-office", "Before a call, two colleagues from different countries chat about the weather, time zones and the new office layout."),
    ("small-talk", "st-commute-coffee", "In the coffee queue before a meeting: A asks B about the commute and a new coffee machine, then mentions a quick question about next week's deadline."),
    ("small-talk", "st-conference-return", "A colleague back from a conference tells another about two interesting talks, a useful contact and a small disappointment."),
    ("small-talk", "st-tech-delay", "Waiting online for the host to open a video meeting: A and B talk about the sound problem, a late participant and their plans for lunch."),
    # QA and deviations
    ("quality", "qa-batch-hold", "A QA specialist tells a planner a batch is on hold pending an investigation; the planner asks how long, what inventory is affected and when a decision is expected."),
    ("quality", "qa-deviation-report", "Two colleagues discuss a minor deviation found during packaging: what happened, whether product is affected and what the corrective action is."),
    ("quality", "qa-release-date", "The planner asks QA for the expected release date of a batch; QA explains the remaining checks and warns about a documentation gap."),
    ("quality", "qa-temperature-excursion", "Logistics reports a temperature excursion in a shipment; QA asks for the data logger report and explains the next steps before the goods can be used."),
    ("quality", "qa-audit-prep", "Preparing for an internal audit: a team lead asks a colleague to check that records are up to date and agree who answers which topics."),
    ("quality", "qa-label-error", "Packaging team discovers a label mistake on a pallet; the planner and QA decide to quarantine it and plan a rework slot."),
    # logistics / customs / warehouse
    ("logistics", "lg-customs-hold", "A logistics coordinator tells a planner that a shipment is stuck at customs for missing paperwork; they plan what to send and who to call."),
    ("logistics", "lg-warehouse-space", "The warehouse manager says storage is almost full; the planner discusses which deliveries can be delayed or redirected."),
    ("logistics", "lg-carrier-miss", "A carrier missed a pickup; the coordinator calls the carrier dispatcher to reschedule and requests a priority slot."),
    ("logistics", "lg-stock-count", "A stock-count difference is found; the inventory controller and planner investigate possible causes (transfer not booked, wrong location) and decide on a recount."),
    ("logistics", "lg-cold-chain", "Two colleagues plan a cold-chain shipment: packaging type, transit time, backup carrier and who tracks it."),
    # escalations
    ("escalation", "es-to-manager", "A planner asks their manager to escalate a stalled supplier issue to the supplier's director; the manager asks for the facts and the impact."),
    ("escalation", "es-stakeholder-angry", "A senior stakeholder is frustrated about repeated late updates; the planner stays calm, acknowledges the problem and offers a new update routine."),
    ("escalation", "es-resource-conflict", "Two team leads need the same specialist in the same week; they try to resolve it themselves and agree to escalate only if they fail."),
    ("escalation", "es-risk-heads-up", "A planner gives an early warning to the commercial lead: a stockout risk in six weeks unless a decision is made this week."),
    # handover / vacation
    ("handover", "ho-before-vacation", "Before a two-week holiday, A hands over open items to B: what is urgent, what can wait, where the files are, who to call."),
    ("handover", "ho-role-change", "A planner moving to another team briefs the successor on the key suppliers, their habits and the recurring problems."),
    ("handover", "ho-back-from-leave", "A colleague returns from parental leave; the teammate catches them up on org changes, new tools and priorities."),
    # remote / cross-cultural / logistics of meetings
    ("remote", "rm-time-zone", "Planners in Europe and Asia find a meeting time that suits both; they compare calendars and choose a rotating schedule."),
    ("remote", "rm-bad-connection", "A call with a bad connection: A cannot hear well, B repeats the key points, and they confirm by written follow-up."),
    ("remote", "rm-reschedule", "A manager asks to move a meeting at short notice; the colleague has a conflict and offers alternatives."),
    ("remote", "rm-hybrid-room", "Setting up a hybrid meeting: someone tests the room screen and microphone while a remote colleague gives feedback."),
    # admin / HR
    ("admin", "ad-holiday-request", "An employee asks HR about carrying over unused vacation days; HR explains the rule and the deadline."),
    ("admin", "ad-training-budget", "An employee asks their manager to approve an external course; the manager asks about relevance, cost and time away."),
    ("admin", "ad-purchase-approval", "A colleague needs finance approval for an urgent purchase order; the finance contact asks for the cost centre and a justification."),
    # feedback and improvement
    ("improvement", "im-process-idea", "A planner proposes automating a weekly report; the colleague asks about effort, risks and who maintains it."),
    ("improvement", "im-root-cause", "After a stockout, two colleagues review what went wrong (late forecast change, no safety stock review) and what to change."),
    ("improvement", "im-kpi-otif", "Discussion of an OTIF drop: A shows 91% this month versus 95% target; B points to two late shipments and proposes actions."),
    ("improvement", "im-meeting-feedback", "A colleague gives gentle feedback to another about meeting habits (long updates, no agenda) and they agree on a simple structure."),
    # clients / internal customers
    ("customer", "cu-order-status", "An internal customer asks a customer service rep where an urgent order is; the rep checks the system and gives a realistic update."),
    ("customer", "cu-allocation", "Product supply is limited; a planner explains to a market contact how allocation will work this month and why the request cannot be fully met."),
    ("customer", "cu-complaint", "A distributor complains about damaged cartons; the rep apologizes, collects details and explains the replacement process."),
    # learning and language
    ("language", "ln-rephrase", "A colleague asks another to review wording in an email to a supplier so it sounds firm but polite; they rewrite one sentence together."),
    ("language", "ln-meeting-prep", "Two colleagues rehearse a short update before a meeting with senior managers, checking numbers, key message and likely questions."),
    # project work
    ("project", "pj-timeline-slip", "A project manager and a team member discuss a two-week slip in a system rollout and what to tell the steering committee."),
    ("project", "pj-data-migration", "Migrating item master data to a new tool: two colleagues review a list of errors and agree on a cleanup plan."),
    ("project", "pj-training-session", "Planning a training session for new software: audience, length, and who prepares materials."),
    ("project", "pj-vendor-selection", "Comparing two software vendors for demand sensing: A and B agree on criteria and divide up the next steps."),
    # misc workplace
    ("misc", "mx-budget-cut", "The manager tells an employee that the travel budget is cut by 20 percent; they decide what to keep (a supplier audit) and what to replace with video calls."),
    ("misc", "mx-reorg", "Two colleagues discuss a team reorganization announced today: what changes, what is unclear, and how to ask the manager."),
    ("misc", "mx-lunch-invite", "A colleague invites another to a team lunch to say goodbye to a teammate; they settle date, place and a small gift."),
    ("misc", "mx-office-move", "Facilities informs an employee of a desk move to a different floor; the employee asks about timing, equipment and the neighbours."),
    ("misc", "mx-safety-walk", "On a site visit a safety officer explains the rules to a visitor: badge, protective equipment, walking routes and an assembly point."),
    ("misc", "mx-late-arrival", "A colleague arrives late to a planning workshop and asks another what was missed; they summarize the decisions so far."),
]

CHANNELS = ["phone call", "video call", "in person at the office", "short walk between meetings", "video call with poor audio quality",
            "in person in a meeting room", "phone call with a colleague abroad", "chat plus voice call", "in person at the site"]
REGISTERS = ["formal and polite", "neutral and professional", "friendly and relaxed", "direct but courteous", "slightly tense but professional"]
TWISTS = [
    "a number or date is corrected in the middle of the conversation (so the listener must catch the final value)",
    "one speaker misunderstands at first and the other clarifies",
    "the request is only partly accepted and an alternative is offered",
    "a new small problem appears near the end and a follow-up is agreed",
    "a compromise is reached after each side gives something up",
    "the decision cannot be made now because information from a third person is missing",
    "one speaker is under stress and the other reassures them and takes one task",
    "the time or place of a follow-up changes twice before it is fixed",
    "a polite disagreement is settled by looking at data",
    "the conversation ends with clear action items, an owner and a deadline for each",
    "one speaker politely declines something and explains why in a way the listener must infer",
    "an unexpected good-news item shifts the plan",
]
INITIATOR = ["A starts and raises the issue", "B is the one with the problem and A answers", "A is senior to B", "B is senior to A",
             "A and B are peers from different departments", "A is external (supplier, carrier or agent) and B is internal"]
LEVELS = [("B1", 0.14), ("B1+", 0.20), ("B2", 0.34), ("B2+", 0.20), ("C1", 0.12)]
QKINDS = ["gist (main purpose of the conversation)", "detail (a concrete fact such as a date, number or place)",
          "number or time detail where a distractor repeats a value mentioned earlier or later", "speaker's reason or cause",
          "speaker's attitude or feeling", "what will happen next or what a speaker will do", "inference (something implied, not said)",
          "function of a sentence (why does a speaker say X?)"]
QSETS = [  # question kind mixes (indices into QKINDS), always one detail and one reasoning kind
    (0, 1, 5), (0, 2, 6), (1, 3, 5), (0, 1, 4, 6), (0, 2, 5, 7), (1, 3, 6), (0, 2, 3, 5), (2, 4, 5), (0, 1, 3, 6), (1, 5, 7, 0),
]
FEMALE = ["Priya", "Marta", "Elena", "Hannah", "Sofia", "Amara", "Claire", "Yuki", "Fatima", "Lucia", "Nora", "Ingrid", "Rachel", "Aisha", "Camila",
          "Ana", "Emma", "Mei", "Katarina", "Leila", "Olivia", "Dana", "Sara", "Chloe"]
MALE = ["Tomas", "Daniel", "Raj", "Mark", "Kenji", "Omar", "Lukas", "Samuel", "Pedro", "Andrew", "Mateo", "Henrik", "Chris", "Ibrahim", "Luis",
        "Victor", "Ben", "Arjun", "Pavel", "Jon", "Marco", "Ethan", "Hugo", "Adam"]
UNITS = ["pallets", "cartons", "batches", "units", "orders", "containers", "kilograms", "tickets", "order lines"]
DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
MONTHS = ["January", "February", "March", "April", "May", "June", "July", "September", "October", "November"]


def h(s: str) -> int:
    return int(hashlib.sha256(s.encode()).hexdigest()[:12], 16)


def pick(seq, key: str):
    return seq[h(key) % len(seq)]


def pick_level(key: str) -> str:
    x = (h(key) % 1000) / 1000
    acc = 0.0
    for lvl, p in LEVELS:
        acc += p
        if x < acc:
            return lvl
    return LEVELS[-1][0]


def facts(key: str) -> list[str]:
    r = random.Random(h("facts" + key))
    qty = r.choice([40, 60, 80, 120, 150, 240, 300, 450, 600, 1200, 2500])
    pct = r.choice([5, 8, 12, 15, 18, 20, 25, 30, 35, 40])
    wk = r.choice([2, 3, 4, 6, 8, 10, 12])
    day = r.choice(DAYS)
    date = f"the {r.choice([3, 5, 8, 11, 14, 17, 19, 22, 24, 27, 29])}th of {r.choice(MONTHS)}"
    hour = r.choice(["9:00", "9:30", "10:15", "11:00", "13:30", "14:00", "15:45", "16:30"])
    unit = r.choice(UNITS)
    code = f"{r.choice('ABCDEFGHKLMNPRSTV')}{r.choice('ABCDEFGHKLMNPRSTV')}-{r.randrange(1000, 9999)}"
    pool = [f"quantity: {qty} {unit}", f"percentage: {pct} percent", f"duration: {wk} weeks", f"day: {day}", f"date: {date}",
            f"time: {hour}", f"reference code: {code}"]
    r.shuffle(pool)
    return pool[:3]


def make_rows() -> list[dict]:
    rows = []
    for si, (cat, key, brief) in enumerate(S):
        for v in range(3):
            k = f"{key}/v{v}"
            twist = TWISTS[(si * 5 + v * 4 + h(key) % 3) % len(TWISTS)]
            fa_female = h(k + "g") % 2 == 0  # speaker A female?
            names = (FEMALE, MALE) if fa_female else (MALE, FEMALE)
            na = names[0][(si * 7 + v * 5) % len(names[0])]
            nb = names[1][(si * 3 + v * 11 + 1) % len(names[1])]
            lines = 8 + h(k + "L") % 7  # 8..14
            qs = QSETS[(si * 3 + v * 7 + h(key) % 5) % len(QSETS)]
            rows.append({
                "id": ids.item_id("listenConversation", SRC, f"{key}-v{v}"),
                "type": "listenConversation",
                "source": SRC,
                "sourceId": k,
                "category": cat,
                "situation": brief,
                "variant": v,
                "channel": pick(CHANNELS, k + "c"),
                "register": pick(REGISTERS, k + "r"),
                "power": pick(INITIATOR, k + "p"),
                "twist": twist,
                "speakers": {"A": {"name": na, "voice": "female" if fa_female else "male"},
                             "B": {"name": nb, "voice": "male" if fa_female else "female"}},
                "targetLines": lines,
                "targetCefr": pick_level(k + "lv"),
                "facts": facts(k),
                "questionKinds": [QKINDS[i] for i in qs],
                "origin": "generated",
            })
    return rows


def brief_tokens(r: dict) -> set[str]:
    return set(re.findall(r"[a-z]{4,}", r["situation"].lower()))


def extract(stage: Path, report: Path) -> None:
    rej: Counter = Counter()
    rows = make_rows()
    idx = dedupe.DedupeIndex.from_content(CONTENT, threshold=0.7)
    existing_titles = set()
    for f in (CONTENT / "items").glob("*.json"):
        for it in json.loads(f.read_text(encoding="utf-8")):
            if it.get("type") == "listenConversation":
                existing_titles.add(it.get("title", "").lower())
    kept, seen_briefs, ex_ids, sigs = [], [], set(), set()
    for r in rows:
        if r["id"] in ex_ids:
            rej["duplicate id"] += 1
            continue
        ex_ids.add(r["id"])
        reason = idx.check(r["situation"])
        if reason:
            rej[f"brief vs Content: {reason.split(' of ')[0]}"] += 1
            continue
        t = brief_tokens(r)
        # different situations must not share (nearly) the same brief
        if any(o["situation"] != r["situation"] and len(t & ot) / max(1, len(t | ot)) > 0.7 for o, ot in seen_briefs):
            rej["brief near-duplicate of another situation"] += 1
            continue
        sig = (r["situation"], r["twist"])
        if sig in sigs:
            rej["same situation+twist"] += 1
            continue
        sigs.add(sig)
        seen_briefs.append((r, t))
        kept.append(r)
    stage.mkdir(parents=True, exist_ok=True)
    (stage / "rows.jsonl").write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in kept), encoding="utf-8")
    # batches: variants of one situation land in different batches; order inside a batch is shuffled by hash
    nb = max(1, round(len(kept) / 36))
    sit_index = {k: i for i, (_, k, _) in enumerate(S)}
    buckets: list[list[dict]] = [[] for _ in range(nb)]
    for r in kept:
        key = r["sourceId"].rsplit("/", 1)[0]
        buckets[(sit_index[key] + r["variant"] * max(1, nb // 3)) % nb].append(r)
    bdir = stage / "batches"
    bdir.mkdir(exist_ok=True)
    for old in bdir.glob("gd-*.jsonl"):
        if ".filled." not in old.name:
            old.unlink()
    paths = []
    for n, b in enumerate(buckets, 1):
        b.sort(key=lambda r: h(r["id"]))
        p = bdir / f"gd-{n:02d}.jsonl"
        p.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in b), encoding="utf-8")
        paths.append((p.resolve(), len(b)))
    report.parent.mkdir(parents=True, exist_ok=True)
    lv, cat, ln = (Counter(r[k] for r in kept) for k in ("targetCefr", "category", "targetLines"))
    md = ["# gen-dialogue (staged)", "", f"- situations: {len(S)} x 3 variants = {len(rows)} rows", f"- kept after dedupe: {len(kept)}",
          f"- rejects: {dict(rej) or 'none'}", f"- existing listenConversation titles: {len(existing_titles)}", "",
          "## Batches", *[f"- {p} ({n} rows)" for p, n in paths], "", f"## Target level\n{dict(sorted(lv.items()))}",
          f"\n## Category\n{dict(sorted(cat.items()))}", f"\n## Target lines\n{dict(sorted(ln.items()))}", "",
          "## Sample rows", *[f"- {r['id']}: [{r['targetCefr']}, {r['targetLines']} lines] {r['situation']} | twist: {r['twist']}"
                              for r in random.Random(1).sample(kept, min(10, len(kept)))]]
    report.write_text("\n".join(md) + "\n", encoding="utf-8")
    print(f"{len(kept)} rows, {len(paths)} batches ->", bdir, dict(rej))


# ---------------------------------------------------------------------------------------------------------
# emit: merge LLM output (batches/gd-NN.filled.jsonl) into items
# ---------------------------------------------------------------------------------------------------------
def build_item(row: dict, fill: dict, rej: Counter):
    sp = row["speakers"]
    script = fill.get("script") or []
    for ln in script:
        if ln.get("speaker") not in ("A", "B") or ln.get("voice") != sp[ln["speaker"]]["voice"]:
            rej["voice/speaker mismatch"] += 1
            return None
    if not (8 <= len(script) <= 14):
        rej["line count"] += 1
        return None
    words = [len(x["line"].split()) for x in script]
    if min(words) < 4 or max(words) > 40 or not (100 <= sum(words) <= 320):
        rej["script length out of bounds"] += 1
        return None
    if any(re.search(r"\d|[{}<>_#@]|https?:", x["line"]) and not re.search(r"\b\d{1,2}(st|nd|rd|th)\b", x["line"]) for x in script):
        rej["digits/symbols in spoken line"] += 1
        return None
    qs = fill.get("questions") or []
    if not (3 <= len(qs) <= 4):
        rej["question count"] += 1
        return None
    for q in qs:
        if not isinstance(q.get("answer"), int) or not 0 <= q["answer"] < 4:
            rej["bad question"] += 1
            return None
        if len({o.strip().lower() for o in q.get("options", [])}) != 4 or not (q.get("explanation") or "").strip():
            rej["bad question"] += 1
            return None
    if all(len(q["options"][q["answer"]]) > max(len(o) for i, o in enumerate(q["options"]) if i != q["answer"]) for q in qs):
        rej["every key is the strictly longest option"] += 1
        return None
    return {"id": row["id"], "type": "listenConversation", "cefr": fill.get("cefr") or row["targetCefr"], "skill": "listening",
            "title": fill["title"].strip(),
            "script": [{"speaker": x["speaker"], "voice": x["voice"], "line": x["line"].strip()} for x in script],
            "topics": ["workplace", "supply-chain", row["category"]], "group": f"gen-dialogue:{row['sourceId'].rsplit('/', 1)[0]}",
            "source": SRC, "sourceId": row["sourceId"], "license": "Original text written for Tenaz (generated)",
            "tier": "permissive", "origin": "generated", "questions": qs}


def emit(stage: Path) -> None:
    rows = {json.loads(l)["id"]: json.loads(l) for l in (stage / "rows.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()}
    rej: Counter = Counter()
    idx = dedupe.DedupeIndex.from_content(CONTENT, threshold=0.7)
    own = CONTENT / "items" / FILENAME
    if own.exists():  # idempotent rerun: our own previous output must not block us
        idx = dedupe.DedupeIndex(0.7)
        for f in sorted((CONTENT / "items").glob("*.json")):
            if f != own:
                for row in json.loads(f.read_text(encoding="utf-8")):
                    idx.add(row["id"], dedupe.item_text(row))
    items = []
    per_batch: dict[str, list[int]] = {}
    for fp in sorted((stage / "batches").glob("gd-*.filled.jsonl")):
        tot = bad = 0
        for l in fp.read_text(encoding="utf-8").splitlines():
            if not l.strip():
                continue
            tot += 1
            before = sum(rej.values())
            fill = json.loads(l)
            if fill.get("verdict", "ok") != "ok" or fill.get("id") not in rows:
                rej["verifier reject or unknown id"] += 1
            else:
                it = build_item(rows[fill["id"]], fill, rej)
                if it:
                    probs = schema.problems_item(it)
                    reason = None if probs else idx.check_and_add(it["id"], dedupe.item_text(it))
                    if probs:
                        rej["schema: " + probs[0][:60]] += 1
                    elif reason:
                        rej["dedupe: " + reason.split(" of ")[0]] += 1
                    else:
                        items.append(it)
            bad += sum(rej.values()) - before
        per_batch[fp.name.split(".")[0]] = [tot, bad]
    entry = emitlib.emit(CONTENT, "items", FILENAME, items, source="Generated workplace dialogues (Tenaz)", url="n/a (original)",
                         license="Original text written for Tenaz (generated)", tier="permissive",
                         attribution="Dialogues, questions and explanations written with Claude from the gen-dialogue scenario matrix")
    print(entry["items"], "items;", dict(rej))
    write_report(items, rej, per_batch)


def write_report(items: list[dict], rej: Counter, per_batch: dict) -> None:
    rep = ROOT / ".ingest/reports" / f"{SRC}.md"
    ans = Counter(q["answer"] for it in items for q in it["questions"])
    longest = sum(1 for it in items for q in it["questions"] if len(q["options"][q["answer"]]) >= max(map(len, q["options"])))
    nq = sum(len(it["questions"]) for it in items)
    md = ["# gen-dialogue (emit)", "", f"- items written: {len(items)}", f"- rejects: {dict(rej) or 'none'}", "",
          "## Per-batch reject rate", *[f"- {b}: {bad}/{tot} ({100*bad/max(tot,1):.0f}%)" for b, (tot, bad) in per_batch.items()], "",
          f"## CEFR\n{dict(sorted(Counter(i['cefr'] for i in items).items()))}",
          f"\n## Lines\n{dict(sorted(Counter(len(i['script']) for i in items).items()))}",
          f"\n## Category\n{dict(sorted(Counter(i['topics'][2] for i in items).items()))}",
          f"\n## Questions per item\n{dict(sorted(Counter(len(i['questions']) for i in items).items()))}",
          f"\n## Answer position\n{dict(sorted(ans.items()))}",
          f"\n## Correct option is (tied) longest\n{longest}/{nq} ({100*longest/nq:.0f}%)", "", "## Random sample (30)"]
    for it in random.Random(7).sample(items, min(30, len(items))):
        md.append(f"\n### {it['id']} [{it['cefr']}] {it['title']}")
        md += [f"- {x['speaker']}: {x['line']}" for x in it["script"]]
        md += [f"  - Q: {q['q']} -> {q['options'][q['answer']]}" for q in it["questions"]]
    rep.write_text("\n".join(md) + "\n", encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["fetch", "extract", "emit"])
    ap.add_argument("--stage", default=str(ROOT / ".ingest/stage" / SRC))
    ap.add_argument("--report", default=str(ROOT / ".ingest/reports" / f"{SRC}.md"))
    a = ap.parse_args()
    if a.cmd == "fetch":
        print("generated source: nothing to fetch")
    elif a.cmd == "extract":
        extract(Path(a.stage), Path(a.report))
    else:
        emit(Path(a.stage))


if __name__ == "__main__":
    main()
