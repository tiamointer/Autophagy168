//
//  Fonts.swift
//  来自 handoff「SwiftUI 松鼠 SVG 动画」。
//  中文用圆体「ZCOOL KuaiLe」(若已加入工程),否则 .custom 自动回退系统字体。
//

import SwiftUI

extension Font {
    /// 中文显示字体。
    static func loopCN(size: CGFloat) -> Font {
        .custom("ZCOOLKuaiLe-Regular", size: size)   // 缺失则回退系统字体
    }
    /// 拉丁文 / 数字(圆体系统字)。
    static func loopLatin(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
