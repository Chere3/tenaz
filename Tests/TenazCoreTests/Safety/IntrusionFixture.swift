import Foundation
@testable import TenazCore

/// A weekday 10:00 in Mexico City, a calendar fixed to that zone, and settings with everything on.
enum IntrusionFixture {
    static var calendar: Calendar { GamificationFixture.calendar }
    static func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }
    static let now = date(2, 10)

    static var armed: IntrusionSettings {
        var s = IntrusionSettings()
        s.overlaysEnabled = true
        s.gateEnabled = true
        s.detectionOnlyAck = true
        s.overlayMode = .poster
        return s
    }

    static func request(_ surface: IntrusionSurface = .overlay, at now: Date = now, settings: IntrusionSettings = armed,
                        _ edit: (inout IntrusionRequest) -> Void = { _ in }) -> IntrusionRequest {
        var r = IntrusionRequest(surface: surface, trigger: surface == .gate ? .unlock : .appSwitch, now: now, settings: settings)
        edit(&r)
        return r
    }

    static func decide(_ r: IntrusionRequest) -> IntrusionVerdict { IntrusionDecider.decide(r, calendar: calendar) }
}
