import SwiftUI

/// One built frame of Tena as plain geometry in the 200-unit grid, before fitting and colour.
/// Parts sit in groups: every group draws all its contours first (at twice the ink weight) and then
/// all its fills, so the outline runs only around the group's union (one silhouette, no seams).
struct TenaFigure {
    enum Fill { case body, belly, gill, gillDeep, highlight, amber, mark, shade, ink, window }

    /// Drawn clipped to the part it belongs to (belly patch, crown, root band, amber tips...).
    struct Decor {
        var path: Path
        var fill: Fill
        /// Stroke at the tier-2 weight instead of filling (fin ribs, bandage creases).
        var line = false
    }

    struct Part {
        var path: Path
        var fill: Fill
        var decor: [Decor] = []
        /// No contour (flat inner shapes inside a group, like the egg window).
        var contour = true
    }

    struct Group {
        var parts: [Part] = []
        /// Contour ink inside `eraseClip` ∩ `erase` is removed (arm roots inside the body).
        var erase: Path?
        var eraseClip: Path?
        /// Clip the whole group (the embryo inside the egg window).
        var clip: Path?
    }

    /// Face anchors in head-local units; the renderer draws them through `headTransform`.
    struct Face {
        var head: HeadShape
        var eyes: [CGPoint]
        var eyeRadius: CGSize
        var mouthCenter: CGPoint
        var mouthWidth: CGFloat
        var mouthHeightLimit: CGFloat
        var nostrils: [CGPoint]
    }

    var groups: [Group] = []
    /// Groups drawn after the face (arms, props).
    var front: [Group] = []
    var face: Face?
    var headTransform: CGAffineTransform = .identity
    /// Strokes drawn last in ink (the "z").
    var inkLines: [Path] = []
    /// The sign card's text box (model units) and its rotation, when Nagging holds one.
    var signBox: (center: CGPoint, size: CGSize, angle: Double)?

    var bounds: CGRect {
        var rect = CGRect.null
        for group in groups + front {
            for part in group.parts { rect = rect.union(part.path.boundingRect) }
        }
        for line in inkLines { rect = rect.union(line.boundingRect.insetBy(dx: -2, dy: -2)) }
        return rect
    }
}
