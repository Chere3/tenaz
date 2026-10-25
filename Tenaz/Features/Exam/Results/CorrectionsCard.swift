import SwiftUI
import TenazCore

/// The top three fixes Claude found in the writing and speaking answers, as text: what you wrote
/// (struck through), the fix, and the rule in one line.
struct CorrectionsCard: View {
    let model: ExamResultModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.corrections.isEmpty ? "Fixes" : "Fix these \(model.corrections.count == 3 ? "three" : "first")")
                .font(Typography.label)
                .foregroundStyle(ResultInk.secondary)
                .padding(.bottom, Tokens.Space.xs)
            if model.corrections.isEmpty {
                Rectangle().fill(ResultInk.rule).frame(height: 1)
                Text(model.pendingCount > 0 ? "Your fixes appear here when Claude finishes grading your writing."
                                            : "No repeated mistakes found. Nice.")
                    .font(Typography.body)
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, Tokens.Space.m)
            } else {
                ForEach(Array(model.corrections.enumerated()), id: \.offset) { i, fix in
                    Rectangle().fill(ResultInk.rule).frame(height: 1)
                    CorrectionRow(number: i + 1, fix: fix)
                        .padding(.vertical, Tokens.Space.m)
                }
            }
            if let feedback = model.feedback {
                Text("“\(feedback)”")
                    .font(Typography.label)
                    .foregroundStyle(ResultInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Tokens.Space.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct CorrectionRow: View {
    let number: Int
    let fix: GradeError

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s) {
            Text("\(number)")
                .font(Typography.display(22))
                .foregroundStyle(ResultInk.secondary)
                .frame(width: 20, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                Text(fix.span)
                    .strikethrough(color: Tokens.wrong)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(ResultInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(fix.correction)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(fix.ruleShort) \(Text(fix.category.replacingOccurrences(of: "_", with: " ")).foregroundStyle(ResultInk.secondary))")
                    .font(Typography.label)
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fix \(number): \(fix.span) should be \(fix.correction). \(fix.ruleShort)")
    }
}
