import AppKit
import Foundation

@MainActor
enum UpdateChecker {
    static let currentVersion = "1.0.0"
    static let repoURL = "https://api.github.com/repos/TheColaBro/Vocabfloat/releases/latest"
    static let releasesPage = "https://github.com/TheColaBro/Vocabfloat/releases"

    /// 检查更新。isUserInitiated 为 true 时（用户手动点击菜单），如果有或没有更新都会弹窗提示；为 false 时（启动时静默检查），只在发现新版本时提示。
    static func checkForUpdates(isUserInitiated: Bool = false) {
        guard let url = URL(string: repoURL) else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("VocabFloat-App", forHTTPHeaderField: "User-Agent")

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
                    if isUserInitiated {
                        showAlert(title: "检查更新失败", message: "暂时无法连接到 GitHub 检查最新版本，请稍后重试。")
                    }
                    return
                }

                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    if isUserInitiated {
                        showAlert(title: "检查更新失败", message: "无法解析版本信息。")
                    }
                    return
                }

                let latestVersion = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                let body = (json["body"] as? String) ?? ""

                if isVersion(latestVersion, greaterThan: currentVersion) {
                    promptUpdateAvailable(latestVersion: latestVersion, releaseNotes: body)
                } else if isUserInitiated {
                    showAlert(title: "已是最新版本", message: "当前版本 v\(currentVersion) 已是最新版本。")
                }
            } catch {
                if isUserInitiated {
                    showAlert(title: "检查更新失败", message: error.localizedDescription)
                }
            }
        }
    }

    /// 语义化版本比对 (如 1.0.1 > 1.0.0)
    private static func isVersion(_ v1: String, greaterThan v2: String) -> Bool {
        return v1.compare(v2, options: .numeric) == .orderedDescending
    }

    private static func promptUpdateAvailable(latestVersion: String, releaseNotes: String) {
        let alert = NSAlert()
        alert.messageText = "发现新版本 VocabFloat v\(latestVersion)！"
        alert.informativeText = "当前版本：v\(currentVersion)\n\n是否前往 GitHub 下载更新？"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "立即前往下载")
        alert.addButton(withTitle: "稍后再说")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: releasesPage) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private static func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }
}
