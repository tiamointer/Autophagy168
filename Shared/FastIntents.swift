import AppIntents

/// One-tap toggle, reused by the App Shortcut (Siri / Spotlight / Action Button).
struct FastToggleIntent: AppIntent {
    static var title: LocalizedStringResource = "切换断食"
    static var description = IntentDescription("开始或结束当前断食。")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let running = await IntentToggle.run()
        return .result(dialog: IntentDialog(running ? "已开始断食 🔥" : "已结束断食，开始进食 🍽️"))
    }
}

/// Bool value intent backing the Control Center toggle (works even on the Lock Screen).
struct SetFastingIntent: SetValueIntent {
    static var title: LocalizedStringResource = "断食开关"

    @Parameter(title: "断食中")
    var value: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        await IntentToggle.set(fasting: value)
        return .result()
    }
}
