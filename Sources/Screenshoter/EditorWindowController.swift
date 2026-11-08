import AppKit
import SwiftUI
import CaptureCore

@MainActor
final class EditorWindowController: NSWindowController, NSWindowDelegate {
    let id = UUID()
    let captureDocument: CaptureDocument
    private let feedback = EditorFeedback()
    var onClose: (() -> Void)?

    init(document: CaptureDocument, newCapture: @escaping () -> Void) {
        self.captureDocument = document
        let available = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1280, height: 800)
        let size = CGSize(width: min(1100, available.width - 60), height: min(780, available.height - 70))
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Screenshoter — Editor"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(Theme.surface)
        window.appearance = NSAppearance(named: .darkAqua)
        window.minSize = CGSize(width: 820, height: 570)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.contentView = NSHostingView(rootView: EditorView(
            document: document,
            copy: { [weak self] in self?.copyImage() },
            save: { [weak self] format in self?.saveImage(format: format) },
            newCapture: newCapture,
            feedback: feedback
        ))
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func copyImage() {
        window?.makeFirstResponder(nil)
        do {
            try ImageExporter.copy(captureDocument)
            if UserDefaults.standard.bool(forKey: "closeAfterCopy") { close() }
            else { feedback.show("Copied to clipboard") }
        } catch { present(error) }
    }

    func saveImage(format: ExportFormat = .png) {
        guard let window else { return }
        window.makeFirstResponder(nil)
        ImageExporter.save(captureDocument, format: format, window: window) { [weak self] result in
            switch result {
            case .success(let url):
                if let url { self?.feedback.show("Saved \(url.lastPathComponent)") }
            case .failure(let error): self?.present(error)
            }
        }
    }

    private func present(_ error: Error) {
        guard let window else { return }
        NSAlert(error: error).beginSheetModal(for: window)
    }

    func windowWillClose(_ notification: Notification) { onClose?() }
}
