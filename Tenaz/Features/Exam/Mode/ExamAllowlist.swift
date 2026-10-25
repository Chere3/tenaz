import Foundation

/// During an Exam Mode section only Tenaz may be in front (PLAN F5 step 4). These can come to the
/// front without being hidden (they cannot answer questions), and call apps pause the exam when a
/// meeting signal is on instead of being hidden.
enum ExamAllowlist {
    static let system: Set<String> = [
        "com.apple.loginwindow", "com.apple.notificationcenterui", "com.apple.controlcenter",
        "com.apple.UserNotificationCenter", "com.apple.SecurityAgent", "com.apple.coreservices.uiagent",
        "com.apple.dock", "com.apple.systemuiserver", "com.apple.WindowManager",
    ]

    static let callApps: Set<String> = [
        "us.zoom.xos", "com.microsoft.teams2", "com.microsoft.teams", "com.apple.FaceTime", "com.tinyspeck.slackmacgap",
        "Cisco-Systems.Spark", "com.cisco.webexmeetingsapp", "com.hnc.Discord", "dev.vencord.vesktop", "net.whatsapp.WhatsApp",
    ]

    static func isAllowed(_ bundleId: String?) -> Bool {
        guard let id = bundleId else { return true }
        if id == Bundle.main.bundleIdentifier || id.hasPrefix("com.chere3.tenaz") || id.hasPrefix("com.chere3.focusflow") { return true }
        return system.contains(id)
    }
}
