import SwiftUI
import CaptureCore

struct EditorView: View {
    @ObservedObject var document: CaptureDocument
    let copy: () -> Void
    let save: (ExportFormat) -> Void
    let newCapture: () -> Void
    @ObservedObject var feedback: EditorFeedback
    @State private var zoom: CGFloat? = nil
    @State private var format: ExportFormat = .png

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.border)
            HStack(spacing: 0) {
                toolRail
                Divider().overlay(Theme.border)
                VStack(spacing: 0) {
                    options
                    Divider().overlay(Theme.border)
                    canvas
                }
            }
            Divider().overlay(Theme.border)
            footer
        }
        .background(Theme.background).foregroundStyle(.white).preferredColorScheme(.dark)
        .frame(minWidth: 820, minHeight: 540)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "viewfinder").font(.system(size: 21, weight: .medium)).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("Make your point.").font(.system(size: 14, weight: .semibold))
                Text("\(document.image.width) × \(document.image.height) pixels")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.secondary)
            }
            Spacer()
            Button(action: newCapture) { Image(systemName: "plus.viewfinder") }
                .buttonStyle(QuietButtonStyle()).help("New capture (⇧⌘2)").accessibilityLabel("New capture")
            Button(action: copy) { Label("Copy", systemImage: "doc.on.doc").padding(.horizontal, 3) }
                .buttonStyle(QuietButtonStyle()).keyboardShortcut("c", modifiers: .command)
            HStack(spacing: 7) {
                Button { save(format) } label: { Label("Save image", systemImage: "arrow.down.to.line") }
                    .buttonStyle(AccentButtonStyle()).keyboardShortcut("s", modifiers: .command)
                Menu {
                    Picker("Format", selection: $format) {
                        ForEach(ExportFormat.allCases) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    Text(format.rawValue).font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .menuStyle(.borderlessButton).fixedSize().frame(width: 53)
                .help("Export format")
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14).background(Theme.surface)
    }

    private var toolRail: some View {
        VStack(spacing: 5) {
            ForEach(AnnotationTool.allCases) { tool in
                Button {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    document.tool = tool
                } label: {
                    Image(systemName: tool.symbol).font(.system(size: 17, weight: .medium))
                        .frame(width: 42, height: 40)
                        .foregroundStyle(document.tool == tool ? Theme.accent : Theme.secondary)
                        .background(document.tool == tool ? Theme.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(document.tool == tool ? Theme.accent.opacity(0.3) : .clear))
                }
                .buttonStyle(.plain).keyboardShortcut(KeyEquivalent(tool.shortcut.first!), modifiers: [])
                .help("\(tool.title) (\(tool.shortcut.uppercased()))")
                .accessibilityLabel(tool.title).accessibilityAddTraits(document.tool == tool ? .isSelected : [])
            }
            Spacer()
            Text("TOOLS").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1)
                .foregroundStyle(Theme.secondary.opacity(0.55)).padding(.bottom, 7)
        }
        .padding(10).background(Theme.surface)
    }

    private var options: some View {
        HStack(spacing: 14) {
            Text(document.tool.title).font(.system(size: 11, weight: .semibold)).frame(width: 58, alignment: .leading)
            Rectangle().fill(Theme.border).frame(width: 1, height: 18)
            HStack(spacing: 7) {
                ForEach(Array(AnnotationColor.palette.enumerated()), id: \.offset) { _, color in
                    Button { document.color = color } label: {
                        Circle().fill(Color(nsColor: color.nsColor)).frame(width: 16, height: 16)
                            .padding(3)
                            .overlay(Circle().strokeBorder(document.color == color ? Color.white : .clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain).disabled(document.tool == .redact)
                    .accessibilityLabel(colorName(color))
                    .help(colorName(color))
                }
            }
            Rectangle().fill(Theme.border).frame(width: 1, height: 18)
            if document.tool == .text {
                Text("Size").font(.system(size: 11)).foregroundStyle(Theme.secondary)
                Picker("Font size", selection: $document.fontSize) {
                    ForEach([CGFloat(16), 24, 32, 48, 64], id: \.self) { Text("\(Int($0)) pt").tag($0) }
                }.labelsHidden().frame(width: 76).controlSize(.small)
            } else if document.tool == .redact {
                Text("Opaque coverage").font(.system(size: 11)).foregroundStyle(Theme.secondary)
            } else {
                HStack(spacing: 4) {
                    ForEach([CGFloat(2), 3, 6], id: \.self) { width in
                        Button { document.lineWidth = width } label: {
                            Capsule().fill(document.lineWidth == width ? Theme.accent : Theme.secondary)
                                .frame(width: 17, height: width)
                                .frame(width: 29, height: 25)
                                .background(document.lineWidth == width ? Theme.elevated : .clear, in: RoundedRectangle(cornerRadius: 5))
                        }.buttonStyle(.plain).help("\(Int(width)) pt stroke").accessibilityLabel("\(Int(width)) point stroke")
                    }
                }
            }
            Spacer(minLength: 2)
            Button { NSApp.keyWindow?.makeFirstResponder(nil); document.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(document.annotations.isEmpty).help("Undo (⌘Z)").keyboardShortcut("z", modifiers: .command)
                .accessibilityLabel("Undo")
            Button { document.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .disabled(document.redoStack.isEmpty).help("Redo (⇧⌘Z)").keyboardShortcut("z", modifiers: [.command, .shift])
                .accessibilityLabel("Redo")
        }
        .buttonStyle(.plain).padding(.horizontal, 16).frame(height: 48).background(Theme.surface.opacity(0.45))
    }

    private var canvas: some View {
        GeometryReader { geometry in
            let fit = min((geometry.size.width - 64) / document.logicalSize.width,
                          (geometry.size.height - 64) / document.logicalSize.height, 1)
            let scale = zoom ?? max(0.01, fit)
            ScrollView([.horizontal, .vertical]) {
                AnnotationCanvas(document: document, zoom: scale)
                    .frame(width: document.logicalSize.width * scale, height: document.logicalSize.height * scale)
                    .background(.white)
                    .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
                    .padding(32)
                    .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
            }
            .background {
                Canvas { context, size in
                    for x in stride(from: CGFloat(12), to: size.width, by: 20) {
                        for y in stride(from: CGFloat(12), to: size.height, by: 20) {
                            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)), with: .color(.white.opacity(0.09)))
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: feedback.message == nil ? "cursorarrow" : "checkmark.circle.fill")
                .foregroundStyle(feedback.message == nil ? Theme.secondary : Theme.accent)
            Text(feedback.message ?? toolHint).font(.system(size: 11)).foregroundStyle(Theme.secondary)
                .lineLimit(1)
            Spacer()
            Text("\(document.annotations.count) \(document.annotations.count == 1 ? "mark" : "marks")")
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.secondary)
            Rectangle().fill(Theme.border).frame(width: 1, height: 16).padding(.horizontal, 6)
            Button { zoom = max(0.1, (zoom ?? 1) / 1.25) } label: { Image(systemName: "minus") }
                .help("Zoom out").accessibilityLabel("Zoom out")
            Menu {
                Button("Fit to window") { zoom = nil }
                ForEach([CGFloat(0.5), 1, 1.5, 2], id: \.self) { value in
                    Button("\(Int(value * 100))%") { zoom = value }
                }
            } label: {
                Text(zoom.map { "\(Int($0 * 100))%" } ?? "Fit")
                    .font(.system(size: 10, design: .monospaced)).frame(width: 35)
            }
            .menuStyle(.borderlessButton).fixedSize()
            Button { zoom = min(4, (zoom ?? 1) * 1.25) } label: { Image(systemName: "plus") }
                .help("Zoom in").accessibilityLabel("Zoom in")
        }
        .buttonStyle(.plain).padding(.horizontal, 18).frame(height: 39).background(Theme.surface)
    }

    private var toolHint: String {
        switch document.tool {
        case .text: "Click to add text · Return to apply · Esc to cancel"
        case .pen: "Draw freely on your capture"
        case .redact: "Drag over sensitive details to cover them in black"
        default: "Drag to draw · Hold Shift to constrain"
        }
    }

    private func colorName(_ color: AnnotationColor) -> String {
        ["Coral", "Amber", "Mint", "Blue", "White", "Black"][AnnotationColor.palette.firstIndex(of: color) ?? 0]
    }
}

@MainActor
final class EditorFeedback: ObservableObject {
    @Published var message: String?
    private var clearTask: Task<Void, Never>?

    func show(_ message: String) {
        clearTask?.cancel()
        self.message = message
        clearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }
}
