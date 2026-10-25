import SwiftUI
import TenazCore

/// One quest as a large row: a progress ring with the slot glyph, the title in Fraunces, the reward
/// as a plain line, and the count on the right. Done = the ring becomes a green check.
struct QuestCard: View {
    let quest: QuestRecord
    var daysLeft: Int?

    private var slot: (title: String, hint: String, glyph: String) {
        switch quest.slot {
        case .core: ("Core", "Clear your set", "target")
        case .skill: ("Skill", "Your weak spot", "pencil.line")
        case .stretch: ("Stretch", "Optional", "bolt.fill")
        case .weekly: ("Weekly", "Meeting prep", "mic.fill")
        }
    }

    private var fraction: Double { quest.target == 0 ? 0 : min(1, Double(quest.progress) / Double(quest.target)) }

    var body: some View {
        HStack(alignment: .center, spacing: Tokens.Space.l) {
            marker
            VStack(alignment: .leading, spacing: 4) {
                if let label {
                    Text(label)
                        .font(Typography.label)
                        .foregroundStyle(Tokens.brand)
                }
                Text(quest.title)
                    .font(Typography.title)
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(rewardLine)
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
            }
            Spacer(minLength: Tokens.Space.m)
            Text("\(min(quest.progress, quest.target)) / \(quest.target)")
                .font(Typography.numeric(26))
                .foregroundStyle(quest.done ? Tokens.brand : Tokens.ink)
                .contentTransition(.numericText())
                .fixedSize()
        }
        .padding(.vertical, Tokens.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { ProgressRule() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(slot.title) quest: \(quest.title)")
        .accessibilityValue(quest.done ? "Done" : "\(quest.progress) of \(quest.target)")
    }

    /// Only the one fact the title does not already say.
    private var label: String? {
        if let daysLeft { return "\(daysLeft) \(daysLeft == 1 ? "day" : "days") left" }
        return quest.slot == .stretch ? "optional" : nil
    }

    private var rewardLine: String {
        var parts = ["+\(quest.rewardXP) xp", "+\(quest.rewardScales) scales"]
        if quest.mysteryDrop { parts.append("mystery drop") }
        return parts.joined(separator: " · ")
    }

    private var marker: some View {
        ZStack {
            if quest.done {
                Circle().fill(Tokens.correct)
                Image(systemName: "checkmark").font(.system(size: 26, weight: .black)).foregroundStyle(Tokens.inverse)
            } else {
                Circle().stroke(Tokens.ink.opacity(0.12), lineWidth: 6)
                if fraction > 0 {
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(Tokens.ink, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                Image(systemName: slot.glyph).font(.system(size: 20, weight: .black)).foregroundStyle(Tokens.ink)
            }
        }
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
    }
}
