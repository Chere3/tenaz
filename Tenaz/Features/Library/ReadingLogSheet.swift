import SwiftUI
import TenazCore

/// Log a reading session in under 30 seconds: minutes (keys 1-5), pages, a 3-question self-check,
/// and an honest way out of a book. Return saves, Esc closes.
struct ReadingLogSheet: View {
    let item: CatalogItem
    var onSave: (ReadingLogEntry) -> Void = { _ in }
    var onCancel: () -> Void = {}

    @State private var minutes = 15
    @State private var pages = ""
    @State private var answers = [false, false, false]
    @State private var finished = false
    @State private var typing = false

    private static let minuteChoices = [5, 10, 15, 20, 30]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            VStack(alignment: .leading, spacing: 4) {
                Text("LOG READING").font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(1.4).foregroundStyle(Tokens.accentText)
                MisprintText(item.title, font: Typography.display(30), offset: CGSize(width: 2, height: 2))
            }
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text("How long did you read?").font(Typography.labelBold).foregroundStyle(Tokens.ink)
                HStack(spacing: Tokens.Space.xs) {
                    ForEach(Array(Self.minuteChoices.enumerated()), id: \.offset) { index, value in
                        Button { minutes = value } label: {
                            VStack(spacing: 0) {
                                Text("\(value)").font(Typography.display(22))
                                Text("min · \(index + 1)").font(Typography.caption)
                            }
                            .foregroundStyle(minutes == value ? Tokens.onAccent : Tokens.ink)
                            .frame(width: 64, height: 50)
                            .sticker(minutes == value ? Tokens.accent : Tokens.paper, radius: 12, depth: minutes == value ? 1 : 3)
                            .padding(.bottom, 3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(value) minutes")
                        .accessibilityAddTraits(minutes == value ? .isSelected : [])
                    }
                }
            }
            HStack(spacing: Tokens.Space.s) {
                Text("Pages (optional)").font(Typography.labelBold).foregroundStyle(Tokens.ink)
                ProgressField(prompt: "e.g. 8", text: $pages, onFocusChange: { typing = $0 }).frame(width: 110)
            }
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text("Quick check").font(Typography.labelBold).foregroundStyle(Tokens.ink)
                ForEach(ReadingCheck.questions.indices, id: \.self) { i in
                    ProgressCheck(title: ReadingCheck.questions[i], isOn: $answers[i])
                }
                Text("Your pace counts only when 2 or 3 answers are yes.")
                    .font(Typography.caption)
                    .foregroundStyle(Tokens.brand)
            }
            ProgressCheck(title: "I finished the book!", isOn: $finished)
            HStack(spacing: Tokens.Space.s) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.ink)
                    .keyboardShortcut(.cancelAction)
                Menu("Stop this book") {
                    Button("Too hard for now") { save(.abandoned, "tooHard") }
                    Button("Boring") { save(.abandoned, "boring") }
                    Button("No time") { save(.abandoned, "noTime") }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .foregroundStyle(Tokens.brand)
                Spacer()
                Button { save(finished ? .finished : nil, nil) } label: {
                    HStack(spacing: Tokens.Space.s) {
                        Text("Save \(minutes) min")
                        KeyCap("Return", fill: Tokens.accent)
                    }
                }
                .buttonStyle(.fat)
                .keyboardShortcut(.defaultAction)
                .frame(width: 260)
            }
        }
        .padding(Tokens.Space.xl)
        .frame(width: 560)
        .paperBackground()
        .onKeyPress(characters: CharacterSet(charactersIn: "12345")) { press in
            guard !typing, let n = Int(press.characters), Self.minuteChoices.indices.contains(n - 1) else { return .ignored }
            minutes = Self.minuteChoices[n - 1]
            return .handled
        }
    }

    private func save(_ status: LibraryStatus?, _ reason: String?) {
        onSave(ReadingLogEntry(minutes: minutes, pages: Int(pages.trimmingCharacters(in: .whitespaces)),
                               understood: answers.filter { $0 }.count, newStatus: status, abandonReason: reason))
    }
}
