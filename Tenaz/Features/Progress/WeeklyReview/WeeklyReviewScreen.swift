import SwiftUI
import TenazCore

/// The 5-minute Sunday review (PLAN F16): look back (consistency, mastered words, mistakes, rules,
/// hatches), then write one if-then plan and, every two weeks, rate how automatic practice feels.
/// One primary action: save.
struct WeeklyReviewScreen: View {
    let report: WeeklyReviewReport
    /// Why the last save failed, shown by the button.
    var problem: String?
    /// Opens the Contract from the kill-switch advice; nil hides the link.
    var openContract: (() -> Void)?
    /// Returns true when saved.
    var onSave: (WeeklyReviewAnswers, Int?, (cue: String, action: String)?) -> Bool = { _, _, _ in true }

    @State private var whatWorked = ""
    @State private var rethink: Set<String> = []
    @State private var cue = ""
    @State private var action = ""
    @State private var automaticity: Int?
    @State private var justSaved = false
    /// Fields being typed in; digit shortcuts are off while any has focus.
    @State private var typing: Set<String> = []

    private func focus(_ id: String) -> (Bool) -> Void {
        { if $0 { typing.insert(id) } else { typing.remove(id) } }
    }

    private static let suggestions: [(String, String)] = [
        ("I open my laptop after lunch", "I review 5 words"),
        ("a meeting ends", "I write down 1 phrase I needed"),
        ("I make my first coffee", "I read one Brain bite"),
    ]

    var body: some View {
        ProgressPage(spacing: Tokens.Space.l) {
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                ProgressHeader(eyebrow: "Sunday review · 5 min", title: "Your week", subtitle: weekRange) {
                    if report.saved != nil || justSaved { savedStamp }
                }
                HStack(alignment: .top, spacing: Tokens.Space.xxl) {
                    ConsistencyCard(report: report)
                        .frame(width: 440, alignment: .leading)
                    MasteredCard(report: report)
                        .padding(.top, Tokens.Space.l)
                }
            }
            HStack(alignment: .top, spacing: Tokens.Space.xxl) {
                ErrorsCard(errors: report.errors)
                VStack(alignment: .leading, spacing: Tokens.Space.l) {
                    RulesCard(rules: report.rules, rethink: $rethink, openContract: openContract)
                    HatchCard(hatches: report.hatches, openContract: openContract)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            planSection
            if report.automaticityDue { automaticitySection }
            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                ProgressField(prompt: "What worked this week? (e.g. reviews on the bus)", text: $whatWorked, onSubmit: save, onFocusChange: focus("worked"))
            }
            Button(action: save) {
                HStack(spacing: Tokens.Space.s) {
                    Text(report.saved != nil || justSaved ? "Update my review" : "Save my review")
                    KeyCap("Return")
                }
            }
            .buttonStyle(.fat)
            .keyboardShortcut(.defaultAction)
            .frame(maxWidth: 420)
            if let problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "1234567")) { press in
            guard report.automaticityDue, typing.isEmpty, let n = Int(press.characters) else { return .ignored }
            automaticity = n
            return .handled
        }
        .onAppear(perform: restore)
    }

    private var planSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            ProgressSectionLabel("One if-then plan", detail: "Small and concrete works best")
            HStack(spacing: Tokens.Space.s) {
                Text("If").font(Typography.display(26)).foregroundStyle(Tokens.ink)
                ProgressField(prompt: "a moment that happens anyway", text: $cue, onFocusChange: focus("cue"))
                Text("then").font(Typography.display(26)).foregroundStyle(Tokens.ink)
                ProgressField(prompt: "one tiny English action", text: $action, onFocusChange: focus("action"))
            }
            WordWrapLayout(spacing: Tokens.Space.xs, lineSpacing: 4) {
                Text("Try:").font(Typography.labelBold).foregroundStyle(Tokens.brand)
                ForEach(Array(Self.suggestions.enumerated()), id: \.element.0) { index, s in
                    HStack(spacing: Tokens.Space.xs) {
                        if index > 0 { Text("·").font(Typography.label).foregroundStyle(Tokens.brand) }
                        Button("If \(s.0)…") { cue = s.0; action = s.1 }
                            .buttonStyle(.ink)
                    }
                }
            }
            if !report.plans.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(report.plans, id: \.id) { plan in
                        Label(plan.sentence, systemImage: "arrow.turn.down.right")
                            .font(Typography.label)
                            .foregroundStyle(Tokens.brand)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private var automaticitySection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            ProgressSectionLabel("Every two weeks", detail: report.lastAutomaticity.map { "Last time: \($0)" })
            Text("How automatic does practising English feel? 1 = I must force it, 7 = I do it without thinking.")
                .font(Typography.body)
                .foregroundStyle(Tokens.ink)
            HStack(spacing: Tokens.Space.s) {
                ForEach(1...7, id: \.self) { n in
                    Button { automaticity = n } label: {
                        Text("\(n)")
                            .font(Typography.display(28))
                            .foregroundStyle(Tokens.ink)
                            .frame(width: 40, height: 44)
                            .overlay(alignment: .bottom) {
                                if automaticity == n { Rectangle().fill(Tokens.ink).frame(height: 3).padding(.horizontal, 6) }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(n) of 7")
                    .accessibilityAddTraits(automaticity == n ? .isSelected : [])
                }
                Text("or press 1–7").font(Typography.label).foregroundStyle(Tokens.brand)
            }
        }
    }

    private var savedStamp: some View {
        Label("Saved", systemImage: "checkmark.seal.fill")
            .font(Typography.title)
            .foregroundStyle(Tokens.correct)
    }

    private var weekRange: String {
        guard let first = report.last7.first?.day, let last = report.last7.last?.day else { return "" }
        return "\(Self.short(first)) – \(Self.short(last)). Look back, keep what works, change one thing."
    }

    private static func short(_ day: Int) -> String {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(months[(day / 100 % 100) - 1]) \(day % 100)"
    }

    private func restore() {
        guard let saved = report.saved,
              let answers = try? JSONDecoder().decode(WeeklyReviewAnswers.self, from: Data(saved.answers.utf8)) else { return }
        whatWorked = answers.whatWorked
        rethink = Set(answers.rulesToRethink)
        automaticity = saved.automaticity
    }

    private func save() {
        let saved = onSave(WeeklyReviewAnswers(whatWorked: whatWorked.trimmingCharacters(in: .whitespacesAndNewlines),
                                               rulesToRethink: rethink.sorted()),
                           report.automaticityDue ? automaticity : nil,
                           cue.isEmpty || action.isEmpty ? nil : (cue, action))
        guard saved else { return }
        cue = ""
        action = ""
        justSaved = true
    }
}
