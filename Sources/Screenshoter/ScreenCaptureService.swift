import AppKit
import ScreenCaptureKit
import CaptureCore

struct DisplaySnapshot {
    let screen: NSScreen
    let image: CGImage
}

enum CaptureError: LocalizedError {
    case noDisplays, cropFailed, renderFailed
    var errorDescription: String? {
        switch self {
        case .noDisplays: "No available displays were found. Connect a display and try again."
        case .cropFailed: "This selection could not be captured. Please select a larger area."
        case .renderFailed: "The image could not be rendered. Try a smaller image."
        }
    }
}

@MainActor
enum ScreenCaptureService {
    static func snapshots(includeCursor: Bool) async throws -> [DisplaySnapshot] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        var snapshots: [DisplaySnapshot] = []
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let display = content.displays.first(where: { $0.displayID == number.uint32Value }) else { continue }
            let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = Int((filter.contentRect.width * CGFloat(filter.pointPixelScale)).rounded())
            configuration.height = Int((filter.contentRect.height * CGFloat(filter.pointPixelScale)).rounded())
            configuration.captureResolution = .best
            configuration.showsCursor = includeCursor
            configuration.capturesAudio = false
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            snapshots.append(DisplaySnapshot(screen: screen, image: image))
        }
        guard !snapshots.isEmpty else { throw CaptureError.noDisplays }
        return snapshots
    }

    static func crop(_ source: CGImage, displaySize: CGSize, selection: CGRect) throws -> CaptureDocument {
        guard let rect = CaptureGeometry.pixelRect(
            for: selection, logicalSize: displaySize,
            pixelSize: CGSize(width: source.width, height: source.height)),
              let image = source.cropping(to: rect) else { throw CaptureError.cropFailed }
        let sx = CGFloat(source.width) / displaySize.width
        let sy = CGFloat(source.height) / displaySize.height
        return CaptureDocument(image: image, logicalSize: CGSize(width: rect.width / sx, height: rect.height / sy))
    }
}
