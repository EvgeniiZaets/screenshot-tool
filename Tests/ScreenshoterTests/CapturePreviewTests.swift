import AppKit
import ImageIO
import Testing
import CaptureCore
@testable import Screenshoter

@MainActor
private final class PreviewClock {
    final class Scheduled {
        let delay: TimeInterval
        let action: @MainActor @Sendable () -> Void
        var cancelled = false

        init(delay: TimeInterval, action: @escaping @MainActor @Sendable () -> Void) {
            self.delay = delay
            self.action = action
        }
    }

    var now: TimeInterval = 100
    var scheduled: [Scheduled] = []

    func lifetime() -> CapturePreviewLifetime {
        CapturePreviewLifetime(now: { self.now }, schedule: { delay, action in
            let event = Scheduled(delay: delay, action: action)
            self.scheduled.append(event)
            return { event.cancelled = true }
        })
    }
}

@MainActor @Test func previewExpiresAfterFiveSecondsAndReleasesItsCapture() throws {
    let clock = PreviewClock()
    let lifetime = clock.lifetime()
    var document: CaptureDocument? = CaptureDocument(image: try #require(DemoImage.make()))
    let retainedDocument = { [weak document] in document }
    lifetime.show(try #require(document), expires: true)
    document = nil
    #expect(retainedDocument() != nil)
    #expect(clock.scheduled.count == 1)
    #expect(clock.scheduled[0].delay == 5)

    clock.now += 5
    clock.scheduled[0].action()
    #expect(lifetime.document == nil)
    #expect(retainedDocument() == nil)
    #expect(clock.scheduled[0].cancelled)
}

@MainActor @Test func hoveringPausesAndResumesOnlyTheRemainingPreviewTime() throws {
    let clock = PreviewClock()
    let lifetime = clock.lifetime()
    let document = CaptureDocument(image: try #require(DemoImage.make()))
    lifetime.show(document, expires: true)
    clock.now += 2
    lifetime.setHovered(true)
    #expect(clock.scheduled[0].cancelled)
    // Even a callback already enqueued before the hover must be ignored.
    clock.scheduled[0].action()
    #expect(lifetime.document === document)

    clock.now += 100
    lifetime.setHovered(true)
    lifetime.setHovered(false)
    lifetime.setHovered(false)
    #expect(clock.scheduled.count == 2)
    #expect(clock.scheduled[1].delay == 3)
    clock.now += 1
    lifetime.setHovered(true)
    clock.now += 100
    lifetime.setHovered(false)
    #expect(clock.scheduled.count == 3)
    #expect(clock.scheduled[2].delay == 2)
    clock.scheduled[1].action()
    #expect(lifetime.document === document)
    clock.now += 2
    clock.scheduled[2].action()
    #expect(lifetime.document == nil)
}

@MainActor @Test func replacingAndDismissingPreviewsInvalidateOlderTimers() throws {
    let clock = PreviewClock()
    let lifetime = clock.lifetime()
    let image = try #require(DemoImage.make())
    var first: CaptureDocument? = CaptureDocument(image: image)
    let firstDocument = { [weak first] in first }
    lifetime.show(try #require(first), expires: true)
    first = nil
    let second = CaptureDocument(image: image, logicalSize: CGSize(width: 550, height: 350))
    lifetime.show(second, expires: true)
    #expect(firstDocument() == nil)
    #expect(clock.scheduled[0].cancelled)
    clock.scheduled[0].action()
    #expect(lifetime.document === second)

    lifetime.dismiss()
    #expect(clock.scheduled[1].cancelled)
    lifetime.show(CaptureDocument(image: image), expires: true)
    clock.scheduled[1].action()
    #expect(lifetime.document != nil)
    lifetime.dismiss()
    #expect(clock.scheduled[2].cancelled)
    #expect(lifetime.document == nil)
}

@MainActor @Test func failedCopyPreviewRemainsUntilEditedOrDismissed() throws {
    let clock = PreviewClock()
    let lifetime = clock.lifetime()
    let document = CaptureDocument(image: try #require(DemoImage.make()))
    lifetime.show(document, expires: true)
    lifetime.show(document, expires: false)
    #expect(clock.scheduled.count == 1)
    #expect(clock.scheduled[0].cancelled)
    clock.now += 10_000
    lifetime.setHovered(true)
    lifetime.setHovered(false)
    clock.scheduled[0].action()
    #expect(lifetime.document === document)
    #expect(clock.scheduled.count == 1)

    var edited: CaptureDocument?
    lifetime.onEdit = { edited = $0 }
    lifetime.edit()
    #expect(edited === document)
    #expect(lifetime.document == nil)
    lifetime.show(document, expires: false)
    lifetime.dismiss()
    #expect(lifetime.document == nil)
}

@MainActor @Test func editingPreviewKeepsTheOriginalDocumentAndFullResolutionExports() throws {
    let clock = PreviewClock()
    let lifetime = clock.lifetime()
    let document = CaptureDocument(image: try #require(DemoImage.make()), logicalSize: CGSize(width: 550, height: 350))
    lifetime.show(document, expires: true)
    var edited: CaptureDocument?
    lifetime.onEdit = { edited = $0 }
    lifetime.edit()
    let editorDocument = try #require(edited)
    #expect(editorDocument === document)
    #expect(editorDocument.logicalSize == CGSize(width: 550, height: 350))
    #expect(lifetime.document == nil)
    #expect(clock.scheduled[0].cancelled)

    editorDocument.append(Annotation(tool: .arrow, points: [CGPoint(x: 10, y: 10), CGPoint(x: 100, y: 100)]))
    let item = try ImageExporter.clipboardItem(for: editorDocument)
    for type in [NSPasteboard.PasteboardType.png, .tiff] {
        let data = try #require(item.data(forType: type))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(decoded.width == 1100 && decoded.height == 700)
    }
    let rendered = try #require(editorDocument.render())
    for format in ExportFormat.allCases {
        let data = try ImageExporter.data(for: rendered, format: format)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(decoded.width == 1100 && decoded.height == 700)
    }
    // A timer delivered after editing cannot close a newer preview.
    lifetime.show(CaptureDocument(image: document.image), expires: true)
    clock.scheduled[0].action()
    #expect(lifetime.document != nil)
    lifetime.dismiss()
}

@MainActor @Test func previewDismissalLeavesAnIndependentClipboardPayload() throws {
    let clock = PreviewClock()
    let lifetime = clock.lifetime()
    var document: CaptureDocument? = CaptureDocument(image: try #require(DemoImage.make()))
    let retainedDocument = { [weak document] in document }
    let item = try ImageExporter.clipboardItem(for: try #require(document))
    lifetime.show(try #require(document), expires: true)
    document = nil
    lifetime.dismiss()
    #expect(retainedDocument() == nil)
    for type in [NSPasteboard.PasteboardType.png, .tiff] {
        let data = try #require(item.data(forType: type))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(decoded.width == 1100 && decoded.height == 700)
    }
}

@MainActor @Test func previewPlacementUsesEachDisplaysUsablePointCoordinates() {
    let size = CGSize(width: 320, height: 248)
    // Bottom Dock, left Dock on a negative-origin secondary display, and a right Dock.
    let usableFrames = [CGRect(x: 0, y: 76, width: 1512, height: 870),
                        CGRect(x: -1840, y: -200, width: 1840, height: 1056),
                        CGRect(x: 1512, y: 400, width: 2464, height: 1416)]
    for usable in usableFrames {
        let frame = CapturePreviewController.frame(in: usable, size: size)
        #expect(frame.size == size)
        #expect(frame.maxX == usable.maxX - 16)
        #expect(frame.minY == usable.minY + 16)
        #expect(usable.contains(frame))
    }
}
