import SwiftUI

@MainActor
final class FloatingCardViewModel: ObservableObject {
    @Published var word: String = ""
    @Published var phonetic: String = ""
    @Published var translation: String = ""
    @Published var context: String = ""
    @Published var contextTranslation: String = ""
    @Published var isTranslatingContext: Bool = false
    @Published var isSaved: Bool = false
    @Published var sourceApp: String = "Preview"
    @Published var sourceDocument: String = ""

    func update(selection: CapturedSelection, entry: (word: String, phonetic: String, translation: String)?) {
        self.word = entry?.word ?? selection.word
        self.phonetic = entry?.phonetic ?? ""
        self.translation = entry?.translation ?? "正在查询释义…"
        self.context = selection.context
        self.contextTranslation = ""
        self.isSaved = false
        self.sourceApp = selection.sourceApp
        self.sourceDocument = selection.sourceDocument

        // 异步整句翻译
        if !selection.context.isEmpty && selection.context != selection.word {
            self.isTranslatingContext = true
            Task { [weak self] in
                guard let self = self else { return }
                if let trans = await DictionaryService.shared.translateText(selection.context) {
                    self.contextTranslation = trans
                } else {
                    self.contextTranslation = "(网络翻译不可用)"
                }
                self.isTranslatingContext = false
                FloatingPanel.shared.adjustHeightToFit()
            }
        }
    }

    func playSound() {
        AudioPlayerManager.shared.play(word: self.word)
    }

    func saveToVocabulary() {
        guard !word.isEmpty, !isSaved else { return }
        VocabularyStore.shared.save(
            word: word,
            phonetic: phonetic,
            translation: translation,
            context: context,
            contextTranslation: contextTranslation,
            sourceApp: sourceApp,
            sourceDocument: sourceDocument.isEmpty ? nil : sourceDocument
        )
        isSaved = true
    }
}

struct FloatingCardView: View {
    @ObservedObject var model: FloatingCardViewModel
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: 生词 (.primary, .bold) + 音标 + 发音 + 来源 + 关闭按钮
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(model.word)
                    .font(.system(size: 23, weight: .bold, design: .default))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .layoutPriority(1)

                if !model.phonetic.isEmpty {
                    Text("/\(model.phonetic)/")
                        .font(.system(size: 13.5, weight: .regular, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Button {
                    model.playSound()
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                Text(model.sourceDocument.isEmpty ? model.sourceApp : model.sourceDocument)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.gray.opacity(0.6))
                        .padding(4)
                }
                .buttonStyle(.plain)
            }

            // 核心释义区
            VStack(alignment: .leading, spacing: 4) {
                Text(model.translation)
                    .font(.system(size: 14.5, weight: .regular))
                    .lineSpacing(3.5)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 原句上下文 (Apple HIG 标准 3pt 贴合细线)
            if !model.context.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 5) {
                        HighlightHelper.highlightSwiftUI(sentence: model.context, targetWord: model.word)
                            .lineSpacing(3.5)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)

                        if !model.contextTranslation.isEmpty {
                            Text(model.contextTranslation)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(model.contextTranslation.contains("不可用") ? Color.gray.opacity(0.6) : Color.secondary)
                                .lineSpacing(2.5)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                                .padding(.top, 2)
                        } else if model.isTranslatingContext {
                            Text("正在翻译原句…")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.leading, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(nsColor: .quaternaryLabelColor))
                            .frame(width: 3),
                        alignment: .leading
                    )
                }
            }

            // Footer
            HStack {
                Spacer()
                Button {
                    model.saveToVocabulary()
                } label: {
                    Text(model.isSaved ? "已加入生词本" : "加入生词本 (⏎)")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(model.isSaved ? Color.secondary : Color.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}
