/// The popover's buttons. Each feature plugs its entry point in here; the defaults do nothing.
struct PopoverActions {
    var review: () -> Void = {}
    var write: () -> Void = {}
    var exam: () -> Void = {}
    var quests: () -> Void = {}
    /// Safety hatch: pause every intrusion for one hour (always works, never priced).
    var pauseIntrusions: () -> Void = {}
    var quietHours: () -> Void = {}
    var openApp: () -> Void = {}
}
