import SwiftUI

/// After Return the whole field turns: `.good` with the word huge and the XP, or `.fix` with the
/// right word huge, what went wrong in small type, and when the word comes back. Never "you failed".
/// Tena (ecstatic or focused) hangs off the bottom-left corner; the text column sits to her right.
struct ReviewFeedbackHero: View {
    let card: ReviewCardModel
    let feedback: ReviewFeedback
    let stage: TenaStage
    let next: () -> Void

    /// The word itself: the English headword for meaning cards, the expected answer otherwise.
    private var word: String { card.isChoice ? card.headword : card.answerText }

    private var wordSize: CGFloat {
        switch word.count {
        case ...8: 120
        case ...12: 100
        case ...18: 80
        default: 64
        }
    }

    /// What the word means, under it (meaning cards show the right option).
    private var meaning: String { card.isChoice ? card.answerText : card.gloss }

    private var verdict: String {
        if feedback.correct { return feedback.nearMiss ? "Almost! Check the spelling." : "Right!" }
        return "Not quite"
    }

    private var score: String? {
        var parts: [String] = []
        if feedback.xp > 0 { parts.append("+\(feedback.xp) xp") }
        if feedback.combo >= 2 { parts.append("\(feedback.combo) in a row") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "again in 1 min", from the model's `backIn`.
    private var again: String {
        guard let backIn = feedback.backIn else { return "again later" }
        return "again in \(max(1, Int((backIn / 60).rounded()))) min"
    }

    /// What the learner picked or typed, when it was wrong.
    private var mistake: String? {
        if feedback.correct && !feedback.nearMiss { return nil }
        if let chosen = feedback.chosenOption, card.options.indices.contains(chosen) { return card.options[chosen] }
        return feedback.typed.isEmpty ? nil : feedback.typed
    }

    var body: some View {
        GeometryReader { proxy in
            let column = proxy.size.width * BleedTena.columnShare
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                if feedback.correct {
                    Sparkle(size: 22)
                        .padding(.leading, -Tokens.Space.l)
                        .padding(.bottom, Tokens.Space.xs)
                }
                Label(verdict, systemImage: feedback.correct ? "checkmark" : "arrow.uturn.backward")
                    .font(Typography.title)
                    .foregroundStyle(Tokens.ink)
                Text(word)
                    .font(Typography.display(wordSize))
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(word.contains(" ") ? 2 : 1)
                    .minimumScaleFactor(0.4)
                    .padding(.top, -Tokens.Space.s)
                details
                Button(action: next) {
                    HStack(spacing: Tokens.Space.s) {
                        Text(feedback.correct ? "Next" : "Got it")
                        KeyCap("Return")
                    }
                }
                .buttonStyle(.fat)
                .keyboardShortcut(.defaultAction)
                .frame(width: 200)
                .padding(.top, Tokens.Space.xl)
                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, column)
        }
        .accessibilityElement(children: .contain)
    }

    /// "suponer, dar por hecho · you wrote ~~asume~~": the meaning, then the slip, struck through.
    private var meaningLine: Text? {
        var parts: [Text] = []
        if !meaning.isEmpty, meaning != word { parts.append(Text(meaning)) }
        if let mistake {
            let struck = Text(mistake).strikethrough()
            parts.append(Text("\(card.isChoice ? "you picked" : "you wrote") \(struck)"))
        }
        guard var line = parts.first else { return nil }
        for part in parts.dropFirst() {
            line = Text("\(line) · \(part)")
        }
        return line
    }

    @ViewBuilder private var details: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            if feedback.correct, let score {
                Text(score)
                    .font(Typography.title)
                    .foregroundStyle(Tokens.ink)
            }
            if let line = meaningLine {
                line
                    .font(Typography.body)
                    .foregroundStyle(Tokens.brand)
            }
            if !feedback.correct {
                if !card.exampleEn.isEmpty {
                    Text(card.exampleEn)
                        .font(Typography.body)
                        .foregroundStyle(Tokens.ink)
                        .padding(.top, Tokens.Space.xs)
                }
                Label(again, systemImage: "clock.arrow.circlepath")
                    .font(Typography.title)
                    .foregroundStyle(Tokens.ink)
                    .padding(.top, Tokens.Space.xs)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
