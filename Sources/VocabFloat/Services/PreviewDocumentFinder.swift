import AppKit
import ApplicationServices

@MainActor
enum PreviewDocumentFinder {
    /// 通过 macOS Accessibility API 自动检测当前前台 Preview.app 正在阅读的 PDF 文件 URL
    static func getFrontmostPreviewPDFURL() -> URL? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.bundleIdentifier == "com.apple.Preview" || frontApp.localizedName == "Preview" else {
            return nil
        }

        let appRef = AXUIElementCreateApplication(frontApp.processIdentifier)
        
        // 1. 获取当前主窗口 (Focused Window)
        var windowVal: AnyObject?
        guard AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowVal) == .success,
              let window = windowVal,
              CFGetTypeID(window) == AXUIElementGetTypeID() else {
            return nil
        }

        let axWindow = window as! AXUIElement

        // 2. 尝试直接获取窗口绑定的 Document URL (kAXDocumentAttribute)
        var docVal: AnyObject?
        if AXUIElementCopyAttributeValue(axWindow, "AXDocument" as CFString, &docVal) == .success,
           let docStr = docVal as? String {
            if let url = URL(string: docStr), url.isFileURL {
                return url
            } else if let url = URL(fileURLWithPath: docStr.replacingOccurrences(of: "file://", with: "")) as URL? {
                return url
            }
        }

        // 3. 兜底方案：通过窗口标题 (Title) 在最近打开的 PDF 中匹配
        var titleVal: AnyObject?
        if AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleVal) == .success,
           let title = titleVal as? String {
            var cleanName = title.components(separatedBy: " (")[0]
            if !cleanName.hasSuffix(".pdf") && title.contains(".pdf") {
                if let range = title.range(of: ".pdf") {
                    cleanName = String(title[..<range.upperBound])
                }
            }
            cleanName = cleanName.trimmingCharacters(in: .whitespacesAndNewlines)

            let recentDocs = NSDocumentController.shared.recentDocumentURLs
            if let matched = recentDocs.first(where: { $0.lastPathComponent == cleanName || $0.deletingPathExtension().lastPathComponent == cleanName }) {
                return matched
            }
        }

        return nil
    }
}
