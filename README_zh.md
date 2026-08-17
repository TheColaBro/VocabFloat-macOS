# VocabFloat

极简、沉浸式的 macOS 英文阅读伴侣，专注于主动词汇习得与生成式笔记沉淀。

[English](README.md) | [简体中文]

---

## 主动阅读闭环 (The Active Reading Cycle)

1. **阅读与查词**：在系统原生「预览」中阅读英文 PDF。按 `⌥D` 查词，轻按 `Space` 聆听发音，按 `⏎` 一键入库。
2. **高亮启发**：阅读中划线高亮真正给你启发、触动思考的关键句子。
3. **提取笔记 (`⌥N`)**：按下 `⌥N` 自动落盘并结构化提取高亮文段，文末自动汇总本次所有生词。
4. **生成式沉淀**：打开 Markdown 笔记，围绕高亮句子用自己的语言进行扩展重构。
5. **独立复习**：随时单独打开专用生词本，进行词汇复习与长期记忆巩固。

---

## 快捷键速查

| 快捷键 | 功能 |
| :--- | :--- |
| `⌥D` (Option + D) | 全局查词与语境例句提取 |
| `Space` | 浮窗打开时播放原生真人发音 |
| `⏎` (Enter) | 将单词存入独立生词本并关闭浮窗 |
| `⌥N` (Option + N) | 自动保存 Preview 并提取 PDF 高亮笔记 + 本篇生词 |
| `Esc` | 关闭浮窗 |

---

## 核心特性

- **全局极速查词 (`⌥D`)**：在系统预览、Safari、Chrome 等任意应用中双击单词，即时浮出音标、精炼释义与原句语境。
- **空格发音与回车入库**：浮窗内按 `Space` 触发离线原生发音，按 `⏎` 一键将单词归入独立生词本。
- **9 行物理窗口分句**：结合 Apple 原生 NLP 分句引擎，自动抹平跨行连字符，完整捕获完整例句。
- **PDF 像素级高亮提取 (`⌥N`)**：自动向 Preview 发送保存信号，基于四边形切片算法精准提取高亮内容并打包生词。
- **独立生词本与随时复习**：提供全局统一的生词本（网页版与 Markdown 版），支持一键导出 CSV 闪卡。
- **开机自启动选项**：菜单栏内置原生开机自启开关，随时自由开启或关闭。
- **自定义存储目录**：支持自定义笔记与生词本存储路径，便于本地知识库统一管理。
- **纯净轻量与隐私**：100% 本地运算，无任何用户追踪或遥测，常驻仅占约 40MB 内存。

---

## 安装方法

### 通过 Homebrew 安装 (推荐)

```bash
brew tap TheColaBro/tap
brew install --cask vocabfloat
```

### 直接下载安装

1. 从 [Releases](https://github.com/TheColaBro/Vocabfloat/releases/tag/v1.0.0) 下载 `VocabFloat.zip`；
2. 解压并将 `VocabFloat.app` 移动至 `/Applications` 文件夹；
3. 若遇系统拦截提示，在终端执行：
   ```bash
   xattr -cr /Applications/VocabFloat.app
   ```
   *(或在 **系统设置 -> 隐私与安全性** 中点击 **仍要打开**)*。

---

## 开源许可与致谢

本项目采用 [MIT License](LICENSE) 开源协议。

- **词典数据集**：基于 Skywind3000 开源的 [ECDICT](https://github.com/skywind3000/ECDICT) 词库 (MIT License)。
- **语音发音**：基于 Apple macOS 原生语音合成系统 (AVSpeechSynthesizer / System Neural Voices)。
- **分句引擎**：基于 Apple 官方 NaturalLanguage 框架 (NLTokenizer)。
- **PDF 渲染与几何解析**：基于 Apple 官方 PDFKit 框架。
