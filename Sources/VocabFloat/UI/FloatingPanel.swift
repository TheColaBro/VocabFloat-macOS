import AppKit
import SwiftUI

@MainActor
final class FloatingPanel: NSPanel {
    static let shared = FloatingPanel()

    let viewModel = FloatingCardViewModel()
    private var hostingView: NSHostingView<FloatingCardView>?
    private var globalClickMonitor: Any?

    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 200),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        // 回归最初的纯粹与极简
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true

        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false

        let rootView = FloatingCardView(model: viewModel) { [weak self] in
            self?.dismiss()
        }
        let hosting = NSHostingView(rootView: rootView)
        self.hostingView = hosting
        self.contentView = hosting
    }

    /// 显示并根据内容 fittingSize 动态自适应调整窗口尺寸
    func showNearMouseOrCenter() {
        adjustHeightToFit(animate: false)

        let mouseLocation = NSEvent.mouseLocation
        let panelSize = self.frame.size
        var origin = CGPoint(x: mouseLocation.x + 12, y: mouseLocation.y - panelSize.height + 20)

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            origin.x = max(screenFrame.minX + 16, min(origin.x, screenFrame.maxX - panelSize.width - 16))
            origin.y = max(screenFrame.minY + 16, min(origin.y, screenFrame.maxY - panelSize.height - 16))
        }

        self.setFrameOrigin(origin)
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        startClickOutsideMonitor()
    }

    /// 动态计算内容 fittingSize，平滑自适应窗口高度
    func adjustHeightToFit(animate: Bool = true) {
        guard let hosting = hostingView else { return }
        
        let targetSize = hosting.fittingSize
        let currentFrame = self.frame
        let newWidth = max(380, targetSize.width)
        let newHeight = max(100, targetSize.height)

        let newY = currentFrame.maxY - newHeight
        let newFrame = NSRect(x: currentFrame.origin.x, y: newY, width: newWidth, height: newHeight)

        if animate && self.isVisible {
            self.animator().setFrame(newFrame, display: true)
        } else {
            self.setFrame(newFrame, display: true)
        }
    }

    func dismiss() {
        stopClickOutsideMonitor()
        self.orderOut(nil)
    }

    private func startClickOutsideMonitor() {
        stopClickOutsideMonitor()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            let clickLocation = NSEvent.mouseLocation
            if !self.frame.contains(clickLocation) {
                Task { @MainActor in
                    self.dismiss()
                }
            }
        }
    }

    private func stopClickOutsideMonitor() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }

    override func resignKey() {
        super.resignKey()
        dismiss()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            dismiss()
        } else if event.keyCode == 36 { // Enter
            viewModel.saveToVocabulary()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.dismiss()
            }
        } else if event.keyCode == 49 { // Space (发音)
            viewModel.playSound()
        } else {
            super.keyDown(with: event)
        }
    }

    override var canBecomeKey: Bool {
        return true
    }
}
