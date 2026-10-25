import SwiftUI

/// Where Tena's ink actually sits inside her square canvas, as unit fractions (0...1). Each stage and
/// mood draws a different silhouette (a round hatchling, a wide adult, Proud's elbows), so hero screens
/// crop her by the window edges from her real resting silhouette instead of guessing. Measured from the
/// rig's geometry (`TenaRig.inkFrame`, cached per stage, mood and tier), never by rendering.
enum TenaInk {
    /// `word`: Nagging's due word (with it she holds the sign, without it her fists).
    static func bounds(stage: TenaStage, mood: TenaMood, size: CGFloat = 160, word: String? = nil) -> CGRect {
        TenaRig(mood: mood, stage: stage, time: 0, size: size, word: word).inkFrame
    }

    /// The unit y (0...1 of her frame) where a hero's bottom window edge crops her at `size`: through the
    /// hips (86 % of her ink height, and at least 0.35 head heights below her chin), pushed down until
    /// `margin` points clear her lowest hand (Proud's hands on her hips, Happy's open paws, Sad's hanging
    /// arms). When that lands at her feet (a hand hanging that low, the hatchling's short body) she shows
    /// whole, `margin` above the edge, so nothing of her grazes it. Asleep lies on her belly with her chin
    /// on her folded paws at the bottom of her ink, so any crop would cut her chin: she lies whole, the
    /// same `margin` above the edge.
    static func bottomCut(stage: TenaStage, mood: TenaMood, size: CGFloat, margin: CGFloat, word: String? = nil) -> CGFloat {
        let rest = TenaRig(mood: mood, stage: stage, time: 0, size: size, word: word).rest
        let ink = rest.ink
        if mood == .asleep { return ink.maxY + margin / size }
        // Through the hips, and at least 0.35 head heights below her chin (the big-headed hatchling).
        let chin = rest.skull.map { $0.maxY + 0.35 * $0.height } ?? 0
        var cut = max(ink.minY + ink.height * 0.86, chin)
        if let hands = rest.arms?.maxY { cut = max(cut, hands + margin / size) }
        // A cut through her ankles reads as a crop; one lower than a quarter into her feet (or, legless,
        // in the lowest 3 % of her frame) would only graze them: show her whole, clear of the edge.
        let graze = rest.feet.map { $0 + 0.25 * (ink.maxY - $0) } ?? ink.maxY - 0.03
        return cut >= graze ? max(cut, ink.maxY + margin / size) : cut
    }
}
