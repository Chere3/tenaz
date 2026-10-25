import SwiftUI

/// Tena at the top of the sidebar: small and unframed, the app name, her stage and streak.
struct SidebarHeader: View {
    let summary: TodaySummary

    var body: some View {
        HStack(spacing: Tokens.Space.xs) {
            TenaView(mood: summary.mood, stage: summary.stage, size: 64)
                .frame(width: 52, height: 52)
                .offset(y: -4)
            VStack(alignment: .leading, spacing: 1) {
                Text("Tenaz")
                    .font(Typography.display(24))
                    .foregroundStyle(Tokens.ink)
                Text("\(summary.stageName) · \(summary.streakDays) day\(summary.streakDays == 1 ? "" : "s")")
                    .font(Typography.caption)
                    .foregroundStyle(Tokens.brand)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tena, \(summary.stageName), streak \(summary.streakDays) days")
    }
}
