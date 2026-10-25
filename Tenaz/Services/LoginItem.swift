import Foundation
import ServiceManagement

/// Open Tenaz at login, through `SMAppService.mainApp` (listed in System Settings › General › Login Items).
/// Off until the learner turns it on, in Settings › Data or with `--tenaz-login-item on` (scripts/install-tenaz.sh).
enum LoginItem {
    static var status: SMAppService.Status { SMAppService.mainApp.status }
    /// Registered, even if macOS still wants approval in System Settings (the toggle shows it as on).
    static var isRegistered: Bool { status == .enabled || status == .requiresApproval }

    static func set(_ on: Bool) throws {
        if on {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static var statusText: String {
        switch status {
        case .enabled: "on"
        case .requiresApproval: "needs approval in System Settings › General › Login Items"
        // macOS reports .notFound for an app that was never registered.
        case .notRegistered, .notFound: "off"
        @unknown default: "unknown"
        }
    }

    /// `--tenaz-login-item on|off|status`: prints the resulting status; exit code 0 only when it matches the request.
    static func runCommand(_ action: String) -> Int32 {
        #if TENAZ_DEV_BUILD
        // Only the installed Tenaz may open at login: a TenazDev item too would mean two gates.
        if action != "status" {
            print("login item: TenazDev has no login item; install Tenaz (scripts/install-tenaz.sh)")
            return 2
        }
        #endif
        do {
            switch action {
            case "on": if status != .enabled { try set(true) }
            case "off": if isRegistered { try set(false) }
            case "status": break
            default:
                print("login item: unknown action \(action) (use on, off or status)")
                return 2
            }
        } catch {
            print("login item: \(action) failed: \(error.localizedDescription)")
            print("login item: \(statusText)")
            return 1
        }
        print("login item: \(statusText)")
        switch action {
        case "on": return status == .enabled ? 0 : 1
        case "off": return status == .enabled ? 1 : 0
        default: return 0
        }
    }
}
