import SwiftUI
import TenazCore

/// Consistency: the last 7 days as dots, and the 30-day count.
struct ConsistencyCard: View {
    let report: WeeklyReviewReport

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
                Text("\(report.daysPracticed7)")
                    .font(Typography.numberHero)
                    .foregroundStyle(Tokens.ink)
                    .padding(.vertical, -26)
                Text("of 7 days")
                    .font(Typography.title)
                    .foregroundStyle(Tokens.ink)
            }
            WeekDots(days: report.last7)
            Text("\(report.daysPracticed30) of the last 30 days. \(report.daysPracticed7 >= 5 ? "Weekly goal met!" : "The goal is 5 of 7, not 7 of 7.")")
                .font(Typography.label)
                .foregroundStyle(Tokens.brand)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Tokens.Space.xxs)
        }
        .accessibilityElement(children: .contain)
    }
}

/// Mastered notes: today's count, this week's gain and the 30-day line.
struct MasteredCard: View {
    let report: WeeklyReviewReport

    var body: some View {
        ReviewCard(title: "Mastered words", systemImage: "brain.head.profile") {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(report.masteredNow)").font(Typography.displayM).foregroundStyle(Tokens.ink)
                if report.masteredGained7 > 0 {
                    Text("+\(report.masteredGained7) this week")
                        .font(Typography.labelBold)
                        .foregroundStyle(Tokens.correct)
                }
            }
            if report.masteredSeries.contains(where: { $0 > 0 }) {
                ProgressSparkline(values: report.masteredSeries).frame(height: 64)
                HStack {
                    Text("30 days ago"); Spacer(); Text("today")
                }
                .font(Typography.caption)
                .foregroundStyle(Tokens.brand)
            } else {
                Text("A word counts as mastered after 3 good reviews spread over about 3 weeks. Your line starts soon.")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Every escape hatch used this week, counted honestly, never blocked.
struct HatchCard: View {
    let hatches: HatchCounts
    var openContract: (() -> Void)?

    private var rows: [(String, String, Int)] {
        [("Kill switch", "power", hatches.killSwitch), ("Pause 1 h", "pause.circle.fill", hatches.pause),
         ("Snoozes", "zzz", hatches.snoozes), ("Meeting claims", "video.fill", hatches.meetingClaims),
         ("Claims, no meeting found", "questionmark.video.fill", hatches.uncorroboratedClaims),
         ("Skips", "forward.fill", hatches.skips), ("Emergency skips", "exclamationmark.octagon.fill", hatches.emergencySkips)]
            .filter { $0.2 > 0 || $0.0 == "Kill switch" }
    }

    var body: some View {
        ReviewCard(title: "Escape hatches", systemImage: "door.left.hand.open") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(rows, id: \.0) { row in
                    HStack(spacing: Tokens.Space.xs) {
                        Image(systemName: row.1).font(.system(size: 12, weight: .bold)).frame(width: 18)
                        Text(row.0).font(Typography.label)
                        Spacer()
                        Text("\(row.2)").font(Typography.numeric(15))
                    }
                    .foregroundStyle(Tokens.ink)
                }
            }
            if hatches.asksRenegotiation {
                VStack(alignment: .leading, spacing: 4) {
                    Text("The kill switch fired \(hatches.killSwitch) times. Which rule was too much?")
                        .font(.system(size: 16, design: .rounded))
                        .foregroundStyle(Tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let openContract {
                        Button("Change it in the Contract", action: openContract)
                            .buttonStyle(.ink)
                    }
                }
            } else {
                Text("Hatches always work. They are counted, not punished.")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
            }
        }
    }
}

/// The error categories that showed up this week (from the error ledger).
struct ErrorsCard: View {
    let errors: [ErrorTrend]

    var body: some View {
        ReviewCard(title: "What tripped you up", systemImage: "exclamationmark.bubble.fill") {
            if errors.isEmpty {
                Text("No repeated mistakes logged yet. Writing and speaking tasks fill this in.")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(errors) { e in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(e.name.prefix(1).uppercased() + e.name.dropFirst()).font(Typography.labelBold).foregroundStyle(Tokens.ink)
                        if e.isNew { Text("· new this week").font(Typography.caption).foregroundStyle(Tokens.brand) }
                        else if e.activeThisWeek { Text("· this week").font(Typography.caption).foregroundStyle(Tokens.brand) }
                        Spacer()
                        Text("×\(e.count)").font(Typography.numeric(14)).foregroundStyle(Tokens.ink)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .black)).foregroundStyle(Tokens.wrong)
                        Text(e.example).strikethrough(color: Tokens.wrong).foregroundStyle(Tokens.wrong)
                    }
                    .font(Typography.label)
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .black)).foregroundStyle(Tokens.correct)
                        Text(e.correction).foregroundStyle(Tokens.correct)
                    }
                    .font(Typography.labelBold)
                }
                .padding(.vertical, 2)
            }
        }
    }
}

/// Which contract rules fired and how often the learner escaped them (the experiment log).
struct RulesCard: View {
    let rules: [RuleWeek]
    @Binding var rethink: Set<String>
    var openContract: (() -> Void)?

    var body: some View {
        ReviewCard(title: "Your rules this week", systemImage: "signature") {
            if rules.isEmpty {
                Text("No contract rule fired. Rules stay off until you choose them in the Contract.")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(rules) { rule in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(rule.title).font(Typography.labelBold).foregroundStyle(Tokens.ink)
                        Spacer()
                        Text("fired \(rule.stats.fired) · dismissed \(rule.stats.dismissed) · escaped \(rule.stats.escaped)")
                            .font(Typography.numeric(12))
                            .foregroundStyle(Tokens.brand)
                    }
                    HStack(spacing: Tokens.Space.xs) {
                        MeterCells(fraction: rule.stats.escapeRate, fill: rule.stats.escapeRate > 0.6 ? Tokens.wrong : Tokens.brand)
                            .frame(height: 10)
                        Text("\(Int((rule.stats.escapeRate * 100).rounded()))% escaped")
                            .font(Typography.numeric(12))
                            .foregroundStyle(rule.stats.escapeRate > 0.6 ? Tokens.wrong : Tokens.ink)
                            .fixedSize()
                    }
                    if rule.suggestTurnOff {
                        Text("You escaped it most of the time two weeks in a row. It may be too strong. Turn it off?")
                            .font(Typography.label)
                            .foregroundStyle(Tokens.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    let on = rethink.contains(rule.rule)
                    Button { if on { rethink.remove(rule.rule) } else { rethink.insert(rule.rule) } } label: {
                        Text(on ? "✓ Rethink this rule in the Contract" : "Rethink this rule in the Contract")
                    }
                    .buttonStyle(.ink)
                    .accessibilityLabel("Rethink this rule in the Contract")
                    .accessibilityValue(on ? "On" : "Off")
                }
                .padding(.vertical, 2)
            }
        }
    }
}
