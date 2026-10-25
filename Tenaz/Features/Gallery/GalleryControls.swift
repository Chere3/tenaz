import SwiftUI

/// The ink pill (the one primary), text buttons, keycaps, chips and toasts.
struct GalleryControls: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            HStack(spacing: Tokens.Space.m) {
                Button {} label: {
                    HStack(spacing: Tokens.Space.s) {
                        Text("Check")
                        KeyCap("Return")
                    }
                }
                .buttonStyle(.fat)
                .frame(width: 220)
                Button("Unlock") {}
                    .buttonStyle(.fat)
                    .disabled(true)
                    .frame(width: 160)
                Text("ink pill, 62 pt: one per screen")
                    .font(Typography.caption)
                    .foregroundStyle(Tokens.brand)
            }
            HStack(spacing: Tokens.Space.xs) {
                Button("Write", systemImage: "pencil.line") {}.buttonStyle(.ink)
                Button("Exam", systemImage: "doc.text.magnifyingglass") {}.buttonStyle(.ink)
                Button("I don't know") {}.buttonStyle(.ink)
                Spacer(minLength: 0)
                Text("text button 16").font(Typography.caption).foregroundStyle(Tokens.brand)
            }
            HStack(spacing: Tokens.Space.xs) {
                KeyCap("esc")
                KeyCap("Return")
                KeyCap("⌘D")
                KeyCap("⌘⌥⎋")
                Text("keycaps: hairline, 60 % of the text colour").font(Typography.caption).foregroundStyle(Tokens.brand)
                    .padding(.leading, Tokens.Space.xs)
            }
            .foregroundStyle(Tokens.ink)
            HStack(spacing: Tokens.Space.xs) {
                Chip("Reading", systemImage: "book.fill", state: .active)
                Chip("Listening", systemImage: "headphones")
                Chip("Speaking", state: .done)
                Chip("Writing", state: .locked)
            }
            HStack(spacing: Tokens.Space.s) {
                Sticker(text: "+10 XP", systemImage: "star.fill")
                Sticker(text: "9 days", systemImage: "flame.fill", fill: Tokens.accent, foreground: Tokens.onAccent)
                Sticker(text: "Correct", systemImage: "checkmark", fill: Tokens.correct, foreground: Tokens.inverse)
                SpeechBubble("We go again.").fixedSize()
            }
        }
    }
}
