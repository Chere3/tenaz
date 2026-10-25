import SwiftUI
import TenazCore

/// Today's three quests plus the weekly one (PLAN F9), with Tena's comment and the time until the
/// 04:00 refresh. One hero (the three rows, large) and one primary action: go do the reviews.
struct QuestsScreen: View {
    let model: QuestsModel
    var startReviews: () -> Void = {}
    var openAchievements: () -> Void = {}

    private var allDone: Bool { !model.quests.isEmpty && model.doneCount == model.quests.count }

    var body: some View {
        ProgressPage {
            HStack(alignment: .top, spacing: Tokens.Space.xxl) {
                VStack(alignment: .leading, spacing: Tokens.Space.l) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(model.doneCount) of \(model.quests.count)")
                            .font(Typography.numberHero)
                            .foregroundStyle(Tokens.ink)
                            .lineLimit(1)
                            .padding(.vertical, -26)
                            .accessibilityAddTraits(.isHeader)
                        Text("quests done today")
                            .font(Typography.title)
                            .foregroundStyle(Tokens.ink)
                        Text("\(model.streakDays) of 7 days practised · new quests \(model.refreshText)")
                            .font(Typography.body)
                            .foregroundStyle(Tokens.brand)
                    }
                    VStack(spacing: 0) {
                        if model.quests.isEmpty {
                            Text("Quests appear after your first review today.")
                                .font(Typography.body)
                                .foregroundStyle(Tokens.brand)
                                .padding(.vertical, Tokens.Space.m)
                        }
                        ForEach(model.quests, id: \.id) { QuestCard(quest: $0) }
                    }
                    if let weekly = model.weekly {
                        VStack(alignment: .leading, spacing: 0) {
                            ProgressSectionLabel("This week")
                                .padding(.top, Tokens.Space.l)
                            QuestCard(quest: weekly, daysLeft: daysLeftInWeek)
                        }
                    }
                    primaryButton
                        .padding(.top, Tokens.Space.xs)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                tenaColumn
                    .frame(width: 260)
            }
        }
    }

    @ViewBuilder private var primaryButton: some View {
        if allDone {
            Button(action: openAchievements) {
                HStack(spacing: Tokens.Space.s) {
                    Text("See your achievements")
                    KeyCap("Return")
                }
            }
            .buttonStyle(.fat)
            .keyboardShortcut(.defaultAction)
            .fixedSize()
        } else {
            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                Button(action: startReviews) {
                    HStack(spacing: Tokens.Space.s) {
                        Text(model.nextUndone?.title ?? "Start reviewing")
                            .lineLimit(1)
                        KeyCap("Return")
                    }
                }
                .buttonStyle(.fat)
                .keyboardShortcut(.defaultAction)
                .fixedSize()
                if model.core?.done == true {
                    Button("Or keep reviewing words", action: startReviews)
                        .buttonStyle(.ink)
                }
            }
        }
    }

    /// Tena whole, with one line of speech right above her head.
    private var tenaColumn: some View {
        VStack(alignment: .center, spacing: Tokens.Space.s) {
            SpeechBubble(model.tenaLine)
            TenaView(mood: tenaMood, stage: model.stage, size: 220)
                .accessibilityHidden(true)
        }
        .padding(.top, Tokens.Space.xl)
    }

    /// Quests done lift Tena's mood: the core quest makes her happy, all three proud.
    private var tenaMood: TenaMood {
        if allDone { return .proud }
        if model.core?.done == true, [.hungry, .nagging, .sad, .neutral].contains(model.mood) { return .happy }
        return model.mood
    }

    private var daysLeftInWeek: Int {
        let today = DayBoundary.day(for: model.now)
        return 7 - LearningDays.distance(from: LearningDays.weekStart(today), to: today)
    }
}
