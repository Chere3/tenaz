/// The two intrusive surfaces Tenaz owns (`intrusion_log.surface`).
public enum IntrusionSurface: String, Codable, CaseIterable, Sendable {
    /// The word overlay (F1), shown as a poster or a sticker.
    case overlay
    /// The unlock gate (F2): a full-screen notebook page after unlock or wake.
    case gate
}
