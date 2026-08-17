import Foundation

actor DictionaryService {
    static let shared = DictionaryService()

    struct Entry: Codable, Sendable {
        let t: String
        let p: String?

        var translation: String {
            t.replacingOccurrences(of: "\\r", with: "\n")
        }
    }

    private var entries: [String: Entry]?

    /// 核心 ECDICT 离线查词 + 形态学还原 + MyMemory 在线翻译兜底
    func lookup(_ rawWord: String) async -> (word: String, phonetic: String, translation: String)? {
        let cleanWord = rawWord.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
        guard !cleanWord.isEmpty else { return nil }

        // 1. 惰性加载 ECDICT 本地轻量离线词库
        if entries == nil {
            guard let url = Bundle.module.url(forResource: "mini_dict", withExtension: "json") else {
                if let online = await MyMemoryTranslationService.shared.translate(text: cleanWord) {
                    return (word: cleanWord, phonetic: "", translation: online)
                }
                return nil
            }
            let data = try? Data(contentsOf: url, options: .mappedIfSafe)
            if let data = data {
                entries = try? JSONDecoder().decode([String: Entry].self, from: data)
            }
        }

        let key = cleanWord.lowercased()

        // Tier 1: ECDICT 本地精确命中
        if let entry = entries?[key] {
            return (word: cleanWord, phonetic: entry.p ?? "", translation: entry.translation)
        }

        // Tier 2: Apple NaturalLanguage 词形还原 (symptoms -> symptom, technologies -> technology)
        let lemma = NLPService.lemmatize(cleanWord)
        if lemma != key, let entry = entries?[lemma] {
            return (word: cleanWord, phonetic: entry.p ?? "", translation: entry.translation)
        }

        // Tier 3: 规则形态学候选词 (es, ies, ed, ing)
        let candidates = Lemmatizer.candidates(for: cleanWord)
        for candidate in candidates {
            if let entry = entries?[candidate] {
                return (word: cleanWord, phonetic: entry.p ?? "", translation: entry.translation)
            }
        }

        // Tier 4: MyMemory 免费翻译 API 兜底
        if let myMemoryTrans = await MyMemoryTranslationService.shared.translate(text: cleanWord) {
            return (word: cleanWord, phonetic: "", translation: myMemoryTrans)
        }

        return nil
    }

    /// 长文本与例句翻译：使用 MyMemory 翻译服务
    func translateText(_ text: String) async -> String? {
        return await MyMemoryTranslationService.shared.translate(text: text)
    }
}
