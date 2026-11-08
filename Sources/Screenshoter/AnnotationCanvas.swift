import AppKit
import SwiftUI
import CaptureCore

struct AnnotationCanvas: NSViewRepresentable {
    @ObservedObject var document: CaptureDocument
    let zoom: CGFloat

    func makeNSView(context: Context) -> CanvasView { CanvasView(document: document, zoom: zoom) }
    func updateNSView(_ view: CanvasView, context: Context) {
        view.zoom = zoom
        view.needsDisplay = true
    }
}

@MainActor
final class CanvasView: NSView, NSTextFieldDelegate {
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    private let document: CaptureDocument
    var zoom: CGFloat
    private var draft: Annotation?
    private var textField: NSTextField?
    private var textOrigin: CGPoint?

    init(document: CaptureDocument, zoom: CGFloat) {
        self.document = document; self.zoom = zoom
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: document.tool == .text ? .iBeam : .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.scaleBy(x: zoom, y: zoom)
        context.clip(to: CGRect(origin: .zero, size: document.logicalSize))
        AnnotationRenderer.drawImage(document.image, in: CGRect(origin: .zero, size: document.logicalSize), context: context)
        document.annotations.forEach { AnnotationRenderer.draw($0, context: context) }
        if let draft { AnnotationRenderer.draw(draft, context: context) }
        context.restoreGState()
    }

    private func position(_ event: NSEvent) -> CGPoint {
        let local = convert(event.locationInWindow, from: nil)
        return CaptureGeometry.clamped(CGPoint(x: local.x / zoom, y: local.y / zoom),
                                       to: CGRect(origin: .zero, size: document.logicalSize))
    }

    override func mouseDown(with event: NSEvent) {
        commitText()
        window?.makeFirstResponder(self)
        let point = position(event)
        if document.tool == .text {
            beginText(at: point)
        } else {
            draft = Annotation(tool: document.tool, points: [point], color: document.color,
                               lineWidth: document.lineWidth, fontSize: document.fontSize)
            needsDisplay = true
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard var annotation = draft, let start = annotation.points.first else { return }
        var end = position(event)
        if event.modifierFlags.contains(.shift), annotation.tool != .pen {
            let dx = end.x - start.x, dy = end.y - start.y
            if [.rectangle, .ellipse, .highlight, .redact].contains(annotation.tool) {
                let side = max(abs(dx), abs(dy))
                end = CGPoint(x: start.x + (dx < 0 ? -side : side), y: start.y + (dy < 0 ? -side : side))
            } else {
                let angle = (atan2(dy, dx) / (.pi / 4)).rounded() * (.pi / 4)
                let length = hypot(dx, dy)
                end = CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
            }
            end = CaptureGeometry.clamped(end, to: CGRect(origin: .zero, size: document.logicalSize))
        }
        if annotation.tool == .pen { annotation.points.append(end) }
        else { annotation.points = [start, end] }
        draft = annotation
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let draft else { return }
        if draft.tool == .pen || draft.bounds.width > 1 || draft.bounds.height > 1 {
            document.append(draft)
        }
        self.draft = nil
        needsDisplay = true
    }

    private func beginText(at point: CGPoint) {
        let field = NSTextField(frame: CGRect(x: point.x * zoom, y: point.y * zoom,
                                             width: max(40, min(320, bounds.width - point.x * zoom)),
                                             height: max(28, document.fontSize * zoom + 10)))
        field.placeholderString = "Type, then press Return"
        field.font = .systemFont(ofSize: document.fontSize * zoom, weight: .semibold)
        field.textColor = document.color.nsColor
        field.backgroundColor = NSColor.black.withAlphaComponent(0.8)
        field.isBordered = true
        field.focusRingType = .none
        field.delegate = self
        textField = field; textOrigin = point
        addSubview(field)
        window?.makeFirstResponder(field)
    }

    private func commitText() {
        guard let field = textField, let origin = textOrigin else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        textField = nil; textOrigin = nil
        field.removeFromSuperview()
        if !text.isEmpty {
            document.append(Annotation(tool: .text, points: [origin], color: document.color,
                                       text: text, fontSize: document.fontSize))
        }
        needsDisplay = true
    }

    func controlTextDidEndEditing(_ notification: Notification) { commitText() }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            commitText(); window?.makeFirstResponder(self); return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            textField?.stringValue = ""
            commitText(); window?.makeFirstResponder(self); return true
        }
        return false
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { draft = nil; needsDisplay = true; return }
        if event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
           let character = event.charactersIgnoringModifiers?.lowercased(),
           let tool = AnnotationTool.allCases.first(where: { $0.shortcut == character }) {
            document.tool = tool
            window?.invalidateCursorRects(for: self)
            return
        }
        super.keyDown(with: event)
    }
}
