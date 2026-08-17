import AppKit
import ApplicationServices

@MainActor
final class PermissionManager {
    static let shared = PermissionManager()

    private init() {}

    /// Check accessibility permission. If not granted, prompt the user and guide them to System Settings.
    @discardableResult
    func checkAccessibilityPermission() -> Bool {
        let isTrusted = AXIsProcessTrusted()
        Logger.debug(" [PermissionManager] Current AXIsProcessTrusted = \(isTrusted)")

        if !isTrusted {
            Logger.debug(" [PermissionManager] ❌ Accessibility Permission NOT granted.")
            Logger.debug(" [PermissionManager] Prompting macOS System Settings...")

            // Trigger system prompt modal
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)

            // Show native alert window to user
            let alert = NSAlert()
            alert.messageText = "⚠️ 缺少「辅助功能」权限"
            alert.informativeText = """
VocabFloat 需要辅助功能权限来获取选中的文本和响应全局快捷键 (⌥D)。

请在弹出的系统设置中：
1. 勾选当前终端（Terminal / iTerm2 / VSCode）或 VocabFloat；
2. 勾选后重新运行程序即可。
"""
            alert.alertStyle = .critical
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "稍后设置")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            return false
        } else {
            Logger.debug(" [PermissionManager] ✅ Accessibility Permission GRANTED.")
            return true
        }
    }
}
