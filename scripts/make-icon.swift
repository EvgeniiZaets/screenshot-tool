import AppKit

// Vector-drawn app icon, packaged directly as ICNS without external tools or assets.
let output = CommandLine.arguments[1]
var payload = Data()
for (type, size) in [("ic07", 128), ("ic08", 256), ("ic09", 512), ("ic10", 1024)] {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    NSColor(srgbRed: 0.07, green: 0.10, blue: 0.12, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 210, yRadius: 210).fill()
    NSColor(srgbRed: 0.43, green: 0.94, blue: 0.77, alpha: 1).setStroke()
    for (x, y, dx, dy) in [(285.0, 285.0, 1.0, 1.0), (739, 285, -1, 1), (285, 739, 1, -1), (739, 739, -1, -1)] {
        let path = NSBezierPath(); path.lineWidth = 46; path.lineCapStyle = .round; path.lineJoinStyle = .round
        path.move(to: NSPoint(x: x, y: y + dy * 116)); path.line(to: NSPoint(x: x, y: y)); path.line(to: NSPoint(x: x + dx * 116, y: y)); path.stroke()
    }
    let arrow = NSBezierPath(); arrow.lineWidth = 42; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round
    arrow.move(to: NSPoint(x: 419, y: 419)); arrow.line(to: NSPoint(x: 610, y: 610)); arrow.stroke()
    arrow.move(to: NSPoint(x: 482, y: 610)); arrow.line(to: NSPoint(x: 610, y: 610)); arrow.line(to: NSPoint(x: 610, y: 482)); arrow.stroke()
    image.unlockFocus()
    let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let png = bitmap.representation(using: .png, properties: [:])!
    payload.append(type.data(using: .ascii)!)
    var length = UInt32(png.count + 8).bigEndian
    withUnsafeBytes(of: &length) { payload.append(contentsOf: $0) }
    payload.append(png)
}
var result = Data("icns".utf8)
var length = UInt32(payload.count + 8).bigEndian
withUnsafeBytes(of: &length) { result.append(contentsOf: $0) }
result.append(payload)
try result.write(to: URL(fileURLWithPath: output), options: .atomic)
