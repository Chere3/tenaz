import SwiftUI

/// Answer options as paper rows with their number key. The picked one is filled with ink, paper
/// text and a check (state by shape and word too, never colour alone). No right/wrong during exams.
struct ExamOptionList: View {
    let options: [String]
    let selected: Int?
    var columns = 1
    let choose: (Int) -> Void

    var body: some View {
        let grid = Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.s), count: columns)
        LazyVGrid(columns: grid, alignment: .leading, spacing: Tokens.Space.s) {
            ForEach(options.indices, id: \.self) { i in
                ExamOptionTile(number: i + 1, text: options[i], isSelected: selected == i) { choose(i) }
            }
        }
    }
}

private struct ExamOptionTile: View {
    let number: Int
    let text: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Tokens.Space.s) {
                KeyCap("\(number)")
                Text(text)
                    .font(.system(size: 19, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Tokens.Space.xs)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .black))
                }
            }
            .foregroundStyle(isSelected ? Tokens.paper : Tokens.ink)
            .padding(.horizontal, Tokens.Space.m)
            .padding(.vertical, Tokens.Space.s)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .modifier(ExamSheet(radius: 18, fill: isSelected ? Tokens.ink : (isHovering ? Tokens.card : Tokens.paper)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel("Option \(number): \(text)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
