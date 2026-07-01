#if DEBUG
import SwiftUI
import WidgetKit

/// In-app render of the widget views in every family, so the look can be verified
/// headlessly via a simulator screenshot (no Home/Lock screen interaction needed).
struct WidgetGallery: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("Widget Gallery").font(.headline).padding(.top, 12)

                item("accessoryRectangular（锁屏）", .accessoryRectangular, w: 170, h: 76)
                HStack(spacing: 28) {
                    item("circular 断食", .accessoryCircular, w: 76, h: 76)
                    item("circular 进食", .accessoryCircular, w: 76, h: 76, eating: true)
                }
                item("accessoryInline", .accessoryInline, w: 220, h: 30)
                HStack(spacing: 20) {
                    item("systemSmall 断食", .systemSmall, w: 150, h: 150)
                    item("systemSmall 进食", .systemSmall, w: 150, h: 150, eating: true)
                }

                Text("Live Activity 锁屏").font(.caption2).foregroundStyle(.secondary)
                LiveLockScreenView(phase: .fasting,
                                   windowStart: .now.addingTimeInterval(-9 * 3600),
                                   windowEnd: .now.addingTimeInterval(7 * 3600))
                    .padding()
                    .frame(width: 300)
                    .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 20))
                    .environment(\.colorScheme, .dark)
                LiveLockScreenView(phase: .eating,
                                   windowStart: .now.addingTimeInterval(-2 * 3600),
                                   windowEnd: .now.addingTimeInterval(6 * 3600))
                    .padding()
                    .frame(width: 300)
                    .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 20))
                    .environment(\.colorScheme, .dark)
            }
            .padding()
        }
    }

    private func item(_ title: String, _ family: WidgetFamily, w: CGFloat, h: CGFloat, eating: Bool = false) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            FastWidgetView(entry: eating ? .sampleEating : .sample, family: family)
                .padding(8)
                .frame(width: w, height: h)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 18))
        }
    }
}
#endif
