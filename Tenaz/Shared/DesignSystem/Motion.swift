import SwiftUI
import TenazCore

/// Maps the TenazCore motion tokens to SwiftUI animations. Pass the view's
/// `accessibilityReduceMotion`; every token then becomes the same short crossfade.
enum Motion {
    static func animation(_ token: MotionToken, reduceMotion: Bool) -> Animation {
        switch token.curve(reduceMotion: reduceMotion) {
        case let .spring(duration, bounce): .spring(duration: duration, bounce: bounce)
        case let .loop(duration): .easeInOut(duration: duration).repeatForever(autoreverses: true)
        case let .crossfade(duration): .easeOut(duration: duration)
        }
    }
}
