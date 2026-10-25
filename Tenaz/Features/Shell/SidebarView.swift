import SwiftUI

/// The quiet paper sidebar: Tena header, three groups of destinations, the kill-switch reminder at the bottom.
/// Pure (selection and summary come in), so the `main` snapshot can draw it. ⌘1-⌘9 jump to the first
/// nine destinations; ↑/↓ move the selection while the sidebar has focus.
struct SidebarView: View {
    @Binding var selection: Route
    let summary: TodaySummary
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.m) {
            SidebarHeader(summary: summary)
                .padding(.top, 40)
                .padding(.horizontal, 6)
                .padding(.bottom, Tokens.Space.xs)
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                ForEach(SidebarGroup.allCases) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.rawValue)
                            .font(Typography.caption)
                            .foregroundStyle(Tokens.brand.opacity(0.75))
                            .padding(.leading, 12)
                            .padding(.bottom, 2)
                        ForEach(group.routes) { route in
                            SidebarRow(route: route, selected: selection == route, badge: badge(for: route),
                                       shortcut: shortcut(for: route)) { selection = route }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Label("Kill switch ⌃⌥⌘⎋", systemImage: "power")
                .font(Typography.caption)
                .foregroundStyle(Tokens.brand)
                .padding(.leading, 12)
                .padding(.bottom, Tokens.Space.m)
                .help("Press Control-Option-Command-Escape to stop every intrusion at once.")
        }
        .padding(.horizontal, Tokens.Space.s)
        .frame(width: 228)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            ZStack(alignment: .trailing) {
                Tokens.paper
                PaperGrain()
                // A hairline, not an outline: rest screens are paper too and need an edge.
                Rectangle().fill(Tokens.ink.opacity(0.08)).frame(width: 1)
            }
            .ignoresSafeArea()
        }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { move(-1) }
        .onKeyPress(.downArrow) { move(1) }
    }

    private func badge(for route: Route) -> Int? {
        route == .review && summary.placementTaken ? summary.todaySetCount : nil
    }

    private func shortcut(for route: Route) -> KeyEquivalent? {
        guard let index = SidebarGroup.orderedRoutes.firstIndex(of: route), index < 9 else { return nil }
        return KeyEquivalent(Character(String(index + 1)))
    }

    private func move(_ step: Int) -> KeyPress.Result {
        let routes = SidebarGroup.orderedRoutes
        guard let index = routes.firstIndex(of: selection) else { return .ignored }
        selection = routes[(index + step + routes.count) % routes.count]
        return .handled
    }
}
