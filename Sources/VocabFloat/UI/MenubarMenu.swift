import AppKit
import SwiftUI

@MainActor
final class MenubarController: NSObject, NSMenuDelegate {
    static let shared = MenubarController()

    private var statusItem: NSStatusItem?
    private var launchAtLoginMenuItem: NSMenuItem?

    private override init() {
        super.init()
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "character.book.closed", accessibilityDescription: "VocabFloat")
            button.image?.isTemplate = true
            button.toolTip = "VocabFloat (⌥D 查词 · ⌥N 提取当前 Preview 高亮)"
        }

        let menu = NSMenu()
        menu.delegate = self

        menu.addItem(NSMenuItem(title: "全局查词：⌥D (Option+D)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "提取当前 PDF 笔记：⌥N (Option+N)", action: #selector(handleExtractCurrentPreviewPDF), keyEquivalent: "n"))
        menu.addItem(NSMenuItem.separator())

        let openHighlightsDirItem = NSMenuItem(title: "打开笔记与生词本存储目录…", action: #selector(openHighlightsFolder), keyEquivalent: "")
        openHighlightsDirItem.target = self
        menu.addItem(openHighlightsDirItem)

        let setCustomDirItem = NSMenuItem(title: "自定义笔记/生词存放路径…", action: #selector(promptSetCustomFolder), keyEquivalent: "")
        setCustomDirItem.target = self
        menu.addItem(setCustomDirItem)

        let selectFileItem = NSMenuItem(title: "手动选择 PDF 提取笔记…", action: #selector(promptSelectPDF), keyEquivalent: "")
        selectFileItem.target = self
        menu.addItem(selectFileItem)

        menu.addItem(NSMenuItem.separator())

        let openHtmlItem = NSMenuItem(title: "浏览生词本 (网页版)…", action: #selector(openHtmlViewer), keyEquivalent: "v")
        openHtmlItem.target = self
        menu.addItem(openHtmlItem)

        let openMdItem = NSMenuItem(title: "查看全部生词本 (Markdown 版)…", action: #selector(openMarkdownViewer), keyEquivalent: "m")
        openMdItem.target = self
        menu.addItem(openMdItem)

        let exportItem = NSMenuItem(title: "导出生词本为 Anki CSV…", action: #selector(exportAnki), keyEquivalent: "e")
        exportItem.target = self
        menu.addItem(exportItem)

        menu.addItem(NSMenuItem.separator())

        let launchItem = NSMenuItem(title: "开机自动启动 (Launch at Login)", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = LaunchAtLoginManager.isEnabled ? .on : .off
        self.launchAtLoginMenuItem = launchItem
        menu.addItem(launchItem)

        let checkUpdateItem = NSMenuItem(title: "检查新版本 (Check for Updates)…", action: #selector(manualCheckUpdate), keyEquivalent: "u")
        checkUpdateItem.target = self
        menu.addItem(checkUpdateItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出 VocabFloat", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    /// 菜单即将打开时动态更新勾选状态
    func menuWillOpen(_ menu: NSMenu) {
        launchAtLoginMenuItem?.state = LaunchAtLoginManager.isEnabled ? .on : .off
    }

    /// 开机自启动切换
    @objc private func toggleLaunchAtLogin() {
        let current = LaunchAtLoginManager.isEnabled
        LaunchAtLoginManager.isEnabled = !current
        launchAtLoginMenuItem?.state = (!current) ? .on : .off
    }

    /// 手动检查版本更新
    @objc private func manualCheckUpdate() {
        UpdateChecker.checkForUpdates(isUserInitiated: true)
    }

    /// 核心操作：自动保存 Preview.app 当前文档，并毫秒级提取高亮笔记
    @objc func handleExtractCurrentPreviewPDF() {
        Task { @MainActor in
            if let frontApp = NSWorkspace.shared.frontmostApplication,
               frontApp.bundleIdentifier == "com.apple.Preview" || frontApp.localizedName == "Preview" {
                triggerAutoSave()
                try? await Task.sleep(nanoseconds: 80_000_000)
            }

            if let autoURL = PreviewDocumentFinder.getFrontmostPreviewPDFURL() {
                if processPDF(url: autoURL, showNoHighlightsAlert: true) {
                    return
                }
            }

            promptSelectPDF()
        }
    }

    private func triggerAutoSave() {
        let src = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x01, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x01, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    @discardableResult
    func processPDF(url: URL, showNoHighlightsAlert: Bool = true) -> Bool {
        if let mdURL = PDFHighlightExtractor.extractAndSaveMarkdown(from: url) {
            NSWorkspace.shared.open(mdURL)
            return true
        } else if showNoHighlightsAlert {
            let alert = NSAlert()
            alert.messageText = "未检测到高亮笔记或生词"
            alert.informativeText = "该 PDF 文件中没有找到 Highlight/Underline 批注，且未查阅过生词。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "好的")
            alert.runModal()
        }
        return false
    }

    @objc private func promptSetCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "选择自定义笔记与生词本存放文件夹"

        if panel.runModal() == .OK, let url = panel.url {
            PDFHighlightExtractor.setCustomNotesDirectory(url)
            VocabularyStore.shared.generateMarkdown()
            VocabularyStore.shared.generateHTML()
            
            let alert = NSAlert()
            alert.messageText = "设置成功"
            alert.informativeText = "所有生成的文献笔记、生词本 (HTML & Markdown) 与 Anki CSV 将统一存放在：\n\(url.path)"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "好的")
            alert.runModal()
        }
    }

    @objc private func promptSelectPDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.title = "选择要提取高亮笔记的 PDF 文件"

        if panel.runModal() == .OK, let url = panel.url {
            processPDF(url: url)
        }
    }

    @objc private func openHighlightsFolder() {
        let dir = PDFHighlightExtractor.getCustomNotesDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        NSWorkspace.shared.open(dir)
    }

    @objc private func openHtmlViewer() {
        let htmlURL = VocabularyStore.shared.getHtmlURL()
        NSWorkspace.shared.open(htmlURL)
    }

    @objc private func openMarkdownViewer() {
        let mdURL = VocabularyStore.shared.getMarkdownURL()
        NSWorkspace.shared.open(mdURL)
    }

    @objc private func exportAnki() {
        if let csvURL = VocabularyStore.shared.exportAnkiCSV() {
            NSWorkspace.shared.activateFileViewerSelecting([csvURL])
        }
    }
}
