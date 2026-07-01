import ActivityKit
import WidgetKit
import SwiftUI

struct FastLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FastActivityAttributes.self) { context in
            LiveLockScreenView(phase: context.state.phase,
                               windowStart: context.state.windowStart,
                               windowEnd: context.state.windowEnd)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.25))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let fasting = context.state.phase == .fasting
            let tint: Color = fasting ? .orange : .green
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image("squirrel_glyph").renderingMode(.template)
                            .resizable().scaledToFit().frame(width: 16, height: 16)
                        Text(fasting ? "断食" : "进食")
                    }
                    .foregroundStyle(tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.windowStart...context.state.windowEnd, countsDown: true)
                        .monospacedDigit()
                        .frame(maxWidth: 80, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(timerInterval: context.state.windowStart...context.state.windowEnd,
                                 countsDown: false) {
                        Text(fasting ? "断食中" : "进食中")
                    } currentValueLabel: { EmptyView() }
                    .tint(tint)
                }
            } compactLeading: {
                Image("squirrel_glyph").renderingMode(.template)
                    .resizable().scaledToFit().frame(width: 20, height: 20)
                    .foregroundStyle(tint)
            } compactTrailing: {
                ProgressView(timerInterval: context.state.windowStart...context.state.windowEnd,
                             countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.circular)
                    .tint(tint)
                    .frame(width: 22)
            } minimal: {
                Image("squirrel_glyph").renderingMode(.template)
                    .resizable().scaledToFit().frame(width: 20, height: 20)
                    .foregroundStyle(tint)
            }
        }
    }
}
