import Foundation

/// The three kill switches that do not need the UI (PLAN §5.2):
/// 1. hotkey Control-Option-Command-Escape: everything off until the next 04:00 day boundary;
/// 2. `defaults write com.chere3.tenaz(.dev) killSwitch -bool true`: off until set back to false;
/// 3. the file `<Application Support>/<Tenaz|TenazDev>/DISABLE_OVERLAYS`: off while it exists.
/// Any one of them engaged closes every surface and blocks every new one.
public struct KillSwitchState: Equatable, Sendable {
    public var hotkeyUntil: Date?
    public var defaultsKey: Bool
    public var fileFlag: Bool

    public init(hotkeyUntil: Date? = nil, defaultsKey: Bool = false, fileFlag: Bool = false) {
        self.hotkeyUntil = hotkeyUntil
        self.defaultsKey = defaultsKey
        self.fileFlag = fileFlag
    }

    public func isEngaged(at now: Date) -> Bool {
        defaultsKey || fileFlag || (hotkeyUntil.map { now < $0 } ?? false)
    }

    /// Which switch is on, for logs and the Safety page.
    public func reason(at now: Date) -> String? {
        if fileFlag { return "kill switch: DISABLE_OVERLAYS file" }
        if defaultsKey { return "kill switch: defaults key" }
        if let until = hotkeyUntil, now < until { return "kill switch: hotkey (until 04:00)" }
        return nil
    }

    /// The hotkey's "until": the next 04:00 learning-day boundary after `now`.
    public static func hotkeyUntil(after now: Date, calendar: Calendar = .current) -> Date {
        let start = DayBoundary.start(ofDayContaining: now, calendar: calendar)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? now.addingTimeInterval(86400)
    }
}
