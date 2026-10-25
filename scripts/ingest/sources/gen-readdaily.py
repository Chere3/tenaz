"""P3 gen-readdaily: generated workplace/everyday-genre readDaily items (STAGE + EMIT; the LLM fill happens in between).

  extract -> .ingest/stage/gen-readdaily/scenarios.jsonl            all scenario rows
             .ingest/stage/gen-readdaily/batches/batch_NNN.jsonl    25-50 rows each, for the fill agents
             .ingest/reports/gen-readdaily.md
  emit    -> reads batches/batch_NNN.filled.jsonl, validates, dedupes (0.7) and writes Content/items/read-daily-gen.json
  (no fetch: nothing is downloaded; origin=generated, tier=permissive, original Tenaz text, no licenses.json obligations beyond the entry)

Run: uv run --project scripts/ingest python -I scripts/ingest/sources/gen-readdaily.py extract
"""
from __future__ import annotations

import argparse
import json
import random
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import dedupe, ids, schema, textnorm  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
SEED = 20261024
OUT_FILE = "read-daily-gen.json"

# genre -> (format instruction, [situations]); 20 situations per genre -> 400 distinct (genre, situation) rows
WORK = "workplace"
EVERY = "everyday"
GENRES: dict[str, tuple[str, str, list[str]]] = {
    "teams_chat": (WORK, "A Teams/Slack chat excerpt: 3-7 short messages, each line 'Name: message', informal-professional tone, contractions, one or two emoji-free abbreviations at most (ETA, FYI, EOD).", [
        "a supplier confirms a shorter lead time for one raw material but not for packaging",
        "two planners disagree on whether to trust last month's forecast for a launch product",
        "someone asks who owns a mismatch between ERP stock and the warehouse count",
        "a colleague cannot open the new S&OP dashboard and gets a permissions workaround",
        "a peer in another country asks to move a call because of a public holiday",
        "a teammate shares the OTIF figure for the week and explains why it dropped",
        "a manager asks for a quick status on a shipment held at customs",
        "someone offers to cover a colleague's tasks during a week off",
        "a planner asks QA whether a batch can be released before the weekend",
        "a team agrees how to split the work for a quarter-end inventory review",
        "a colleague asks whether the safety stock rule changed for a slow-moving item",
        "a new team member asks where to find the weekly demand review slides",
        "a peer flags that a master-data field is wrong and asks who can fix it",
        "the team reacts to a carrier's message that a pallet was damaged",
        "someone asks for the latest version of a spreadsheet and gets three conflicting answers",
        "a manager gently asks why a report was sent late",
        "two colleagues plan who presents which slide in tomorrow's review",
        "a planner thanks a supplier contact for expediting an urgent order and asks about the next one",
        "a colleague asks to postpone a decision until finance confirms the budget",
        "the team debates whether to air-freight a small order to avoid a stock-out",
    ]),
    "email_internal": (WORK, "An internal email with a Subject line, greeting, 2-3 short paragraphs, and sign-off.", [
        "a manager summarises decisions from the monthly demand review and lists two follow-up actions",
        "a planner apologises for a wrong number in last week's forecast and sends the corrected figure",
        "a team lead announces a new approval step for purchase orders above a limit",
        "a colleague asks several teams to confirm their inventory counts by a deadline",
        "a peer declines politely to take on an extra report and proposes an alternative",
        "a manager recognises the team for reducing backorders and shares what comes next",
        "a colleague hands over a project before going on leave and says who to contact",
        "someone asks for clarification about a requirement in a data request",
        "a planner follows up after a meeting and recaps who will do what",
        "a manager announces a change in the weekly reporting schedule",
        "a buyer informs the team that a contract renewal is delayed and explains the impact",
        "a colleague invites the team to a short training on a new planning tool",
        "a supply planner escalates a recurring shortage to the head of the department",
        "a finance partner explains why a purchase request was sent back",
        "an analyst explains why two reports show different inventory totals",
        "a manager asks for volunteers for a cross-site working group",
        "a colleague shares the outcome of a supplier audit visit in plain terms",
        "a team lead reminds everyone about timesheet and holiday planning for year end",
        "a planner requests an exception to a freeze period and justifies it",
        "an IT contact explains that a report will be unavailable during a system upgrade",
    ]),
    "email_supplier": (WORK, "An email between a company and an external supplier or carrier, with Subject, greeting, short paragraphs, polite business English, sign-off with name and company (invented).", [
        "a supplier proposes a new delivery date because a component is delayed",
        "a buyer asks a supplier to confirm quantities and price before placing an order",
        "a supplier explains a price increase and offers a volume discount",
        "a buyer complains that a delivery arrived with missing documents",
        "a carrier asks for a customs invoice to release a shipment",
        "a supplier asks whether the forecast shared last month is firm or indicative",
        "a buyer asks a supplier to split one large order into two shipments",
        "a supplier confirms a corrected certificate of analysis has been uploaded",
        "a buyer asks for a revised quote with a longer payment term",
        "a supplier announces a planned maintenance shutdown and its effect on capacity",
        "a buyer thanks a supplier for the quick response and asks for weekly updates",
        "a supplier requests a purchase order number that is missing from an invoice",
        "a buyer declines an alternative material offered by the supplier",
        "a logistics provider proposes a different route to avoid a port strike",
        "a supplier confirms a delivery slot and lists what the driver must bring",
        "a buyer asks a supplier to explain a quality complaint and propose actions",
        "a supplier introduces a new account manager and shares contact details",
        "a buyer requests an update on a delayed order and a recovery plan",
        "a supplier asks for payment of an overdue invoice in a polite but firm tone",
        "a buyer explains that the specification changed and asks if the supplier can adapt",
    ]),
    "shipment_notification": (WORK, "An automated-style shipment or logistics notification (courier/carrier/system) with labelled fields (Order, Carrier, ETA, Status...) followed by one or two sentences of text.", [
        "a pallet shipment is in transit with a revised ETA due to weather",
        "a temperature-controlled parcel is delivered and the receiver must check the data logger",
        "a shipment is held at customs pending a missing commercial invoice",
        "a delivery attempt failed because the dock was closed and a new slot is offered",
        "a partial shipment is dispatched and the remainder follows later",
        "a shipment was rerouted through another hub and the new ETA is given",
        "an air freight booking is confirmed with a cut-off time for handover",
        "a delivery is scheduled for tomorrow and a signature is required",
        "a container has arrived at port and storage charges start after a free period",
        "a return shipment label has been created with an expiry date",
        "a consolidated shipment lists three order numbers with different statuses",
        "a proof of delivery is available and a damage claim deadline is stated",
        "a pickup is rescheduled because the vehicle is delayed",
        "an import shipment needs an extra document before the customs broker can proceed",
        "a courier changes the delivery address window and asks to confirm by reply",
        "a sea shipment's departure is postponed by one week",
        "a cold-chain shipment's tracking shows a stop for inspection",
        "a recurring weekly delivery schedule is updated for the holiday period",
        "an electronic notice lists the items, quantities and what is backordered",
        "a transport booking is cancelled and the reason and rebooking steps are given",
    ]),
    "delay_notice": (WORK, "A short formal notice or alert (e.g. 'Service notice', 'Supply alert') with a bold-style heading line, 3-6 sentences, concrete dates and actions.", [
        "a key packaging material will be delayed by two weeks and planners must review orders",
        "a warehouse will be closed for a stock count and no shipments leave that day",
        "a quality hold prevents shipment of a batch until further tests are done",
        "a planned system downtime affects order entry over a weekend",
        "a supplier's site shutdown affects supply of one ingredient",
        "a port congestion alert advises booking earlier",
        "a labeling change means old stock must be used first and new stock will be segregated",
        "a transport strike may delay deliveries in one country",
        "the cut-off time for same-day dispatch has changed",
        "an allocation notice explains that limited stock will be shared between regions",
        "a recall-style notice asks teams to check stock of a specific lot and report by a deadline",
        "a carrier changes its pickup days for a region",
        "a planned inventory freeze blocks adjustments for three days",
        "a price list update takes effect on the first of next month",
        "a notice announces a temporary alternative supplier for one item",
        "a customs rule change requires an extra declaration",
        "a notice warns that the shipping portal will move to a new login method",
        "a delay in a regulatory approval postpones a product launch date",
        "a notice announces that month-end order cut-off is brought forward",
        "a cold storage unit failed and affected stock is being checked",
    ]),
    "meeting_agenda": (WORK, "A meeting agenda: title, date/time/place, 4-7 numbered or bulleted items with time allocations and owners, and a one-line note at the end.", [
        "a weekly demand review with forecast accuracy, risks and decisions",
        "a monthly S&OP pre-meeting with a short list of decisions to prepare",
        "a supplier performance review with OTIF, quality and action items",
        "a project kickoff for a new planning tool with roles and timeline",
        "an inventory review meeting about excess and obsolete stock",
        "a cross-functional shortage meeting with a daily rhythm",
        "a quarterly business review with a key logistics provider",
        "a team offsite day with working sessions and lunch",
        "a post-mortem on a missed delivery with root causes and actions",
        "a new-joiner onboarding week for the planning team",
        "a budget planning session with timings for each region",
        "a launch readiness meeting with supply, quality and commercial",
        "a data quality workshop on master data errors",
        "a 30-minute stand-up with a rotating facilitator",
        "an all-hands update with Q&A and the order of speakers",
        "a transport tender review with a decision point",
        "a risk review for single-source materials",
        "a process improvement session with two breakout groups",
        "a cross-site handover meeting before a team reorganisation",
        "an end-of-year planning meeting with deadlines for inputs",
    ]),
    "meeting_invite_reschedule": (WORK, "A calendar invitation or reschedule message (Subject/When/Where/Join/Who and a short note), including what to prepare or what changed.", [
        "a recurring forecast call moves one hour later because of time zones",
        "a meeting changes from in person to online and attendees must update their plans",
        "an urgent call about a shortage is added at short notice with a clear agenda",
        "a review meeting is cancelled and its items move to email",
        "a workshop is rescheduled and the room changes",
        "a one-to-one is moved because of a clash with a customer call",
        "a training session is added and attendance is optional but recorded",
        "a meeting needs a decision from someone who is travelling and an alternative is proposed",
        "an interview panel meeting for a new colleague is scheduled with instructions",
        "a quarterly review invitation asks participants to send slides in advance",
        "a meeting is split into two shorter sessions for different regions",
        "a lunch-and-learn invitation mentions registration and dietary needs",
        "a call is extended by 15 minutes to cover an extra topic",
        "a meeting is moved forward because a deadline came earlier",
        "a dial-in number changes and a new link is provided",
        "a steering committee date is confirmed after checking availability",
        "an invitation asks people to accept or decline by a certain day",
        "a meeting is cancelled for a public holiday and the next date is given",
        "a client visit schedule is shared with arrival and parking instructions",
        "a colleague proposes three time slots and asks which suits best",
    ]),
    "training_schedule": (WORK, "A training or onboarding schedule: title, a table-like list of days/times/topics/trainers, and a short note about preparation or attendance.", [
        "a two-day course on a new planning system",
        "an onboarding week for a new supply planner",
        "a short workshop on giving presentations in English",
        "a data analysis course with three evening sessions",
        "a compliance refresher with a mandatory online quiz",
        "a warehouse safety training for office staff visiting the site",
        "a negotiation skills workshop for buyers",
        "a spreadsheet advanced functions masterclass",
        "a leadership programme with monthly sessions",
        "an introduction to supply chain risk management",
        "a cybersecurity awareness session with a deadline",
        "a tool demo series for the new dashboard",
        "a mentoring programme kickoff with pairings and meeting rhythm",
        "a language course timetable with levels and rooms",
        "a first-aid course with limited places",
        "a project management certification prep schedule",
        "a customs and incoterms basics session",
        "a cross-training plan so planners learn each other's materials",
        "a webinar series about forecasting methods",
        "a site tour and induction for visitors",
    ]),
    "policy_snippet": (WORK, "A short excerpt from a company policy or intranet page: heading, 3-6 sentences or a short bulleted list with conditions, exceptions and a contact for questions.", [
        "rules for working from home and core hours",
        "expense claims limits and deadlines for submitting receipts",
        "the approval chain for purchase requests above a threshold",
        "how to report a quality deviation within a time limit",
        "guidelines for travelling for work and booking flights early",
        "the policy on sharing files outside the company",
        "annual leave requests and how many days can be carried over",
        "dress and safety requirements when visiting a production site",
        "rules for accepting gifts from suppliers",
        "an out-of-office and handover requirement for absences over three days",
        "password and device security rules",
        "the process for requesting new software",
        "meeting-free time and focus hours guidelines",
        "using personal phones for work",
        "overtime approval and compensation time",
        "the process for raising a concern anonymously",
        "document retention periods for orders and invoices",
        "visitor registration and badge rules",
        "guidelines for writing clear emails to external partners",
        "parking and shuttle use at the site",
    ]),
    "invoice_summary": (WORK, "An invoice, order confirmation or statement summary: a header, 3-5 line items with quantities and prices (use consistent arithmetic), totals, payment terms, and a short note.", [
        "an invoice for pallets of packaging material with a late-payment note",
        "an order confirmation with two items back-ordered",
        "a credit note for damaged goods with the original invoice number",
        "a freight invoice with fuel surcharge and customs fee",
        "a statement of account listing an overdue amount",
        "a quote for training seats with a discount for early booking",
        "an invoice with a wrong purchase order number that must be corrected",
        "a monthly storage fee invoice with per-pallet pricing",
        "a proforma invoice for samples with 'no commercial value' text",
        "an invoice for translation services with hours and rate",
        "a receipt for a conference ticket with a cancellation policy",
        "an order summary with a volume discount that applies above a threshold",
        "a rental invoice for equipment with a deposit refund note",
        "a supplier price list with a validity date and minimum order",
        "an invoice paid in two instalments with due dates",
        "a catering invoice for an offsite event with a headcount mismatch",
        "a courier invoice with extra charges for a failed delivery",
        "an expense report summary with one item rejected",
        "an order change notice that reduces one quantity and adds another",
        "an invoice in a different currency with the exchange rate stated",
    ]),
    "status_report": (WORK, "A short status update, KPI summary or dashboard alert in plain text: a heading, 3-5 labelled lines or bullets with figures and a final 'next steps' sentence.", [
        "weekly OTIF performance by region with the main reason for misses",
        "forecast accuracy this month compared with last month",
        "inventory coverage in days for three key materials",
        "open purchase orders past due and the oldest one",
        "a project status with green, amber and red areas",
        "backorder trend with a recovery date",
        "a dashboard alert about stock below the safety level",
        "a transport cost summary with a variance against budget",
        "supplier lead time changes for the quarter",
        "a data cleanup progress report with percentages",
        "a cycle count results summary with discrepancies found",
        "a weekly summary of deviations opened and closed",
        "the status of a system migration with remaining tasks",
        "a service level report with a short explanation of a dip",
        "a savings tracker for a procurement project",
        "a headcount and hiring update for the team",
        "a risk register update with top three risks",
        "an end-of-month close checklist with who is late",
        "a forecast bias summary by product family",
        "a launch readiness scorecard with open items",
    ]),
    "handover_ooo": (WORK, "An out-of-office auto-reply or a handover note: concrete dates, who covers what, what is urgent versus can wait, and how to reach the person in an emergency.", [
        "a planner on two weeks of holiday names two backups for different tasks",
        "a manager on a business trip with limited email access",
        "a buyer leaving the role and handing over supplier contacts",
        "a colleague on parental leave with a return date and contact for urgent matters",
        "a handover note for a month-end close with risks to watch",
        "a team member in training all week who answers only after 5 pm",
        "an auto-reply during a company-wide shutdown",
        "a handover for an open shortage case with the next three steps",
        "a colleague away sick with a coworker covering reports",
        "a planner moving to a new team but still answering questions for a month",
        "a handover note listing recurring weekly tasks and their deadlines",
        "an auto-reply from a person who changed roles with new contacts",
        "a colleague on a site visit offline with a mobile number for emergencies only",
        "a note about a pending approval that blocks an order",
        "an auto-reply during a public holiday week in one country",
        "a handover with login access warnings and shared folder paths",
        "a manager's delegation of approval rights during leave",
        "a temporary cover plan for the forecast review meeting",
        "a handover note about a supplier negotiation in progress",
        "an auto-reply that sends customers to a shared mailbox",
    ]),
    "deviation_quality": (WORK, "A short quality or deviation notification in plain business English (no real regulatory text): reference number, what happened, impact, immediate action, owner and deadline. Keep it generic and non-sensitive.", [
        "a temperature excursion during transport and the stock placed on hold",
        "a label mismatch found during goods receipt",
        "a damaged outer carton found on arrival with photos requested",
        "a missing certificate of analysis for a delivered lot",
        "a short shipment where quantity received is lower than the delivery note",
        "an expiry date closer than agreed for a delivered batch",
        "a batch put on hold pending test results and what planners should do",
        "a pallet stored in the wrong location and moved after a check",
        "an incorrect quantity booked in the system and corrected",
        "a delayed documentation review and the new target date",
        "a request to confirm the root cause of a recurring packaging defect",
        "a notification that a corrective action was completed and is being verified",
        "a supplier nonconformity report with a response deadline",
        "a late deviation closure and a reminder to the owner",
        "a lot released after additional checks with conditions",
        "a returned goods inspection outcome",
        "a request to quarantine a lot as a precaution while a check completes",
        "an audit observation about incomplete records and the follow-up date",
        "a deviation about a missed cleaning log entry and the action plan",
        "a trend note that three similar issues were reported this month",
    ]),
    "job_posting": (WORK, "An internal job posting or short professional announcement: role, 3-5 responsibilities or requirements, location/hours, deadline and how to apply.", [
        "an internal opening for a supply planner with English required",
        "a temporary role covering a parental leave",
        "a graduate rotation programme announcement",
        "a call for a volunteer to lead a data-quality initiative",
        "a vacancy for a logistics coordinator with shift work",
        "an internship in demand planning with a start date",
        "an internal move for a senior buyer with travel up to 20%",
        "a project role for a system implementation on a part-time basis",
        "a call for mentors in an inclusion programme",
        "a new team lead position with leadership requirements",
        "a data analyst opening with SQL and dashboard skills",
        "a call for speakers at an internal knowledge-sharing day",
        "a vacancy for a customs specialist",
        "a recruiter's message inviting a candidate to an interview",
        "a job offer summary listing salary range elements and a response deadline",
        "a rejection email that gives constructive feedback",
        "a job alert listing three roles in different cities",
        "a freelance translator request with rate and deadline",
        "a reference check request email",
        "a career fair announcement with registration details",
    ]),
    "vendor_ad": (WORK, "A short product or service advertisement aimed at professionals (software, logistics, courses), 50-110 words, with a clear offer, one condition or limitation, and a call to action. Invent company names.", [
        "a planning software promotes a free trial and a limited-time discount",
        "a freight forwarder advertises faster customs clearance",
        "an online English course for professionals with a money-back guarantee",
        "a warehouse-automation firm invites visitors to a demo day",
        "a coworking space advertises a day pass for travellers",
        "a business hotel promotes a corporate rate with breakfast included",
        "a data-visualisation tool announces a new version with a webinar",
        "a cold-chain packaging provider advertises reusable boxes",
        "a conference announces early-bird tickets that end soon",
        "a courier offers a business account with volume pricing",
        "an airline promotes a business-class upgrade offer with restrictions",
        "a catering service promotes lunch boxes for meetings",
        "a laptop shop's business promotion with a trade-in deal",
        "a translation agency promotes a rush service",
        "a cybersecurity training provider advertises a group discount",
        "a recruitment agency advertises a free salary guide",
        "an ERP consultancy invites supply leaders to a roundtable",
        "an app for expense tracking promotes a premium plan",
        "a car rental company promotes a weekly rate for site visits",
        "a standing-desk retailer advertises a sale with a delivery condition",
    ]),
    "facility_notice": (EVERY, "A notice on a company intranet or office wall (cafeteria, building, IT, facilities): heading, 3-6 sentences, dates, times, practical instructions.", [
        "the cafeteria changes opening hours and introduces a new payment method",
        "the lift in the main building is out of service for two days",
        "the car park will be resurfaced and spaces are temporarily limited",
        "the fire alarm test on Thursday morning will be loud but is only a test",
        "the office kitchen needs everyone to label food and clear the fridge on Friday",
        "the Wi-Fi network name and password are changing next week",
        "the printers on the third floor are replaced and old cards must be re-registered",
        "a bike-to-work day offers free breakfast",
        "a new recycling system with different bins is introduced",
        "the shuttle bus timetable changes after the summer",
        "the gym on site opens an extra session at lunchtime",
        "the reception desk will be unstaffed on one afternoon and parcels go to the mailroom",
        "the building air conditioning is under maintenance and some rooms may be warm",
        "a lost-and-found reminder before items are donated",
        "a blood donation day with a booking link",
        "a flu vaccination clinic with times and eligibility",
        "the meeting room booking system adds a no-show rule",
        "the cleaning schedule changes for the open-plan area",
        "a charity bake sale this Wednesday",
        "a reminder to return borrowed equipment such as monitors and headsets",
    ]),
    "everyday_message": (EVERY, "A personal-practical message or confirmation about daily life (text message, short email or voicemail transcript): rent, bank, doctor, gym, airline, online order. 'From:' optional, 50-110 words.", [
        "a landlord says a plumber will visit and asks the tenant to be at home",
        "a bank asks to confirm a card transaction and explains how to block the card",
        "a dentist's reminder to confirm or reschedule an appointment",
        "a gym announces new class times and a freeze option for the membership",
        "an airline informs about a gate change and a delay with a meal voucher",
        "an online shop says an order is split into two parcels",
        "a neighbour asks to keep the noise down on a specific evening",
        "a friend sends details for a wedding including dress code and a hotel block",
        "a course provider confirms registration and lists what to bring",
        "a hotel confirms a booking and asks for an arrival time",
        "a car service reminds about an inspection and a cost estimate",
        "a bank branch changes opening hours and recommends the app",
        "a doctor's clinic gives preparation instructions before blood tests",
        "a utility company announces a planned water cut",
        "a parcel locker notice with a pickup deadline",
        "a flatmate leaves a note about splitting the internet bill",
        "a streaming service announces a price change and how to cancel",
        "a restaurant confirms a table for a group and asks about allergies",
        "a library notice about an overdue book and how to renew online",
        "a language exchange meetup changes location this week",
    ]),
    "travel_itinerary": (WORK, "A business travel itinerary or travel notice: day-by-day lines with times, flights/hotels/transfers (invented), and a note about a change or a requirement (visa, documents, expense rule).", [
        "a two-day trip to a supplier site with an early flight",
        "a connecting flight with a tight layover and a rebooking option",
        "a hotel check-in instructions note for a late arrival",
        "a conference trip with sessions to attend and a dinner",
        "a train journey between two cities with seat reservation details",
        "a trip cancelled and refund instructions",
        "a visa reminder with processing time and documents",
        "an itinerary with a transfer shuttle that must be booked in advance",
        "a three-city customer tour with a rental car",
        "a business trip with an extra personal day and who pays for what",
        "a flight change notice offering two alternatives",
        "an airport transfer confirmation with a driver's phone number",
        "a site visit schedule including safety induction",
        "a travel expense reminder for per diem rates",
        "a delay notice for a flight with meal vouchers and a compensation note",
        "a hotel's confirmation with a cancellation deadline",
        "a trip plan that includes a local holiday on one day",
        "a ground transport plan during a strike",
        "an itinerary for a visiting colleague with a welcome schedule",
        "a travel insurance reminder with what is covered",
    ]),
    "feedback_review": (WORK, "A short written exchange of feedback: a performance-style comment, a peer's thank-you note, a customer's review of a service, or an internal survey result. Neutral to positive tone with one constructive point.", [
        "a manager's mid-year feedback about communication in meetings",
        "a peer thanks a colleague for staying late to fix a data problem",
        "a customer review of a logistics provider praising speed but criticising communication",
        "a survey summary showing satisfaction with a new tool and two complaints",
        "a mentor's note after a presentation with three suggestions",
        "a team retrospective with what went well, what did not and one action",
        "a supplier feedback form with ratings explained in words",
        "a colleague's reply to a request for feedback on a draft report",
        "a hotel review written by a business traveller",
        "a conference attendee's feedback on the schedule",
        "a training evaluation comment about pace and materials",
        "a new joiner's one-month reflection",
        "a manager asking for 360 feedback and explaining the process",
        "a thank-you note to a team after a successful audit",
        "a candidate's feedback about an interview process",
        "a client's compliment with a request for a small change",
        "a peer review of a process document with comments",
        "a note explaining how to give feedback in a respectful way",
        "a survey on remote work with a short summary of results",
        "a complaint about slow IT support with a request for a response time",
    ]),
    "customer_service": (EVERY, "A customer-service reply or ticket update (company to customer), with ticket reference, what was done, what happens next, and a polite closing. Everyday services and B2B portals.", [
        "an IT helpdesk ticket is resolved but needs a restart",
        "an online store approves a refund and explains the timeline",
        "a telecom provider explains a charge on the monthly bill",
        "a logistics portal replies about a missing delivery document",
        "a software vendor confirms a bug is fixed in the next update",
        "a travel agency offers a rebooking after a cancelled flight",
        "a bank explains that a transfer is pending and why",
        "a utilities provider confirms a meter reading appointment",
        "an equipment supplier proposes a replacement under warranty",
        "a courier apologises for a delay and offers a credit",
        "a hotel responds to a complaint about noise and offers a voucher",
        "a conference organiser answers a question about invoicing for a ticket",
        "an HR portal answers a question about a payslip date",
        "a car rental company explains a deposit hold and release date",
        "a streaming provider confirms a cancellation takes effect at period end",
        "a training provider reschedules a course due to low enrolment",
        "an insurance provider asks for one more document before processing a claim",
        "a supplier portal explains how to reset access for a new user",
        "a mobile operator confirms roaming settings for a trip",
        "an online course platform explains how to download a certificate",
    ]),
}

TWISTS = [
    "one detail changes midway (a date, a place or a quantity) and the reader must track the final version",
    "there is an exception or condition ('unless', 'only if', 'except') that decides what to do",
    "two numbers must be combined or compared to answer one question",
    "the writer's real purpose is only clear from one sentence, not the heading",
    "someone is NOT responsible for a task, and a careless reader would assign it to them",
    "a polite request that is actually a deadline",
    "a deadline is given as a relative time ('two working days before the review') that needs working out",
    "a tempting wrong answer appears in the text but refers to the old plan, not the current one",
    "the tone is indirect and the reader must infer the writer's attitude or concern",
    "a short phrase must be understood from context (idiom, phrasal verb or workplace jargon)",
    "two people or two options are contrasted and the reader must say which one fits a condition",
    "something is promised only if another thing happens first (sequence of steps)",
]

Q_FOCUS = ["main purpose of the text", "specific detail (who/what/when/where)", "what the reader should do next", "inference about a person's attitude or a hidden reason",
           "meaning of a word or phrase in context", "a number, date or time calculation", "what is NOT true or NOT required", "reason why something happened or changed",
           "which statement matches the text", "who is responsible for an action"]

CEFR_W = [("B1", 20, (45, 80)), ("B1+", 20, (55, 95)), ("B2", 30, (65, 115)), ("B2+", 15, (80, 130)), ("C1", 15, (90, 145))]
GENRE_TITLES = {
    "teams_chat": "Teams chat", "email_internal": "internal email", "email_supplier": "external email", "shipment_notification": "shipment notification",
    "delay_notice": "notice", "meeting_agenda": "agenda", "meeting_invite_reschedule": "calendar invitation", "training_schedule": "schedule",
    "policy_snippet": "policy", "invoice_summary": "invoice/order", "status_report": "status report", "handover_ooo": "handover/out-of-office",
    "deviation_quality": "quality notification", "job_posting": "job posting", "vendor_ad": "advertisement", "facility_notice": "facility notice",
    "everyday_message": "personal message", "travel_itinerary": "travel itinerary", "feedback_review": "feedback", "customer_service": "customer-service reply",
}
NAMES = ["Marta", "Jonas", "Priya", "Tomasz", "Aisha", "Lucas", "Ingrid", "Kenji", "Sofia", "Omar", "Elena", "Rafael", "Hannah", "Mateo", "Chloe", "Dev", "Nadia", "Pavel", "Grace", "Andrés",
         "Yuki", "Fatima", "Liam", "Beatriz", "Samir", "Greta", "Tariq", "Camille", "Noah", "Ines"]
COMPANIES = ["Norvia Packaging", "Keldra Logistics", "Brightfield Components", "Alpenhal Freight", "Tessaro Materials", "Marlowe Cargo", "Vantis Labels", "Ostrava Pallets",
             "Calder & Finch", "Ridgeway Cold Chain", "Solano Plastics", "Harbourline Shipping", "Quillon Software", "Nordvik Transport", "Pellegrini Glassworks", "Eastgate Warehousing"]
SITES = ["the Nottingham site", "the Södertälje site", "the Mexico City office", "the Barcelona hub", "the Warsaw distribution centre", "the Frankfurt warehouse", "the Cork plant",
         "the Singapore office", "the Rotterdam port terminal", "the Guadalajara office", "the Prague service centre", "the Ghent site"]
WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]


def build_rows() -> list[dict]:
    rng = random.Random(SEED)
    rows = []
    for genre, (kind, fmt, sits) in GENRES.items():
        assert len(sits) == 20 and len(set(sits)) == 20, genre
        for i, sit in enumerate(sits):
            rows.append({"genre": genre, "kind": kind, "format": fmt, "situation": sit, "_i": i})
    assert len(rows) == 400
    rng.shuffle(rows)
    cefrs = [c for c, w, _ in CEFR_W for _ in range(w * 4)]  # 400 slots, proportional
    rng.shuffle(cefrs)
    wrange = {c: r for c, _, r in CEFR_W}
    out = []
    focus_used = Counter()
    for n, r in enumerate(rows):
        lvl = cefrs[n]
        lo, hi = wrange[lvl]
        nq = 2 if rng.random() < 0.3 else 3
        foci = rng.sample(Q_FOCUS, nq)
        if r["genre"] == "invoice_summary" and "a number, date or time calculation" not in foci:
            foci[-1] = "a number, date or time calculation"
        for f in foci:
            focus_used[f] += 1
        apos = [rng.randrange(4) for _ in range(nq)]
        # keep answer positions balanced overall: rotate start so each position is used about equally
        apos = [(a + n) % 4 for a in apos]
        wl = lo + rng.randrange(hi - lo + 1)
        key = ids.sha8(f"{r['genre']}|{r['situation']}")
        out.append({
            "id": ids.item_id("readDaily", "gen", f"{r['genre']}-{key}"),
            "genre": r["genre"], "genreLabel": GENRE_TITLES[r["genre"]], "kind": r["kind"], "format": r["format"],
            "situation": r["situation"], "twist": rng.choice(TWISTS), "cefr": lvl, "targetWords": wl,
            "questionFocus": foci, "answerPositions": apos,
            "details": {"people": rng.sample(NAMES, 3), "company": rng.choice(COMPANIES), "site": rng.choice(SITES), "day": rng.choice(WEEKDAYS)},
            "topics": ["workplace", "readDaily-genre"] if r["kind"] == WORK else ["everyday", "readDaily-genre"],
        })
    out.sort(key=lambda x: x["id"])
    return out


def extract(stage: Path, report: Path) -> None:
    rows = build_rows()
    assert len({r["id"] for r in rows}) == 400
    # dedupe the scenario brief against everything already in Content/ (titles + text of existing readDaily) at a loose level, and within the set
    idx = dedupe.DedupeIndex.from_content(ROOT / "Content")
    dropped = []
    kept = []
    inner = dedupe.DedupeIndex(threshold=0.7)
    for r in rows:
        brief = f"{r['situation']} {r['genreLabel']}"
        d = idx.check(brief) or inner.check(brief)
        if d:
            dropped.append((r["id"], d))
            continue
        inner.add(r["id"], brief)
        kept.append(r)
    stage.mkdir(parents=True, exist_ok=True)
    bdir = stage / "batches"
    bdir.mkdir(exist_ok=True)
    for old in bdir.glob("*.jsonl"):
        old.unlink()
    with (stage / "scenarios.jsonl").open("w", encoding="utf-8") as f:
        for r in kept:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    # interleave genres so every batch mixes genres and levels
    kept.sort(key=lambda r: (r["genre"], r["id"]))
    n = len(kept)
    nb = max(1, round(n / 40))
    batches = [[] for _ in range(nb)]
    for i, r in enumerate(kept):
        batches[i % nb].append(r)
    paths = []
    for b, rs in enumerate(batches, 1):
        p = bdir / f"batch_{b:02d}.jsonl"
        with p.open("w", encoding="utf-8") as f:
            for r in rs:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
        paths.append(p)
    report.parent.mkdir(parents=True, exist_ok=True)
    g = Counter(r["genre"] for r in kept)
    c = Counter(r["cefr"] for r in kept)
    nq = Counter(len(r["questionFocus"]) for r in kept)
    ap = Counter(a for r in kept for a in r["answerPositions"])
    lines = ["# gen-readdaily extract", "", f"- scenario rows: {len(rows)}; kept after dedupe vs Content/: {len(kept)}; dropped: {len(dropped)}",
             f"- batches: {nb} ({min(len(b) for b in batches)}-{max(len(b) for b in batches)} rows)",
             "- CEFR: " + ", ".join(f"{k}={v}" for k, v in sorted(c.items())), "- questions per text: " + ", ".join(f"{k}={v}" for k, v in sorted(nq.items())),
             "- answer positions: " + ", ".join(f"{k}={v}" for k, v in sorted(ap.items())),
             "- workplace: %d, everyday: %d" % (sum(r["kind"] == WORK for r in kept), sum(r["kind"] == EVERY for r in kept)), "", "## Genres", ""]
    lines += [f"- {k}: {v}" for k, v in sorted(g.items())]
    lines += ["", "## Dropped", ""] + [f"- {i}: {d}" for i, d in dropped]
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines[:14]))
    print("\n".join(str(p) for p in paths))


def emit_step(stage: Path, report: Path, dry: bool) -> None:
    from lib import emit as emit_lib
    scen = {json.loads(l)["id"]: json.loads(l) for l in (stage / "scenarios.jsonl").read_text(encoding="utf-8").splitlines() if l.strip()}
    own = ROOT / "Content/items" / OUT_FILE
    idx = dedupe.DedupeIndex(threshold=0.7)
    for ex in sorted((ROOT / "Content/items").glob("*.json")):
        if ex.resolve() == own.resolve():
            continue
        for it in json.loads(ex.read_text(encoding="utf-8")):
            t = dedupe.item_text(it)
            if t:
                idx.add(it["id"], t)
    rej: Counter = Counter()
    per_batch: dict = {}
    items = []
    for fp in sorted((stage / "batches").glob("batch_*.filled.jsonl")):
        per_batch[fp.name] = [0, 0]
        for line in fp.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            r = json.loads(line)
            per_batch[fp.name][0] += 1
            if r.get("reject"):
                per_batch[fp.name][1] += 1
            s = scen.get(r.get("id"))
            if not s:
                rej["unknown id"] += 1
                continue
            if r.get("reject"):
                rej["rejected by fill agent"] += 1
                continue
            qs = []
            ok = True
            for q, pos in zip(r["questions"], s["answerPositions"]):
                if q.get("answer") != pos and len(r["questions"]) == len(s["answerPositions"]):
                    pass  # position is a request, not a hard rule; schema only needs a valid index
                qs.append({"q": q["q"].strip(), "options": [o.strip() for o in q["options"]], "answer": q["answer"], "explanation": q["explanation"].strip()})
            if any(len({o.lower() for o in q["options"]}) < 4 for q in qs):
                rej["duplicate options"] += 1
                continue
            item = {"id": r["id"], "type": "readDaily", "skill": "reading", "cefr": r.get("cefr", s["cefr"]), "title": r["title"].strip(), "text": r["text"].replace("**", "").strip("\n "),
                    "questions": qs, "source": "gen-readdaily", "sourceId": r["id"], "license": "Original text written for Tenaz (generated)", "tier": "permissive",
                    "group": f"gen-readdaily:{s['genre']}:{ids.sha8(s['situation'])}", "origin": "generated", "topics": s["topics"]}
            if len(item["title"].split()) > 6:
                rej["title > 6 words"] += 1
                continue
            probs = schema.problems_item(item)
            if probs:
                rej["schema: " + probs[0][:60]] += 1
                continue
            d = idx.check(item["text"])
            if d:
                rej["dedupe: " + d.split(" of ")[0]] += 1
                continue
            idx.add(item["id"], item["text"])
            items.append(item)
    items.sort(key=lambda i: i["id"])
    print(f"valid items: {len(items)}; rejects: {dict(rej)}")
    if dry:
        return
    entry = emit_lib.emit(ROOT / "Content", "items", OUT_FILE, items, source="Tenaz generated readDaily genres", url="n/a (original, LLM-generated from scenario matrix)",
                          license="Original text written for Tenaz (generated)", tier="permissive", attribution="Generated with Claude from scripts/ingest/sources/gen-readdaily.py scenarios")
    lines = ["", "# emit", "", f"- emitted {len(items)}; rejects {dict(rej)}", "- per-batch fill rejects: " + ", ".join(f"{k}: {b}/{a}" for k, (a, b) in per_batch.items()),
             "- CEFR: " + str(dict(sorted(Counter(i["cefr"] for i in items).items()))),
             "- genres: " + str(dict(sorted(Counter(scen[i["id"]]["genre"] for i in items).items()))),
             "- questions/item: " + str(dict(Counter(len(i["questions"]) for i in items))),
             "- answer positions: " + str(dict(sorted(Counter(q["answer"] for i in items for q in i["questions"]).items()))),
             "- words/text: min %d max %d" % (min(textnorm.word_count(i["text"]) for i in items), max(textnorm.word_count(i["text"]) for i in items)),
             "- manual fix: rd-gen-customer-service-01a2c468 had Q1/Q2 options swapped; fixed in the filled file", "", "## 30-item sample (read manually)", ""]
    for i in random.Random(SEED).sample(items, min(30, len(items))):
        lines += [f"### {i['id']} ({i['cefr']}) {i['title']}", "", i["text"], ""] + [f"- Q: {q['q']} => {q['options'][q['answer']]}" for q in i["questions"]] + [""]
    report.write_text(report.read_text(encoding="utf-8") + "\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps(entry)[:300])


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["extract", "emit"])
    ap.add_argument("--stage", default=str(ROOT / ".ingest/stage/gen-readdaily"))
    ap.add_argument("--report", default=str(ROOT / ".ingest/reports/gen-readdaily.md"))
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    if a.cmd == "extract":
        extract(Path(a.stage), Path(a.report))
    else:
        emit_step(Path(a.stage), Path(a.report), a.dry_run)


if __name__ == "__main__":
    main()
