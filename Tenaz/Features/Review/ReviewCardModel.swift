import TenazCore

/// What one card shows, flattened from `SessionItem` so the views stay pure.
struct ReviewCardModel: Equatable, Identifiable {
    var id: String
    var type: CardType
    /// Main line: the English chunk (R), the cloze sentence (C), the Spanish cue (L), the phrase (K).
    var text: String
    /// Secondary cue: example (R), Spanish gloss (C, K), English definition (L).
    var hint: String?
    var options: [String] = []
    var correctOption: Int?
    var expected: String?
    var headword: String
    var exampleEn: String
    var exampleEs: String
    var gloss: String

    init(id: String, type: CardType, text: String, hint: String?, options: [String] = [], correctOption: Int? = nil,
         expected: String?, headword: String, exampleEn: String, exampleEs: String, gloss: String)
    {
        self.id = id
        self.type = type
        self.text = text
        self.hint = hint
        self.options = options
        self.correctOption = correctOption
        self.expected = expected
        self.headword = headword
        self.exampleEn = exampleEn
        self.exampleEs = exampleEs
        self.gloss = gloss
    }

    init(_ item: SessionItem) {
        self.init(id: item.card.id, type: item.prompt.type, text: item.prompt.text, hint: item.prompt.hint,
                  options: item.prompt.options, correctOption: item.prompt.correctOption, expected: item.prompt.expected,
                  headword: item.note.display, exampleEn: item.note.exampleEn, exampleEs: item.note.exampleEs, gloss: item.note.glossEs)
    }

    /// The right answer as text (the gloss for recognition cards).
    var answerText: String {
        if type == .recognition, let i = correctOption, options.indices.contains(i) { return options[i] }
        return expected ?? headword
    }

    var isChoice: Bool { type == .recognition }

    /// The instruction above the card, in plain words.
    var instruction: String {
        switch type {
        case .recognition: "What does it mean?"
        case .cloze: "Fill the gap"
        case .recall: "Say it in English"
        case .collocation: "Complete the phrase"
        case .production: "Write one sentence"
        case .spelling: "Type what you hear"
        }
    }

    var instructionSymbol: String {
        switch type {
        case .recognition: "eye"
        case .cloze: "text.insert"
        case .recall: "arrow.left.arrow.right"
        case .collocation: "link"
        case .production: "pencil.line"
        case .spelling: "ear"
        }
    }
}
