import SwiftUI

/// The metabolic mascot. Swapped from flat sprites to the handoff design
/// "SwiftUI 松鼠 SVG 动画": a calibrated SVG pose that breathes, ringed by the
/// AutophagyRing. Unlike the handoff demo (which auto-loops on a free clock),
/// the stage and arc here are driven by the *real* fasting progress.
struct MascotView: View {
    let display: DisplayState
    let now: Date
    var style: MascotStyle = .classic

    @State private var stageEnteredAt: Double = 0

    private var progress: Double {
        let total = display.end.timeIntervalSince(display.start)
        guard total > 0 else { return 0 }
        return max(now.timeIntervalSince(display.start) / total, 0)   // uncapped: overtime stays in waking
    }
    private var remaining: TimeInterval { display.end.timeIntervalSince(now) }
    private var fasting: Bool { display.phase == .fasting }

    // progress → metabolic stage (illustrative, not a medical measurement).
    // Returns the LoopStage plus the fraction travelled *within* that stage, so the
    // ring arc can sweep toward the active node exactly like the handoff loop.
    private var resolved: (stage: LoopStage, frac: Double) {
        guard fasting else { return (.feeding, min(max(progress, 0), 1)) }   // eating window
        switch progress {
        case ..<0.12: return (.satiated,  progress / 0.12)
        case ..<0.5:  return (.digesting, (progress - 0.12) / 0.38)
        case ..<0.9:  return (.autophagy, (progress - 0.5) / 0.4)
        default:      return (.waking,    min((progress - 0.9) / 0.1, 1))
        }
    }
    private var stage: LoopStage { resolved.stage }
    /// Arc fraction so the sweep lands on the active node: one fifth per stage.
    private var ringProgress: Double {
        (Double(stage.rawValue) + min(max(resolved.frac, 0), 1)) / 5
    }

    // Keep the app's richer metabolic caption (its own voice) over the stage.
    private var caption: String {
        if !fasting { return "觅食 · 进食窗口" }
        switch progress {
        case ..<0.12: return "刚吃饱 · 血糖上升"
        case ..<0.5:  return "消化中 · 用糖供能"
        case ..<0.9:  return "深度蛰眠 · 开始燃脂"
        default:      return "唤醒 · 自噬启动 ✨"
        }
    }

    private let box: CGFloat = 300

    // Squash-and-rebound pulse that masks the pose swap on a stage change —
    // ported from the vector skin's squash-loop technique (see 松鼠循环动画
    // handoff), retimed to fire once per real stage transition instead of a
    // free-running clock. Classic style stays a plain crossfade (returns 1,1).
    private func squash(elapsed: Double) -> (CGFloat, CGFloat) {
        guard style == .vector, elapsed >= 0, elapsed < 0.42 else { return (1, 1) }
        func smooth(_ x: Double) -> Double { let c = max(0, min(1, x)); return c * c * (3 - 2 * c) }
        let u = elapsed / 0.42
        let sq = smooth(1 - u)
        let reb = abs(u - 0.55) < 0.35 ? smooth(1 - abs(u - 0.55) / 0.35) : 0
        return (CGFloat(1 + 0.16 * sq - 0.05 * reb), CGFloat(1 - 0.24 * sq + 0.08 * reb))
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(caption)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(stage.color)
                .contentTransition(.opacity)
                .animation(.easeInOut, value: caption)

            ZStack {
                glow
                AutophagyRing(progress: min(ringProgress, 1),
                              activeIndex: stage.rawValue,
                              arcColor: stage.color,
                              box: box)
                // Continuous clock drives the breathing; opacity cross-fades the pose on stage change.
                // ForEach needs an explicit ZStack to centre — a bare ForEach as TimelineView's
                // content doesn't stack-align, which flings the pose outside the ring.
                TimelineView(.animation) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let (sx, sy) = squash(elapsed: t - stageEnteredAt)
                    ZStack {
                        ForEach(LoopStage.allCases) { p in
                            SquirrelPoseView(phase: p, stage: box * 320 / 460, time: t, intensity: 1, style: style)
                                .opacity(p == stage ? 1 : 0)
                                .animation(.easeInOut(duration: style == .vector ? 0.16 : 0.6), value: stage)
                        }
                    }
                    .frame(width: box, height: box)
                    .scaleEffect(x: sx, y: sy, anchor: UnitPoint(x: LoopStage.targetCenter, y: LoopStage.targetFeet))
                }

                // Per-stage particles in front of the squirrel: waking → gold stars,
                // autophagy → white healing motes. Other stages draw nothing.
                LoopStageFX(stage: stage, box: box)
            }
            .frame(width: box, height: box)
            .onChange(of: stage) { _, _ in stageEnteredAt = Date().timeIntervalSinceReferenceDate }

            Text(remaining > 0 ? hms(remaining) : "已达成 🎉")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(remaining > 0
                 ? (fasting ? "预计 \(time(display.end)) 完成" : "距下次断食")
                 : (fasting ? "超出 \(hms(-remaining))" : "进食窗口已过"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // Soft amber glow behind the squirrel — the handoff's ambient backing.
    private var glow: some View {
        Circle()
            .fill(RadialGradient(
                gradient: Gradient(colors: [Color(hex: 0xF7C483).opacity(0.55),
                                            Color(hex: 0xF7C483).opacity(0)]),
                center: .center, startRadius: 0, endRadius: box * 300 / 460 / 2))
            .frame(width: box * 300 / 460, height: box * 300 / 460)
            .offset(y: -box * 0.03)
    }

    private func hms(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
    private func time(_ d: Date) -> String { d.formatted(date: .omitted, time: .shortened) }
}
