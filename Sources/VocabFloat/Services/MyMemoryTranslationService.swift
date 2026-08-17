import Foundation

actor MyMemoryTranslationService {
    static let shared = MyMemoryTranslationService()

    private init() {}

    /// 通过 MyMemory API 进行翻译，严格设置 2.5 秒超时与 429 容错
    func translate(text: String, from: String = "en", to: String = "zh-CN") async -> String? {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return nil }

        let langPair = "\(from)|\(to)"
        guard let encodedText = cleanText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedPair = langPair.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        let urlString = "https://api.mymemory.translated.net/get?q=\(encodedText)&langpair=\(encodedPair)"
        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 2.5
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return nil }

            if httpResponse.statusCode == 429 {
                Logger.debug("[MyMemory] ⚠️ Rate limit exceeded (429).")
                return nil
            }

            guard httpResponse.statusCode == 200 else { return nil }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseData = json["responseData"] as? [String: Any],
               let translatedText = responseData["translatedText"] as? String,
               !translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let result = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
                // 过滤 MyMemory 常见的未命中提示
                if result.contains("MYMEMORY WARNING:") {
                    return nil
                }
                return result
            }
        } catch {
            Logger.debug("[MyMemory] Request failed or timed out: \(error)")
        }

        return nil
    }
}
