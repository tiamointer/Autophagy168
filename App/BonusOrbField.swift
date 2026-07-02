import SwiftUI

/// 蚂蚁森林式的悬浮能量球，绕松鼠环内悬浮，点击收集。
/// 球的身份 = 全局 earned 序号（collected..<collected+visible）：可见球是连续序号，
/// `index % 8` 槽位必不重叠，位置跨重渲染/重启稳定。状态全是计数器，没有球实体。
struct BonusOrbField: View {
    let collected: Int        // 首个可见球的全局序号
    let available: Int
    let box: CGFloat          // 300，与 MascotView 同
    let onCollect: () -> Void

    private static let maxVisible = 8

    var body: some View {
        let visible = min(available, Self.maxVisible)
        ZStack {
            ForEach(collected..<(collected + visible), id: \.self) { index in
                Orb(index: index, box: box)
                    .position(orbPosition(index))
                    .onTapGesture { onCollect() }
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale(scale: 1.6).combined(with: .opacity)))
            }
        }
        .frame(width: box, height: box)
        .animation(.spring(duration: 0.35), value: collected)
        .animation(.spring(duration: 0.45), value: available)
        .sensoryFeedback(.impact(weight: .light), trigger: collected)
    }

    /// Deterministic pseudo-random in 0..1 (same trick as LoopStageFX).
    private func rnd(_ s: Int) -> Double { let x = sin(Double(s) * 12.9898) * 43758.5453; return x - floor(x) }

    /// 槽角 -67.5° + 45°×(index%8) ± 8° jitter；半径 0.30–0.36×box（90–108pt）。
    /// 球径 36 → 外缘 ≤126pt，避开 128pt 虚线轨道与外圈标签。
    private func orbPosition(_ index: Int) -> CGPoint {
        let slot = index % Self.maxVisible
        let ang = (-67.5 + 45 * Double(slot) + (rnd(index * 7 + 1) - 0.5) * 16) * .pi / 180
        let rad = box * (0.30 + rnd(index * 3 + 2) * 0.06)
        return CGPoint(x: box / 2 + CGFloat(cos(ang)) * rad,
                       y: box / 2 + CGFloat(sin(ang)) * rad)
    }
}

/// 单颗金球：径向渐变 + 软金阴影 + "+1"，自带缓慢上下浮动。
private struct Orb: View {
    let index: Int
    let box: CGFloat
    @State private var bobbing = false

    private var jitter: Double { let x = sin(Double(index) * 12.9898) * 43758.5453; return x - floor(x) }

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    gradient: Gradient(colors: [Color(hex: 0xFFE3A0), Color(hex: 0xFFC95A)]),
                    center: UnitPoint(x: 0.35, y: 0.3), startRadius: 2, endRadius: 22))
            Circle()
                .stroke(Color(hex: 0xF2C879).opacity(0.9), lineWidth: 1)
            Text("+1")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: 0x8A5A18))
        }
        .frame(width: 36, height: 36)
        .shadow(color: Color(hex: 0xFFC95A).opacity(0.55), radius: 6)
        .contentShape(Circle().inset(by: -6))
        .offset(y: bobbing ? -4 : 4)
        .onAppear {
            // repeatForever bob instead of a second TimelineView — MascotView already runs one.
            withAnimation(.easeInOut(duration: 1.6 + jitter * 0.6).repeatForever(autoreverses: true)) {
                bobbing = true
            }
        }
    }
}

#Preview {
    BonusOrbField(collected: 2, available: 5, box: 300, onCollect: {})
        .background(Color(.secondarySystemBackground))
}
