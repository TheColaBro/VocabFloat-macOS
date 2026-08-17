import Foundation
import PDFKit

/// 像素级精准提取的 PDF 高亮与本篇生词归档提取器
@MainActor
enum PDFHighlightExtractor {

    /// 传入 PDF 文件 URL，解析提取高亮段落，并智能附加本篇 PDF 查阅过的生词摘抄
    static func extractAndSaveMarkdown(from fileURL: URL) -> URL? {
        guard let document = PDFDocument(url: fileURL) else { return nil }
        
        let filename = fileURL.deletingPathExtension().lastPathComponent
        var extractedHighlights: [String] = []
        let pageCount = document.pageCount

        for pageIndex in 0..<pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            let annotations = page.annotations

            for annotation in annotations {
                let typeStr = annotation.type ?? ""
                let isHighlight = typeStr.caseInsensitiveCompare("Highlight") == .orderedSame ||
                                  typeStr.caseInsensitiveCompare("Underline") == .orderedSame ||
                                  typeStr.caseInsensitiveCompare("/Highlight") == .orderedSame ||
                                  typeStr.caseInsensitiveCompare("/Underline") == .orderedSame

                guard isHighlight else { continue }

                var text = ""

                // 1. Quadrilateral Points (四边形点集切片：像素级精准截取)
                let lineRects = getPreciseLineRects(for: annotation)
                if !lineRects.isEmpty {
                    var lineTexts: [String] = []
                    for rect in lineRects {
                        if let sel = page.selection(for: rect),
                           let str = sel.string?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                            lineTexts.append(str)
                        }
                    }
                    if !lineTexts.isEmpty {
                        text = lineTexts.joined(separator: " ")
                    }
                }

                // 2. 兜底方案
                if text.isEmpty, let contents = annotation.contents?.trimmingCharacters(in: .whitespacesAndNewlines), !contents.isEmpty {
                    text = contents
                }
                if text.isEmpty, let selection = page.selection(for: annotation.bounds),
                   let raw = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
                    text = raw
                }

                if !text.isEmpty {
                    let clean = text.replacingOccurrences(of: "-\r\n", with: "")
                        .replacingOccurrences(of: "-\n", with: "")
                        .replacingOccurrences(of: "-\r", with: "")
                        .replacingOccurrences(of: "\r\n", with: " ")
                        .replacingOccurrences(of: "\n", with: " ")
                        .replacingOccurrences(of: "\r", with: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if !clean.isEmpty && !extractedHighlights.contains(clean) {
                        extractedHighlights.append(clean)
                    }
                }
            }
        }

        // 3. 提取阅读本篇 PDF 期间查阅并收藏的所有生词
        let relatedVocabs = VocabularyStore.shared.getWords(forDocument: filename)

        // 如果既无高亮又无生词，返回 nil
        guard !extractedHighlights.isEmpty || !relatedVocabs.isEmpty else { return nil }

        // 4. 构建排版极其精美的学术笔记 Markdown (无 Emoji)
        var md = "# " + filename + "\n\n"

        // 第一部分：高亮要点 (Highlights)
        if !extractedHighlights.isEmpty {
            md += extractedHighlights.joined(separator: "\n\n") + "\n\n"
        }

        // 第二部分：本篇文献生词摘抄 (Vocabulary)
        if !relatedVocabs.isEmpty {
            md += "---\n\n## 重点生词摘抄\n\n"
            for vocab in relatedVocabs {
                let phonetic = vocab.phonetic.isEmpty ? "" : " `/" + vocab.phonetic + "/`"
                let cleanTrans = vocab.translation.replacingOccurrences(of: "\n", with: "； ")
                md += "- **" + vocab.word + "**" + phonetic + " — " + cleanTrans + "\n"
                if !vocab.context.isEmpty && vocab.context != vocab.word {
                    let highlightedCtx = HighlightHelper.highlightMarkdown(sentence: vocab.context, targetWord: vocab.word)
                    md += "  > " + highlightedCtx + "\n"
                    if !vocab.contextTranslation.isEmpty {
                        md += "  > *" + vocab.contextTranslation + "*\n"
                    }
                }
                md += "\n"
            }
        }

        // 5. 获取用户自定义配置的保存目录 (默认 Downloads/VocabFloat_Notes)
        let saveDir = getCustomNotesDirectory()
        try? FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)

        let safeName = filename.replacingOccurrences(of: "/", with: "_")
        let outputURL = saveDir.appendingPathComponent(safeName + "_notes.md")
        try? md.write(to: outputURL, atomically: true, encoding: .utf8)

        return outputURL
    }

    /// 获取或设置用户自定义的笔记保存目录
    static func getCustomNotesDirectory() -> URL {
        if let customPath = UserDefaults.standard.string(forKey: "customNotesDirectory"),
           !customPath.isEmpty {
            let customURL = URL(fileURLWithPath: customPath)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: customURL.path, isDirectory: &isDir), isDir.boolValue {
                return customURL
            }
        }
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        return downloads.appendingPathComponent("VocabFloat_Notes", isDirectory: true)
    }

    static func setCustomNotesDirectory(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: "customNotesDirectory")
    }

    private static func getPreciseLineRects(for annotation: PDFAnnotation) -> [CGRect] {
        guard let quadPoints = annotation.quadrilateralPoints, !quadPoints.isEmpty else {
            return []
        }

        var rects: [CGRect] = []
        let count = quadPoints.count

        for i in stride(from: 0, to: count - 3, by: 4) {
            let p1 = quadPoints[i].pointValue
            let p2 = quadPoints[i + 1].pointValue
            let p3 = quadPoints[i + 2].pointValue
            let p4 = quadPoints[i + 3].pointValue

            let minX = min(p1.x, p2.x, p3.x, p4.x)
            let maxX = max(p1.x, p2.x, p3.x, p4.x)
            let minY = min(p1.y, p2.y, p3.y, p4.y)
            let maxY = max(p1.y, p2.y, p3.y, p4.y)

            let width = maxX - minX
            let height = maxY - minY

            if width > 1 && height > 1 {
                var rect = CGRect(x: minX, y: minY, width: width, height: height)
                if rect.minX < annotation.bounds.minX || rect.minY < annotation.bounds.minY {
                    rect.origin.x += annotation.bounds.origin.x
                    rect.origin.y += annotation.bounds.origin.y
                }
                rects.append(rect)
            }
        }

        rects.sort { $0.midY > $1.midY }
        return rects
    }
}
