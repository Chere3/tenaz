import SwiftUI
import TenazCore

/// One exam kind. The screen's primary exam is the hero (big title, one line, the ink pill);
/// the others are quiet text columns with a text "Start" or the reason they are locked.
struct ExamCard: View {
    let info: ExamCardInfo
    let isPrimary: Bool
    let availability: ExamsOverviewState.Availability
    let note: String?
    let action: () -> Void

    var body: some View {
        if isPrimary { hero } else { quiet }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(info.title)
                .font(Typography.displayL)
                .foregroundStyle(Tokens.ink)
                .accessibilityAddTraits(.isHeader)
            Text("\(info.length) · \(info.purpose)")
                .font(Typography.title)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Tokens.Space.xs)
            if let note {
                // Green and a check only for "Done …"; "In progress" is not a success state.
                let done = note.hasPrefix("Done")
                Label(note, systemImage: done ? "checkmark" : "arrow.uturn.right")
                    .font(Typography.labelBold)
                    .foregroundStyle(done ? Tokens.correct : Tokens.brand)
                    .padding(.top, Tokens.Space.xs)
            }
            switch availability {
            case .open:
                Button(action: action) {
                    HStack(spacing: Tokens.Space.s) {
                        Text("Start")
                        KeyCap("Return")
                    }
                }
                .buttonStyle(.fat)
                .keyboardShortcut(.defaultAction)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.top, Tokens.Space.l)
            case let .locked(reason):
                LockedLine(reason: reason)
                    .padding(.top, Tokens.Space.m)
            }
        }
    }

    private var quiet: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(info.title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.ink)
            Text(info.purpose)
                .font(Typography.label)
                .foregroundStyle(Tokens.brand)
                .lineLimit(2, reservesSpace: true)
            Text(note.map { "\(info.length) · \($0)" } ?? info.length)
                .font(Typography.label)
                .foregroundStyle(Tokens.brand)
            Group {
                switch availability {
                case .open:
                    Button(action: action) {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.ink)
                    .padding(.leading, -Tokens.Space.s)
                case let .locked(reason):
                    LockedLine(reason: reason)
                        .frame(minHeight: 32)
                }
            }
            .padding(.top, Tokens.Space.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// "Opens Nov 20" with a lock: a state, in words and a glyph, not a button.
private struct LockedLine: View {
    let reason: String

    var body: some View {
        Label(reason.prefix(1).uppercased() + reason.dropFirst(), systemImage: "lock.fill")
            .font(Typography.labelBold)
            .foregroundStyle(Tokens.brand)
    }
}
