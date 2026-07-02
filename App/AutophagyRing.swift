//
//  AutophagyRing.swift
//  来自 handoff「SwiftUI 松鼠 SVG 动画」(类型 Phase 改名为 LoopStage)。
//
//  环形进度盘:虚线轨道 + 扫动的进度弧(颜色随相位渐变)+ 五个阶段节点
//  与中文标签,激活节点放大并染色。几何完全按舞台比例缩放。
//

import SwiftUI

struct AutophagyRing: View {
    let progress: Double      // 0...1
    let activeIndex: Int
    let arcColor: Color
    let box: CGFloat          // 容器边长(参照值 460)
    // 五个节点在环上的比例位置(0..1,顶部起顺时针)。按阶段真实时长摆放,
    // 弧长与时间严格成正比;弧扫到节点的时刻 = 阶段切换时刻。
    let nodeFractions: [Double]

    private var k: CGFloat { box / 460 }          // 缩放因子
    private var center: CGFloat { box / 2 }
    private var rNode: CGFloat { box * 196 / 460 } // 节点所在半径
    private var rLabel: CGFloat { box * 230 / 460 } // 标签所在半径

    private func pos(_ i: Int, radius: CGFloat) -> CGPoint {
        let a = (-90 + 360 * nodeFractions[i]) * .pi / 180
        return CGPoint(x: center + CGFloat(cos(a)) * radius,
                       y: center + CGFloat(sin(a)) * radius)
    }

    /// 短阶段的标签会贴近下一个节点(如「苏醒」与顶部「觅食」);与下一节点
    /// 角距 <20° 时该标签外推一档,避免重叠(18:6 / 20:4 档尤其需要)。
    private func labelRadius(_ i: Int) -> CGFloat {
        let next = nodeFractions[(i + 1) % nodeFractions.count]
        let gap = (next - nodeFractions[i] + 1).truncatingRemainder(dividingBy: 1) * 360
        return gap < 20 ? rLabel + 22 * k : rLabel
    }

    var body: some View {
        ZStack {
            // 虚线轨道
            Circle()
                .stroke(Color(hex: 0xE7D4B6),
                        style: StrokeStyle(lineWidth: 3 * k, lineCap: .round, dash: [2 * k, 9 * k]))
                .frame(width: rNode * 2, height: rNode * 2)
                .position(x: center, y: center)

            // 进度弧
            Circle()
                .trim(from: 0, to: CGFloat(max(0.0001, progress)))
                .stroke(arcColor, style: StrokeStyle(lineWidth: 6 * k, lineCap: .round))
                .frame(width: rNode * 2, height: rNode * 2)
                .rotationEffect(.degrees(-90))
                .position(x: center, y: center)

            // 节点 + 标签
            ForEach(LoopStage.allCases) { p in
                let i = p.rawValue
                let on = i == activeIndex
                let np = pos(i, radius: rNode)
                let lp = pos(i, radius: labelRadius(i))

                Circle().fill(p.color).opacity(on ? 0.18 : 0)
                    .frame(width: 24 * k, height: 24 * k)
                    .position(np)

                Circle().fill(on ? p.color : Color(hex: 0xE7D4B6))
                    .frame(width: (on ? 16 : 10) * k, height: (on ? 16 : 10) * k)
                    .position(np)
                    .animation(.easeInOut(duration: 0.5), value: on)

                Text(p.cn)
                    .font(.loopCN(size: (on ? 18 : 15) * k))
                    .foregroundColor(on ? p.color : Color(hex: 0xB9966B))
                    .position(lp)
                    .animation(.easeInOut(duration: 0.5), value: on)
            }
        }
        .frame(width: box, height: box)
    }
}
