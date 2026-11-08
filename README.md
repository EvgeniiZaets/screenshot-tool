# Screenshoter

A native macOS screenshot app inspired by Lightshot. It lives in the menu bar: select a region, annotate it, then copy or save the result. Built with Swift 6, AppKit, SwiftUI, and ScreenCaptureKit. No dependencies, accounts, uploads, or network requests.

## Run

Requires macOS 14 or later and Xcode 16 or later (Swift 6).

```sh
bash scripts/run.sh
```

This builds and opens `build/Screenshoter.app`. You can also open that app directly in Finder. Keep it in a stable location when granting Screen Recording access; moving or rebuilding an ad-hoc-signed app can cause macOS to request permission again.

For a build without launching:

```sh
bash scripts/build.sh
open build/Screenshoter.app
```

The default build targets your Mac's architecture. To build for both Apple silicon and Intel:

```sh
UNIVERSAL=1 bash scripts/build.sh
```

Open `Package.swift` in Xcode to work on the source. For testing Screen Recording permissions, launch the packaged `.app`, rather than the bare SwiftPM executable, so macOS uses the correct app identity.

## First capture

1. Open Screenshoter. Click **Allow access** and enable it under **System Settings → Privacy & Security → Screen & System Audio Recording** (called **Screen Recording** on older macOS versions). Reopen the app if macOS asks.
2. Press **Shift–Command–2** or choose **Capture a Region** from the menu bar.
3. Drag a rectangle on any display. Release to open the editor. Press **Space** to capture the whole display, or **Escape** / right-click to cancel.
4. Add annotations. **Command–C** copies the flattened image; **Command–S** opens the save dialog. Choose PNG or JPEG next to Save.

**Try editor** opens a generated sample without Screen Recording access. **Open image** imports an existing PNG, JPEG, TIFF, HEIC, WebP, or BMP and applies its orientation metadata.

## Editing

| Tool / action | Key |
| --- | --- |
| Pen | P |
| Line | L |
| Arrow | A |
| Rectangle | R |
| Ellipse | O |
| Highlight | H |
| Text | T |
| Opaque black redaction | B |
| Constrain shapes / snap line angles | Hold Shift while dragging |
| Commit / cancel text | Return / Escape |
| Undo / redo | Command–Z / Shift–Command–Z |
| Copy image | Command–C |
| Save image | Command–S |
| Open image | Command–O |
| Close editor | Command–W |

Exports preserve the capture's original pixel dimensions regardless of editor zoom. Clipboard images include PNG and TIFF representations. Redaction is an opaque black rectangle flattened into the exported image. The editor defaults to closing after a successful copy; this can be changed in Settings & Help.

## Verification

```sh
bash scripts/test.sh
```

Tests cover selection direction and bounds, fractional Retina crops, nonuniform scale factors, rendering orientation, full-resolution PNG/JPEG export, all drawing tools, opaque redaction, translucent highlights, undo/redo history, and PNG/TIFF clipboard payloads. Tests generate clipboard data in memory and never replace your system clipboard.

Development baseline: macOS 26.6.2, Swift 6.3.3, macOS 26.5 SDK. The deployment target is macOS 14. The implementation uses Apple's supported [ScreenCaptureKit screenshot API](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager), available from macOS 14, instead of the deprecated CGWindow capture APIs. Compatibility with OS releases beyond the machine used for testing requires an on-device smoke test; the minimum deployment target alone does not certify every newer macOS release.

The initial build passed 14 automated tests and produced a verified, ad-hoc-signed universal app (`arm64` + `x86_64`). Native UI checks confirmed sample-image annotation, text entry, undo/redo, and PNG/JPEG saves at the original dimensions. Real display capture still needs an interactive check after the user grants Screen Recording access. The system clipboard was not overwritten during verification; its image payload was tested in memory instead.

## Project layout

- `Sources/CaptureCore`: coordinate conversion, annotation model/history, and shared pixel renderer.
- `Sources/Screenshoter`: application lifecycle, menu/shortcut, screen capture, selection overlays, native editor, clipboard/export, and welcome/settings window.
- `Tests/CaptureCoreTests`: geometry and rendering regression tests.
- `Tests/ScreenshoterTests`: export, clipboard-payload, and capture-cropping regression tests.
- `Resources/Info.plist`: app identity and permission description.
- `scripts`: build, test, launch, and vector app-icon generation.

## Current scope

This is a local-first MVP. A selection stays within one display; displays may use different scaling or desktop positions. Annotation happens in a separate editor after selection. The global shortcut is fixed at Shift–Command–2; conflicts are reported in the home window. There is no screenshot history, cloud sharing, scrolling capture, OCR, movable annotations, or automatic launch at login. Unsaved captures live only in memory and are discarded when their editor closes. Protected system/video content may be unavailable to ScreenCaptureKit.

The build script ad-hoc signs for local use. For distribution, supply your Developer ID via `CODE_SIGN_IDENTITY`, then notarize and staple the resulting app using your Apple Developer account. No certificates or credentials are stored in this project.
