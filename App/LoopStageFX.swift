import SwiftUI

/// Per-stage ambient particles layered over the mascot, matching the reference art:
/// • waking → golden 4-point sparkle stars (renewal / "autophagy complete")
/// • autophagy → soft white "healing" motes (sparkles + puffs) drifting around the curled body
/// Every other stage draws nothing. Fully procedural Canvas, no assets.
struct LoopStageFX: View {
    let stage: LoopStage
    let box: CGFloat

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                switch stage {
                case .waking:    drawStars(&ctx, size: size, t: t)
                case .autophagy: drawMotes(&ctx, size: size, t: t)
                default:         break
                }
            }
        }
        .frame(width: box, height: box)
        .allowsHitTesting(false)
    }

    /// Deterministic pseudo-random in 0..1 from a seed (stable per frame, no Math.random).
    private func rnd(_ s: Int) -> Double { let x = sin(Double(s) * 12.9898) * 43758.5453; return x - floor(x) }

    // 苏醒:绕松鼠一圈金色四角星,大小不一、各自闪烁(顶部偏多,呼应参考图)。
    private func drawStars(_ ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let cx = size.width / 2, cy = size.height / 2
        let k = size.width / 300
        let gold = Color(hex: 0xFFC95A)
        let n = 10
        for i in 0..<n {
            let ang = Double(i) / Double(n) * 2 * .pi + rnd(i) * 0.7
            let rad = size.width * (0.30 + rnd(i * 3 + 1) * 0.15)
            let x = cx + CGFloat(cos(ang)) * rad
            let y = cy + CGFloat(sin(ang)) * rad - size.height * 0.05      // 略偏上
            let tw = (sin(t * 2.0 + rnd(i * 7) * 6.28) + 1) / 2            // 0..1 闪烁
            let big = rnd(i * 5) < 0.4                                     // 少数大星,其余小点
            let r = (big ? 9 : 4) * (0.5 + 0.9 * CGFloat(tw)) * k
            ctx.fill(star(CGPoint(x: x, y: y), r), with: .color(gold.opacity(0.35 + 0.6 * tw)))
        }
    }

    // 自噬:绕蜷睡松鼠的柔白自愈光点 —— 圆绒球 + 小星交替,缓慢上飘 + 轻闪。
    // 暖米底上纯白会糊掉,所以往外圈铺(多落在背景上)、提亮、并描一圈淡金描边让它跳出来。
    private func drawMotes(_ ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let cx = size.width / 2, cy = size.height / 2
        let k = size.width / 300
        let white = Color(hex: 0xFFFFFF)
        let halo = Color(hex: 0xF2C879)                                   // 淡金描边
        let n = 12
        for i in 0..<n {
            let ang = Double(i) / Double(n) * 2 * .pi + rnd(i) * 0.9
            let drift = (t * 0.12 + rnd(i * 3 + 2)).truncatingRemainder(dividingBy: 1)   // 0..1 缓升
            let rad = size.width * (0.30 + rnd(i * 5 + 1) * 0.16)         // 外圈,落在米底上
            let x = cx + CGFloat(cos(ang)) * rad
            let y = cy + CGFloat(sin(ang)) * rad - CGFloat(drift) * size.height * 0.10
            let tw = (sin(t * 1.4 + rnd(i * 9) * 6.28) + 1) / 2
            let a = (0.50 + 0.45 * tw) * (1 - drift * 0.4)
            if rnd(i * 11) < 0.45 {
                let r = (3.5 + 3.5 * CGFloat(tw)) * k                      // 绒球
                let rect = CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)
                ctx.stroke(Path(ellipseIn: rect.insetBy(dx: -1, dy: -1)), with: .color(halo.opacity(a * 0.5)), lineWidth: 1.2 * k)
                ctx.fill(Path(ellipseIn: rect), with: .color(white.opacity(a)))
            } else {
                let r = (3 + 3.5 * CGFloat(tw)) * k                        // 小星
                ctx.fill(star(CGPoint(x: x, y: y), r * 1.25), with: .color(halo.opacity(a * 0.45)))
                ctx.fill(star(CGPoint(x: x, y: y), r), with: .color(white.opacity(a)))
            }
        }
    }

    /// A small 4-point sparkle centred at `c` with radius `r`.
    private func star(_ c: CGPoint, _ r: CGFloat) -> Path {
        var p = Path(); let n = r * 0.35
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + n, y: c.y - n))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + n, y: c.y + n))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - n, y: c.y + n))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - n, y: c.y - n))
        return p
    }
}
