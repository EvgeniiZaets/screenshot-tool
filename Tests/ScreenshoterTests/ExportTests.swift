import AppKit
import ImageIO
import Testing
import CaptureCore
@testable import Screenshoter

@MainActor @Test func pngAndJPEGExportsAreDecodableAtOriginalResolution() throws {
    let image = try #require(DemoImage.make())
    let document = CaptureDocument(image: image, logicalSize: CGSize(width: 550, height: 350))
    document.append(Annotation(tool: .arrow, points: [CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 50)]))
    let rendered = try #require(document.render())
    for format in ExportFormat.allCases {
        let data = try ImageExporter.data(for: rendered, format: format)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        #expect(CGImageSourceGetType(source) as String? == format.type.identifier)
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(decoded.width == 1100 && decoded.height == 700)
    }
}

@MainActor @Test func clipboardPayloadContainsPNGAndTIFFWithoutTouchingSystemClipboard() throws {
    // Exercise the exact payload used by Copy without connecting to the pasteboard server.
    let image = try #require(DemoImage.make())
    let document = CaptureDocument(image: image)
    document.append(Annotation(tool: .redact, points: [CGPoint(x: 0, y: 0), CGPoint(x: 30, y: 30)]))
    let item = try ImageExporter.clipboardItem(for: document)
    #expect(item.types.contains(.png))
    #expect(item.types.contains(.tiff))
    for type in [NSPasteboard.PasteboardType.png, .tiff] {
        let data = try #require(item.data(forType: type))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(decoded.width == image.width && decoded.height == image.height)
    }
}

@MainActor @Test func cropUsesDisplayLocalCoordinatesAtRetinaScale() throws {
    let displaySize = CGSize(width: 640, height: 480)
    let pixelWidth = Int(displaySize.width * 2)
    let pixelHeight = Int(displaySize.height * 2)
    let context = try #require(CGContext(data: nil, width: pixelWidth, height: pixelHeight,
                                        bitsPerComponent: 8, bytesPerRow: 0,
                                        space: CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    let image = try #require(context.makeImage())
    let document = try ScreenCaptureService.crop(image, displaySize: displaySize, selection: CGRect(x: 10, y: 20, width: 100, height: 80))
    #expect(document.image.width == 200 && document.image.height == 160)
    #expect(document.logicalSize == CGSize(width: 100, height: 80))
}
