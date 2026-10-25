import AppKit
import Carbon.HIToolbox
import TenazCore

/// Every way to switch Tenaz's intrusions off without the UI (PLAN §5.2). All always work:
/// - global hotkey Control-Option-Command-Escape (Carbon hotkey, no permission needed): closes every
///   surface and keeps intrusions off until the next 04:00 day boundary;
/// - `defaults write com.chere3.tenaz.dev killSwitch -bool true`: off until set back to false;
/// - the file `~/Library/Application Support/TenazDev/DISABLE_OVERLAYS`: off while it exists
///   (watched with a DispatchSource on the folder, the one sanctioned DispatchSource use);
/// - quitting or force-quitting the app (the panels belong to the process; nothing relaunches it).
/// `onEngage` fires on the edge (off → on, or every hotkey press), never repeatedly.
@MainActor
final class KillSwitch {
    static let hotkeyLabel = "⌃⌥⌘ Esc"
    /// Built from this build's bundle id (dev `com.chere3.tenaz.dev`, release `com.chere3.tenaz`).
    static var defaultsCommand: String {
        "defaults write \(Bundle.main.bundleIdentifier ?? "com.chere3.tenaz.dev") killSwitch -bool true"
    }

    /// `touch` for this build's DISABLE_OVERLAYS file, with the path shell-escaped.
    static var fileCommand: String {
        "touch '" + disableFile.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static var disableFile: URL { Paths.forApp(bundleIdentifier: Bundle.main.bundleIdentifier).disableOverlaysFlag }

    /// What the three switches say right now.
    static func read(_ defaults: UserDefaults = .standard) -> KillSwitchState {
        KillSwitchState(
            hotkeyUntil: IntrusionSettings.date(defaults, IntrusionSettings.Keys.killSwitchUntil),
            defaultsKey: defaults.bool(forKey: IntrusionSettings.Keys.killSwitch),
            fileFlag: FileManager.default.fileExists(atPath: disableFile.path))
    }

    private(set) var state = KillSwitchState()
    var onEngage: (String) -> Void = { _ in }
    var onChange: (KillSwitchState) -> Void = { _ in }

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var pollTimer: Timer?
    private var folderSource: (any DispatchSourceFileSystemObject)?

    func start() {
        state = Self.read()
        registerHotKey()
        watchFolder()
        // The defaults key can be written by another process; a 1 s read catches it within a tick.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func stop() {
        pollTimer?.invalidate()
        folderSource?.cancel()
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    func refresh() {
        let new = Self.read()
        let old = state
        let now = Date()
        let wasEngaged = state.isEngaged(at: now)
        state = new
        if new != old { onChange(new) }
        if !wasEngaged, let reason = new.reason(at: now) { onEngage(reason) }
    }

    /// The hotkey: off until the next 04:00, close everything now.
    func fireHotkey() {
        let until = KillSwitchState.hotkeyUntil(after: Date())
        UserDefaults.standard.set(until.timeIntervalSince1970, forKey: IntrusionSettings.Keys.killSwitchUntil)
        state = Self.read()
        onChange(state)
        onEngage("kill switch: hotkey (until 04:00)")
    }

    /// Settings → Safety "Turn intrusions back on": clears the hotkey and the defaults key.
    /// The file flag is never removed by the app; the learner delete it themselves.
    func reset() {
        UserDefaults.standard.removeObject(forKey: IntrusionSettings.Keys.killSwitchUntil)
        UserDefaults.standard.set(false, forKey: IntrusionSettings.Keys.killSwitch)
        refresh()
    }

    private func watchFolder() {
        let folder = Self.disableFile.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.refresh() }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        folderSource = source
    }

    private func registerHotKey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let me = Unmanaged<KillSwitch>.fromOpaque(userData).takeUnretainedValue()
            MainActor.assumeIsolated { me.fireHotkey() }
            return noErr
        }, 1, &spec, context, &handlerRef)
        let id = EventHotKeyID(signature: OSType(0x544E_5A4B), id: 1) // "TNZK"
        RegisterEventHotKey(UInt32(kVK_Escape), UInt32(controlKey | optionKey | cmdKey), id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
