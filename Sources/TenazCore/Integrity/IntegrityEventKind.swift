import Foundation

public enum IntegrityEventKind: String, Codable, Sendable {
    case app, paste, clipboard, burst, focusLoss, tivra
}
