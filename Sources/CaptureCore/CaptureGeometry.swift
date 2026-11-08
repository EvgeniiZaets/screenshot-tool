import Foundation

public enum CaptureGeometry {
    public static func rectangle(from start: CGPoint, to end: CGPoint, within bounds: CGRect) -> CGRect {
        let a = clamped(start, to: bounds)
        let b = clamped(end, to: bounds)
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                      width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    public static func clamped(_ point: CGPoint, to bounds: CGRect) -> CGPoint {
        CGPoint(x: min(max(point.x, bounds.minX), bounds.maxX),
                y: min(max(point.y, bounds.minY), bounds.maxY))
    }

    /// Both rectangles use top-left coordinates. Round outward to retain every selected pixel.
    public static func pixelRect(for selection: CGRect, logicalSize: CGSize, pixelSize: CGSize) -> CGRect? {
        guard logicalSize.width > 0, logicalSize.height > 0,
              pixelSize.width > 0, pixelSize.height > 0,
              !selection.isNull, !selection.isInfinite else { return nil }
        let clipped = selection.standardized.intersection(CGRect(origin: .zero, size: logicalSize))
        guard !clipped.isNull, clipped.width > 0, clipped.height > 0 else { return nil }
        let sx = pixelSize.width / logicalSize.width
        let sy = pixelSize.height / logicalSize.height
        let pixels = CGRect(x: clipped.minX * sx, y: clipped.minY * sy,
                            width: clipped.width * sx, height: clipped.height * sy).integral
        return pixels.intersection(CGRect(origin: .zero, size: pixelSize))
    }
}
