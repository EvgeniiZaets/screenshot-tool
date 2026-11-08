import AppKit
import UniformTypeIdentifiers
import ImageIO
import CaptureCore

enum ExportFormat: String, CaseIterable, Identifiable {
    case png = "PNG", jpeg = "JPEG"
    var id: String { rawValue }
    var type: UTType { self == .png ? .png : .jpeg }
    var suffix: String { self == .png ? "png" : "jpg" }
}

@MainActor
enum ImageExporter {
    static func data(for image: CGImage, format: ExportFormat) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, format.type.identifier as CFString, 1, nil)
        else { throw CaptureError.renderFailed }
        let options: [CFString: Any] = format == .jpeg ? [kCGImageDestinationLossyCompressionQuality: 0.94] : [:]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CaptureError.renderFailed }
        return data as Data
    }

    static func clipboardItem(for document: CaptureDocument) throws -> NSPasteboardItem {
        guard let image = document.render() else { throw CaptureError.renderFailed }
        let png = try data(for: image, format: .png)
        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        if let tiff = NSBitmapImageRep(cgImage: image).tiffRepresentation { item.setData(tiff, forType: .tiff) }
        return item
    }

    static func copy(_ document: CaptureDocument) throws {
        let item = try clipboardItem(for: document)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.writeObjects([item]) else { throw CaptureError.renderFailed }
    }

    static func save(_ document: CaptureDocument, format: ExportFormat, window: NSWindow,
                     completion: @escaping (Result<URL?, Error>) -> Void) {
        let panel = NSSavePanel()
        panel.title = "Save screenshot"
        panel.allowedContentTypes = [format.type]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        panel.nameFieldStringValue = "Screenshot \(formatter.string(from: Date())).\(format.suffix)"
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { completion(.success(nil)); return }
            do {
                guard let image = document.render() else { throw CaptureError.renderFailed }
                try data(for: image, format: format).write(to: url, options: .atomic)
                completion(.success(url))
            } catch { completion(.failure(error)) }
        }
    }
}
