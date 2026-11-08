import AppKit
import SwiftUI
import CaptureCore

@MainActor
final class CapturePreviewController {
    private let lifetime = CapturePreviewLifetime()
    private var panel: NSPanel?
    private var displayID: CGDirectDisplayID?
    private var presentationID: UUID?

    init(onEdit: @escaping (CaptureDocument) -> Void) {
        lifetime.onEdit = onEdit
        lifetime.onDismiss = { [weak self] in self?.closePanel() }
    }

    func show(_ document: CaptureDocument, on screen: NSScreen, copyError: Error?) {
        lifetime.show(document, expires: copyError == nil)
        guard let displayID = Self.displayID(for: screen),
              let screen = NSScreen.screens.first(where: { Self.displayID(for: $0) == displayID }) else {
            dismiss()
            return
        }
        self.displayID = displayID
        let id = UUID()
        presentationID = id
        let size = CGSize(width: 320, height: copyError == nil ? 248 : 278)
        let panel = CapturePreviewPanel(contentRect: Self.frame(in: screen.visibleFrame, size: size),
                                        styleMask: [.borderless, .nonactivatingPanel],
                                        backing: .buffered, defer: false)
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.acceptsMouseMovedEvents = true
        panel.setAccessibilityLabel(copyError == nil ? "Screenshot copied to clipboard" : "Screenshot could not be copied")

        let content = CapturePreviewView(
            thumbnail: NSImage(cgImage: document.image, size: document.logicalSize),
            pixelSize: CGSize(width: document.image.width, height: document.image.height),
            copyError: copyError?.localizedDescription,
            size: size,
            edit: { [weak self] in
                guard let self, presentationID == id else { return }
                lifetime.edit()
            },
            dismiss: { [weak self] in
                guard let self, presentationID == id else { return }
                dismiss()
            }
        )
        let hostingView = CapturePreviewHostingView(rootView: content)
        hostingView.hoverChanged = { [weak self] hovered in
            guard let self, presentationID == id else { return }
            lifetime.setHovered(hovered)
        }
        panel.contentView = hostingView
        self.panel = panel
        panel.orderFrontRegardless()
        lifetime.setHovered(panel.frame.contains(NSEvent.mouseLocation))
    }

    func dismiss() { lifetime.dismiss() }

    func reposition() {
        guard let panel, let displayID else { return }
        guard let screen = NSScreen.screens.first(where: { Self.displayID(for: $0) == displayID }) else {
            dismiss()
            return
        }
        panel.setFrame(Self.frame(in: screen.visibleFrame, size: panel.frame.size), display: true)
        lifetime.setHovered(panel.frame.contains(NSEvent.mouseLocation))
    }

    /// AppKit screen coordinates and visibleFrame are in points, including on mixed-scale displays.
    static func frame(in visibleFrame: CGRect, size: CGSize) -> CGRect {
        CGRect(x: visibleFrame.maxX - size.width - 16, y: visibleFrame.minY + 16,
               width: size.width, height: size.height)
    }

    private static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    private func closePanel() {
        presentationID = nil
        displayID = nil
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel?.close()
        panel = nil
    }
}

private final class CapturePreviewPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
private final class CapturePreviewHostingView<Content: View>: NSHostingView<Content> {
    var hoverChanged: ((Bool) -> Void)?
    private var hoverTracking: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking { removeTrackingArea(hoverTracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverTracking = area
    }

    override func mouseEntered(with event: NSEvent) { hoverChanged?(true) }
    override func mouseExited(with event: NSEvent) { hoverChanged?(false) }
}

private struct CapturePreviewView: View {
    let thumbnail: NSImage
    let pixelSize: CGSize
    let copyError: String?
    let size: CGSize
    let edit: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: copyError == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(copyError == nil ? Theme.accent : Color.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(copyError == nil ? "Copied to clipboard" : "Couldn’t copy screenshot")
                        .font(.system(size: 12, weight: .semibold))
                    if copyError != nil {
                        Text("Open the editor to copy or save it.")
                            .font(.system(size: 11)).foregroundStyle(Theme.secondary)
                    }
                }
                Spacer(minLength: 0)
                Button(action: dismiss) {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                        .frame(width: 20, height: 20).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(Theme.secondary)
                .help("Dismiss preview").accessibilityLabel("Dismiss preview")
            }
            .help(copyError ?? "The full-resolution screenshot is ready to paste.")

            Button(action: edit) {
                Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity).frame(height: 136)
                    .background(Theme.background, in: RoundedRectangle(cornerRadius: 8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.border))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).help("Edit screenshot").accessibilityLabel("Edit screenshot preview")

            HStack {
                Text("\(Int(pixelSize.width)) × \(Int(pixelSize.height)) px")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.secondary)
                Spacer()
                Button("Edit", action: edit).buttonStyle(AccentButtonStyle())
            }
        }
        .padding(14).frame(width: size.width, height: size.height)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.border))
        .preferredColorScheme(.dark)
    }
}
