import Foundation

extension VocabularyStore {
    /// 统一获取当前用户配置的笔记/生词存储主目录
    static var baseDirectory: URL {
        return PDFHighlightExtractor.getCustomNotesDirectory()
    }

    func getHtmlURL() -> URL {
        generateHTML()
        return VocabularyStore.baseDirectory.appendingPathComponent("vocabulary.html")
    }

    func getMarkdownURL() -> URL {
        generateMarkdown()
        return VocabularyStore.baseDirectory.appendingPathComponent("vocabulary.md")
    }

    func generateMarkdown() {
        let dir = VocabularyStore.baseDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let mdURL = dir.appendingPathComponent("vocabulary.md")

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"

        var md = "# VocabFloat 生词本\n\n"
        md += "> 共有 **" + String(items.count) + "** 个生词 · 更新于 " + df.string(from: Date()) + "\n\n---\n\n"

        for item in items {
            let phonetic = item.phonetic.isEmpty ? "" : " `/" + item.phonetic + "/`"
            md += "### " + item.word + phonetic + "\n\n"
            md += "- **释义**：" + item.translation.replacingOccurrences(of: "\n", with: "；") + "\n"
            if !item.context.isEmpty {
                let highlightedContext = HighlightHelper.highlightMarkdown(sentence: item.context, targetWord: item.word)
                md += "- **原句**：\n> " + highlightedContext + "\n"
                if !item.contextTranslation.isEmpty {
                    md += "> \n> " + item.contextTranslation + "\n"
                }
            }
            let source = item.sourceDocument ?? item.sourceApp
            md += "- **来源**：`" + source + "` · **时间**：" + df.string(from: item.createdAt) + "\n\n---\n\n"
        }

        try? md.write(to: mdURL, atomically: true, encoding: .utf8)
    }

    func generateHTML() {
        generateMarkdown()
        let dir = VocabularyStore.baseDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let htmlURL = dir.appendingPathComponent("vocabulary.html")

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"

        var cardsHTML = ""
        for item in items {
            let phoneticHTML = item.phonetic.isEmpty ? "" : "<span class=\"phonetic\">/" + escapeHTML(item.phonetic) + "/</span>"
            
            let highlightedContext = HighlightHelper.highlightHTML(sentence: escapeHTML(item.context), targetWord: escapeHTML(item.word))
            let contextTransHTML = item.contextTranslation.isEmpty ? "" : "<div class=\"context-trans\">" + escapeHTML(item.contextTranslation) + "</div>"
            let contextHTML = item.context.isEmpty ? "" : "<div class=\"context-box\"><div class=\"context-en\">" + highlightedContext + "</div>" + contextTransHTML + "</div>"

            let sourceText = escapeHTML(item.sourceDocument ?? item.sourceApp)

            cardsHTML += """
            <div class="card" data-word="\(escapeHTML(item.word.lowercased()))" data-date="\(df.string(from: item.createdAt))">
                <div class="card-header">
                    <span class="word">\(escapeHTML(item.word))</span>
                    \(phoneticHTML)
                    <span class="badge">\(sourceText)</span>
                </div>
                <div class="translation">\(escapeHTML(item.translation).replacingOccurrences(of: "\n", with: "<br>"))</div>
                \(contextHTML)
                <div class="card-footer">
                    <span>收藏时间：\(df.string(from: item.createdAt))</span>
                </div>
            </div>
            """
        }

        let fullHTML = """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>VocabFloat 生词本</title>
            <style>
                :root {
                    --bg: #F5F5F7;
                    --card-bg: #FFFFFF;
                    --text: #1D1D1F;
                    --text-sec: #86868B;
                    --accent: #0071E3;
                    --highlight-bg: #FFE58F;
                    --border: rgba(0, 0, 0, 0.08);
                }
                @media (prefers-color-scheme: dark) {
                    :root {
                        --bg: #000000;
                        --card-bg: #1C1C1E;
                        --text: #F5F5F7;
                        --text-sec: #86868B;
                        --accent: #2997FF;
                        --highlight-bg: #634A00;
                        --border: rgba(255, 255, 255, 0.12);
                    }
                }
                * { box-sizing: border-box; margin: 0; padding: 0; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
                    background-color: var(--bg);
                    color: var(--text);
                    line-height: 1.5;
                    padding: 40px 20px;
                }
                .container { max-width: 800px; margin: 0 auto; }
                header { margin-bottom: 30px; display: flex; justify-content: space-between; align-items: baseline; }
                h1 { font-size: 28px; font-weight: 700; }
                .count { color: var(--text-sec); font-size: 14px; }
                .search-box {
                    width: 100%;
                    padding: 12px 16px;
                    border-radius: 10px;
                    border: 1px solid var(--border);
                    background: var(--card-bg);
                    color: var(--text);
                    font-size: 15px;
                    margin-bottom: 24px;
                    outline: none;
                }
                .card {
                    background: var(--card-bg);
                    border-radius: 12px;
                    padding: 20px;
                    margin-bottom: 16px;
                    border: 1px solid var(--border);
                    transition: transform 0.1s ease;
                }
                .card-header { display: flex; align-items: baseline; gap: 8px; margin-bottom: 8px; flex-wrap: wrap; }
                .word { font-size: 20px; font-weight: 600; }
                .phonetic { color: var(--text-sec); font-family: ui-monospace, monospace; font-size: 13px; }
                .badge { margin-left: auto; font-size: 11px; background: rgba(128, 128, 128, 0.15); padding: 2px 8px; border-radius: 4px; color: var(--text-sec); }
                .translation { font-size: 15px; color: var(--text); margin-bottom: 12px; }
                .context-box {
                    background: rgba(128, 128, 128, 0.06);
                    border-left: 3px solid var(--accent);
                    padding: 10px 14px;
                    border-radius: 0 8px 8px 0;
                    margin-bottom: 12px;
                }
                .context-en { font-size: 14px; margin-bottom: 4px; }
                .context-en mark { background-color: var(--highlight-bg); color: inherit; padding: 1px 4px; border-radius: 3px; font-weight: 600; }
                .context-trans { font-size: 13px; color: var(--text-sec); }
                .card-footer { font-size: 11px; color: var(--text-sec); }
            </style>
        </head>
        <body>
            <div class="container">
                <header>
                    <h1>VocabFloat 生词本</h1>
                    <span class="count">共 \(items.count) 个生词</span>
                </header>
                <input type="text" class="search-box" id="search" placeholder="搜索生词、释义或例句…">
                <div id="list">
                    \(cardsHTML)
                </div>
            </div>
            <script>
                document.getElementById(search).addEventListener(input, (e) => {
                    const query = e.target.value.toLowerCase();
                    document.querySelectorAll(.card).forEach(card => {
                        const text = card.textContent.toLowerCase();
                        card.style.display = text.includes(query) ? block : none;
                    });
                });
            </script>
        </body>
        </html>
        """

        try? fullHTML.write(to: htmlURL, atomically: true, encoding: .utf8)
    }

    private func escapeHTML(_ string: String) -> String {
        return string.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
