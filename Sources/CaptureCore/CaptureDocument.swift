import AppKit
import Combine

@MainActor
public final class CaptureDocument: ObservableObject {
    public let image: CGImage
    public let logicalSize: CGSize
    @Published public private(set) var annotations: [Annotation] = []
    @Published public private(set) var redoStack: [Annotation] = []
    @Published public var tool: AnnotationTool = .arrow
    @Published public var color: AnnotationColor = .coral
    @Published public var lineWidth: CGFloat = 3
    @Published public var fontSize: CGFloat = 24

    public init(image: CGImage, logicalSize: CGSize? = nil) {
        self.image = image
        self.logicalSize = logicalSize ?? CGSize(width: image.width, height: image.height)
    }

    public func append(_ annotation: Annotation) {
        annotations.append(annotation)
        redoStack.removeAll()
    }

    public func undo() {
        guard let last = annotations.popLast() else { return }
        redoStack.append(last)
    }

    public func redo() {
        guard let last = redoStack.popLast() else { return }
        annotations.append(last)
    }

    public func render() -> CGImage? {
        AnnotationRenderer.render(image: image, logicalSize: logicalSize, annotations: annotations)
    }
}
