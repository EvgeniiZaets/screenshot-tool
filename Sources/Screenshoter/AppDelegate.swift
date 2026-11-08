import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ImageIO
import CaptureCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private let shortcut = GlobalShortcut()
    private var statusItem: NSStatusItem?
    private var homeWindow: NSWindow?
    private var editors: [UUID: EditorWindowController] = [:]
    private var overlays: [SelectionPanel] = []
    private var hiddenWindows: [NSWindow] = []
    private var previousApplication: NSRunningApplication?
    private var captureTask: Task<Void, Never>?
    private var captureGeneration = UUID()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["includeCursor": false, "closeAfterCopy": true, "showWelcomeOnLaunch": true])
        buildMenu()
        buildStatusItem()
        shortcut.onPress = { [weak self] in self?.capture() }
        state.shortcutAvailable = shortcut.register()
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        if ProcessInfo.processInfo.arguments.contains("--demo") { openDemo() }
        else if UserDefaults.standard.bool(forKey: "showWelcomeOnLaunch") { showHome() }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        state.hasPermission = CGPreflightScreenCaptureAccess()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showHome() }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcut.unregister()
        captureTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    private func buildMenu() {
        let main = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(item("About Screenshoter", action: #selector(showHome), key: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(item("Quit Screenshoter", action: #selector(quit), key: "q"))
        let appItem = NSMenuItem(); appItem.submenu = appMenu; main.addItem(appItem)

        let fileMenu = NSMenu(title: "File")
        let captureItem = item("Capture a Region", action: #selector(capture), key: "2")
        captureItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(captureItem)
        fileMenu.addItem(item("Open Image…", action: #selector(openImage), key: "o"))
        fileMenu.addItem(item("Show Screenshoter", action: #selector(showHome), key: "0"))
        fileMenu.addItem(.separator())
        fileMenu.addItem(NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        let fileItem = NSMenuItem(title: "File", action: nil, keyEquivalent: ""); fileItem.submenu = fileMenu; main.addItem(fileItem)

        let editMenu = NSMenu(title: "Edit")
        for (title, selector, key) in [("Cut", "cut:", "x"), ("Copy", "copy:", "c"),
                                        ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            editMenu.addItem(NSMenuItem(title: title, action: NSSelectorFromString(selector), keyEquivalent: key))
        }
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: ""); editItem.submenu = editMenu; main.addItem(editItem)
        NSApp.mainMenu = main
    }

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "Screenshoter")
        item.button?.image?.isTemplate = true
        item.button?.toolTip = "Screenshoter · ⇧⌘2"
        let menu = NSMenu()
        let captureItem = self.item("Capture a Region", action: #selector(capture), key: "2")
        captureItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(captureItem)
        menu.addItem(self.item("Open Image…", action: #selector(openImage), key: "o"))
        menu.addItem(.separator())
        menu.addItem(self.item("Settings & Help…", action: #selector(showHome), key: ","))
        menu.addItem(self.item("Try the Editor", action: #selector(openDemo), key: ""))
        menu.addItem(.separator())
        menu.addItem(self.item("Quit Screenshoter", action: #selector(quit), key: "q"))
        item.menu = menu
        statusItem = item
    }

    private func item(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func showHome() {
        guard !state.isCapturing else { return }
        if homeWindow == nil {
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 650, height: 680),
                                  styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Screenshoter"
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(Theme.background)
            window.appearance = NSAppearance(named: .darkAqua)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: HomeView(
                state: state,
                capture: { [weak self] in self?.capture() },
                openImage: { [weak self] in self?.openImage() },
                openDemo: { [weak self] in self?.openDemo() },
                requestPermission: { [weak self] in self?.requestPermission() }
            ))
            window.center()
            homeWindow = window
        }
        state.hasPermission = CGPreflightScreenCaptureAccess()
        NSApp.activate(ignoringOtherApps: true)
        homeWindow?.makeKeyAndOrderFront(nil)
    }

    private func requestPermission() {
        state.hasPermission = CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess()
        if !state.hasPermission { showPermissionHelp() }
    }

    private func showPermissionHelp() {
        let alert = NSAlert()
        alert.messageText = "Allow Screenshoter to capture your screen"
        alert.informativeText = "In System Settings → Privacy & Security → Screen & System Audio Recording, enable Screenshoter. macOS may ask you to quit and reopen the app. Screenshoter captures still images only; it does not record audio."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc private func capture() {
        guard !state.isCapturing else { return }
        guard NSApp.modalWindow == nil, !NSApp.windows.contains(where: { $0.attachedSheet != nil }) else {
            NSSound.beep(); return
        }
        state.hasPermission = CGPreflightScreenCaptureAccess()
        guard state.hasPermission else { requestPermission(); return }
        state.isCapturing = true
        let generation = UUID()
        captureGeneration = generation
        previousApplication = NSWorkspace.shared.frontmostApplication
        hiddenWindows = NSApp.windows.filter { $0.isVisible && $0 != statusItem?.button?.window }
        hiddenWindows.forEach { $0.orderOut(nil) }
        captureTask = Task { [weak self] in
            guard let self else { return }
            do {
                // Let WindowServer finish hiding the editor before freezing all displays.
                try await Task.sleep(for: .milliseconds(180))
                let snapshots = try await ScreenCaptureService.snapshots(includeCursor: UserDefaults.standard.bool(forKey: "includeCursor"))
                try Task.checkCancellation()
                guard captureGeneration == generation else { return }
                NSApp.activate(ignoringOtherApps: true)
                overlays = snapshots.map { snapshot in
                    SelectionPanel(snapshot: snapshot, onSelect: { [weak self] rect in
                        self?.finishSelection(snapshot: snapshot, rect: rect)
                    }, onCancel: { [weak self] in self?.cancelCapture() })
                }
                for overlay in overlays { overlay.orderFrontRegardless() }
                let mouse = NSEvent.mouseLocation
                (overlays.first(where: { $0.frame.contains(mouse) }) ?? overlays.first)?.makeKey()
            } catch is CancellationError {
                if captureGeneration == generation { cancelCapture() }
            } catch {
                guard captureGeneration == generation else { return }
                cancelCapture()
                state.hasPermission = CGPreflightScreenCaptureAccess()
                if !state.hasPermission { showPermissionHelp() }
                else { NSApp.activate(ignoringOtherApps: true); NSAlert(error: error).runModal() }
            }
        }
    }

    private func finishSelection(snapshot: DisplaySnapshot, rect: CGRect) {
        do {
            let document = try ScreenCaptureService.crop(snapshot.image, displaySize: snapshot.screen.frame.size, selection: rect)
            dismissOverlays()
            restoreWindows()
            showEditor(document)
        } catch {
            cancelCapture()
            NSAlert(error: error).runModal()
        }
    }

    private func dismissOverlays() {
        captureGeneration = UUID()
        overlays.forEach { $0.orderOut(nil); $0.close() }
        overlays.removeAll()
        state.isCapturing = false
    }

    private func restoreWindows() {
        hiddenWindows.forEach { $0.orderFront(nil) }
        hiddenWindows.removeAll()
    }

    private func cancelCapture() {
        dismissOverlays()
        restoreWindows()
        previousApplication?.activate()
        previousApplication = nil
    }

    @objc private func displaysChanged() {
        guard state.isCapturing else { return }
        captureTask?.cancel()
        cancelCapture()
    }

    private func showEditor(_ document: CaptureDocument) {
        let controller = EditorWindowController(document: document, newCapture: { [weak self] in self?.capture() })
        let id = controller.id
        controller.onClose = { [weak self] in self?.editors.removeValue(forKey: id) }
        editors[id] = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openDemo() {
        guard !state.isCapturing, let image = DemoImage.make() else { return }
        showEditor(CaptureDocument(image: image))
    }

    @objc private func openImage() {
        guard !state.isCapturing else { return }
        let panel = NSOpenPanel()
        panel.title = "Open an image to annotate"
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic, .webP, .bmp]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int,
                  width > 0, height > 0, width <= 16000, height <= 16000,
                  Double(width) * Double(height) <= 80_000_000 else { throw ImportError.invalidImage }
            // Apply EXIF orientation while preserving original dimensions.
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                          kCGImageSourceCreateThumbnailWithTransform: true,
                                          kCGImageSourceThumbnailMaxPixelSize: max(width, height)]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
            else { throw ImportError.invalidImage }
            showEditor(CaptureDocument(image: image))
        } catch { NSAlert(error: error).runModal() }
    }
}

private enum ImportError: LocalizedError {
    case invalidImage
    var errorDescription: String? { "This image could not be opened. Choose a supported image under 80 megapixels and 16,000 pixels per side." }
}
