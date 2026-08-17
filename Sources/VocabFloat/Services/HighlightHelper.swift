import Foundation
import SwiftUI

enum HighlightHelper {
    /// 1. SwiftUI 视图高亮：Apple System Blue / Indigo，加粗 + 醒目高对比度
    @MainActor
    static func highlightSwiftUI(sentence: String, targetWord: String) -> Text {
        guard !sentence.isEmpty, !targetWord.isEmpty else {
            return Text(sentence)
        }

        let cleanWord = targetWord.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
        guard !cleanWord.isEmpty else { return Text(sentence) }

        var result = Text("")
        var searchRange = sentence.startIndex..<sentence.endIndex

        while let matchRange = sentence.range(of: cleanWord, options: .caseInsensitive, range: searchRange) {
            // 前缀普通文本
            let prefix = String(sentence[searchRange.lowerBound..<matchRange.lowerBound])
            if !prefix.isEmpty {
                result = result + Text(prefix)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundColor(.secondary)
            }

            // 匹配到的生词：加粗 + Apple Blue
            let matchedText = String(sentence[matchRange])
            result = result + Text(matchedText)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundColor(.blue)

            searchRange = matchRange.upperBound..<sentence.endIndex
        }

        // 剩余文本
        let suffix = String(sentence[searchRange])
        if !suffix.isEmpty {
            result = result + Text(suffix)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundColor(.secondary)
        }

        return result
    }

    /// 2. 为 HTML 导出生成 <mark class="vocab-highlight">（透明背景 + Apple Blue + 加粗）
    static func highlightHTML(sentence: String, targetWord: String) -> String {
        guard !sentence.isEmpty, !targetWord.isEmpty else { return sentence }
        let cleanWord = targetWord.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
        guard !cleanWord.isEmpty else { return sentence }

        var result = ""
        var searchRange = sentence.startIndex..<sentence.endIndex

        while let matchRange = sentence.range(of: cleanWord, options: .caseInsensitive, range: searchRange) {
            let prefix = String(sentence[searchRange.lowerBound..<matchRange.lowerBound])
            result += prefix

            let matchedText = String(sentence[matchRange])
            result += "<mark class=\"vocab-highlight\">" + matchedText + "</mark>"

            searchRange = matchRange.upperBound..<sentence.endIndex
        }

        result += String(sentence[searchRange])
        return result
    }

    /// 3. 为 Markdown 导出生成 **生词** 加粗语法
    static func highlightMarkdown(sentence: String, targetWord: String) -> String {
        guard !sentence.isEmpty, !targetWord.isEmpty else { return sentence }
        let cleanWord = targetWord.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
        guard !cleanWord.isEmpty else { return sentence }

        var result = ""
        var searchRange = sentence.startIndex..<sentence.endIndex

        while let matchRange = sentence.range(of: cleanWord, options: .caseInsensitive, range: searchRange) {
            let prefix = String(sentence[searchRange.lowerBound..<matchRange.lowerBound])
            result += prefix

            let matchedText = String(sentence[matchRange])
            result += "**" + matchedText + "**"

            searchRange = matchRange.upperBound..<sentence.endIndex
        }

        result += String(sentence[searchRange])
        return result
    }
}
