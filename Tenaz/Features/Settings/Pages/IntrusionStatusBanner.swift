import SwiftUI
import TenazCore

/// The first thing on the Intrusions and Safety pages: is anything able to appear right now?
/// No card: Tena, one line, one sentence and a status chip on the paper.
struct IntrusionStatusBanner: View {
    let anythingOn: Bool
    let killSwitch: KillSwitchState

    private var engaged: Bool { killSwitch.isEngaged(at: Date()) }

    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            TenaView(mood: anythingOn && !engaged ? .focused : .asleep, stage: .juvenile, size: 72)
            VStack(alignment: .leading, spacing: 2) {
                Text(engaged ? "Kill switch is on" : (anythingOn ? "Intrusions are on" : "Everything is off"))
                    .font(Typography.displayS)
                    .foregroundStyle(Tokens.ink)
                Text(engaged ? (killSwitch.reason(at: Date()) ?? "") + ". Nothing can appear."
                     : (anythingOn ? "They wait for a gap: never in a meeting, never in quiet hours."
                        : "Nothing will pop up. Turn things on below when you are ready."))
                    .font(Typography.label)
                    .foregroundStyle(Tokens.brand)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Chip(engaged ? "Killed" : (anythingOn ? "On" : "Off"), systemImage: engaged ? "hand.raised.fill" : (anythingOn ? "bolt.fill" : "moon.zzz.fill"),
                 state: anythingOn && !engaged ? .active : .idle)
        }
    }
}
