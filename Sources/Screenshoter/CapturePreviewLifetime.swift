import Foundation
import CaptureCore

/// Owns the capture only while its preview is visible, independently of the panel.
@MainActor
final class CapturePreviewLifetime {
    typealias Schedule = (TimeInterval, @escaping @MainActor @Sendable () -> Void) -> () -> Void

    private(set) var document: CaptureDocument?
    var onDismiss: (() -> Void)?
    var onEdit: ((CaptureDocument) -> Void)?

    private let now: () -> TimeInterval
    private let schedule: Schedule
    private var remaining: TimeInterval?
    private var deadline: TimeInterval?
    private var cancelTimer: (() -> Void)?
    private var timerID = UUID()

    init(now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         schedule: @escaping Schedule = { delay, action in
             let timer = Timer(timeInterval: delay, repeats: false) { _ in
                 MainActor.assumeIsolated { action() }
             }
             RunLoop.main.add(timer, forMode: .common)
             return { timer.invalidate() }
         }) {
        self.now = now
        self.schedule = schedule
    }

    func show(_ document: CaptureDocument, expires: Bool) {
        dismiss()
        self.document = document
        remaining = expires ? 5 : nil
        resume()
    }

    func setHovered(_ hovered: Bool) {
        guard document != nil else { return }
        if hovered {
            if let deadline { remaining = max(0, deadline - now()) }
            cancelCountdown()
        } else {
            resume()
        }
    }

    func edit() {
        guard let document else { return }
        dismiss()
        onEdit?(document)
    }

    func dismiss() {
        cancelCountdown()
        document = nil
        remaining = nil
        onDismiss?()
    }

    private func resume() {
        guard document != nil, cancelTimer == nil, let remaining else { return }
        guard remaining > 0 else { dismiss(); return }
        deadline = now() + remaining
        let id = UUID()
        timerID = id
        cancelTimer = schedule(remaining) { [weak self] in
            // A cancelled timer may already have delivered its callback.
            guard let self, timerID == id else { return }
            dismiss()
        }
    }

    private func cancelCountdown() {
        timerID = UUID()
        cancelTimer?()
        cancelTimer = nil
        deadline = nil
    }
}
