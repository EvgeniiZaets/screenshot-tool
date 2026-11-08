import AppKit

@MainActor
public enum AnnotationRenderer {
    /// Render once at the capture's original pixel dimensions; editor zoom never affects export.
    public static func render(image: CGImage, logicalSize: CGSize, annotations: [Annotation]) -> CGImage? {
        guard logicalSize.width > 0, logicalSize.height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: image.width, height: image.height,
                                      bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.scaleBy(x: CGFloat(image.width) / logicalSize.width,
                        y: CGFloat(image.height) / logicalSize.height)
        context.translateBy(x: 0, y: logicalSize.height)
        context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        defer { NSGraphicsContext.restoreGraphicsState() }
        drawImage(image, in: CGRect(origin: .zero, size: logicalSize), context: context)
        annotations.forEach { draw($0, context: context) }
        return context.makeImage()
    }

    /// The canvas and annotation coordinates are top-left based.
    public static func drawImage(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    public static func draw(_ annotation: Annotation, context: CGContext) {
        guard let start = annotation.points.first else { return }
        context.saveGState()
        defer { context.restoreGState() }
        let color = annotation.color.nsColor.cgColor
        context.setStrokeColor(color)
        context.setFillColor(color)
        context.setLineWidth(annotation.lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        let end = annotation.points.last ?? start

        switch annotation.tool {
        case .pen:
            if annotation.points.count < 2 {
                let radius = annotation.lineWidth / 2
                context.fillEllipse(in: CGRect(x: start.x - radius, y: start.y - radius,
                                              width: radius * 2, height: radius * 2))
            } else {
                context.addLines(between: annotation.points)
                context.strokePath()
            }
        case .line:
            context.move(to: start); context.addLine(to: end); context.strokePath()
        case .arrow:
            let distance = hypot(end.x - start.x, end.y - start.y)
            guard distance > 1 else { return }
            let angle = atan2(end.y - start.y, end.x - start.x)
            let length = min(max(12, annotation.lineWidth * 4), distance * 0.65)
            context.move(to: start); context.addLine(to: end); context.strokePath()
            context.move(to: CGPoint(x: end.x - length * cos(angle - .pi / 6),
                                    y: end.y - length * sin(angle - .pi / 6)))
            context.addLine(to: end)
            context.addLine(to: CGPoint(x: end.x - length * cos(angle + .pi / 6),
                                       y: end.y - length * sin(angle + .pi / 6)))
            context.strokePath()
        case .rectangle:
            context.stroke(annotation.bounds)
        case .ellipse:
            context.strokeEllipse(in: annotation.bounds)
        case .highlight:
            context.setFillColor(annotation.color.nsColor.withAlphaComponent(0.30).cgColor)
            context.fill(annotation.bounds)
        case .redact:
            context.setFillColor(NSColor.black.cgColor)
            // Integral, opaque coverage prevents edge pixels leaking through the export.
            context.setShouldAntialias(false)
            context.fill(annotation.bounds.integral)
        case .text:
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            (annotation.text as NSString).draw(at: start, withAttributes: [
                .font: NSFont.systemFont(ofSize: annotation.fontSize, weight: .semibold),
                .foregroundColor: annotation.color.nsColor,
                .paragraphStyle: paragraph,
            ])
        }
    }
}
