import Foundation
import NaturalLanguage

enum NLPService {
    /// Extract the base lemma of an English word (e.g. symptoms -> symptom, running -> run)
    static func lemmatize(_ word: String) -> String {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters).lowercased()
        guard !clean.isEmpty else { return word }

        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = clean
        
        var lemma = clean
        tagger.enumerateTags(in: clean.startIndex..<clean.endIndex, unit: .word, scheme: .lemma) { tag, _ in
            if let tag = tag {
                lemma = tag.rawValue
            }
            return false
        }
        return lemma
    }

    /// Extract target word and surrounding sentence from selected text
    static func analyzeSelectedText(_ text: String) -> (targetWord: String, contextSentence: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return ("", "") }

        let words = clean.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        // If only 1 or 2 words selected, targetWord is the word
        if words.count <= 2 {
            let w = words.first ?? clean
            return (w.trimmingCharacters(in: .punctuationCharacters), clean)
        }

        // If a longer sentence was selected, the entire selection is the context
        // and we pick the first significant word (length > 3) or the first word
        let target = words.first(where: { $0.count > 3 }) ?? words.first ?? clean
        return (target.trimmingCharacters(in: .punctuationCharacters), clean)
    }
}
