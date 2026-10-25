import SwiftUI
import TenazCore

/// The menu-bar popover (PLAN F12, wireframe docs/research/11 §6.1): Tena + stage + streak,
/// Vitality/Spirit, the one primary action, text buttons, and the safety row. Opaque paper content;
/// the system draws the window chrome around it.
struct MenuPopover: View {
    var state: PopoverState = .placeholder
    var actions = PopoverActions()
    #if TENAZ_DEV_BUILD
        @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("Tenaz")
                    .font(Typography.display(26))
                    .foregroundStyle(Tokens.ink)
                Spacer()
                StreakBadge(days: state.streakDays)
            }
            TenaStageCard(state: state)
                .padding(.leading, -Tokens.Space.l)
            Button(action: actions.review) {
                HStack(spacing: Tokens.Space.s) {
                    Text(state.primaryTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    KeyCap("Return")
                }
            }
            .buttonStyle(.fat)
            .keyboardShortcut(.defaultAction)
            .frame(width: 214, alignment: .leading)
            alsoToday
            stats
            Rectangle().fill(Tokens.ink.opacity(0.12)).frame(height: Tokens.rule)
            PopoverSafetyRow(actions: actions, pausedUntil: state.pausedUntil)
            footer
        }
        .padding(Tokens.Space.l)
        .frame(width: 360, alignment: .leading)
        .flood(state.flood)
        .clipped()
    }

    private var alsoToday: some View {
        HStack(spacing: Tokens.Space.xs) {
            Text("Also today:").foregroundStyle(Tokens.brand)
            Button("write", action: actions.write)
            Text("·").foregroundStyle(Tokens.brand)
            Button("exam", action: actions.exam)
            Text("·").foregroundStyle(Tokens.brand)
            Button("quests", action: actions.quests)
        }
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .buttonStyle(.plain)
        .foregroundStyle(Tokens.ink)
        .padding(.vertical, Tokens.Space.xs)
    }

    private var stats: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.l) {
            stat("\(state.streakDays)", "day streak")
            stat("\(Int(state.vitality))", "vitality")
            stat("\(Int(state.spirit))", "spirit")
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Vitality \(Int(state.vitality)), Spirit \(Int(state.spirit)), \(state.stage.title), \(state.levelLabel)")
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(Typography.display(34)).foregroundStyle(Tokens.ink)
            Text(label).font(Typography.label).foregroundStyle(Tokens.brand)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            HStack(spacing: Tokens.Space.xs) {
                Button("Quiet hours", action: actions.quietHours)
                Text("·")
                Button("Open", action: actions.openApp)
                    .keyboardShortcut("o")
                Spacer()
                #if TENAZ_DEV_BUILD
                    Button("Gallery") { openWindow(id: "gallery") }
                #endif
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .buttonStyle(.plain)
            .font(Typography.label)
            .foregroundStyle(Tokens.ink)
            Text("Kill switch \(KillSwitch.hotkeyLabel)")
                .font(Typography.label)
                .foregroundStyle(Tokens.brand)
        }
    }
}
