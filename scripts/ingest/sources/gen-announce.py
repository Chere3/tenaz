"""P3 gen-announce: generated listenAnnouncement items (no dataset; scenario matrix expansion). STAGE + emit.

  fetch   -> nothing to download (generated source); prints that and exits 0
  extract -> .ingest/stage/gen-announce/rows.jsonl             all scenario rows (deduped, balanced)
             .ingest/stage/gen-announce/batches/batch_NNN.jsonl  rows for the LLM fill agents (40 rows each)
             .ingest/reports/gen-announce.md
  emit    -> reads .ingest/stage/gen-announce/batches/batch_NNN.filled.jsonl -> Content/items/listen-announcement-gen.json

Run: uv run --project scripts/ingest python -I scripts/ingest/sources/gen-announce.py extract
Matrix slots live in this file (setting x purpose pairs per genre, 2 detail slots, concrete facts, names, question focus).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import random
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import dedupe, emit as emit_lib, ids, schema, textnorm  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
SRC = "gen-announce"
SEED = 20261024
ROWS_PER_BATCH = 40

FEMALE = ["Laura", "Priya", "Marta", "Hannah", "Chloe", "Ingrid", "Nadia", "Sofia", "Grace", "Elena", "Yuki", "Fatima",
          "Rachel", "Camila", "Aisha", "Mei", "Katarina", "Olivia", "Renata", "Beatrice"]
MALE = ["Tom", "Rahul", "Javier", "Marcus", "Dmitri", "Kenji", "Omar", "Lucas", "Stefan", "Daniel", "Andre", "Mateo",
        "Viktor", "Samuel", "Pavel", "Hugo", "Arjun", "Callum", "Tariq", "Nils"]
SURNAMES = ["Okafor", "Lindqvist", "Moreau", "Haddad", "Brennan", "Castillo", "Novak", "Sato", "Fischer", "Patel",
            "Rossi", "Kowalski", "Mendes", "Larsen", "Ibrahim", "Walsh", "Duarte", "Tanaka", "Weber", "Hughes"]
SUPPLIERS = ["Norvia Packaging", "Altona Glassworks", "Brightfield Logistics", "Calder & Voss Components",
             "Eastbay Cold Chain", "Marlow Labels", "Tessera Plastics", "Hollin Freight", "Pinecrest Chemicals",
             "Solano Vials", "Kestrel Cartons", "Verdana Ingredients", "Orbis Transport", "Lumen Filters",
             "Barrow & Finch Pallets", "Quillon Reagents"]
SITES = ["Building C", "the north site", "Plant 2", "the distribution centre", "the Riverside office", "the east campus",
         "the main warehouse", "Tower B"]
DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
CITIES = ["Frankfurt", "Lisbon", "Warsaw", "Dublin", "Madrid", "Prague", "Zurich", "Vienna", "Lyon", "Milan", "Gothenburg",
          "Porto", "Rotterdam", "Seville", "Krakow"]

# genre -> (rows wanted, [(setting, speaker role, purpose, [detail A: key facts], [detail B: complication or instruction])])
G: dict[str, tuple[int, list]] = {}

G["supplier_voicemail"] = (30, [
    ("supplier account manager leaving a voicemail for a planning team", "supplier account manager", "delivery will arrive late",
     ["a truck broke down on the motorway and the delivery will be one day late", "a customs inspection at the border holds the shipment for two days", "a raw-material shortage pushes the dispatch back by a week", "the carrier missed the loading slot and offers a new date"],
     ["ask them to confirm whether a partial shipment is acceptable", "ask them to call back before noon to decide on the new date", "offer to send a revised delivery note by email", "warn that the delay may affect the next order too"]),
    ("supplier sales contact leaving a voicemail", "supplier sales contact", "price or lead-time change",
     ["lead time moves from four weeks to six weeks from next month", "a minimum order quantity is being introduced", "a surcharge on fuel applies to orders from the first of the month", "prices stay the same but the quote is only valid until Friday"],
     ["suggest placing the order this week to keep the old terms", "ask for a call to talk through alternatives", "promise a written confirmation by tomorrow", "mention a possible discount for a longer contract"]),
    ("quality representative at a packaging supplier", "supplier quality manager", "a quality issue with a delivered lot",
     ["a few cartons in lot 4471 have labels printed slightly off-centre", "a certificate of analysis was missing from the last delivery", "a sample from the latest batch is outside the agreed tolerance", "the supplier found a problem in its own audit and wants to inform the customer early"],
     ["ask the team to quarantine the lot until they speak", "offer a replacement lot at no cost", "ask for photos and the lot number by email", "propose a short call with both quality teams"]),
    ("logistics coordinator at a freight company", "freight coordinator", "pickup or delivery appointment change",
     ["the pickup moves from Tuesday morning to Wednesday afternoon", "the driver will arrive at dock 3 instead of dock 1", "the delivery window shrinks to two hours", "the truck needs a driver's contact number before arriving"],
     ["ask them to reply with a name for the gate", "remind them that the dock closes at four", "say the driver will phone fifteen minutes before arrival", "ask whether the temperature logger is ready"]),
    ("supplier account manager", "supplier account manager", "confirming an order and asking for missing information",
     ["the purchase order is confirmed for 12,000 units", "the order is confirmed but the delivery address is incomplete", "the supplier can deliver on time if they get the final forecast today", "the order is split into two deliveries one week apart"],
     ["ask for the missing purchase-order number", "ask for a firm forecast for the next quarter", "mention that the office is closed on Friday", "ask them to reply in writing, not by phone"]),
    ("supplier representative", "supplier representative", "a request to reschedule a supplier review meeting",
     ["the quarterly review on Thursday must move because their director is travelling", "they would like to add a third person from their quality team", "they propose to hold the review online instead of on site", "they need the agenda two days before the meeting"],
     ["suggest two possible new slots", "ask the team to send their OTIF figures before the meeting", "apologise and ask for a reply by Wednesday", "say they will bring updated capacity numbers"]),
])

G["colleague_voicemail"] = (30, [
    ("colleague in another country leaving a voicemail", "supply planner at another site", "a forecast change",
     ["the forecast for the next quarter was revised up by eight percent", "a large order from one market was cancelled, so demand drops for two months", "a tender result will change next month's volumes", "the demand review moved a launch forward by three weeks"],
     ["ask for an updated supply plan by Thursday", "ask the listener to flag any capacity concern today", "say the new numbers are already in the shared file", "suggest a short call tomorrow morning"]),
    ("manager leaving a voicemail while travelling", "line manager", "a change to a meeting",
     ["the weekly review moves to 3 p.m. and a new person will join", "the meeting is cancelled and replaced by an email update", "the agenda changes and the listener should present the inventory numbers", "the room is changed and half the team will join online"],
     ["ask the listener to prepare two slides only", "remind the listener to send the data file beforehand", "say the manager will be late by ten minutes", "ask the listener to share the link with the team"]),
    ("colleague from quality assurance", "quality assurance colleague", "a batch on hold and a request for information",
     ["a batch is on hold while the lab repeats one test", "a deviation report is open and the supply plan may need a change", "the release of a batch is delayed until Friday", "a document needs a second signature before release"],
     ["ask the listener to hold the shipment until QA confirms", "ask for the planned dispatch date", "say QA will send a written update at five", "ask the listener to warn the customer service team"]),
    ("teammate leaving a handover message before holiday", "teammate going on leave", "a handover before a holiday",
     ["she is away from Monday for two weeks and a colleague covers her suppliers", "the open orders are listed in the shared tracker", "one urgent shipment needs checking on Tuesday", "the weekly report is due on Thursday and the template is in the team folder"],
     ["say who to contact for emergencies", "ask the listener to confirm they got the tracker link", "mention that her phone will be off", "thank the listener and promise a coffee on return"]),
    ("colleague from finance", "finance colleague", "a budget or invoice question",
     ["an invoice does not match the purchase order by about two thousand euros", "the budget for freight is nearly used up this quarter", "the month-end close is on Wednesday and accruals are needed by Tuesday", "a cost centre code is wrong on a recent order"],
     ["ask for the correct code by email", "ask the listener to check the goods receipt first", "offer to join a short call", "ask for approval before noon"]),
    ("new team member leaving a polite voicemail", "new team member", "asking for help with a tool or report",
     ["she cannot open the inventory dashboard and gets an access error", "he needs help finding last month's shortfall report", "she wants to understand one column in the forecast file", "he needs the right person to approve his system access"],
     ["say they will try again after lunch", "ask the listener to reply by chat if the phone is busy", "mention they are free all afternoon", "thank the listener in advance"]),
    ("colleague from a distribution centre", "warehouse team lead", "a stock discrepancy found on a count",
     ["the physical count shows 140 fewer units than the system", "two pallets are in the wrong location and cannot be picked", "an inventory variance appeared after the cycle count", "a pallet label is damaged and the batch cannot be scanned"],
     ["ask the planner to block the stock in the system", "ask whether the order for tomorrow can be covered another way", "say they will recount in the morning", "request an urgent call back"]),
])

G["site_ops"] = (40, [
    ("manufacturing site loudspeaker", "site operations manager", "a planned shutdown or maintenance window",
     ["power to the packaging hall will be off from 6 a.m. to noon on Saturday", "the water system is tested this weekend and the canteen is closed", "the car park nearest the gate is closed for resurfacing for three days", "the main lift in Building C is out of service until Wednesday"],
     ["staff should use the stairs and the east entrance", "contractors need a visitor badge from reception", "anyone working Saturday should tell their line manager", "the shuttle bus runs every ten minutes instead"]),
    ("warehouse floor announcement", "warehouse supervisor", "a change to loading or dispatch times",
     ["the last truck leaves at 4 p.m. instead of 6 p.m. today", "outbound pallets must be wrapped and labelled by two o'clock", "dock 2 is closed and all trucks use dock 4", "an extra shift starts at 10 p.m. to clear a backlog"],
     ["drivers must check in at the gatehouse", "forklift drivers should check the new floor plan", "temperature-controlled goods go first", "overtime is voluntary and sign-up is at the desk"]),
    ("cold-chain storage announcement", "cold-store supervisor", "a temperature alarm or cold-room procedure",
     ["cold room 3 will be closed for calibration from nine to eleven", "a door alarm has sounded and product is being checked", "the freezer will defrost on Sunday and stock moves to room 2", "a new logger must be placed in every shipment from Monday"],
     ["only authorised staff may enter", "nobody should leave the door open", "report any alarm to the control room at once", "a short training takes place at the start of each shift"]),
    ("quality laboratory announcement", "laboratory manager", "a change in sample handling",
     ["samples must reach the lab by 2 p.m. to be tested the same day", "the sample fridge is moved to the second floor", "the lab is closed to visitors on Thursday because of an audit", "new labels are required on all sample bags"],
     ["bring the paperwork with each sample", "ask the lab team for the new labels", "do not leave samples at the front desk", "audit questions go to the quality office"]),
    ("production site announcement", "site director", "an audit or inspection visit",
     ["an external audit takes place next Tuesday and Wednesday", "inspectors will tour the packaging lines on Thursday morning", "a customer audit team visits the warehouse this afternoon", "the internal audit starts a day earlier than planned"],
     ["everyone should keep their area tidy and documents up to date", "staff should answer honestly and ask for help if unsure", "do not take photos during the visit", "visitors must wear the correct protective clothing"]),
    ("site announcement", "operations coordinator", "a new procedure or policy",
     ["every pallet leaving the site now needs a second check before dispatch", "visitor badges must be returned at the gate", "mobile phones are not allowed on the packaging floor from next week", "the shift handover now includes a written note"],
     ["a short guide is on the intranet", "the policy starts on the first of next month", "supervisors will explain it at the shift start", "questions go to the quality team"]),
    ("warehouse announcement", "inventory control lead", "a cycle count or stock check",
     ["the cycle count for aisles 10 to 14 happens tonight", "stock in zone B is frozen until the count is finished", "the annual stock take is on the last weekend of the month", "counters will need access to the high racks tomorrow morning"],
     ["do not move pallets in the counted zone", "report any missing label to the lead", "scanners must be charged before the shift", "the count team starts at 7 a.m."]),
])

G["it_outage"] = (30, [
    ("company-wide message from the IT service desk", "IT service desk lead", "a planned system downtime",
     ["the ERP system will be unavailable from 8 p.m. Saturday until 6 a.m. Sunday", "the email system is updated overnight and mail may be delayed", "the planning tool is offline for two hours at lunchtime on Wednesday", "the VPN is unavailable between midnight and 4 a.m."],
     ["save your work before the downtime", "urgent orders must be entered before 6 p.m.", "the help desk is open on the phone only", "a status page shows when the system is back"]),
    ("IT announcement during an unplanned incident", "IT incident manager", "an unplanned outage under investigation",
     ["the inventory dashboard has been down since ten o'clock", "nobody can log in to the shared drive", "the video-call platform is slow and calls are dropping", "the printing service has stopped across Building C"],
     ["use the backup phone line for urgent matters", "do not restart your computer", "the next update will be at one o'clock", "join meetings by phone if the video fails"]),
    ("IT security message", "IT security officer", "a suspicious email or password reset",
     ["a fake email about a delivery notification is circulating", "everyone must change their password by Friday", "multi-factor authentication becomes mandatory next Monday", "a phishing test will be sent to all staff this month"],
     ["do not click links in the suspicious message", "forward it to the security mailbox", "use the self-service portal to reset", "a ten-minute training video is on the intranet"]),
    ("IT rollout announcement", "project lead for a new tool", "a new tool or software rollout",
     ["a new forecasting tool replaces the old spreadsheets from the first of the month", "everyone's laptop updates automatically on Thursday night", "the new expense app goes live next week", "a new ticket system replaces email requests"],
     ["training sessions are on Tuesday and Thursday", "log in once before the go-live date", "the old system stays read-only for a month", "super-users are available on each floor"]),
    ("IT announcement about the network", "network engineer", "a network or Wi-Fi change",
     ["the guest Wi-Fi is renamed and has a new password", "the office Wi-Fi is down on the third floor during repairs", "the VPN is moving to a new address next week", "a faster connection is installed in the warehouse"],
     ["reconnect your devices after the change", "use the wired port at your desk meanwhile", "visitors should ask reception for the code", "report any problem to the service desk"]),
])

G["safety_drill"] = (25, [
    ("fire drill announcement over the loudspeaker", "health and safety officer", "a scheduled fire drill",
     ["a fire drill takes place at 10:30 this morning", "the alarm will sound for about two minutes during the drill", "the drill starts at the end of the lunch break", "the drill happens in Building C only"],
     ["leave through the nearest exit and gather at the car park", "do not use the lifts", "wardens will wear yellow vests", "report to your warden for the head count"]),
    ("site safety briefing", "safety coordinator", "a new safety rule on the site",
     ["safety glasses are required in all warehouse aisles from Monday", "forklifts have a new speed limit of ten kilometres per hour", "pedestrian walkways in the yard are marked in green", "nobody may carry a hot drink on the production floor"],
     ["supervisors will check the rules this week", "free glasses are available at the store", "report any near miss to your supervisor", "a short toolbox talk is held at shift start"]),
    ("evacuation test announcement", "building manager", "an emergency evacuation test with a changed assembly point",
     ["the usual assembly point is under construction and the new one is the east lawn", "the test is unannounced this quarter", "the evacuation includes a check of the visitor list", "the test measures how long it takes to empty the building"],
     ["visitors leave with their hosts", "people with reduced mobility should contact a warden beforehand", "take your badge but not your coat", "wait for the all-clear before going back"]),
    ("first-aid and wellbeing announcement", "occupational health nurse", "a first-aid, flu-vaccine or health-check event",
     ["flu vaccinations are offered on the ground floor next Wednesday", "new defibrillators are installed on each floor", "first-aid refresher courses start on the 14th", "a health check day is on Thursday"],
     ["book a time slot on the intranet", "it is voluntary and free", "the training takes three hours", "bring your employee badge"]),
    ("weather and travel notice", "facilities manager", "a weather or transport disruption affecting the site",
     ["heavy snow is expected tonight and the car park may close", "a train strike affects the usual commuter line on Thursday", "a storm warning means outdoor work stops at three", "flooding closes the main access road"],
     ["staff may work from home if their manager agrees", "the shuttle runs from the next station", "check the intranet before leaving home", "drivers should leave extra time"]),
])

G["all_hands"] = (30, [
    ("all-hands meeting opening", "head of supply chain", "logistics and agenda for a monthly all-hands",
     ["the meeting is in the main hall at ten and also streamed", "the agenda has three items: results, a new project and questions", "the session is shorter this month, finishing at 11:15", "snacks are served afterwards on the first floor"],
     ["send questions in advance through the form", "the recording is shared afterwards", "remote staff should use the link in the invitation", "sit near the front if you want to ask something"]),
    ("update from the site leader", "site leader", "a results or performance update",
     ["on-time delivery rose from 91 to 95 percent this quarter", "inventory levels dropped by ten percent after the clean-up project", "the team passed the audit with no major findings", "complaints from customers fell by a third"],
     ["thank the planning, warehouse and quality teams", "say the next target is even more demanding", "ask everyone to keep reporting problems early", "announce a team lunch next Friday"]),
    ("announcement from management", "department head", "an organisational change",
     ["two teams merge into one planning department from next month", "a new manager joins the demand planning team on Monday", "the supplier management group moves to the second floor", "the shift system changes from three to four shifts"],
     ["a question session is held on Thursday", "nothing changes for ongoing orders", "details will follow in an email", "people affected will get a personal call"]),
    ("hybrid-work and office announcement", "workplace manager", "a change to desk booking or hybrid working",
     ["desks must be booked the day before through the app", "the quiet zone moves to the fourth floor", "the office is closed on the bridge day after the holiday", "team days are now Tuesday and Thursday"],
     ["unbooked desks are released at nine", "lockers need a new key", "ask facilities if you need a special desk", "the policy is reviewed after three months"]),
    ("project kickoff announcement", "project sponsor", "a new project or initiative launch",
     ["a project to cut transport emissions starts next week", "a pilot of a new planning process begins in two markets", "a data-quality clean-up starts with the supplier master list", "a new weekly meeting on shortages starts on Monday"],
     ["volunteers are welcome from every team", "the first workshop is on the 20th", "a short summary is on the intranet", "contact the project office to join"]),
    ("HR announcement to staff", "HR partner", "a deadline for forms, training or reviews",
     ["mid-year reviews must be finished by the end of the month", "compliance training must be completed by Friday", "holiday requests for December close on the 15th", "the engagement survey closes tomorrow evening"],
     ["it takes about fifteen minutes", "the link is in the email from HR", "managers will send reminders", "answers are anonymous"]),
])

G["transport"] = (40, [
    ("airport gate announcement", "gate agent", "a gate change",
     ["flight 482 to {city} now boards at gate B17 instead of B9", "the {city} flight moves to gate 22 on the lower level", "boarding for the {city} flight is delayed by twenty minutes and moves to gate A4", "the gate for the {city} service has changed to C12"],
     ["passengers should hurry because the walk takes ten minutes", "boarding starts with families and priority passengers", "have your passport and boarding pass ready", "screens in the terminal show the new gate"]),
    ("airport delay announcement", "airport customer-service agent", "a flight delay",
     ["the flight to {city} is delayed by two hours because of fog", "the aircraft for {city} arrives late from the previous flight", "an air traffic restriction delays all departures by ninety minutes", "a technical check delays the {city} flight until 7:40"],
     ["meal vouchers are available at the service desk", "do not leave the departure area", "listen for further updates every thirty minutes", "passengers with connections should visit the transfer desk"]),
    ("airport baggage or security announcement", "airport security officer", "a baggage or security reminder",
     ["unattended bags will be removed", "liquids over 100 millilitres must be placed in the tray", "the lost-property office has moved to level 1", "oversized baggage goes to the special counter"],
     ["keep your luggage with you", "have your boarding pass ready at the checkpoint", "ask staff in blue vests if you are unsure", "the office opens daily from 8 to 8"]),
    ("train station announcement", "station announcer", "a platform change",
     ["the 9:15 to {city} leaves from platform 3 instead of platform 7", "the express to {city} is on the opposite side of the station", "the regional train to {city} now departs from the lower platform", "the evening train to {city} is shortened to four carriages"],
     ["passengers should use the underpass", "seat reservations are not valid on the shortened train", "mind the gap when boarding", "the next announcement will be in two minutes"]),
    ("train service announcement", "railway customer-service announcer", "a cancellation or delay",
     ["the 17:40 to {city} is cancelled because of a signal fault", "trains to {city} run every hour instead of every half hour", "a track repair stops all trains between two stations this weekend", "a train is delayed by thirty-five minutes"],
     ["tickets remain valid on the next service", "replacement buses leave from the front of the station", "refund forms are at the information desk", "check the app for live times"]),
    ("onboard train announcement", "train conductor", "an arrival and connection information",
     ["the train arrives in {city} in ten minutes and the connection to the airport leaves from platform 5", "this is the last stop and the train does not continue", "the next stop is {city} and doors open on the left", "the restaurant car closes in half an hour"],
     ["check around your seat for belongings", "tickets will be checked once more", "the connecting train waits for passengers", "wheelchair users should ask staff for a ramp"]),
    ("ferry or bus terminal announcement", "terminal announcer", "an arrival, boarding or timetable change",
     ["the ferry to the island leaves forty minutes later than planned because of wind", "bus 24 to the airport stops at a temporary stop across the road", "the night bus to {city} is fully booked, and an extra bus is added", "boarding for the coach to {city} begins at bay 9"],
     ["foot passengers board first", "have your ticket on your phone", "luggage goes in the hold under the bus", "stay away from the edge of the dock"]),
    ("hotel front desk announcement", "hotel receptionist", "a hotel service change",
     ["breakfast is served from 7 until 10 on the ground floor, an hour later at the weekend", "the pool is closed for cleaning until noon", "the lift on the east side is out of service", "check-out is extended to 1 p.m. because of a late checkout request"],
     ["luggage can be stored free of charge", "ask for a taxi at least thirty minutes ahead", "late arrivals use the side door with the code", "the gym is open all day"]),
])

G["conference"] = (30, [
    ("conference housekeeping announcement", "conference host", "a session schedule or room change",
     ["the keynote moves to the large hall in Hall A at 9:30", "the workshop on demand planning moves to room 204 and starts at 2 p.m.", "the afternoon session on risk starts fifteen minutes late", "the panel is shortened by ten minutes to fit lunch"],
     ["the programme in the app is updated", "volunteers in orange shirts help with directions", "coffee is served outside the room", "the slides are shared afterwards"]),
    ("webinar opening", "webinar moderator", "technical housekeeping at the start of an online session",
     ["the webinar is being recorded and the link is sent tomorrow", "questions go in the chat box and the host reads them at the end", "attendees are muted at the start", "there is live captioning if you click the button"],
     ["raise a hand icon if you want to speak", "use the poll in the second half", "the session lasts exactly forty-five minutes", "a feedback form follows at the end"]),
    ("conference lunch and logistics announcement", "event organiser", "lunch, registration or transport information",
     ["lunch is served in the atrium from 12:30 and vegetarian meals are at the left counter", "the evening shuttle to the hotel leaves at six from the main entrance", "registration for tomorrow opens at 8 a.m.", "name badges are required to enter the lunch area"],
     ["the cloakroom closes at 6:30", "free Wi-Fi is available with the event code", "a lost phone is at the information desk", "tomorrow's start time is 9 sharp"]),
    ("training session opening", "trainer", "the rules and plan for a training day",
     ["the course runs from 9 to 4 with a lunch break at noon", "everyone gets a workbook and a login for the online tool", "groups of four are formed after the first break", "there is a short quiz at the end of the morning"],
     ["phones on silent", "ask questions at any time", "the slides are in the folder on the desk", "certificates are issued at the end"]),
    ("speaker introduction announcement", "master of ceremonies", "introducing a session and a speaker",
     ["the next speaker leads the supply planning team at a global company and will talk about resilient supply chains", "a short video starts the session before the talk", "there is a short Q&A after the 25-minute talk", "the panel includes three experts from logistics, quality and finance"],
     ["please welcome the speaker", "turn off the phone ringer", "scan the code to ask a question", "the session is being filmed"]),
    ("meeting-room announcement", "meeting facilitator", "starting an online or hybrid team meeting",
     ["the meeting begins with a five-minute update and the agenda has four items", "the host asks participants to rename themselves with their country", "the call is limited to thirty minutes because of the next meeting", "a decision on the supplier shortlist is needed before the end"],
     ["keep your microphone off unless you speak", "use the chat for short questions", "notes are taken by one named person", "actions are assigned at the end"]),
])

G["everyday_voicemail"] = (30, [
    ("pharmacy voicemail", "pharmacist", "a prescription or order ready for collection",
     ["a prescription is ready and the pharmacy closes at 7 p.m.", "an order arrived but a different brand of the product is in stock", "the pharmacy needs the patient's date of birth to confirm the order", "a repeat prescription needs a new check with the doctor"],
     ["bring an ID", "call back if the brand is a problem", "the pharmacy is closed on Sunday", "collection is possible until Friday"]),
    ("clinic reception voicemail", "clinic receptionist", "an appointment change",
     ["an appointment on Tuesday at 9:15 must move to Thursday at 11", "the doctor is ill, so a colleague will see the patient instead", "the clinic needs a fasting blood test before the visit", "a visit is confirmed for Monday and the patient should come ten minutes early"],
     ["call to confirm the new time", "bring the previous test results", "fill in the form online beforehand", "cancel at least a day before if it does not work"]),
    ("courier voicemail", "delivery driver", "a missed delivery",
     ["a parcel could not be delivered because nobody opened the door", "the driver will return tomorrow between 2 and 4", "the parcel is at the pickup point and stays for five days", "the courier needs a signature and an adult must be present"],
     ["call to arrange a new time", "collect from the pickup point with ID", "leave instructions with the neighbour", "use the tracking link"]),
    ("bank voicemail", "bank advisor", "a card, account or appointment notice",
     ["a new debit card is ready to collect at the branch", "a meeting about a business account is moved to Friday at ten", "a payment needs confirmation in the banking app", "the branch is closed on Monday for staff training"],
     ["never share the PIN with anyone", "bring photo identification", "use the app to confirm", "call the number on the back of the card"]),
    ("hotel or event voicemail", "event coordinator", "a booking confirmation with a change",
     ["a room is confirmed for the 18th but breakfast is not included", "a team dinner is moved to a restaurant nearer the station", "the group booking needs the final number of guests by Thursday", "the conference room is available from 8 a.m. instead of 9"],
     ["reply with the final list", "ask for a quote with breakfast", "the restaurant keeps the table until 7:30", "send dietary needs by email"]),
    ("gym or club voicemail", "membership manager", "a schedule or membership change",
     ["the Tuesday class moves from 7 to 6:30 p.m.", "the pool is closed for repairs for a week", "the annual membership renews at the end of the month", "a free trial session is offered on Saturday"],
     ["book through the app", "bring your own towel", "the new price is on the website", "call the front desk to cancel or change"]),
])

# question types the three questions are drawn from (always includes "detail")
FOCUS = ["purpose", "detail", "action", "reason", "next", "number", "inference", "not-stated-contrast"]
OPENERS = ["start with a greeting that fits the setting and a short natural self-introduction",
           "start directly with the news (no greeting)",
           "start with a time reference ('As of this morning...', 'Just before lunch...')",
           "start with a short apology or thanks",
           "start with the listener's name or group ('Hello, team', 'Good afternoon, passengers', 'Hi there')",
           "start with the speaker's role and why they are calling or speaking",
           "start with a short reminder of what happened earlier",
           "start with 'Quick update' or similar plain-language flag"]
CEFR_POOL = ["B1", "B1+", "B1+", "B2", "B2", "B2", "B2+", "B2+", "C1"]
WORKPLACE_GENRES = {"supplier_voicemail", "colleague_voicemail", "site_ops", "it_outage", "all_hands", "conference"}


def h(s: str) -> int:
    return int(hashlib.sha256(s.encode()).hexdigest()[:8], 16)


def build_rows() -> list[dict]:
    rng = random.Random(SEED)
    rows: list[dict] = []
    for genre, (n, scen) in G.items():
        by_s: dict[int, list] = {}
        for si, (_, _, _, da, db) in enumerate(scen):
            cs = [(si, a, b) for a in range(len(da)) for b in range(len(db))]
            rng.shuffle(cs)
            by_s[si] = cs
        picked, usedA = [], Counter()
        order = list(by_s)
        while len(picked) < n and any(by_s.values()):
            for s in order:
                if by_s[s] and len(picked) < n:
                    by_s[s].sort(key=lambda c: usedA[(c[0], c[1])])
                    c = by_s[s].pop(0)
                    usedA[(c[0], c[1])] += 1
                    picked.append(c)
        for si, a, b in picked:
            setting, role, purpose, da, db = scen[si]
            city = rng.choice(CITIES)
            rows.append({"genre": genre, "setting": setting, "speakerRole": role, "purpose": purpose,
                         "detailA": da[a].replace("{city}", city), "detailB": db[b]})
    rng.shuffle(rows)
    per_genre: Counter = Counter()
    for r in rows:
        g = r["genre"]
        r["voice"] = ("female", "male")[(per_genre[g] + h(g)) % 2]
        per_genre[g] += 1
        first = rng.choice(FEMALE if r["voice"] == "female" else MALE)
        r["speakerName"] = f"{first} {rng.choice(SURNAMES)}" if "supplier" in g else first
        r["otherPerson"] = rng.choice(MALE if r["voice"] == "female" else FEMALE)
        r["supplierName"] = rng.choice(SUPPLIERS)
        r["day"] = rng.choice(DAYS)
        r["site"] = rng.choice(SITES)
        r["number"] = rng.choice([12, 15, 20, 25, 30, 40, 45, 50, 90, 120, 250, 480])
        r["cefr"] = rng.choice(CEFR_POOL)
        r["targetWords"] = rng.choice([85, 90, 95, 100, 105, 110, 115, 120, 125, 130])
        r["questionFocus"] = ["detail"] + rng.sample([f for f in FOCUS if f != "detail"], 2)
        r["opener"] = rng.choice(OPENERS)
    for i, r in enumerate(rows, 1):
        key = "|".join([r["genre"], r["setting"], r["purpose"], r["detailA"], r["detailB"]])
        r["sourceId"] = f"gen-{ids.sha8(key)}"
        r["id"] = f"la-gen-{ids.sha8(key)}"
    return rows


def seed_text(r: dict) -> str:
    return f"{r['setting']}. {r['purpose']}. {r['detailA']}. {r['detailB']}"


def extract(stage: Path, report: Path) -> None:
    stage.mkdir(parents=True, exist_ok=True)
    (stage / "batches").mkdir(exist_ok=True)
    for old in (stage / "batches").glob("batch_*.jsonl"):
        if ".filled." not in old.name:
            old.unlink()
    rows = build_rows()
    idx = dedupe.DedupeIndex.from_content(ROOT / "Content", threshold=0.7)
    seed_idx = dedupe.DedupeIndex(threshold=0.7)
    kept, rejects, seen = [], [], set()
    for r in rows:
        t = seed_text(r)
        why = ("duplicate id" if r["id"] in seen else None) or seed_idx.check(t) or idx.check(t)
        if why:
            rejects.append((r["sourceId"], why))
            continue
        seed_idx.add(r["sourceId"], t)
        seen.add(r["id"])
        kept.append(r)
    with (stage / "rows.jsonl").open("w", encoding="utf-8") as f:
        for r in kept:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    chunks = [kept[b:b + ROWS_PER_BATCH] for b in range(0, len(kept), ROWS_PER_BATCH)]
    if len(chunks) > 1 and len(chunks[-1]) < 25:
        last = chunks.pop()
        chunks[-1] += last
    for n, chunk in enumerate(chunks, 1):
        with (stage / "batches" / f"batch_{n:03d}.jsonl").open("w", encoding="utf-8") as f:
            for r in chunk:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
    c_g, c_v, c_c = Counter(r["genre"] for r in kept), Counter(r["voice"] for r in kept), Counter(r["cefr"] for r in kept)
    lines = ["# gen-announce extract", "",
             f"- scenario rows: {len(rows)}; after dedupe (0.7 vs Content and within run): {len(kept)}; rejected: {len(rejects)}; batches: {len(chunks)}",
             "- target 200 final items; ~320 rows because fill agents may reject up to ~35%",
             "- origin generated; licence: original text written for Tenaz (tier permissive; the schema has no 'generated' tier)", "",
             "## Genres", ""] + [f"- {k}: {v}" for k, v in sorted(c_g.items())] + \
            ["", "## Voice", ""] + [f"- {k}: {v}" for k, v in c_v.items()] + \
            ["", "## Target CEFR", ""] + [f"- {k}: {v}" for k, v in sorted(c_c.items())] + \
            ["", "## Rejects", ""] + [f"- {a}: {b}" for a, b in rejects[:50]]
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines[2:3]))


def emit_step(stage: Path, report: Path) -> None:
    rows = {json.loads(l)["sourceId"]: json.loads(l) for l in (stage / "rows.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()}
    own = ROOT / "Content" / "items" / "listen-announcement-gen.json"
    if own.exists():
        own.unlink()  # idempotent rewrite: its previous ids/text must not collide with itself
    idx = dedupe.DedupeIndex.from_content(ROOT / "Content", threshold=0.7)
    out, rej = [], []
    per_batch: dict[str, Counter] = {}
    filters: Counter = Counter()
    seen_src: set[str] = set()
    for fp in sorted((stage / "batches").glob("batch_*.filled.jsonl")):
        pb = per_batch.setdefault(fp.name.split(".")[0], Counter())
        for line in fp.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            f = json.loads(line)
            pb["rows"] += 1
            r = rows.get(f.get("sourceId"))
            if not r:
                rej.append((f.get("sourceId"), "unknown sourceId")); filters["unknown sourceId"] += 1; pb["rejected"] += 1
                continue
            if r["sourceId"] in seen_src:
                rej.append((r["sourceId"], "duplicate sourceId")); filters["duplicate sourceId"] += 1; pb["rejected"] += 1
                continue
            seen_src.add(r["sourceId"])
            if f.get("reject"):
                rej.append((r["sourceId"], f"fill agent: {f['reject']}")); filters["fill agent reject"] += 1; pb["rejected"] += 1
                continue
            item = {"id": r["id"], "type": "listenAnnouncement", "cefr": f.get("cefr") or r["cefr"], "skill": "listening",
                    "title": str(f.get("title", "")).strip(), "voice": r["voice"],
                    "script": textnorm.fix_unicode(str(f.get("script", ""))).strip(),
                    "questions": f.get("questions"), "source": SRC, "sourceId": r["sourceId"],
                    "license": "Original (written for Tenaz)", "tier": "permissive", "origin": "generated",
                    "topics": ["workplace" if r["genre"] in WORKPLACE_GENRES else "everyday", r["genre"]]}
            probs = schema.problems_item(item)
            if probs:
                why = "schema: " + "; ".join(probs); filters["schema"] += 1
            else:
                qs = item["questions"]
                opts_ok = all(len({o.strip().lower() for o in q["options"]}) == 4 for q in qs)
                if not opts_ok:
                    why = "duplicate options"; filters["duplicate options"] += 1
                else:
                    why = idx.check(dedupe.item_text(item))
                    if why:
                        filters["dedupe"] += 1
            if why:
                rej.append((r["sourceId"], why)); pb["rejected"] += 1
                continue
            idx.add(r["id"], dedupe.item_text(item))
            out.append(item)
            pb["emitted"] += 1
    emit_lib.emit(ROOT / "Content", "items", "listen-announcement-gen.json", out, source="Tenaz generated announcements",
                  url="", license="Original (written for Tenaz)", tier="permissive",
                  attribution="Generated for Tenaz from the scenario matrix in scripts/ingest/sources/gen-announce.py")
    wc = [textnorm.word_count(i["script"]) for i in out]
    lines = ["", "## emit", "", f"- emitted: {len(out)}; rejected: {len(rej)}", "",
             "### Per-batch reject rate", ""]
    for k, c in sorted(per_batch.items()):
        lines.append(f"- {k}: {c['rows']} rows, {c['rejected']} rejected ({100 * c['rejected'] / max(1, c['rows']):.1f}%), {c['emitted']} emitted")
    lines += ["", f"- scenario rows never filled (no batch covered them): {len(set(rows) - seen_src)}"]
    lines += ["", "### Rejects per filter", ""] + [f"- {k}: {v}" for k, v in filters.items()]
    lines += ["", "### Distributions", "",
              f"- voice: {dict(Counter(i['voice'] for i in out))}",
              f"- cefr: {dict(sorted(Counter(i['cefr'] for i in out).items()))}",
              f"- genre: {dict(sorted(Counter(i['topics'][1] for i in out).items()))}",
              f"- answer index (all questions): {dict(sorted(Counter(q['answer'] for i in out for q in i['questions']).items()))}",
              f"- script words: min {min(wc)}, median {sorted(wc)[len(wc) // 2]}, max {max(wc)}",
              "- origin: generated for all; tier permissive", "", "### Rejected ids", ""]
    lines += [f"- {a}: {b}" for a, b in rej[:80]]
    sample = random.Random(1).sample(out, min(30, len(out)))
    lines += ["", "### Random sample (30)", ""]
    for i in sample:
        lines += [f"**{i['id']}** [{i['cefr']}, {i['voice']}, {i['topics'][1]}] {i['title']}", "", i["script"], ""]
        for q in i["questions"]:
            lines.append(f"- {q['q']} -> {q['options'][q['answer']]} ({q['explanation']})")
        lines.append("")
    with report.open("a", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print(f"emitted {len(out)}, rejected {len(rej)}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["fetch", "extract", "emit"])
    ap.add_argument("--raw", default=str(ROOT / ".ingest/raw" / SRC))
    ap.add_argument("--stage", default=str(ROOT / ".ingest/stage" / SRC))
    ap.add_argument("--report", default=str(ROOT / ".ingest/reports" / f"{SRC}.md"))
    a = ap.parse_args()
    if a.cmd == "fetch":
        print("generated source: nothing to fetch")
    elif a.cmd == "extract":
        extract(Path(a.stage), Path(a.report))
    else:
        emit_step(Path(a.stage), Path(a.report))


if __name__ == "__main__":
    main()
