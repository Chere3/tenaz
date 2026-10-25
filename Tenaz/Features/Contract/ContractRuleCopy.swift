import TenazCore

/// Plain-English words for each Contract rule (B1-friendly, no shaming).
extension PenaltyRuleKind {
    var title: String {
        switch self {
        case .responseCost: "Response cost"
        case .repairTask: "Repair task"
        case .forgottenWordReturns: "Forgotten words come back"
        case .strictGate: "Strict gate"
        case .extraCards: "Extra cards"
        case .examStake: "Exam stake"
        case .funAppSpeedBump: "Fun-app speed bump"
        case .tivraFunAppBlock: "Tivra blocks fun apps"
        }
    }

    var explanation: String {
        switch self {
        case .responseCost: "Skipping costs Tena a little Vitality, and a missed day costs Vitality and Scales. Doing your reviews heals her."
        case .repairTask: "When Tena gets sick (Vitality 30 or less), you heal her: 15 reviews without hints, then a 60-word paragraph."
        case .forgottenWordReturns: "A word you miss twice in one day becomes the word you must use in your next unlock gate."
        case .strictGate: "On the unlock gate, the skip button appears only after 10 seconds."
        case .extraCards: "After a missed day you get 5 more review cards, still inside the daily limit."
        case .examStake: "A failed or flagged mock exam means a retake within 48 hours and −15 Vitality."
        case .funAppSpeedBump: "After 20:00, if today's minimum isn't done and a fun app is in front, the 3-word sticker appears over it, at most every 10 minutes. It never closes the app."
        case .tivraFunAppBlock: "Tivra would block fun apps until your reviews are done. It needs a change in Tivra first, so it can't be turned on yet."
        }
    }

    var costLine: String {
        switch self {
        case .responseCost: "Word skip −3 · Gate skip −20 · Missed day −10 and −20 Scales"
        case .repairTask: "About 5 minutes"
        case .forgottenWordReturns: "No cost"
        case .strictGate: "A 10-second wait"
        case .extraCards: "+5 cards"
        case .examStake: "−15 Vitality and a retake"
        case .funAppSpeedBump: "A sticker over the app"
        case .tivraFunAppBlock: "Coming later: needs a Tivra update"
        }
    }

    var symbol: String {
        switch self {
        case .responseCost: "heart.slash"
        case .repairTask: "bandage"
        case .forgottenWordReturns: "arrow.uturn.backward.circle"
        case .strictGate: "timer"
        case .extraCards: "rectangle.stack.badge.plus"
        case .examStake: "flag.2.crossed"
        case .funAppSpeedBump: "gamecontroller"
        case .tivraFunAppBlock: "lock.app.dashed"
        }
    }
}
