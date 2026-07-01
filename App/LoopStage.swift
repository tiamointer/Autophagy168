//
//  LoopStage.swift
//  自噬循环的五个姿态 —— 来自 handoff「SwiftUI 松鼠 SVG 动画」。
//
//  原 handoff 里这个类型叫 `Phase`,但本工程已有 `enum Phase`(fasting/eating,
//  见 FastingEngine.swift),为避免冲突改名为 `LoopStage`。其余数据(配色、文案、
//  脚部锚点、校准缩放、呼吸曲线)与 handoff 原样一致。
//

import SwiftUI

enum LoopStage: Int, CaseIterable, Identifiable {
    case feeding, satiated, digesting, autophagy, waking
    var id: Int { rawValue }

    /// 资源名(Assets 里的矢量 PDF)。
    var asset: String {
        switch self {
        case .feeding:   return "squirrel-feed"
        case .satiated:  return "squirrel-full"
        case .digesting: return "squirrel-digest"
        case .autophagy: return "squirrel-sleep"
        case .waking:    return "squirrel-wake"
        }
    }

    /// 资源名,按选中的松鼠皮肤(经典/矢量)分流;经典皮肤沿用 `asset`。
    func asset(style: MascotStyle) -> String {
        guard style == .vector else { return asset }
        switch self {
        case .feeding:   return "squirrel-vec-feed"
        case .satiated:  return "squirrel-vec-full"
        case .digesting: return "squirrel-vec-digest"
        case .autophagy: return "squirrel-vec-sleep"
        case .waking:    return "squirrel-vec-wake"
        }
    }

    var cn:   String { ["进食", "饱足", "消化", "自噬", "苏醒"][rawValue] }
    var en:   String { ["FEEDING", "SATIATED", "DIGESTING", "AUTOPHAGY", "WAKING"][rawValue] }
    var desc: String { ["摄入能量", "能量充盈", "静息代谢", "自我更新", "重启循环"][rawValue] }

    var color: Color {
        switch self {
        case .feeding:   return Color(hex: 0xE8924A)
        case .satiated:  return Color(hex: 0xE0A53C)
        case .digesting: return Color(hex: 0xC9803C)
        case .autophagy: return Color(hex: 0xA85C6B)
        case .waking:    return Color(hex: 0xE07B43)
        }
    }

    // 共同的对齐目标(占舞台尺寸的比例):水平居中、脚部落在统一基线。
    static let targetCenter: CGFloat = 0.5
    static let targetFeet:   CGFloat = 0.8375   // = 268 / 320

    // 脚部锚点 —— 在原始 1254×1254 矢量画布中的归一化坐标。
    // 校准与呼吸的所有缩放/旋转都绕这一点进行(等价于 CSS 的 transform-origin)。
    var anchor: UnitPoint {
        switch self {
        case .feeding:   return UnitPoint(x: 663.0/1254, y: 1100.0/1254)
        case .satiated:  return UnitPoint(x: 686.0/1254, y: 1077.0/1254)
        case .digesting: return UnitPoint(x: 683.0/1254, y: 1139.0/1254)
        case .autophagy: return UnitPoint(x: 606.0/1254, y: 1050.0/1254)
        case .waking:    return UnitPoint(x: 714.0/1254, y: 1136.0/1254)
        }
    }

    // 每个姿态的微调缩放,使五种体型观感一致(测量自原图包围盒)。
    var calibrationScale: CGFloat {
        switch self {
        case .feeding:   return 1.00
        case .satiated:  return 0.99
        case .digesting: return 0.93
        case .autophagy: return 1.06
        case .waking:    return 1.00
        }
    }

    // MARK: - 呼吸 / Breathing

    struct Breath {
        var scaleX: CGFloat = 1
        var scaleY: CGFloat = 1
        var rotation: Angle = .zero
        var offsetY: CGFloat = 0   // 占舞台尺寸的比例
    }

    /// 给定连续时间 t(秒)与强度 amp,返回该姿态当前的呼吸变换。
    func breath(at t: Double, intensity amp: Double) -> Breath {
        func wave(_ period: Double) -> Double { (1 - cos(2 * .pi * t / period)) / 2 } // 0→1→0
        func smooth(_ x: Double) -> Double { let c = max(0, min(1, x)); return c * c * (3 - 2 * c) }
        let a = amp

        switch self {
        case .feeding:          // 轻快咀嚼:小幅上下 + 纵向起伏
            let w = wave(0.9)
            return Breath(scaleY: CGFloat(1 + 0.013 * a * w), offsetY: CGFloat(-0.0094 * a * w))
        case .satiated:         // 满足的深呼吸 + 轻微 squash & stretch
            let w = wave(3.4)
            return Breath(scaleX: CGFloat(1 - 0.008 * a * w), scaleY: CGFloat(1 + 0.022 * a * w))
        case .digesting:        // 困倦摇摆 + 缓慢呼吸
            let w = wave(3.8)
            return Breath(scaleY: CGFloat(1 + 0.016 * a * w),
                          rotation: .degrees(-0.7 * a + 1.4 * a * w))
        case .autophagy:        // 蜷睡:最慢最深的腹式呼吸
            let w = wave(4.7)
            return Breath(scaleX: CGFloat(1 + 0.01 * a * w), scaleY: CGFloat(1 + 0.032 * a * w))
        case .waking:           // 伸懒腰:快速上挺 → 回落 → 停顿
            let period = 2.9
            let u = t.truncatingRemainder(dividingBy: period) / period
            var s = 0.0
            if u < 0.28 { s = smooth(u / 0.28) }
            else if u < 0.55 { s = smooth(1 - (u - 0.28) / 0.27) }
            return Breath(scaleY: CGFloat(1 + 0.045 * a * s), offsetY: CGFloat(-0.0219 * a * s))
        }
    }
}
