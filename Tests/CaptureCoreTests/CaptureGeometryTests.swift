import Foundation
import Testing
@testable import CaptureCore

@Test func selectionWorksInEveryDragDirection() {
    let bounds = CGRect(x: 0, y: 0, width: 500, height: 300)
    let expected = CGRect(x: 10, y: 20, width: 80, height: 50)
    for (a, b) in [(CGPoint(x: 10, y: 20), CGPoint(x: 90, y: 70)),
                   (CGPoint(x: 90, y: 70), CGPoint(x: 10, y: 20)),
                   (CGPoint(x: 90, y: 20), CGPoint(x: 10, y: 70)),
                   (CGPoint(x: 10, y: 70), CGPoint(x: 90, y: 20))] {
        #expect(CaptureGeometry.rectangle(from: a, to: b, within: bounds) == expected)
    }
}

@Test func selectionClampsAtDisplayEdges() {
    let bounds = CGRect(x: 0, y: 0, width: 200, height: 100)
    #expect(CaptureGeometry.rectangle(from: CGPoint(x: -50, y: -30), to: CGPoint(x: 250, y: 130), within: bounds) == bounds)
}

@Test func retinaCropKeepsTopLeftCoordinatesAndRoundsOutward() {
    let rect = CaptureGeometry.pixelRect(for: CGRect(x: 10.25, y: 20.25, width: 30.5, height: 40.5),
                                         logicalSize: CGSize(width: 100, height: 100),
                                         pixelSize: CGSize(width: 200, height: 200))
    #expect(rect == CGRect(x: 20, y: 40, width: 62, height: 82))
}

@Test func cropHandlesDifferentHorizontalAndVerticalScale() {
    let rect = CaptureGeometry.pixelRect(for: CGRect(x: 10, y: 20, width: 30, height: 40),
                                         logicalSize: CGSize(width: 100, height: 100),
                                         pixelSize: CGSize(width: 200, height: 150))
    #expect(rect == CGRect(x: 20, y: 30, width: 60, height: 60))
}

@Test func cropsClipToImageAndRejectEmptySelections() {
    let logical = CGSize(width: 100, height: 100), pixels = CGSize(width: 200, height: 200)
    #expect(CaptureGeometry.pixelRect(for: CGRect(x: 90, y: 90, width: 50, height: 50),
                                      logicalSize: logical, pixelSize: pixels) == CGRect(x: 180, y: 180, width: 20, height: 20))
    for rect in [CGRect.zero, .null, CGRect(x: 150, y: 0, width: 20, height: 20)] {
        #expect(CaptureGeometry.pixelRect(for: rect, logicalSize: logical, pixelSize: pixels) == nil)
    }
    #expect(CaptureGeometry.pixelRect(for: CGRect(x: 0, y: 0, width: 10, height: 10),
                                      logicalSize: .zero, pixelSize: pixels) == nil)
}
