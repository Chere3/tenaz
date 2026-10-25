import AppKit
import SwiftUI

/// A Terminal command printed in a mono strip with a Copy button.
struct CommandLineStrip: View {
    let command: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            Text(command)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Tokens.ink)
                .textSelection(.enabled)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc", action: copy)
                .buttonStyle(.ink)
                .font(Typography.label)
        }
        .padding(.horizontal, Tokens.Space.s)
        .padding(.vertical, 6)
        .background { RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Tokens.ink.opacity(0.06)) }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        copied = true
    }
}
