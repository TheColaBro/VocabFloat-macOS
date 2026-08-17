import AppKit
import ApplicationServices
import NaturalLanguage

struct CapturedSelection: Sendable {
    let word: String
    let context: String
    let sourceApp: String
    let sourceDocument: String
}

@MainActor
final class TextCaptureService {
    static let shared = TextCaptureService()

    private init() {}

    func captureCurrentSelection() async -> CapturedSelection? {
        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = frontApp?.localizedName ?? "Preview"
        
        // 获取当前 Preview 正在打开的 PDF 文档名
        var docName = ""
        if let previewURL = PreviewDocumentFinder.getFrontmostPreviewPDFURL() {
            docName = previewURL.deletingPathExtension().lastPathComponent
        }

        // 1. 获取当前选区生词 (精准目标)
        guard let rawCaptured = await copyCurrentSelection(waitTimeoutMs: 180) else {
            return nil
        }

        let safeRaw = rawCaptured.count > 600 ? String(rawCaptured.prefix(600)) : rawCaptured
        let cleanText = safeRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return nil }

        let words = cleanText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.trimmingCharacters(in: .punctuationCharacters).isEmpty }
        guard !words.isEmpty else { return nil }

        // 用户主动划选了长句/词组
        if words.count > 2 {
            let candidate = words.first(where: { $0.count > 3 }) ?? words.first ?? cleanText
            var cleanTarget = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: .punctuationCharacters)
            if cleanTarget.count > 40 { cleanTarget = String(cleanTarget.prefix(40)) }

            let contextText = cleanText.count > 300 ? String(cleanText.prefix(300)) + "..." : cleanText
            return CapturedSelection(word: cleanTarget, context: contextText, sourceApp: appName, sourceDocument: docName)
        }

        // 用户双击生词
        var targetWord = words.first?.trimmingCharacters(in: .punctuationCharacters) ?? cleanText
        if targetWord.count > 50 {
            targetWord = String(targetWord.prefix(50))
        }

        // 🌟 核心高精度方案：基于鼠标物理坐标的精准 9 行滑动窗口提取
        if let coordinateSentence = getSentenceViaCoordinateTraversal(targetWord: targetWord) {
            let safeSentence = coordinateSentence.count > 350 ? String(coordinateSentence.prefix(350)) + "..." : coordinateSentence
            return CapturedSelection(word: targetWord, context: safeSentence, sourceApp: appName, sourceDocument: docName)
        }

        return CapturedSelection(word: targetWord, context: targetWord, sourceApp: appName, sourceDocument: docName)
    }

    /// 基于鼠标所在物理坐标的精准局部视窗遍历 (避免同名词匹配错位与全页死锁)
    private func getSentenceViaCoordinateTraversal(targetWord: String) -> String? {
        let mouseLoc = NSEvent.mouseLocation
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 1080
        let axX = Float(mouseLoc.x)
        let axY = Float(primaryScreenHeight - mouseLoc.y)

        let systemWide = AXUIElementCreateSystemWide()
        var clickedElement: AXUIElement?
        let copyStatus = AXUIElementCopyElementAtPosition(systemWide, axX, axY, &clickedElement)

        guard copyStatus == .success, let currentElement = clickedElement else {
            return nil
        }

        var currentText: AnyObject?
        _ = AXUIElementCopyAttributeValue(currentElement, kAXValueAttribute as CFString, &currentText)
        let curLine = (currentText as? String) ?? ""

        var parentElement: AnyObject?
        guard AXUIElementCopyAttributeValue(currentElement, kAXParentAttribute as CFString, &parentElement) == .success,
              let parent = parentElement,
              CFGetTypeID(parent) == AXUIElementGetTypeID() else {
            return extractSentenceFromBlock(targetWord: targetWord, block: curLine)
        }

        let axParent = parent as! AXUIElement
        var childrenValue: AnyObject?
        guard AXUIElementCopyAttributeValue(axParent, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement], !children.isEmpty else {
            return extractSentenceFromBlock(targetWord: targetWord, block: curLine)
        }

        var currentIndex = -1
        for (idx, child) in children.enumerated() {
            if CFEqual(child, currentElement) {
                currentIndex = idx
                break
            }
        }

        if currentIndex == -1 && !curLine.isEmpty {
            for (idx, child) in children.enumerated() {
                var val: AnyObject?
                if AXUIElementCopyAttributeValue(child, kAXValueAttribute as CFString, &val) == .success,
                   let str = val as? String, str == curLine {
                    currentIndex = idx
                    break
                }
            }
        }

        var extractedLines: [String] = []
        if currentIndex >= 0 {
            // 取鼠标前后各 4 行 (共 9 行的宽幅上下文，彻底跨越长难句与段落换行)
            let startIdx = max(0, currentIndex - 4)
            let endIdx = min(children.count - 1, currentIndex + 4)

            for i in startIdx...endIdx {
                var lineVal: AnyObject?
                if AXUIElementCopyAttributeValue(children[i], kAXValueAttribute as CFString, &lineVal) == .success,
                   let lineStr = lineVal as? String, !lineStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    extractedLines.append(lineStr)
                }
            }
        }

        let mergedBlock = extractedLines.joined(separator: " ")
        return extractSentenceFromBlock(targetWord: targetWord, block: mergedBlock.isEmpty ? curLine : mergedBlock)
    }

    private func extractSentenceFromBlock(targetWord: String, block: String) -> String? {
        let cleanWord = targetWord.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
        guard !cleanWord.isEmpty, !block.isEmpty else { return nil }

        var cleaned = block.replacingOccurrences(of: "-\r\n", with: "")
            .replacingOccurrences(of: "-\n", with: "")
            .replacingOccurrences(of: "-\r", with: "")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")

        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = cleaned

        var matchedSentence: String? = nil
        tokenizer.enumerateTokens(in: cleaned.startIndex..<cleaned.endIndex) { sentenceRange, _ in
            let sentence = String(cleaned[sentenceRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if sentence.localizedStandardContains(cleanWord) {
                matchedSentence = sentence
                return false
            }
            return true
        }

        return matchedSentence
    }

    private func copyCurrentSelection(waitTimeoutMs: Int) async -> String? {
        let pasteboard = NSPasteboard.general
        let oldChangeCount = pasteboard.changeCount

        let savedItems = pasteboard.pasteboardItems?.compactMap { item -> [NSPasteboard.PasteboardType: Data]? in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { dict[type] = data }
            }
            return dict.isEmpty ? nil : dict
        }

        let src = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        let iterations = waitTimeoutMs / 10
        for _ in 0..<iterations {
            try? await Task.sleep(nanoseconds: 10_000_000)
            if pasteboard.changeCount != oldChangeCount {
                let text = pasteboard.string(forType: .string)

                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    pasteboard.clearContents()
                    if let saved = savedItems {
                        for dict in saved {
                            let item = NSPasteboardItem()
                            for (type, data) in dict { item.setData(data, forType: type) }
                            pasteboard.writeObjects([item])
                        }
                    }
                }
                return text
            }
        }
        return nil
    }
}
