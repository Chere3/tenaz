import SwiftUI
import TenazCore

/// The last 7 learning days: green with a check = practised, ink at 12 % = not. Today has an ink ring.
struct WeekDots: View {
    let days: [WeeklyReviewReport.Day]
    var dot: CGFloat = 38

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            ForEach(days) { d in
                VStack(spacing: 6) {
                    ZStack {
                        if d.qualified {
                            Circle().fill(Tokens.correct)
                            Image(systemName: "checkmark").font(.system(size: dot * 0.4, weight: .black)).foregroundStyle(Tokens.inverse)
                        } else {
                            Circle().fill(Tokens.ink.opacity(0.12))
                        }
                        if d.id == days.last?.id {
                            Circle().strokeBorder(Tokens.ink, lineWidth: 2).padding(-5)
                        }
                    }
                    .frame(width: dot, height: dot)
                    .padding(.top, 5)
                    Text(letter(d.day))
                        .font(Typography.label)
                        .foregroundStyle(Tokens.brand)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(weekdayName(d.day))
                .accessibilityValue(d.qualified ? "Practised" : "Missed")
            }
        }
    }

    private static let letters = ["S", "M", "T", "W", "T", "F", "S"]
    private static let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private func letter(_ day: Int) -> String { Self.letters[LearningDays.weekday(day) - 1] }
    private func weekdayName(_ day: Int) -> String { Self.names[LearningDays.weekday(day) - 1] }
}
