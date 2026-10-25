import Foundation
import TenazCore

/// Plain-words meaning of a TOEFL-style band (PLAN §2 row 6 labels), and the approximate IELTS band
/// from ETS's concordance (F7), always the lower one when in doubt.
enum BandWords {
    /// The one level name used everywhere (Home, sidebar, popover, results): the CEFR label, e.g. "B1+".
    static func label(_ band: Double) -> String { AbilityEstimator.cefr(forBand: band).label }

    static func meaning(_ band: Double) -> String {
        switch band {
        case ..<3: "You handle simple, familiar topics. Short and clear English works best for you now."
        case ..<3.5: "You get the main points of clear English on familiar topics, and you can write simple connected text."
        case ..<4: "You follow most everyday and work English and can explain your ideas. Long or fast English still takes effort."
        case ..<4.5: "You can work in English: you follow meetings and write clear emails. Your mistakes rarely block understanding."
        case ..<5: "You are comfortable in most work situations. Next: more precise words and more natural phrasing."
        default: "You use English flexibly and precisely, even on complex topics."
        }
    }

    static func ielts(_ band: Double) -> String {
        switch band {
        case ..<3.5: "≈ IELTS 5.0 or below (approx.)"
        case ..<4: "≈ IELTS 5.0 (approx.)"
        case ..<4.5: "≈ IELTS 6.0 (approx.)"
        case ..<5: "≈ IELTS 6.5 (approx.)"
        case ..<5.5: "≈ IELTS 7.0 (approx.)"
        case ..<6: "≈ IELTS 7.5 (approx.)"
        default: "≈ IELTS 8.0+ (approx.)"
        }
    }

    static func format(_ band: Double) -> String { band.formatted(.number.precision(.fractionLength(1))) }
}
