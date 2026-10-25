/// Call, chat and presentation apps (PLAN F14). Bundle ids read from this Mac where installed.
/// A presentation app in front is a hard signal (defer); a call or chat app in front with no other
/// signal only limits the overlay to sticker mode, so Tenaz is not silent all day because Teams is open.
public enum MeetingApps {
    public static let callApps: Set<String> = [
        "us.zoom.xos", "com.microsoft.teams2", "com.microsoft.teams", "com.apple.FaceTime", "com.tinyspeck.slackmacgap",
        "Cisco-Systems.Spark", "com.webex.meetingmanager", "com.hnc.Discord", "dev.vencord.vesktop", "net.whatsapp.WhatsApp",
    ]
    public static let chatApps: Set<String> = [
        "com.microsoft.teams2", "com.microsoft.teams", "com.tinyspeck.slackmacgap", "com.hnc.Discord",
        "dev.vencord.vesktop", "net.whatsapp.WhatsApp", "ru.keepcoder.Telegram",
    ]
    public static let presentationApps: Set<String> = ["com.apple.iWork.Keynote", "com.microsoft.Powerpoint", "us.zoom.xos"]
    /// Tenaz itself never counts as a mic holder.
    public static let ignoreMicHolders: Set<String> = ["com.chere3.tenaz", "com.chere3.tenaz.dev"]

    public enum Front: Equatable, Sendable { case presentation, callOrChat, other }

    public static func classify(frontmost bundleId: String?) -> Front {
        guard let id = bundleId else { return .other }
        if presentationApps.contains(id) { return .presentation }
        if callApps.contains(id) || chatApps.contains(id) { return .callOrChat }
        return .other
    }
}
