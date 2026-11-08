import AppKit
import Testing
@testable import CaptureCore

private func image(width: Int = 100, height: Int = 100, pixels: [UInt8]? = nil) -> CGImage {
    let data = Data(pixels ?? Array(repeating: UInt8(255), count: width * height * 4))
    return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                   bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                   provider: CGDataProvider(data: data as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}

private func pixel(_ image: CGImage, x: Int, y: Int) -> [UInt8] {
    let data = image.dataProvider!.data!
    let bytes = CFDataGetBytePtr(data)!
    let offset = y * image.bytesPerRow + x * 4
    return Array(UnsafeBufferPointer(start: bytes + offset, count: 4))
}

@MainActor @Test func rendererPreservesOrientationAndPixelDimensions() throws {
    let original = image(width: 2, height: 2, pixels: [255, 0, 0, 255, 0, 255, 0, 255,
                                                     0, 0, 255, 255, 255, 255, 0, 255])
    let output = try #require(AnnotationRenderer.render(image: original, logicalSize: CGSize(width: 1, height: 1), annotations: []))
    #expect(output.width == 2 && output.height == 2)
    #expect(pixel(output, x: 0, y: 0) == [255, 0, 0, 255])
    #expect(pixel(output, x: 1, y: 0) == [0, 255, 0, 255])
    #expect(pixel(output, x: 0, y: 1) == [0, 0, 255, 255])
    #expect(pixel(output, x: 1, y: 1) == [255, 255, 0, 255])
}

@MainActor @Test func annotationsScaleToRetinaPixelsAndRedactionIsOpaque() throws {
    let annotation = Annotation(tool: .redact, points: [CGPoint(x: 5, y: 10), CGPoint(x: 15, y: 20)], color: .coral)
    let output = try #require(AnnotationRenderer.render(image: image(), logicalSize: CGSize(width: 50, height: 50), annotations: [annotation]))
    #expect(pixel(output, x: 10, y: 20) == [0, 0, 0, 255])
    #expect(pixel(output, x: 29, y: 39) == [0, 0, 0, 255])
    #expect(pixel(output, x: 9, y: 20) == [255, 255, 255, 255])
    #expect(pixel(output, x: 30, y: 40) == [255, 255, 255, 255])
}

@MainActor @Test func highlightIsTranslucentAndConfinedToSelection() throws {
    let annotation = Annotation(tool: .highlight, points: [CGPoint(x: 10, y: 10), CGPoint(x: 30, y: 30)],
                                color: AnnotationColor(red: 1, green: 0, blue: 0))
    let output = try #require(AnnotationRenderer.render(image: image(), logicalSize: CGSize(width: 100, height: 100), annotations: [annotation]))
    let inside = pixel(output, x: 20, y: 20)
    #expect(inside[0] == 255 && inside[1] > 100 && inside[1] < 240 && inside[3] == 255)
    #expect(pixel(output, x: 40, y: 40) == [255, 255, 255, 255])
}

@MainActor @Test func everyDrawingToolProducesPixelsWithoutChangingImageSize() throws {
    for tool in AnnotationTool.allCases {
        let annotation = Annotation(tool: tool, points: [CGPoint(x: 10, y: 10), CGPoint(x: 60, y: 60)],
                                    color: .black, lineWidth: 4, text: "Hi", fontSize: 24)
        let output = try #require(AnnotationRenderer.render(image: image(), logicalSize: CGSize(width: 100, height: 100), annotations: [annotation]))
        #expect(output.width == 100 && output.height == 100)
        var changed = false
        for y in 0..<100 {
            for x in 0..<100 where pixel(output, x: x, y: y) != [255, 255, 255, 255] { changed = true }
        }
        #expect(changed, "The \(tool.title) tool should render a mark")
    }
}

@MainActor @Test func singlePenClickRendersADot() throws {
    let annotation = Annotation(tool: .pen, points: [CGPoint(x: 50, y: 50)], color: .black, lineWidth: 8)
    let output = try #require(AnnotationRenderer.render(image: image(), logicalSize: CGSize(width: 100, height: 100), annotations: [annotation]))
    #expect(pixel(output, x: 50, y: 50)[0] < 20)
}

@MainActor @Test func undoRedoPreservesOrderAndNewEditsDiscardRedoHistory() {
    let document = CaptureDocument(image: image())
    let a = Annotation(tool: .arrow, points: [.zero, CGPoint(x: 20, y: 20)])
    let b = Annotation(tool: .rectangle, points: [.zero, CGPoint(x: 30, y: 30)])
    document.append(a); document.append(b)
    document.undo(); document.undo(); document.undo()
    #expect(document.annotations.isEmpty)
    document.redo(); document.redo(); document.redo()
    #expect(document.annotations.map(\.id) == [a.id, b.id])
    document.undo()
    document.append(Annotation(tool: .pen, points: [.zero]))
    #expect(document.redoStack.isEmpty)
    #expect(document.annotations.count == 2)
}
