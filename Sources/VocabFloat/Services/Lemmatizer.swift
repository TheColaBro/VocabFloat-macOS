import Foundation

enum Lemmatizer {
    static func candidates(for word: String) -> [String] {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return [] }

        var list = [clean]

        // 1. Plural / 3rd person s -> es, ies, s
        if clean.hasSuffix("ies") && clean.count > 3 {
            list.append(String(clean.dropLast(3)) + "y")
        }
        if clean.hasSuffix("es") && clean.count > 3 {
            list.append(String(clean.dropLast(2)))
        }
        if clean.hasSuffix("s") && clean.count > 2 && !clean.hasSuffix("ss") {
            list.append(String(clean.dropLast(1)))
        }

        // 2. Past / Participle ed -> d, ed, ied
        if clean.hasSuffix("ied") && clean.count > 3 {
            list.append(String(clean.dropLast(3)) + "y")
        }
        if clean.hasSuffix("ed") && clean.count > 3 {
            list.append(String(clean.dropLast(2)))
            list.append(String(clean.dropLast(1)))
        }

        // 3. Continuous ing -> ing, e+ing, double consonant
        if clean.hasSuffix("ing") && clean.count > 4 {
            let stem = String(clean.dropLast(3))
            list.append(stem)
            list.append(stem + "e")
            // running -> run
            if stem.count > 2 {
                let chars = Array(stem)
                if chars[chars.count - 1] == chars[chars.count - 2] {
                    list.append(String(stem.dropLast()))
                }
            }
        }

        // 4. Comparative / Superlative er, est, ly
        if clean.hasSuffix("er") && clean.count > 3 {
            list.append(String(clean.dropLast(2)))
            list.append(String(clean.dropLast(1)))
        }
        if clean.hasSuffix("est") && clean.count > 4 {
            list.append(String(clean.dropLast(3)))
            list.append(String(clean.dropLast(2)))
        }
        if clean.hasSuffix("ly") && clean.count > 3 {
            list.append(String(clean.dropLast(2)))
        }

        return list
    }
}
