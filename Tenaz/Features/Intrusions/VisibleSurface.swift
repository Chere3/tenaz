import Foundation
import TenazCore

/// The one intrusive surface on screen, if any (never two at once).
enum VisibleSurface {
    case overlay(OverlayModel, trigger: IntrusionTrigger, shownAt: Date)
    case gate(GateModel, trigger: IntrusionTrigger, shownAt: Date)

    var surface: IntrusionSurface {
        if case .overlay = self { return .overlay }
        return .gate
    }

    var trigger: IntrusionTrigger {
        switch self {
        case let .overlay(_, t, _), let .gate(_, t, _): t
        }
    }

    var shownAt: Date {
        switch self {
        case let .overlay(_, _, d), let .gate(_, _, d): d
        }
    }

    var mode: OverlayMode? {
        if case let .overlay(m, _, _) = self { return m.mode }
        return nil
    }
}
