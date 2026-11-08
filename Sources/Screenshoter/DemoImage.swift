import AppKit

@MainActor
enum DemoImage {
    /// An in-memory sample lets people explore the editor before granting screen access.
    static func make() -> CGImage? {
        let width = 1100, height = 700
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        defer { NSGraphicsContext.restoreGraphicsState() }

        fill(CGRect(x: 0, y: 0, width: width, height: height), color: color(0.94, 0.95, 0.93))
        fill(CGRect(x: 0, y: 0, width: width, height: 65), color: .white)
        text("◉  fieldnotes", x: 35, y: 22, size: 19, weight: .bold)
        text("Workspace     Projects     Activity", x: 350, y: 26, size: 13, color: color(0.44, 0.48, 0.46))
        text("JD", x: 1020, y: 24, size: 13, weight: .semibold)
        text("PROJECT / WEBSITE", x: 65, y: 111, size: 11, weight: .semibold, color: color(0.40, 0.48, 0.44))
        text("Good work starts with a clear idea.", x: 65, y: 145, size: 34, weight: .semibold)
        text("A shared space for the details that make a difference.", x: 65, y: 199, size: 16, color: color(0.44, 0.48, 0.46))

        let columns = [("TO DO", "Polish the landing page", "A fresh look for our next chapter.", "Design"),
                       ("IN PROGRESS", "Make the details count", "Small improvements, big impact.", "Product"),
                       ("READY TO SHARE", "Tell a better story", "Bring the whole team along.", "Content")]
        for (index, column) in columns.enumerated() {
            let x = CGFloat(65 + index * 330)
            text(column.0, x: x, y: 270, size: 11, weight: .semibold, color: color(0.41, 0.46, 0.43))
            fill(CGRect(x: x, y: 302, width: 310, height: 270), color: .white, radius: 14)
            fill(CGRect(x: x + 18, y: 320, width: 274, height: 108),
                 color: [color(0.83, 0.91, 0.82), color(0.87, 0.86, 0.96), color(0.97, 0.87, 0.73)][index], radius: 8)
            let symbols = ["leaf", "sparkles", "paperplane"]
            if let symbol = NSImage(systemSymbolName: symbols[index], accessibilityDescription: nil) {
                symbol.draw(in: CGRect(x: x + 136, y: 354, width: 36, height: 36),
                            from: .zero, operation: .sourceOver, fraction: 0.6, respectFlipped: true, hints: nil)
            }
            text(column.1, x: x + 18, y: 449, size: 17, weight: .semibold)
            text(column.2, x: x + 18, y: 480, size: 12, color: color(0.48, 0.50, 0.49))
            fill(CGRect(x: x + 18, y: 520, width: 76, height: 26), color: color(0.94, 0.95, 0.93), radius: 13)
            text(column.3, x: x + 31, y: 526, size: 10, weight: .medium)
        }
        text("An example canvas. Try an arrow, a highlight, or a quick note.",
             x: 65, y: 637, size: 13, color: color(0.48, 0.52, 0.49))
        return context.makeImage()
    }

    private static func color(_ r: Double, _ g: Double, _ b: Double) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }
    private static func fill(_ rect: CGRect, color: NSColor, radius: CGFloat = 0) {
        color.setFill(); NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    }
    private static func text(_ value: String, x: CGFloat, y: CGFloat, size: CGFloat,
                             weight: NSFont.Weight = .regular, color: NSColor = NSColor(srgbRed: 0.12, green: 0.18, blue: 0.15, alpha: 1)) {
        (value as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
    }
}
