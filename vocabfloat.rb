cask "vocabfloat" do
  version "1.0.0"
  sha256 "b3aec5c30b357d1050f688a8f6cb835294ee79c5f2d96f84ea9f16f3aceabfe2"

  url "https://github.com/TheColaBro/Vocabfloat/releases/download/v#{version}/VocabFloat.zip"
  name "VocabFloat"
  desc "Minimalist macOS companion for global vocabulary lookup and PDF highlight extraction"
  homepage "https://github.com/TheColaBro/Vocabfloat"

  depends_on macos: :sonoma

  app "VocabFloat.app"

  zap trash: [
    "~/Library/Application Support/VocabFloat",
    "~/Library/Preferences/com.thecolabro.vocabfloat.plist",
  ]
end
