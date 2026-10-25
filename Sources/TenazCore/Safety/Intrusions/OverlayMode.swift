/// How big the word overlay is (`intrusion_log.mode`).
public enum OverlayMode: String, Codable, CaseIterable, Sendable {
    /// A paper card over most of the screen, with sound.
    case poster
    /// A small card in the bottom-right corner, no sound (light interruption).
    case sticker
}
