import AVFoundation
import AppKit

@MainActor
final class AudioPlayerManager: ObservableObject {
    static let shared = AudioPlayerManager()

    // 核心修复：必须作为类的长生命周期属性持有，坚决不能写成局部变量，防止被 ARC 瞬间销毁
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    /// 播放在线音频 URL 字符串
    func playOnlineAudio(from urlString: String, fallbackWord: String = "") {
        guard let url = URL(string: urlString) else {
            if !fallbackWord.isEmpty {
                speakOffline(fallbackWord)
            }
            return
        }
        playOnlineAudio(from: url, fallbackWord: fallbackWord)
    }

    /// 播放在线 URL
    func playOnlineAudio(from url: URL, fallbackWord: String = "") {
        Logger.debug(" [AudioPlayerManager] 🎵 Playing online MP3: \(url)")
        let item = AVPlayerItem(url: url)
        self.playerItem = item

        if player == nil {
            player = AVPlayer(playerItem: item)
        } else {
            player?.replaceCurrentItem(with: item)
        }

        player?.seek(to: .zero)
        player?.play()
    }

    /// 统一播放入口：优先播放 URL，否则使用兜底
    func play(word: String, audioURL: URL? = nil) {
        if let url = audioURL {
            playOnlineAudio(from: url, fallbackWord: word)
            return
        }

        // 尝试 Youdao/Oxford 通用流
        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
        if let encoded = cleanWord.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let onlineURL = URL(string: "https://dict.youdao.com/dictvoice?audio=\(encoded)&type=2") {
            playOnlineAudio(from: onlineURL, fallbackWord: cleanWord)
            return
        }

        speakOffline(cleanWord)
    }

    /// 离线 Apple Neural TTS 发音兜底
    private func speakOffline(_ text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        Logger.debug(" [AudioPlayerManager] 🗣 Fallback to Apple Neural TTS: \(cleanText)")
        let utterance = AVSpeechUtterance(string: cleanText)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.48
        synthesizer.speak(utterance)
    }
}
