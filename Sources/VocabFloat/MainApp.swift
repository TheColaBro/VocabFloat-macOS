import AppKit
import SwiftUI

@main
@MainActor
final class MainApp: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = MainApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.debug("[MainApp] 🚀 Application launching...")

        // 1. 检查并请求辅助功能权限
        PermissionManager.shared.checkAccessibilityPermission()

        // 2. 配置菜单栏
        MenubarController.shared.setup()

        // 3. 注册 Carbon 双全局快捷键：⌥D (查词) 与 ⌥N (提取当前 Preview 高亮)
        GlobalHotKeyManager.shared.register(
            onLookup: {
                Task { @MainActor in
                    MainApp.handleGlobalLookup()
                }
            },
            onExtractHighlight: {
                Task { @MainActor in
                    MenubarController.shared.handleExtractCurrentPreviewPDF()
                }
            }
        )

        // 4. 启动后延迟 3 秒静默检查更新 (不打扰用户，发现新版才提示)
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            UpdateChecker.checkForUpdates(isUserInitiated: false)
        }

        Logger.debug("[MainApp] Ready! ⌥D for Lookup, ⌥N for Highlight Extraction.")
    }

    private static func handleGlobalLookup() {
        Task { @MainActor in
            guard let selection = await TextCaptureService.shared.captureCurrentSelection() else {
                Logger.debug("[MainApp] ❌ Selection capture failed.")
                return
            }

            Logger.debug("[MainApp] Word: [\(selection.word)], Context: [\(selection.context)]")

            let lookupResult = await DictionaryService.shared.lookup(selection.word)
            FloatingPanel.shared.viewModel.update(selection: selection, entry: lookupResult)
            FloatingPanel.shared.showNearMouseOrCenter()
        }
    }
}
