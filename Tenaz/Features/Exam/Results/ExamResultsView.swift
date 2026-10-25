import SwiftUI
import TenazCore

/// After submit, on the serious (exam) flood: the overall band as the one hero number, what it
/// means, the skills as a quiet list, the top fixes as text, the integrity verdict, and one next step.
struct ExamResultsView: View {
    let model: ExamResultModel
    var onNext: () -> Void = {}
    var onHistory: () -> Void = {}

    var body: some View {
        SnapshotSafeScroll {
            VStack(alignment: .leading, spacing: Tokens.Space.xxl) {
                VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                    ResultHero(model: model)
                    NextStepCard(model: model, onNext: onNext, onHistory: onHistory)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .overlay(alignment: .topTrailing) {
                    // Tena sits on the hero row, cropped by the right edge.
                    FloorlessTena(mood: model.provisional ? .focused : .proud, size: 380, inset: Tokens.Space.hero)
                        .offset(y: 20)
                        .accessibilityHidden(true)
                }
                HStack(alignment: .top, spacing: 56) {
                    VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                        SkillBandList(model: model)
                        IntegrityCard(model: model)
                    }
                    .frame(width: 420, alignment: .leading)
                    CorrectionsCard(model: model)
                }
            }
            .padding(.horizontal, Tokens.Space.hero)
            .padding(.top, Tokens.Space.xxl)
            .padding(.bottom, Tokens.Space.xxl)
            .frame(maxWidth: 1180, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipped()
        .flood(.serious)
    }
}

/// Secondary text on the indigo flood: ink, quieter (the warm brand grey reads muddy on indigo).
enum ResultInk {
    static var secondary: Color { Tokens.ink.opacity(0.72) }
    /// The 1 pt rule between list rows.
    static var rule: Color { Tokens.ink.opacity(0.12) }
}

private struct ResultHero: View {
    let model: ExamResultModel

    /// Names only the skills still waiting for Claude ("Speaking is…", "Writing and speaking are…").
    private var pendingLine: String? {
        let names = model.skills.filter(\.pending).map { $0.skill.label.lowercased() }
        if names.isEmpty {
            return model.skills.contains(where: \.failed) ? "A grade didn't come through yet. Tenaz tries again the next time it opens." : nil
        }
        // English on any system language (ListFormatter would follow the Mac's locale).
        let list = names.count > 1 ? names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1] : names[0]
        return "\(list.prefix(1).uppercased() + list.dropFirst()) \(names.count == 1 ? "is" : "are") still being graded, so this can still move a little."
    }

    private var kindTitle: String {
        switch model.kind {
        case .placement: "Placement test"
        case .daily: "Daily Check"
        case .weekly: "Weekly Mock"
        case .monthly: "Monthly Mock"
        }
    }

    private var rangeLine: String {
        let band = model.overall ?? 0
        var parts: [String] = []
        if let low = model.overallLow, let high = model.overallHigh, low < high {
            parts.append("likely \(BandWords.format(low)) to \(BandWords.format(high))")
        }
        parts.append(BandWords.ielts(band))
        return parts.joined(separator: " · ")
    }

    var body: some View {
        let band = model.overall ?? 0
        VStack(alignment: .leading, spacing: 0) {
            Text("\(kindTitle) · \(model.minutes) min")
                .font(Typography.label)
                .foregroundStyle(ResultInk.secondary)
            HStack(alignment: .lastTextBaseline, spacing: Tokens.Space.l) {
                Text(BandWords.format(band))
                    .font(Typography.numberHero)
                    .foregroundStyle(Tokens.ink)
                    .accessibilityLabel("Band \(BandWords.format(band)) of 6")
                VStack(alignment: .leading, spacing: 2) {
                    Text(BandWords.label(band))
                        .font(Typography.displayM)
                        .foregroundStyle(Tokens.ink)
                    Text("band out of 6, TOEFL-style")
                        .font(Typography.title)
                        .foregroundStyle(Tokens.ink)
                }
                .padding(.bottom, 26)
            }
            .padding(.top, -Tokens.Space.s)
            Text(rangeLine)
                .font(Typography.label)
                .foregroundStyle(ResultInk.secondary)
            Text(BandWords.meaning(band))
                .font(Typography.body)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 600, alignment: .leading)
                .padding(.top, Tokens.Space.m)
            if model.provisional, let line = pendingLine {
                Label(line, systemImage: "hourglass")
                    .font(Typography.labelBold)
                    .foregroundStyle(Tokens.ink)
                    .padding(.top, Tokens.Space.s)
            }
        }
    }
}

/// The five skills as a quiet list: name, band and level, the likely range. Rules, no cards.
private struct SkillBandList: View {
    let model: ExamResultModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("By skill")
                .font(Typography.label)
                .foregroundStyle(ResultInk.secondary)
                .padding(.bottom, Tokens.Space.xs)
            ForEach(model.skills) { row in
                Rectangle().fill(ResultInk.rule).frame(height: 1)
                SkillBandRow(row: row, grading: model.grading)
            }
        }
    }
}

private struct SkillBandRow: View {
    let row: ExamResultModel.SkillRow
    let grading: ExamResultModel.Grading

    private var title: String { row.skill == .grammar ? "Grammar & words" : row.skill.label }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.ink)
                .frame(width: 150, alignment: .leading)
            if row.pending {
                Label(grading == .running ? "Grading with Claude…" : "Pending: will finish when Claude is available",
                      systemImage: grading == .running ? "ellipsis" : "hourglass")
                    .font(Typography.label)
                    .foregroundStyle(ResultInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            } else if let band = row.band {
                Text(BandWords.format(band))
                    .font(Typography.displayS)
                    .foregroundStyle(Tokens.ink)
                    .frame(width: 50, alignment: .leading)
                Text(BandWords.label(band))
                    .font(Typography.labelBold)
                    .foregroundStyle(Tokens.ink)
                    .frame(width: 36, alignment: .leading)
                Spacer(minLength: Tokens.Space.xs)
                Text(row.failed ? "objective part only" : rangeText(row))
                    .font(Typography.label)
                    .foregroundStyle(ResultInk.secondary)
            } else {
                Text("Not tested")
                    .font(Typography.label)
                    .foregroundStyle(ResultInk.secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(minHeight: 50)
        .accessibilityElement(children: .combine)
    }

    private func rangeText(_ row: ExamResultModel.SkillRow) -> String {
        guard let low = row.low, let high = row.high, low < high else { return "Tenaz band" }
        return "likely \(BandWords.format(low)) to \(BandWords.format(high))"
    }
}
