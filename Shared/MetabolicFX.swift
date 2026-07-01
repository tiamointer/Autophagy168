import SwiftUI

/// Ambient, progress-driven particle layer that narrates the metabolic stage behind the mascot:
/// digesting (food specks drift down & fade as food runs out) → fat-burning (embers rise) →
/// autophagy (sparkles twinkle). Eating shows a calm few crumbs. Fully procedural, no assets.
struct MetabolicFX: View {
    let phase: Phase
    let progress: Double   // 0..1+ within the current window

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let mode = Mode(phase: phase, progress: progress)
                for i in 0..<mode.count {
                    draw(particle: i, mode: mode, t: t, size: size, ctx: &ctx)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private enum Kind { case crumb, ember, sparkle }
    private struct Mode {
        let kind: Kind
        let count: Int
        let color: Color
        init(phase: Phase, progress: Double) {
            if phase == .eating {
                kind = .crumb; count = 4; color = .green
            } else if progress < 0.5 {
                // digesting: more crumbs early, fading to none as food is used up
                kind = .crumb
                count = max(0, Int((0.5 - progress) / 0.5 * 9))   // ~9 → 0
                color = .orange
            } else if progress < 0.9 {
                kind = .ember; count = 8; color = .orange
            } else {
                kind = .sparkle; count = 7; color = .purple
            }
        }
    }

    /// Deterministic pseudo-random in 0..1 from an integer seed (no Math.random; stable per frame).
    private func rnd(_ seed: Int) -> Double {
        let x = sin(Double(seed) * 12.9898) * 43758.5453
        return x - floor(x)
    }

    private func draw(particle i: Int, mode: Mode, t: Double, size: CGSize, ctx: inout GraphicsContext) {
        let cx = size.width / 2
        let phase01 = rnd(i)                       // per-particle phase offset
        let xJitter = (rnd(i * 7 + 1) - 0.5) * size.width * 0.6
        let speed = 0.25 + rnd(i * 3 + 2) * 0.35

        switch mode.kind {
        case .crumb:
            // drift downward from mid, fade out near bottom
            let cycle = (t * speed + phase01).truncatingRemainder(dividingBy: 1)
            let y = size.height * (0.35 + cycle * 0.5)
            let x = cx + xJitter * 0.7
            let alpha = (1 - cycle) * 0.7
            let r: CGFloat = 3 + CGFloat(rnd(i * 5)) * 2
            let rect = CGRect(x: x - r/2, y: y - r/2, width: r, height: r)
            ctx.fill(Path(roundedRect: rect, cornerRadius: r * 0.3),
                     with: .color(mode.color.opacity(alpha)))

        case .ember:
            // rise upward, flicker, fade near top
            let cycle = (t * speed + phase01).truncatingRemainder(dividingBy: 1)
            let y = size.height * (0.85 - cycle * 0.7)
            let sway = sin(t * 2 + Double(i)) * size.width * 0.04
            let x = cx + xJitter * 0.5 + sway
            let alpha = (1 - cycle) * 0.85
            let r: CGFloat = 4 - CGFloat(cycle) * 2
            let rect = CGRect(x: x - r/2, y: y - r/2, width: r, height: r)
            ctx.fill(Path(ellipseIn: rect),
                     with: .color(Color.orange.opacity(alpha)))
            ctx.fill(Path(ellipseIn: rect.insetBy(dx: r*0.3, dy: r*0.3)),
                     with: .color(Color.yellow.opacity(alpha)))

        case .sparkle:
            // twinkle in place around the mascot
            let x = cx + xJitter
            let y = size.height * (0.2 + rnd(i * 11) * 0.6)
            let tw = (sin(t * 2.2 + phase01 * 6.28) + 1) / 2      // 0..1 twinkle
            let r: CGFloat = 2 + CGFloat(tw) * 4
            ctx.fill(star(center: CGPoint(x: x, y: y), radius: r),
                     with: .color(mode.color.opacity(0.4 + tw * 0.5)))
        }
    }

    /// A small 4-point sparkle.
    private func star(center: CGPoint, radius r: CGFloat) -> Path {
        var p = Path()
        let n = r * 0.35
        p.move(to: CGPoint(x: center.x, y: center.y - r))
        p.addQuadCurve(to: CGPoint(x: center.x + r, y: center.y), control: CGPoint(x: center.x + n, y: center.y - n))
        p.addQuadCurve(to: CGPoint(x: center.x, y: center.y + r), control: CGPoint(x: center.x + n, y: center.y + n))
        p.addQuadCurve(to: CGPoint(x: center.x - r, y: center.y), control: CGPoint(x: center.x - n, y: center.y + n))
        p.addQuadCurve(to: CGPoint(x: center.x, y: center.y - r), control: CGPoint(x: center.x - n, y: center.y - n))
        return p
    }
}
