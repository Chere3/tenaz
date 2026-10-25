import SwiftUI
import TenazCore

/// A Brain bite to read (PLAN F11): deck words are tappable and show their gloss in the side panel
/// with "Learn this next"; the three target words are marked in orange. Then one sentence about
/// The learner's own work, typed (no paste, no system writing help). Return saves, Esc closes.
struct KnowledgeReader: View {
    let card: KnowledgeCard
    var goDeeper: CatalogItem?
    var picked: Set<String> = []
    var onPick: (VocabEntry) -> Void = { _ in }
    var onSave: (String) -> Void = { _ in }
    var onClose: () -> Void = {}

    @State private var selected: VocabEntry?
    @State private var answer: String
    @State private var justPicked: Set<String> = []
    private let tokens: [Token]
    private let targetEntries: [VocabEntry]

    struct Token: Identifiable {
        let id: Int
        /// Punctuation before and after the word stays plain; only the word is tappable.
        let prefix: String
        let text: String
        let suffix: String
        let entry: VocabEntry?
        let isTarget: Bool
    }

    static func split(_ raw: Substring) -> (String, String, String) {
        let isCore: (Character) -> Bool = { $0.isLetter || $0.isNumber }
        guard let first = raw.firstIndex(where: isCore), let last = raw.lastIndex(where: isCore) else { return ("", String(raw), "") }
        return (String(raw[..<first]), String(raw[first...last]), String(raw[raw.index(after: last)...]))
    }

    /// Splits the body once: each word keeps its punctuation; deck words carry their entry.
    init(card: KnowledgeCard, gloss: GlossIndex, goDeeper: CatalogItem? = nil, picked: Set<String> = [],
         initialAnswer: String = "", onPick: @escaping (VocabEntry) -> Void = { _ in },
         onSave: @escaping (String) -> Void = { _ in }, onClose: @escaping () -> Void = {}) {
        self.card = card
        self.goDeeper = goDeeper
        self.picked = picked
        self.onPick = onPick
        self.onSave = onSave
        self.onClose = onClose
        let targets = Set(card.targetNoteIds)
        let tokens = card.body.split(separator: " ").enumerated().map { index, raw in
            let (prefix, word, suffix) = Self.split(raw)
            let entry = word.isEmpty ? nil : gloss.entry(for: word, preferring: targets)
            return Token(id: index, prefix: prefix, text: word, suffix: suffix, entry: entry,
                         isTarget: entry.map { targets.contains($0.id) } ?? false)
        }
        var seen = Set<String>()
        let targetEntries = tokens.compactMap { $0.isTarget ? $0.entry : nil }.filter { seen.insert($0.id).inserted }
        self.tokens = tokens
        self.targetEntries = targetEntries
        _selected = State(initialValue: targetEntries.first)
        _answer = State(initialValue: initialAnswer)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ReaderScroll {
                VStack(alignment: .leading, spacing: Tokens.Space.m) {
                    header
                    WordWrapLayout(spacing: 5, lineSpacing: 6) {
                        ForEach(tokens) { word($0) }
                    }
                    Text("Written for Tenaz. Facts are simplified: check a source before you quote them.")
                        .font(Typography.caption)
                        .foregroundStyle(Tokens.brand)
                    question
                }
                .padding(Tokens.Space.l)
            }
            panel
                .frame(width: 290)
        }
        .frame(width: 940, height: 820)
        .paperBackground()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            HStack(spacing: Tokens.Space.xs) {
                Label("Brain bite · \(KnowledgeTopic.name(card.topic)) · \(card.readingMinutes) min · \(card.cefr)",
                      systemImage: KnowledgeTopic.glyph(card.topic))
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
                Spacer()
                Button("Close", systemImage: "xmark", action: onClose)
                    .buttonStyle(.ink)
                    .keyboardShortcut(.cancelAction)
            }
            Text(card.title)
                .font(Typography.displayM)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Tokens.Space.xs)
            Text("Tap any underlined word to see what it means.")
                .font(Typography.label)
                .foregroundStyle(Tokens.brand)
        }
    }

    private static let bodyFont = Font.system(size: 18, weight: .regular, design: .rounded)

    @ViewBuilder private func word(_ t: Token) -> some View {
        if let entry = t.entry {
            HStack(spacing: 0) {
                if !t.prefix.isEmpty { Text(t.prefix).font(Self.bodyFont).foregroundStyle(Tokens.ink) }
                tappable(t, entry)
                if !t.suffix.isEmpty { Text(t.suffix).font(Self.bodyFont).foregroundStyle(Tokens.ink) }
            }
        } else {
            Text(t.prefix + t.text + t.suffix)
                .font(Self.bodyFont)
                .foregroundStyle(Tokens.ink)
        }
    }

    private func tappable(_ t: Token, _ entry: VocabEntry) -> some View {
            Button { selected = entry } label: {
                Text(t.text)
                    .font(.system(size: 18, weight: t.isTarget ? .bold : .regular, design: .rounded))
                    .foregroundStyle(Tokens.ink)
                    .background {
                        if selected?.id == entry.id {
                            RoundedRectangle(cornerRadius: 5).fill(Tokens.accent.opacity(0.22)).padding(-3)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(t.isTarget ? Tokens.accent : Tokens.brand.opacity(0.5))
                            .frame(height: t.isTarget ? 2.5 : 1.5)
                            .offset(y: 2)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(t.text)
            .accessibilityHint("Shows the meaning")
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            Label("Use it about your work", systemImage: "briefcase.fill")
                .font(Typography.labelBold)
                .foregroundStyle(Tokens.brand)
            Text(card.question)
                .font(Typography.title)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            AnswerField(text: $answer, prompt: "One sentence about your work", allowsPaste: false, onSubmit: save, showsHint: false)
            HStack {
                Text("No paste, no autocorrect.")
                    .font(Typography.caption)
                    .foregroundStyle(Tokens.brand)
                Spacer()
                Button(action: save) {
                    HStack(spacing: Tokens.Space.s) {
                        Text(answer.isEmpty ? "Done reading" : "Save my sentence")
                        KeyCap("Return")
                    }
                }
                .buttonStyle(.fat)
                .keyboardShortcut(.defaultAction)
                .frame(width: 340)
            }
        }
        .padding(Tokens.Space.m)
        .background { RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous).fill(Tokens.card) }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            if let entry = selected {
                glossCard(entry)
            }
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text("Target words").font(Typography.label).foregroundStyle(Tokens.brand)
                ForEach(targetEntries, id: \.id) { entry in
                    Button { selected = entry } label: {
                        Text(isPicked(entry) ? "\(entry.headword) ✓" : entry.headword)
                            .padding(.bottom, 2)
                            .overlay(alignment: .bottom) {
                                if selected?.id == entry.id { Rectangle().fill(Tokens.ink).frame(height: 2) }
                            }
                    }
                    .buttonStyle(.ink)
                    .accessibilityLabel(entry.headword)
                    .accessibilityAddTraits(selected?.id == entry.id ? .isSelected : [])
                }
            }
            Spacer(minLength: 0)
            if let item = goDeeper { deeper(item) }
        }
        .padding(Tokens.Space.l)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Tokens.card)
    }

    private func glossCard(_ entry: VocabEntry) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.headword).font(Typography.display(30)).foregroundStyle(Tokens.ink)
                Spacer()
                Text(entry.cefr).font(Typography.labelBold).foregroundStyle(Tokens.brand)
            }
            Text(entry.pos).font(Typography.label).foregroundStyle(Tokens.brand)
            Text(entry.es).font(Typography.title).foregroundStyle(Tokens.ink).fixedSize(horizontal: false, vertical: true)
            Text(entry.definition).font(Typography.label).foregroundStyle(Tokens.ink).fixedSize(horizontal: false, vertical: true)
            Text("“\(entry.example)”")
                .font(.system(size: 13, weight: .medium, design: .rounded).italic())
                .foregroundStyle(Tokens.brand)
                .fixedSize(horizontal: false, vertical: true)
            if isPicked(entry) {
                Label("In your next reviews", systemImage: "checkmark.circle.fill")
                    .font(Typography.labelBold)
                    .foregroundStyle(Tokens.correct)
                    .padding(.top, 4)
            } else {
                Button("Learn this next", systemImage: "plus.circle.fill") {
                    justPicked.insert(entry.id)
                    onPick(entry)
                }
                .buttonStyle(.ink)
                .keyboardShortcut("l", modifiers: .command)
            }
        }
    }

    private func deeper(_ item: CatalogItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Go deeper").font(Typography.label).foregroundStyle(Tokens.brand)
            Label(item.title, systemImage: item.kindGlyph)
                .font(Typography.labelBold)
                .foregroundStyle(Tokens.ink)
            Text("\(item.creator) · \(item.levelText)").font(Typography.caption).foregroundStyle(Tokens.brand)
            if let link = item.url.flatMap(URL.init(string:)) {
                Link("Open it", destination: link).font(Typography.labelBold).foregroundStyle(Tokens.brand)
            }
        }
    }

    private func isPicked(_ entry: VocabEntry) -> Bool { picked.contains(entry.id) || justPicked.contains(entry.id) }

    private func save() { onSave(answer) }
}

/// A ScrollView live; the bare content in snapshots (ImageRenderer cannot draw scroll views).
private struct ReaderScroll<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        if isSnapshot {
            content.frame(maxHeight: .infinity, alignment: .top)
        } else {
            ScrollView { content }.scrollContentBackground(.hidden)
        }
    }
}
