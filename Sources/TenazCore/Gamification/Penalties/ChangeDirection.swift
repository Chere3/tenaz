/// A Contract change either tightens (on, stronger) or loosens (off, weaker) the commitment.
/// The delay is asymmetric: tightening waits for the next 04:00 boundary, loosening 24 h (PLAN F10).
public enum ChangeDirection: String, Codable, Sendable {
    case tighten, loosen
}
