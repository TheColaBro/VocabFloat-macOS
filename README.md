# VocabFloat

A quiet, distraction-free macOS companion for active English reading, vocabulary acquisition, and PDF note extraction.

[English] | [简体中文](README_zh.md)

---

## The Active Reading Cycle

1. **Read & Resolve**: Read English PDFs in Preview. Press `⌥D` to inspect words, tap `Space` for pronunciation, and press `⏎` to save words.
2. **Highlight**: Mark meaningful sentences that trigger insight as you read.
3. **Extract (`⌥N`)**: Press `⌥N` to auto-save and synthesize clean Markdown with all session vocabulary.
4. **Reflect**: Open Markdown notes and expand on your highlighted thoughts in your own words.
5. **Review**: Open your dedicated vocabulary store anytime for independent memory reinforcement.

---

## Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `⌥D` (Option + D) | Global word lookup & sentence context |
| `Space` | Play native neural pronunciation |
| `⏎` (Enter) | Save word into vocabulary store & close card |
| `⌥N` (Option + N) | Auto-save Preview & extract notes + vocabulary |
| `Esc` | Dismiss floating card |

---

## Features

- **Global Lookup (`⌥D`)**: Double-click any word across Preview, Safari, Chrome, or other applications for phonetic transcriptions, definitions, and sentence context.
- **Space Audio & Enter Save**: Tap `Space` inside the popup for offline pronunciation, and press `⏎` to silently collect words.
- **9-Line Context Tokenizer**: Captures complete multi-line sentences using physical coordinate slicing and Apple NaturalLanguage NLP.
- **Pixel-Precise PDF Notes**: Extracts only marked highlights via quadrilateral point slicing, avoiding broken sentence fragments.
- **Dedicated Vocabulary Store**: Access your vocabulary store via local web dashboard or Markdown, with one-click flashcard CSV export.
- **Custom Note Directory**: Specify custom destination folders for seamless local organization.
- **Launch at Login**: Optional native login item toggle directly from the status bar menu.
- **Lightweight & Private**: Fully local execution, zero telemetry, ~40MB memory footprint.

---

## Installation

### Via Homebrew (Recommended)

```bash
brew tap TheColaBro/tap
brew install --cask vocabfloat
```

### Direct Download

1. Download `VocabFloat.zip` from [Releases](https://github.com/TheColaBro/Vocabfloat/releases/tag/v1.0.0).
2. Unzip and move `VocabFloat.app` to your `/Applications` directory.
3. If macOS Gatekeeper blocks opening:
   ```bash
   xattr -cr /Applications/VocabFloat.app
   ```
   *(Or navigate to **System Settings -> Privacy & Security** and click **Open Anyway**).*

---

## License & Acknowledgements

This project is licensed under the [MIT License](LICENSE).

- **Dictionary Data**: Built upon [ECDICT](https://github.com/skywind3000/ECDICT) by Skywind3000 (MIT License).
- **Speech Synthesis**: Native macOS Apple Speech Synthesis API (AVSpeechSynthesizer / System Voices).
- **Sentence Tokenization**: Apple NaturalLanguage Framework (NLTokenizer).
- **PDF Engine**: Apple PDFKit Framework.
