import WidgetKit
import SwiftUI

struct FastEntry: TimelineEntry {
    let date: Date
    let phase: Phase
    let windowStart: Date
    let windowEnd: Date

    static let sample = FastEntry(date: .now, phase: .fasting,
                                  windowStart: .now.addingTimeInterval(-9 * 3600),
                                  windowEnd: .now.addingTimeInterval(7 * 3600))
    static let sampleEating = FastEntry(date: .now, phase: .eating,
                                        windowStart: .now.addingTimeInterval(-2 * 3600),
                                        windowEnd: .now.addingTimeInterval(6 * 3600))
}

/// Presentation only — family passed explicitly so the in-app gallery can render every size.
struct FastWidgetView: View {
    let entry: FastEntry
    let family: WidgetFamily

    private var fasting: Bool { entry.phase == .fasting }
    private var progress: Double {
        let total = entry.windowEnd.timeIntervalSince(entry.windowStart)
        guard total > 0 else { return 0 }
        return min(max(entry.date.timeIntervalSince(entry.windowStart) / total, 0), 1)
    }
    private var tint: Color { fasting ? .orange : .green }

    /// The squirrel silhouette as a tintable template glyph (replaces the old SF symbols).
    private func glyph(_ size: CGFloat) -> some View {
        Image("squirrel_glyph").renderingMode(.template)
            .resizable().scaledToFit().frame(width: size, height: size)
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: progress) { glyph(13) }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(tint)

        case .accessoryInline:
            Text("\(fasting ? "断食" : "进食") · \(entry.windowEnd, style: .timer)")

        case .accessoryRectangular:
            HStack(spacing: 8) {
                Gauge(value: progress) { glyph(13) }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(tint)
                VStack(alignment: .leading) {
                    Text(fasting ? "断食中" : "进食中").font(.headline)
                    Text("剩 \(entry.windowEnd, style: .timer)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

        default: // systemSmall
            VStack(spacing: 8) {
                ZStack {
                    Circle().stroke(tint.opacity(0.18), lineWidth: 10)
                    Circle().trim(from: 0, to: progress)
                        .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    glyph(30).foregroundStyle(tint)
                }
                .frame(width: 70, height: 70)
                Text(fasting ? "断食中" : "进食中").font(.subheadline.weight(.semibold))
                Text(entry.windowEnd, style: .timer)
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}
