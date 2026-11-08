import AppKit
import CaptureCore

@MainActor
final class SelectionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(snapshot: DisplaySnapshot, onSelect: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
        super.init(contentRect: snapshot.screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        level = .screenSaver
        isOpaque = true
        backgroundColor = .black
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        acceptsMouseMovedEvents = true
        let view = SelectionView(snapshot: snapshot, onSelect: onSelect, onCancel: onCancel)
        contentView = view
        makeFirstResponder(view)
        setFrame(snapshot.screen.frame, display: true)
    }
}

@MainActor
private final class SelectionView: NSView {
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    private let snapshot: DisplaySnapshot
    private let onSelect: (CGRect) -> Void
    private let onCancel: () -> Void
    private var anchor: CGPoint?
    private var selection: CGRect = .zero
    private var tracking: NSTrackingArea?
    private let accent = NSColor(srgbRed: 0.40, green: 0.94, blue: 0.78, alpha: 1)

    init(snapshot: DisplaySnapshot, onSelect: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
        self.snapshot = snapshot; self.onSelect = onSelect; self.onCancel = onCancel
        super.init(frame: CGRect(origin: .zero, size: snapshot.screen.frame.size))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        if let tracking { addTrackingArea(tracking) }
    }

    override func mouseEntered(with event: NSEvent) { window?.makeKey() }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        AnnotationRenderer.drawImage(snapshot.image, in: bounds, context: context)
        context.saveGState()
        context.addRect(bounds)
        if !selection.isEmpty { context.addRect(selection) }
        context.setFillColor(NSColor.black.withAlphaComponent(0.48).cgColor)
        context.drawPath(using: .eoFill)
        context.restoreGState()

        if !selection.isEmpty {
            context.setStrokeColor(accent.cgColor)
            context.setLineWidth(1.5)
            context.stroke(selection)
            let sx = CGFloat(snapshot.image.width) / bounds.width
            let sy = CGFloat(snapshot.image.height) / bounds.height
            let label = "\(Int((selection.width * sx).rounded())) × \(Int((selection.height * sy).rounded())) px"
            drawPill(label, center: CGPoint(x: selection.midX,
                                           y: selection.minY > 45 ? selection.minY - 25 : selection.maxY + 25),
                     font: .monospacedSystemFont(ofSize: 12, weight: .medium))
            for point in [CGPoint(x: selection.minX, y: selection.minY),
                          CGPoint(x: selection.maxX, y: selection.minY),
                          CGPoint(x: selection.minX, y: selection.maxY),
                          CGPoint(x: selection.maxX, y: selection.maxY)] {
                accent.setFill()
                NSBezierPath(roundedRect: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6),
                             xRadius: 1.5, yRadius: 1.5).fill()
            }
        }
        if anchor == nil {
            drawPill("Drag to capture   ·   Space for this display   ·   Esc to cancel",
                     center: CGPoint(x: bounds.midX, y: bounds.maxY - 72),
                     font: .systemFont(ofSize: 13, weight: .medium))
        }
    }

    private func drawPill(_ text: String, center: CGPoint, font: NSFont) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let size = (text as NSString).size(withAttributes: attributes)
        let width = min(size.width + 28, bounds.width - 16)
        let rect = CGRect(x: min(max(center.x - width / 2, 8), bounds.maxX - width - 8),
                          y: min(max(center.y - 18, 8), bounds.maxY - 44), width: width, height: 36)
        NSColor(srgbRed: 0.08, green: 0.10, blue: 0.13, alpha: 0.96).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12).fill()
        (text as NSString).draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
                               withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        anchor = convert(event.locationInWindow, from: nil)
        selection = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let anchor else { return }
        selection = CaptureGeometry.rectangle(from: anchor, to: convert(event.locationInWindow, from: nil), within: bounds)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let anchor else { return }
        selection = CaptureGeometry.rectangle(from: anchor, to: convert(event.locationInWindow, from: nil), within: bounds)
        self.anchor = nil
        if selection.width >= 3, selection.height >= 3 { onSelect(selection) }
        else { selection = .zero; needsDisplay = true }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: onCancel()
        case 49: onSelect(bounds)
        default: break
        }
    }

    override func rightMouseDown(with event: NSEvent) { onCancel() }
}
