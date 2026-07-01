//
//  ColorUtils.swift
//  来自 handoff「SwiftUI 松鼠 SVG 动画」。
//  十六进制构造 + 颜色插值(进度弧在相邻阶段配色间渐变)+ 明暗判断。
//

import SwiftUI
import UIKit

extension Color {
    init(hex: UInt) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8)  & 0xFF) / 255,
                  blue:  Double( hex        & 0xFF) / 255,
                  opacity: 1)
    }

    /// 在 self 与 other 之间线性插值,t ∈ 0...1。
    func lerp(to other: Color, _ t: Double) -> Color {
        let a = UIColor(self), b = UIColor(other)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let f = CGFloat(max(0, min(1, t)))
        return Color(.sRGB,
                     red:   Double(ar + (br - ar) * f),
                     green: Double(ag + (bg - ag) * f),
                     blue:  Double(ab + (bb - ab) * f),
                     opacity: 1)
    }

    var isDark: Bool {
        let c = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r * 0.299 + g * 0.587 + b * 0.114) < 0.55
    }
}
