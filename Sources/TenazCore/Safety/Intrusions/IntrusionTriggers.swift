/// Which boundaries may start a word overlay (F1). All on; the overlay itself ships off.
public struct IntrusionTriggers: Codable, Equatable, Sendable {
    public var unlock = true
    public var idleReturn = true
    public var appSwitch = true

    public init(unlock: Bool = true, idleReturn: Bool = true, appSwitch: Bool = true) {
        self.unlock = unlock
        self.idleReturn = idleReturn
        self.appSwitch = appSwitch
    }

    public func allows(_ trigger: IntrusionTrigger) -> Bool {
        switch trigger {
        case .unlock: unlock
        case .idleReturn: idleReturn
        case .appSwitch: appSwitch
        case .manual, .smoke: true
        }
    }
}
