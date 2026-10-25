import SwiftUI

/// Step 4: an if-then plan. Pick when, see the sentence printed, then go to the placement test.
struct OnboardingPlanStep: View {
    @Binding var plan: OnboardingPlan
    var onSubmit: () -> Void = {}
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            Text("Make a plan")
                .font(Typography.display(52))
                .foregroundStyle(Tokens.ink)
            Text("People who decide when they will practice do it more often. When will you do your set?")
                .font(Typography.title)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            // Cues are plain text options: the chosen one is ink with a check and an underline.
            ChipFlowLayout(spacing: Tokens.Space.m) {
                ForEach(OnboardingPlan.cues, id: \.self) { cue in
                    let selected = plan.custom.isEmpty && plan.cue == cue
                    Button(action: { choose(cue) }) {
                        HStack(spacing: 4) {
                            if selected { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)) }
                            Text(cue)
                        }
                        .font(selected ? Typography.labelBold : Typography.label)
                        .foregroundStyle(selected ? Tokens.ink : Tokens.brand)
                        .padding(.vertical, 4)
                        .overlay(alignment: .bottom) {
                            if selected { Rectangle().fill(Tokens.ink).frame(height: 2) }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            // The paper sheet: the one rounded surface on the flood.
            Group {
                if isSnapshot {
                    Text(plan.custom.isEmpty ? Self.placeholder : plan.custom)
                        .foregroundStyle(plan.custom.isEmpty ? Tokens.brand.opacity(0.7) : Tokens.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    TextField(Self.placeholder, text: $plan.custom)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .onSubmit(onSubmit)
                }
            }
            .font(.system(size: 20, weight: .medium, design: .rounded))
            .padding(.horizontal, Tokens.Space.l)
            .frame(height: 64)
            .background(RoundedRectangle(cornerRadius: Tokens.Radius.sheet, style: .continuous).fill(Tokens.paper))
            if let sentence = plan.sentence {
                Text(sentence)
                    .font(Typography.displayS)
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Tokens.Space.xs)
            }
        }
    }

    private static let placeholder = "Or write your own, like \"I sit on the train\""

    private func choose(_ cue: String) {
        plan.cue = cue
        plan.custom = ""
    }
}
