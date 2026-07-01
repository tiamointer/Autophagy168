import WidgetKit
import SwiftUI
import AppIntents

/// Control Center / Lock Screen control: a one-tap fasting toggle that works without opening the app.
struct FastControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "FastControl") {
            ControlWidgetToggle(
                "断食",
                isOn: Self.currentlyFasting,
                action: SetFastingIntent()
            ) { isOn in
                Label(isOn ? "断食中" : "进食中", systemImage: isOn ? "flame.fill" : "fork.knife")
            }
        }
        .displayName("断食开关")
        .description("一键开始 / 结束断食，无需打开 App。")
    }

    private static var currentlyFasting: Bool {
        (SharedStore.readSnapshot()?.phaseRaw ?? Phase.eating.rawValue) == Phase.fasting.rawValue
    }
}
