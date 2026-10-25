import SwiftUI

/// "−  8 a day  +": a number with flat minus/plus keys, clamped to `range`.
struct RisoStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    var format: (Int) -> String = { "\($0)" }

    var body: some View {
        HStack(spacing: 0) {
            key("minus", enabled: value - step >= range.lowerBound) { value = max(range.lowerBound, value - step) }
            Text(format(value))
                .font(Typography.numeric(15))
                .foregroundStyle(Tokens.ink)
                .frame(minWidth: 86)
                .contentTransition(.numericText())
            key("plus", enabled: value + step <= range.upperBound) { value = min(range.upperBound, value + step) }
        }
        .padding(3)
        .background { Capsule().fill(Tokens.ink.opacity(0.08)) }
        .accessibilityElement(children: .ignore)
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
    }

    private func key(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(enabled ? Tokens.ink : Tokens.ink.opacity(0.3))
                .frame(width: 26, height: 26)
                .background { Circle().fill(Tokens.paper) }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
