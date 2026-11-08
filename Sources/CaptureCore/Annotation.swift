import AppKit

public enum AnnotationTool: String, CaseIterable, Identifiable, Sendable {
    case pen, line, arrow, rectangle, ellipse, highlight, text, redact

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var symbol: String {
        switch self {
        case .pen: "pencil.tip"
        case .line: "line.diagonal"
        case .arrow: "arrow.up.right"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .highlight: "highlighter"
        case .text: "textformat"
        case .redact: "rectangle.fill"
        }
    }
    public var shortcut: String {
        switch self {
        case .pen: "p"
        case .line: "l"
        case .arrow: "a"
        case .rectangle: "r"
        case .ellipse: "o"
        case .highlight: "h"
        case .text: "t"
        case .redact: "b"
        }
    }
}

public struct AnnotationColor: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    public var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    public static let coral = Self(red: 1, green: 0.30, blue: 0.36)
    public static let amber = Self(red: 1, green: 0.78, blue: 0.23)
    public static let mint = Self(red: 0.30, green: 0.90, blue: 0.73)
    public static let blue = Self(red: 0.31, green: 0.62, blue: 1)
    public static let white = Self(red: 1, green: 1, blue: 1)
    public static let black = Self(red: 0.04, green: 0.05, blue: 0.07)
    public static let palette: [Self] = [.coral, .amber, .mint, .blue, .white, .black]
}

public struct Annotation: Identifiable, Sendable {
    public let id: UUID
    public var tool: AnnotationTool
    public var points: [CGPoint]
    public var color: AnnotationColor
    public var lineWidth: CGFloat
    public var text: String
    public var fontSize: CGFloat

    public init(tool: AnnotationTool, points: [CGPoint], color: AnnotationColor = .coral,
                lineWidth: CGFloat = 3, text: String = "", fontSize: CGFloat = 24) {
        id = UUID()
        self.tool = tool; self.points = points; self.color = color
        self.lineWidth = lineWidth; self.text = text; self.fontSize = fontSize
    }

    public var bounds: CGRect {
        guard let first = points.first, let last = points.last else { return .zero }
        return CGRect(x: min(first.x, last.x), y: min(first.y, last.y),
                      width: abs(last.x - first.x), height: abs(last.y - first.y))
    }
}
