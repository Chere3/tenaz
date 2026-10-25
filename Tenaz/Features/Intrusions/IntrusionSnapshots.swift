import SwiftUI
import TenazCore

/// The registered screens of the intrusions area, rendered on a 1440 × 900 stand-in desktop at the
/// frames the real panels use.
enum IntrusionSnapshots {
    static let screen = CGSize(width: 1440, height: 900)

    /// The panel frame for a layout on a 1440 × 900 screen with a 25 pt menu bar, in SwiftUI
    /// top-left coordinates.
    static func frame(_ layout: OverlayLayout) -> CGRect {
        let visible = CGRect(x: 0, y: 0, width: screen.width, height: screen.height - 25)
        let top = visible.maxY - OverlayLayout.notificationBand.height - 8
        switch layout {
        case .poster:
            let w = min(1180, visible.width * 0.74)
            let h = min(760, top * 0.94)
            return CGRect(x: (screen.width - w) / 2, y: 25 + OverlayLayout.notificationBand.height + 8 + (top - h) / 2, width: w, height: h)
        case .sticker:
            let s = OverlayLayout.stickerSize
            return CGRect(x: screen.width - s.width - 12, y: screen.height - s.height - 12, width: s.width, height: s.height)
        case .toast:
            let s = OverlayLayout.toastSize
            return CGRect(x: screen.width - s.width - 12, y: screen.height - s.height - 12, width: s.width, height: s.height)
        case .fullScreen:
            return CGRect(origin: .zero, size: screen)
        }
    }

    static func overlay(_ env: AppEnvironment, mode: OverlayMode, configure: (OverlayModel) -> Void) -> some View {
        let model = OverlayModel(items: IntrusionSamples.overlayItems(env.content), mode: mode, reviewStore: nil, gamification: nil,
                                 skipCost: 0, snoozesLeft: 3)
        configure(model)
        let f = frame(mode == .poster ? .poster : .sticker)
        let deadline = Date().addingTimeInterval(72)
        return ZStack(alignment: .topLeading) {
            DesktopStandIn()
            Group {
                if mode == .poster {
                    WordOverlayView(model: model, deadline: deadline)
                } else {
                    WordStickerView(model: model, deadline: deadline)
                }
            }
            .frame(width: f.width, height: f.height)
            .offset(x: f.minX, y: f.minY)
        }
    }

    static func gate(_ env: AppEnvironment, text: String, prompt: GatePrompt? = nil) -> some View {
        let model = GateModel(prompt: prompt ?? IntrusionSamples.gatePrompt(env.content), price: GateSkipPrice(responseCostOn: false, mercyLeft: 3),
                              strict: false, store: nil, gamification: nil, shownAt: Date().addingTimeInterval(-74))
        model.preview(text: text)
        return ZStack {
            DesktopStandIn(showBand: false)
            GateView(model: model)
        }
    }

    static func settings(_ env: AppEnvironment, _ section: SettingsSection) -> some View {
        SettingsRoot(initial: section)
            .environment(env)
            .environment(AppDelegate.intrusions)
    }

    static func contract(_ env: AppEnvironment) -> some View {
        let model = ContractModel(engine: env.gamification)
        model.load()
        return ContractPage(model: model)
            .padding(Tokens.Space.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .paperBackground()
            .environment(env)
    }

    static func entry(_ name: String, _ env: AppEnvironment) -> SnapshotEntry {
        screens(env)[name] ?? SnapshotEntry(view: AnyView(Text("missing \(name)")), size: screen)
    }

    private static func screens(_ env: AppEnvironment) -> [String: SnapshotEntry] {
        [
            "overlay-poster": SnapshotEntry(view: AnyView(overlay(env, mode: .poster) { _ in }), size: screen),
            "overlay-sticker": SnapshotEntry(view: AnyView(overlay(env, mode: .sticker) { $0.preview(.asking, text: "follow up", index: 2) }), size: screen),
            "overlay-wrong": SnapshotEntry(view: AnyView(overlay(env, mode: .poster) {
                $0.preview(.wrong(expected: "leverage", given: "levarage"), index: 1)
            }), size: screen),
            "settings-intrusions": SnapshotEntry(view: AnyView(settings(env, .intrusions)), size: CGSize(width: 1000, height: 1320)),
            "settings-safety": SnapshotEntry(view: AnyView(settings(env, .safety)), size: CGSize(width: 1000, height: 1640)),
            "contract": SnapshotEntry(view: AnyView(contract(env)), size: CGSize(width: 1000, height: 2450)),
            "gate-empty": SnapshotEntry(view: AnyView(gate(env, text: "")), size: screen),
            "gate-ready": SnapshotEntry(view: AnyView(gate(env, text: IntrusionSamples.gateParagraph)), size: screen),
            "gate-story": SnapshotEntry(view: AnyView(gate(env, text: "", prompt: IntrusionSamples.gateStoryPrompt)), size: screen),
        ]
    }
}
