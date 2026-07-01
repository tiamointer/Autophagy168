import SwiftUI

/// Lock-screen / banner presentation for the Live Activity. Uses timerInterval primitives
/// so it self-animates without the app pushing updates.
struct LiveLockScreenView: View {
    let phase: Phase
    let windowStart: Date
    let windowEnd: Date

    private var fasting: Bool { phase == .fasting }
    private var tint: Color { fasting ? .orange : .green }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image("squirrel_glyph").renderingMode(.template)
                    .resizable().scaledToFit().frame(width: 18, height: 18)
                    .foregroundStyle(tint)
                Text(fasting ? "断食中" : "进食中")
                    .font(.headline)
                    .foregroundStyle(tint)
                Spacer()
                Text(timerInterval: windowStart...windowEnd, countsDown: true)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .frame(maxWidth: 90, alignment: .trailing)
            }
            ProgressView(timerInterval: windowStart...windowEnd, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(tint)
        }
    }
}
