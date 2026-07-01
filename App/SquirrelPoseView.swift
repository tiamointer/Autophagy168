//
//  SquirrelPoseView.swift
//  来自 handoff「SwiftUI 松鼠 SVG 动画」(类型 Phase 改名为 LoopStage)。
//
//  单个姿态:加载矢量图 → 脚部对齐校准 → 叠加原生呼吸动画。
//  所有变换都绕「脚部锚点」进行,五个姿态交叉淡入时始终站在同一基线、同一水平中心。
//

import SwiftUI

struct SquirrelPoseView: View {
    let phase: LoopStage
    let stage: CGFloat       // 舞台边长(正方形)
    let time: Double         // 连续时间(秒)
    let intensity: Double    // 呼吸强度

    var body: some View {
        let b = phase.breath(at: time, intensity: intensity)
        let anchor = phase.anchor
        let calibOffX = (LoopStage.targetCenter - anchor.x) * stage
        let calibOffY = (LoopStage.targetFeet   - anchor.y) * stage

        poseImage
            .frame(width: stage, height: stage)
            // —— 呼吸(内层,绕脚部)——
            .rotationEffect(b.rotation, anchor: anchor)
            .scaleEffect(x: b.scaleX, y: b.scaleY, anchor: anchor)
            .offset(y: b.offsetY * stage)
            // —— 校准对齐(外层,绕脚部)——
            .scaleEffect(phase.calibrationScale, anchor: anchor)
            .offset(x: calibOffX, y: calibOffY)
            .allowsHitTesting(false)
    }

    // 资源目录里的矢量 PDF(已勾选 Preserve Vector Data,任意放大不糊)。
    private var poseImage: some View {
        Image(phase.asset)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
    }
}
