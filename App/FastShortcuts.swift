import AppIntents

/// Exposes the toggle to Siri / Spotlight / the Action Button.
struct FastShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FastToggleIntent(),
            phrases: [
                "在 \(.applicationName) 切换断食",
                "用 \(.applicationName) 开始断食"
            ],
            shortTitle: "切换断食",
            systemImageName: "flame.fill"
        )
    }
}
