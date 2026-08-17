import Foundation

struct VocabItem: Identifiable, Codable, Sendable {
    let id: UUID
    let word: String
    let phonetic: String
    let translation: String
    let context: String
    let contextTranslation: String
    let sourceApp: String
    let sourceDocument: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        word: String,
        phonetic: String = "",
        translation: String = "",
        context: String = "",
        contextTranslation: String = "",
        sourceApp: String = "Preview",
        sourceDocument: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.word = word
        self.phonetic = phonetic
        self.translation = translation
        self.context = context
        self.contextTranslation = contextTranslation
        self.sourceApp = sourceApp
        self.sourceDocument = sourceDocument
        self.createdAt = createdAt
    }
}

@MainActor
final class VocabularyStore: ObservableObject {
    static let shared = VocabularyStore()

    @Published private(set) var items: [VocabItem] = []

    private let fileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("VocabFloat", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("vocabulary.json")
        load()
    }

    func save(word: String, phonetic: String, translation: String, context: String, contextTranslation: String, sourceApp: String = "Preview", sourceDocument: String? = nil) {
        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = items.firstIndex(where: { item in
            item.word.caseInsensitiveCompare(cleanWord) == .orderedSame
        }) {
            items.remove(at: idx)
        }

        let item = VocabItem(
            word: cleanWord,
            phonetic: phonetic,
            translation: translation,
            context: context,
            contextTranslation: contextTranslation,
            sourceApp: sourceApp,
            sourceDocument: sourceDocument
        )
        items.insert(item, at: 0)
        persist()
    }

    /// 获取特定某篇 PDF 文档在阅读期间收藏的所有生词
    func getWords(forDocument documentName: String) -> [VocabItem] {
        guard !documentName.isEmpty else { return [] }
        let target = documentName.lowercased()
        return items.filter { item in
            if let doc = item.sourceDocument?.lowercased(), !doc.isEmpty {
                return doc == target || doc.contains(target) || target.contains(doc)
            }
            return false
        }
    }

    func exportAnkiCSV() -> URL? {
        let dir = VocabularyStore.baseDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let csvURL = dir.appendingPathComponent("vocabulary_anki.csv")

        var csv = "#separator:Tab\n#html:true\n#tags column:6\n"
        for item in items {
            let word = item.word.replacingOccurrences(of: "\t", with: " ")
            let phonetic = item.phonetic.isEmpty ? "" : "[" + item.phonetic + "]"
            let translation = item.translation.replacingOccurrences(of: "\n", with: "<br>").replacingOccurrences(of: "\t", with: " ")
            let context = HighlightHelper.highlightHTML(sentence: item.context, targetWord: item.word)
                .replacingOccurrences(of: "\n", with: "<br>").replacingOccurrences(of: "\t", with: " ")
            let contextTranslation = item.contextTranslation.replacingOccurrences(of: "\n", with: "<br>").replacingOccurrences(of: "\t", with: " ")

            let line = word + "\t" + phonetic + "\t" + translation + "\t" + context + "\t" + contextTranslation + "\tVocabFloat\n"
            csv += line
        }

        do {
            try csv.write(to: csvURL, atomically: true, encoding: .utf8)
            return csvURL
        } catch {
            return nil
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            items = try JSONDecoder().decode([VocabItem].self, from: data)
        } catch {
            items = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
            generateHTML()
        } catch {
            Logger.debug(" [VocabularyStore] Save failed: \(error)")
        }
    }
}
