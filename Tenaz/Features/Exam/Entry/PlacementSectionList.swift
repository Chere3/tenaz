import SwiftUI
import TenazCore

/// The sections of the test drawn as time: one bar of segments whose widths follow the minutes,
/// a short name under each, then the total and the pause rule in one line.
struct PlacementSectionList: View {
    let sections: [PlacementEntryState.Section]
    let totalMinutes: Int

    private static let gap: CGFloat = 5

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            GeometryReader { proxy in
                let usable = max(0, proxy.size.width - Self.gap * CGFloat(max(sections.count - 1, 0)))
                let total = CGFloat(max(totalMinutes, 1))
                HStack(alignment: .top, spacing: Self.gap) {
                    ForEach(sections) { section in
                        let width = usable * CGFloat(section.minutes) / total
                        VStack(alignment: .leading, spacing: 7) {
                            Capsule()
                                .fill(Tokens.ink.opacity(0.9))
                                .frame(width: width, height: 10)
                            Text(Self.shortNames[section.id] ?? section.title.lowercased())
                                .font(Typography.caption)
                                .foregroundStyle(Tokens.ink.opacity(0.72))
                                .lineLimit(1)
                                .fixedSize()
                                .frame(width: width, alignment: .leading)
                        }
                    }
                }
            }
            .frame(height: 30)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(sections.count) sections: " + sections.map { "\($0.title), \($0.minutes) min" }.joined(separator: "; "))
            Text("\(totalMinutes) min · you can pause between parts")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.ink)
        }
    }

    /// Names short enough to sit under a 5-minute segment.
    static let shortNames: [String: String] = [
        "vocab": "vocab", "reading": "reading", "listening": "listening", "grammar": "gram.",
        "email": "email", "about-you": "about you", "interview": "interview",
    ]
}
