import SwiftUI
import TenazCore

/// Step 3: the daily minimum, two big numerals and ten cells.
struct OnboardingMinimum: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            Text("Your daily minimum")
                .font(Typography.display(52))
                .foregroundStyle(Tokens.ink)
            HStack(alignment: .top, spacing: Tokens.Space.m) {
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    Text("\(StreakEngine.minCorrectRetrievals)")
                        .font(Typography.display(104))
                        .foregroundStyle(Tokens.ink)
                        .frame(height: 112, alignment: .top)
                    MeterCells(fraction: 1, fill: Tokens.ink, cells: StreakEngine.minCorrectRetrievals)
                        .frame(width: 150, height: 14)
                    Text("correct words")
                        .font(Typography.title)
                        .foregroundStyle(Tokens.ink)
                }
                Text("+")
                    .font(Typography.display(52))
                    .foregroundStyle(Tokens.brand)
                    .padding(.top, 40)
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    Text("1")
                        .font(Typography.display(104))
                        .foregroundStyle(Tokens.ink)
                        .frame(height: 112, alignment: .top)
                    Color.clear.frame(height: 14)
                    Text("sentence")
                        .font(Typography.title)
                        .foregroundStyle(Tokens.ink)
                }
            }
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                MinimumPoint(systemImage: "timer", text: "About 4 minutes a day.")
                MinimumPoint(systemImage: "flame.fill", text: "It keeps your streak and feeds Tena.")
                MinimumPoint(systemImage: "calendar", text: "5 of 7 days is a great week.")
                MinimumPoint(systemImage: "arrow.uturn.backward", text: "Missed a day? Just start again. No guilt.")
            }
        }
    }
}
