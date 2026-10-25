import AppKit
import TenazCore

extension SelfTest {
    /// `--tenaz-selftest intrusions`: everything intrusive is off, the pipeline denies, the panels use
    /// a safe window level, no banned presentation option is set, the gate field is paste-proof with
    /// every system writing aid off, and the local gate checks work. Exit 0 only if all hold.
    static func intrusions(environment env: AppEnvironment) -> Int32 {
        let d = UserDefaults.standard
        let coordinator = AppDelegate.intrusions
        let overlayVerdict = IntrusionDecider.decide(coordinator.makeRequest(.overlay, trigger: .appSwitch))
        let gateVerdict = IntrusionDecider.decide(coordinator.makeRequest(.gate, trigger: .unlock))

        let panel = OverlayPanel(frame: NSRect(x: 0, y: 0, width: 10, height: 10), interactive: true)
        let banned: NSApplication.PresentationOptions = [.disableForceQuit, .disableProcessSwitching, .disableSessionTermination, .disableHideApplication]

        let field = ParagraphTextView(frame: .zero)
        field.configure()
        let board = NSPasteboard(name: NSPasteboard.Name("com.chere3.tenaz.selftest.gate"))
        board.clearContents()
        board.setString("pasted paragraph", forType: .string)
        field.paste(nil)
        field.pasteAsPlainText(nil)
        let pasteBlocked = field.string.isEmpty && !field.readSelection(from: board, type: .string)
        board.releaseGlobally()

        let good = GateChecker.check(IntrusionSamples.gateParagraph, chunk: "follow up on")
        let spanish = GateChecker.check("Esta mañana tengo que dar seguimiento al error que rompió la página ayer y luego revisar dos solicitudes con el equipo.", chunk: nil)
        let items = IntrusionSamples.overlayItems(env.content)

        let checks: [(String, Bool)] = [
            ("overlaysOffByDefault", !d.bool(forKey: IntrusionSettings.Keys.overlaysEnabled)),
            ("gateOffByDefault", !d.bool(forKey: IntrusionSettings.Keys.gateEnabled)),
            ("overlayDenied", overlayVerdict.decision == "deny"),
            ("gateDenied", gateVerdict.decision == "deny"),
            ("panelLevelScreenSaver", panel.level == .screenSaver && panel.level.rawValue < Int(CGShieldingWindowLevel())),
            ("panelOnEverySpace", panel.collectionBehavior.contains(.canJoinAllSpaces) && panel.collectionBehavior.contains(.fullScreenAuxiliary)),
            ("noBannedPresentationOptions", NSApp.presentationOptions.isDisjoint(with: banned)),
            ("gateFieldWritingToolsOff", field.writingToolsBehavior == .none && field.inlinePredictionType == .no),
            ("gateFieldCorrectionOff", !field.isAutomaticSpellingCorrectionEnabled && !field.isContinuousSpellCheckingEnabled && !field.isGrammarCheckingEnabled),
            ("gateFieldPasteBlocked", pasteBlocked),
            ("gateFieldServicesOff", field.validRequestor(forSendType: .string, returnType: .string) == nil),
            ("gateChecksAcceptGood", good.passes),
            ("gateChecksRejectSpanish", !spanish.englishOK),
            ("overlayBatchAutoScorable", !items.isEmpty && OverlayBatch.pick(items).count == items.count),
            ("killSwitchReadable", KillSwitch.read(d).fileFlag == FileManager.default.fileExists(atPath: KillSwitch.disableFile.path)),
        ]
        print("overlay: \(overlayVerdict.decision) (\(overlayVerdict.reason ?? "")); gate: \(gateVerdict.decision) (\(gateVerdict.reason ?? ""))")
        for (name, ok) in checks { print("\(ok ? "ok  " : "FAIL") \(name)") }
        return checks.allSatisfy(\.1) ? 0 : 1
    }
}
