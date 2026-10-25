import SwiftUI

/// Tivra's read-only witness as one quiet line: watching (result can be verified) or not (the test
/// still runs and still gives a level, marked unverified for promotion). The detail is in the
/// tooltip and the accessibility label; when Tivra isn't watching it is shown too.
struct WitnessCard: View {
    let witness: ExamWitness

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: witness.systemImage)
                .font(.system(size: 12, weight: .bold))
            Text(witness.isWatching ? witness.title : "\(witness.title). \(witness.detail)")
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(Typography.labelBold)
        .foregroundStyle(Tokens.ink.opacity(0.72))
        .help(witness.detail)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(witness.title). \(witness.detail)")
    }
}
