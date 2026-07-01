import WidgetKit
import SwiftUI

struct FastProvider: TimelineProvider {
    func placeholder(in context: Context) -> FastEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (FastEntry) -> Void) {
        completion(current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FastEntry>) -> Void) {
        let e = current()
        // Re-read at the next transition; the timer text ticks on its own until then.
        completion(Timeline(entries: [e], policy: .after(e.windowEnd)))
    }

    private func current() -> FastEntry {
        guard let s = SharedStore.readSnapshot() else { return .sample }
        return FastEntry(date: .now, phase: Phase(rawValue: s.phaseRaw) ?? .eating,
                         windowStart: s.windowStart, windowEnd: s.windowEnd)
    }
}

struct FastStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FastStatusWidget", provider: FastProvider()) { entry in
            WidgetFamilyReader(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("断食进度")
        .description("一眼看现在是断食还是进食、还剩多久。")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .systemSmall])
    }
}

/// Reads the live widget family from the environment and hands it to the shared view.
private struct WidgetFamilyReader: View {
    @Environment(\.widgetFamily) private var family
    let entry: FastEntry
    var body: some View { FastWidgetView(entry: entry, family: family) }
}
