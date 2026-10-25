"""P3 writeEmail: generated scenario matrix (no open business-email prompt set exists).

  fetch   -> nothing to download (generated source); just creates the raw dir
  extract -> expands the matrix into .ingest/stage/gen-email/rows.jsonl, writes batches of 42 rows to
             .ingest/stage/gen-email/batches/batch-NN.jsonl and a report in .ingest/reports/gen-email.md
  emit    -> reads LLM-filled rows from .ingest/stage/gen-email/filled/*.jsonl and writes Content/items/write-email-gen.json

Run: uv run --project scripts/ingest python -I scripts/ingest/sources/gen-email.py <cmd>
"""
from __future__ import annotations

import argparse
import json
import random
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import dedupe, emit as emitlib, ids, schema, textnorm  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
SOURCE = "gen-email"
FILENAME = "write-email-gen.json"
SEED = 20261024
BATCH = 42
KIND_COUNTS = {"request": 85, "complaint": 80, "update": 85, "reply": 105, "recap": 55}  # 410 rows, ~400 expected after rejects

# situation -> (audiences that make sense, 10 concrete angles)
SITUATIONS: dict[str, tuple[list[str], list[str]]] = {
    "supplier delay": (["manager", "peer", "supplier", "other region"], [
        "an excipient lot is nine days late because of a raw-material shortage at the supplier's plant",
        "printed packaging components arrive after the filling slot, and the line would sit idle",
        "a carrier strike delays inbound active ingredient from Europe by about a week",
        "the supplier moved its dispatch date twice without telling anyone",
        "only half of the ordered glass vials were delivered, the rest has no date",
        "a late certificate of analysis blocks release of an otherwise on-time delivery",
        "the supplier's capacity is reduced after a planned maintenance shutdown ran long",
        "a new sub-supplier qualification is slower than promised and shifts the delivery by three weeks",
        "partial shipments keep arriving, which makes the goods receipt and planning messy",
        "the delay will not hurt this month's output, but it eats all the safety stock for next month"]),
    "forecast change": (["manager", "peer", "other region", "customer"], [
        "a tender win raises next quarter's demand for one product by 25 percent",
        "a competitor's launch lowers the forecast for a mature product by about 15 percent",
        "the statistical forecast and the commercial forecast disagree by a wide margin for two months",
        "a country moves its launch date forward by six weeks",
        "forecast accuracy fell below target last month because of one large unexpected order",
        "a pandemic-era stockpiling pattern disappeared and the baseline needs to be reset",
        "the demand review proposes a manual override that planning does not fully trust",
        "a regulatory approval in a new market creates a demand spike that no history can explain",
        "seasonal demand for a respiratory product starts earlier than the model predicts",
        "a change in the product mix shifts demand from the 30-count pack to the 90-count pack"]),
    "meeting reschedule": (["manager", "peer", "supplier", "other region", "customer"], [
        "the monthly S&OP review has to move because the regional lead is travelling",
        "a supplier business review clashes with an audit and must be postponed by a week",
        "a weekly planning sync must change time because of a time-zone shift after daylight saving ends",
        "a kick-off meeting needs to be split into two shorter sessions",
        "an urgent site visit overlaps with a long-planned stakeholder workshop",
        "a quarterly review is cancelled and replaced by a written update",
        "a meeting invite went to the wrong distribution list and key people are missing",
        "a demand review has to be brought forward by two days to meet a finance deadline",
        "a customer call is moved to early morning because of the other party's public holiday",
        "a long-standing one-to-one slot no longer works and a new rhythm is needed"]),
    "stock-out risk": (["manager", "peer", "other region", "customer"], [
        "projected inventory for one product turns negative in six weeks if nothing changes",
        "a market could run out of a key strength before the next shipment lands",
        "safety stock was consumed by an unplanned export order",
        "a batch failure leaves the next quarter with only two weeks of cover",
        "the reorder point was set on old demand and the system raised no alert",
        "a hospital customer reports that its remaining stock lasts ten days",
        "an air-freight transfer between sites could close the gap but is expensive",
        "a rounding error in the planning tool understated the demand over a three-month horizon",
        "two regions are competing for the same limited batch",
        "a promotion in one country was not shared with planning and will drain the stock"]),
    "quality deviation": (["manager", "peer", "supplier", "other region"], [
        "a temperature excursion was recorded on a pallet during transit",
        "a batch is on hold pending a deviation investigation about a documentation gap",
        "an out-of-specification result in a retained sample needs a retest",
        "labels on a shipment showed the wrong expiry date format",
        "a supplier changed a raw-material specification without notifying the customer",
        "a cleaning verification record was incomplete and the line must be re-checked",
        "a recurring particulate finding was traced to one packaging component",
        "a deviation closed late and put a release date at risk",
        "a change control was implemented before final quality approval",
        "a cold-chain data logger failed during a biologic shipment"]),
    "new process rollout": (["manager", "peer", "other region", "supplier"], [
        "a new weekly exception-based planning routine starts next month",
        "a new tool replaces spreadsheets for tracking purchase order confirmations",
        "a revised approval workflow for expedited shipments goes live",
        "a standard template for demand-review notes is introduced across regions",
        "supplier scorecards will now be updated monthly instead of quarterly",
        "a new rule requires a second check before any manual forecast override",
        "a pilot of automatic safety-stock recalculation starts in two countries",
        "the end-of-month inventory reconciliation gets a stricter cut-off time",
        "a shared tracker replaces email chains for open shipment issues",
        "a new naming convention for planning reports is mandatory from January"]),
    "onboarding a colleague": (["manager", "peer", "other region"], [
        "a new demand planner starts on Monday and you will be the buddy",
        "an intern joins the planning team for three months",
        "a colleague from another function moves into supply planning",
        "a new joiner in another region needs access to your reports",
        "a contractor will cover a maternity leave and needs a fast ramp-up plan",
        "a new team lead joins and wants to understand the planning calendar",
        "a graduate rotating through the team needs a first project",
        "a colleague returns after six months away and the process changed in the meantime",
        "a new analyst has to learn the main systems before the month-end close",
        "a new peer in another country shadows your planning cycle for a week"]),
    "vendor negotiation": (["manager", "peer", "supplier"], [
        "you want to renegotiate a lead time from 12 weeks to 8 weeks for a key component",
        "a logistics provider announced a 6 percent rate increase and you need a counter-offer",
        "you ask a supplier for a longer payment term in exchange for a larger annual volume",
        "a contract renewal is coming and you want a clause for partial deliveries",
        "you want a supplier to hold a consignment stock of a critical item",
        "a supplier offers a discount but with a much higher minimum order quantity",
        "you want a second supplier approved to reduce single-source risk",
        "a packaging vendor wants to change the delivery frequency to every two weeks",
        "you negotiate a penalty-free window for a forecast revision",
        "a transport vendor proposes a longer service-level report cycle and you want it monthly"]),
    "budget approval": (["manager", "peer", "other region"], [
        "you need approval for air freight costs to protect a launch",
        "a request for extra budget to hire a temporary planner for peak season",
        "you ask for approval to buy a safety-stock buffer that ties up working capital",
        "a training budget for a planning certification for two team members",
        "approval to extend a licence for a forecasting tool for one more year",
        "a business case for a data-quality clean-up project of about three months",
        "a request to move unused budget from one quarter to the next",
        "approval to pay for an expedited courier on a critical sample shipment",
        "a request for travel budget to visit a supplier site for a quality audit",
        "a proposal to share a regional analyst's cost between two departments"]),
    "travel and logistics": (["manager", "peer", "supplier", "other region", "customer"], [
        "arranging a two-day visit to a supplier's site next month",
        "a flight cancellation puts your presence at a regional workshop at risk",
        "coordinating a pallet pick-up window with a customer's warehouse",
        "visa and travel dates for a colleague from another country visiting your site",
        "a customs document is missing and the shipment waits at the border",
        "moving a delivery from Friday to Monday because the receiving dock is closed",
        "booking a shared hotel and room for a team offsite with limited budget",
        "a temperature-controlled truck is not available on the agreed day",
        "a delegation visits the warehouse and needs a safety briefing and a route",
        "the shipping address changed and open orders still point to the old one"]),
    "customer escalation": (["manager", "customer", "peer", "other region"], [
        "a wholesaler says three consecutive deliveries arrived short and is threatening to switch",
        "a hospital pharmacy complains that deliveries arrive after the agreed window",
        "a distributor wants a formal explanation for a back-order that was never announced",
        "OTIF to one customer fell to 82 percent and the account manager is upset",
        "a customer received the wrong pack size and asks for an immediate replacement",
        "a key account demands a recovery plan after a stock-out",
        "a customer's invoice does not match the delivered quantity",
        "a tender customer asks for written assurance of supply for the next twelve months",
        "a customer's warehouse rejected a shipment because the documentation was incomplete",
        "a senior director at a customer asks for a call with your management after repeated delays"]),
    "cross-team handover": (["manager", "peer", "other region"], [
        "you are going on two weeks of leave and a colleague covers your products",
        "a product family is moving from your team to a regional team",
        "the owner of a weekly report leaves and you inherit it",
        "responsibilities for a supplier relationship pass from planning to procurement",
        "a late-night shipment issue must be handed to the team in another time zone",
        "a project ends and the run-state support goes to the operations team",
        "a half-finished forecast analysis must be handed over because of a reorganisation",
        "you hand over open purchase orders to the person covering for parental leave",
        "the owner of a safety-stock review changes role and notes are scattered",
        "a regional team takes over a process that was run centrally"]),
}

KIND_AUDIENCE_BLOCK = {"complaint": {"customer"}}
KIND_TONES = {
    "request": ["formal", "neutral", "friendly", "polite but urgent"],
    "complaint": ["firm but polite", "formal", "neutral", "disappointed but professional"],
    "update": ["neutral", "friendly", "formal", "reassuring"],
    "reply": ["neutral", "friendly", "formal", "apologetic", "firm but polite"],
    "recap": ["neutral", "formal", "friendly"],
}
KIND_MINWORDS = {"request": (90, 110), "complaint": (110, 130), "update": (100, 120), "reply": (100, 130), "recap": (120, 150)}
PRODUCTS = ["an oral solid dose tablet", "an inhaler", "a prefilled pen", "a vial-based injectable", "a cold-chain biologic",
            "an oncology infusion", "a paediatric suspension", "a respiratory product", "a diabetes product", "a cardiovascular tablet",
            "an active ingredient", "a secondary packaging component", "a device sub-assembly", "a clinical-supply kit"]
PLACES = ["Poland", "Sweden", "Mexico", "Brazil", "Germany", "Japan", "Spain", "India", "Canada", "Italy", "the UK", "South Africa",
          "Singapore", "Ireland", "Turkey", "Chile", "Egypt", "Australia"]
NAMES = ["Laura", "Mark", "Priya", "Elena", "Tom", "Sofia", "Kenji", "Amira", "Lucas", "Hannah", "Rahul", "Marta", "Daniel", "Ingrid",
         "Carlos", "Nadia", "Oliver", "Yuki", "Fatima", "Peter", "Julia", "Andre", "Chloe", "Viktor", "Mei", "Samir", "Katarina", "Ben"]
SURNAMES = ["Hall", "Novak", "Ruiz", "Okafor", "Lindqvist", "Moreau", "Tanaka", "Silva", "Brandt", "Kowalski", "Haddad", "Reyes",
            "Fischer", "Nair", "Costa", "Ahmed", "Walsh", "Petrov", "Rossi", "Larsen"]


def fetch(raw: Path) -> None:
    raw.mkdir(parents=True, exist_ok=True)
    print("generated source: nothing to download")


def build_rows() -> list[dict]:
    rng = random.Random(SEED)
    pool = [(s, a) for s, (_, angles) in SITUATIONS.items() for a in angles]
    rows: list[dict] = []
    for kind, n in KIND_COUNTS.items():
        # each angle appears at most once per kind (the same story is never told the same way twice)
        picks = rng.sample(pool, n)
        for sit, angle in picks:
            auds = [x for x in SITUATIONS[sit][0] if x not in KIND_AUDIENCE_BLOCK.get(kind, set())]
            aud = rng.choice(auds)
            key = (kind, sit, angle, aud)
            tone = rng.choice(KIND_TONES[kind])
            lo, hi = KIND_MINWORDS[kind]
            row = {
                "rowId": ids.sha8("|".join(key)),
                "kind": kind, "situationType": sit, "angle": angle, "audience": aud, "tone": tone,
                "minWords": rng.choice(range(lo, hi + 1, 10)),
                "product": rng.choice(PRODUCTS), "place": rng.choice(PLACES),
                "counterpartName": f"{rng.choice(NAMES)} {rng.choice(SURNAMES)}" if rng.random() < 0.6 else rng.choice(NAMES),
            }
            if kind == "recap":
                row["bulletCount"] = rng.choice([5, 6, 7])
            rows.append(row)
    rng.shuffle(rows)
    assert len({r["rowId"] for r in rows}) == len(rows)
    return rows


def extract(stage: Path, raw: Path | None = None) -> None:
    stage.mkdir(parents=True, exist_ok=True)
    rows = build_rows()
    # dedupe the seed text against everything already in Content/ (angle text vs existing situations)
    idx = dedupe.DedupeIndex.from_content(ROOT / "Content", threshold=0.7)
    kept, rejected = [], []
    for r in rows:
        reason = idx.check(r["angle"])
        (rejected if reason else kept).append((r, reason))
    kept = [r for r, _ in kept]
    (stage / "rows.jsonl").write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in kept), encoding="utf-8")
    bdir = stage / "batches"
    bdir.mkdir(exist_ok=True)
    for f in bdir.glob("batch-*.jsonl"):
        f.unlink()
    nb = -(-len(kept) // BATCH)
    size = -(-len(kept) // nb)
    paths = []
    for i in range(nb):
        p = bdir / f"batch-{i + 1:02d}.jsonl"
        chunk = kept[i * size:(i + 1) * size]
        p.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in chunk), encoding="utf-8")
        paths.append(p)
    rep = ROOT / ".ingest" / "reports"
    rep.mkdir(parents=True, exist_ok=True)
    c = lambda key: ", ".join(f"{k}={v}" for k, v in sorted(Counter(r[key] for r in kept).items()))
    (rep / f"{SOURCE}.md").write_text(
        f"# gen-email\n\nrows: {len(kept)} (rejected as duplicates of Content: {len(rejected)})\n\n"
        f"- kind: {c('kind')}\n- situation: {c('situationType')}\n- audience: {c('audience')}\n- tone: {c('tone')}\n"
        f"- batches: {len(paths)}\n", encoding="utf-8")
    print(f"{len(kept)} rows, {len(paths)} batches")
    for p in paths:
        print(p)


# read in the 30-item sample pass: product/pack mismatch (tablet counts on a vial, kit or device)
MANUAL_REJECT = {"1f297d86", "9389c3d5", "2dc96aba"}


def _quality_problems(seed: dict, item: dict) -> list[str]:
    import re
    probs = []
    if seed["rowId"] in MANUAL_REJECT:
        probs.append("manual: product/pack mismatch")
    sit = item["situation"]
    wc = textnorm.word_count(sit)
    if not 30 <= wc <= 160:
        probs.append(f"situation words {wc}")
    for t in item["tasks"]:
        n = textnorm.word_count(t)
        if not 6 <= n <= 24:
            probs.append(f"task words {n}")
            break
    if len({t.lower() for t in item["tasks"]}) != 3:
        probs.append("repeated task")
    if seed["kind"] == "recap":
        nb = sum(1 for l in sit.splitlines() if l.lstrip().startswith("- "))
        if nb != seed.get("bulletCount"):
            probs.append(f"recap bullets {nb} != {seed.get('bulletCount')}")
    if seed["kind"] == "reply" and not re.search(r"[\"\u201c\u201d]", sit):
        probs.append("reply without quoted message")
    if re.search(r"\b(TODO|lorem|placeholder|\[[A-Za-z ]+\])", sit + " ".join(item["tasks"]), re.I):
        probs.append("placeholder text")
    return probs


def emit(stage: Path, seed_sample: int = 30) -> None:
    rows_by_id = {json.loads(l)["rowId"]: json.loads(l) for l in (stage / "rows.jsonl").read_text().splitlines() if l}
    (ROOT / "Content" / "items" / FILENAME).unlink(missing_ok=True)  # idempotent: do not dedupe against our own previous output
    idx = dedupe.DedupeIndex.from_content(ROOT / "Content", threshold=0.7)
    out, rejects = [], []
    per_batch: dict[str, list[int]] = {}
    seen_ids: set[str] = set()
    for f in sorted((stage / "filled").glob("*.jsonl")):
        tot = bad = 0
        for line in f.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            tot += 1
            try:
                d = json.loads(line)
                seed = rows_by_id.get(d.get("rowId"))
                if not seed:
                    raise ValueError("unknown rowId")
                if seed["rowId"] in seen_ids:
                    raise ValueError("duplicate rowId")
                item = {
                    "id": ids.item_id("writeEmail", "gen", seed["rowId"]), "type": "writeEmail",
                    "cefr": d.get("cefr") if d.get("cefr") in ("B1", "B1+", "B2", "B2+", "C1") else "B2",
                    "skill": "writing",
                    "situation": textnorm.fix_unicode(d["situation"]).strip(),
                    "tasks": [textnorm.fix_unicode(t).strip() for t in d["tasks"]],
                    "minWords": seed["minWords"], "kind": seed["kind"],
                    "source": SOURCE, "sourceId": seed["rowId"], "license": "original Tenaz content", "tier": "permissive",
                    "origin": "generated", "topics": ["workplace", seed["situationType"].replace(" ", "-")],
                }
                probs = schema.problems_item(item)
                if len(item["tasks"]) != 3:
                    probs.append("need exactly 3 tasks")
                probs += _quality_problems(seed, item)
                if not probs:
                    reason = idx.check_and_add(item["id"], dedupe.item_text(item))
                    if reason:
                        probs.append(f"dup: {reason}")
            except Exception as e:  # malformed row
                probs, item = [f"unparseable: {e}"], {"id": (d.get("rowId") if isinstance(locals().get("d"), dict) else "?")}
                seed = None
            if probs:
                bad += 1
                rejects.append((item["id"], f.name, "; ".join(probs)))
            else:
                seen_ids.add(seed["rowId"])
                item["_seed"] = seed
                out.append(item)
        per_batch[f.name] = [tot, bad]
    seeds = {i["id"]: i.pop("_seed") for i in out}
    rep = ROOT / ".ingest" / "reports"
    rep.mkdir(parents=True, exist_ok=True)
    (rep / f"{SOURCE}-emit-rejects.md").write_text(
        "\n".join(f"- {i} ({f}): {r}" for i, f, r in rejects) + "\n", encoding="utf-8")
    emitlib.emit(ROOT / "Content", "items", FILENAME, out, source="Tenaz generated writeEmail matrix", url="",
                 license="original Tenaz content", tier="permissive",
                 attribution="Generated by Claude for Tenaz from scenario matrix scripts/ingest/sources/gen-email.py")
    cnt = lambda it: ", ".join(f"{k}={v}" for k, v in sorted(Counter(it).items()))
    lines = [f"# gen-email emit\n", f"filled rows: {sum(t for t, _ in per_batch.values())}; emitted: {len(out)}; rejected: {len(rejects)}\n",
             "## Reject rate per batch\n"]
    lines += [f"- {n}: {b}/{t} rejected ({100 * b / max(t, 1):.0f}%)" for n, (t, b) in per_batch.items()]
    lines += ["", "## Reject reasons\n", cnt([r.split(" ")[0] + " " + r.split(" ")[1] if " " in r else r for _, _, rr in rejects for r in rr.split("; ")]) or "none",
              "", "## Distributions\n", f"- kind: {cnt(i['kind'] for i in out)}",
              f"- cefr: {cnt(i['cefr'] for i in out)}", f"- situation: {cnt(i['topics'][1] for i in out)}",
              f"- audience: {cnt(seeds[i['id']]['audience'] for i in out)}", f"- tone: {cnt(seeds[i['id']]['tone'] for i in out)}",
              f"- minWords: {cnt(i['minWords'] for i in out)}", "", f"## Random sample ({seed_sample})\n"]
    for i in random.Random(SEED).sample(out, min(seed_sample, len(out))):
        lines += [f"### {i['id']} [{i['kind']}, {i['cefr']}, minWords {i['minWords']}]", i["situation"], ""] + [f"  * {t}" for t in i["tasks"]] + [""]
    (rep / f"{SOURCE}.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"emitted {len(out)}, rejected {len(rejects)}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["fetch", "extract", "emit"])
    ap.add_argument("--raw", default=str(ROOT / ".ingest/raw" / SOURCE))
    ap.add_argument("--stage", default=str(ROOT / ".ingest/stage" / SOURCE))
    a = ap.parse_args()
    {"fetch": lambda: fetch(Path(a.raw)), "extract": lambda: extract(Path(a.stage)),
     "emit": lambda: emit(Path(a.stage))}[a.cmd]()


if __name__ == "__main__":
    main()
