import AppKit
import SwiftUI

/// Where Tena's ink actually sits inside her square canvas, as unit fractions (0...1). Each stage and
/// mood draws a different silhouette (a round hatchling, a wide adult, a "?" above a curious face), so
/// Today measures it once by rendering her small and scanning the alpha, then crops her by the window
/// edges from the real silhouette instead of guessing. The soft floor shadow is ignored.
@MainActor
enum TenaInk {
    private static var cache: [String: CGRect] = [:]
    private static let fallback = CGRect(x: 0.14, y: 0.30, width: 0.72, height: 0.55)

    static func bounds(stage: TenaStage, mood: TenaMood) -> CGRect {
        let key = "\(stage.rawValue)-\(mood.rawValue)"
        if let known = cache[key] { return known }
        let measured = measure(stage: stage, mood: mood) ?? fallback
        cache[key] = measured
        return measured
    }

    /// The unit y (0...1 of her frame) where a hero's bottom window edge crops her at `size`: through the
    /// hips (86 % of her ink height, and at least 0.35 head heights below her chin), pushed down until
    /// `margin` points clear her lowest hand (Proud's hands on her hips, Happy's open paws, Sad's hanging
    /// arms). A hand that hangs to her feet shows her whole, `margin` above the edge, so no hand ever sits
    /// on the edge. Asleep lies on her belly with her chin on her folded paws at the bottom of her ink, so
    /// any crop would cut her chin: she lies whole, the same `margin` above the edge.
    static func bottomCut(stage: TenaStage, mood: TenaMood, size: CGFloat, margin: CGFloat) -> CGFloat {
        let ink = bounds(stage: stage, mood: mood)
        if mood == .asleep { return ink.maxY + margin / size }
        let rig = TenaRig(mood: mood, stage: stage, time: 0, size: size)
        // Through the hips, and at least 0.35 head heights below her chin (the big-headed hatchling).
        let chin = rig.headFrame.map { $0.maxY + 0.35 * $0.height } ?? 0
        let hips = min(ink.maxY, max(ink.minY + ink.height * 0.86, chin))
        guard let hands = rig.armFrame?.maxY else { return hips }
        return max(hips, hands + margin / size)
    }

    private static func measure(stage: TenaStage, mood: TenaMood) -> CGRect? {
        let side = 160
        // The bare rig in its resting pose: no TimelineView, state or appear hooks to run off-screen.
        let rig = TenaRig(mood: mood, stage: stage, time: 0, size: CGFloat(side))
        let renderer = ImageRenderer(content: Canvas { context, _ in rig.draw(in: &context) }
            .frame(width: CGFloat(side), height: CGFloat(side)))
        renderer.scale = 1
        guard let image = renderer.cgImage else { return nil }
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0 ..< height {
            for x in 0 ..< width where pixels[(y * width + x) * 4 + 3] > 140 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        // The bitmap's first row is the top of the image.
        return CGRect(x: CGFloat(minX) / CGFloat(width), y: CGFloat(minY) / CGFloat(height),
                      width: CGFloat(maxX - minX + 1) / CGFloat(width), height: CGFloat(maxY - minY + 1) / CGFloat(height))
    }
}
