import Foundation

/// 自噬能量：断食超过目标后，每 30 分钟长出一颗可收集的能量球（1 球 = 1 点）。
/// 攒到阈值可兑换一顿放纵餐。球数是纯派生值（超时时长 − 已收集），这里只存两个整数。
struct BonusEnergy: Equatable {
    var balance: Int          // 能量余额：收集加、兑换减
    var threshold: Int        // 兑换一顿放纵餐需要的点数

    static let `default` = BonusEnergy(balance: 0, threshold: 10)
    static let orbInterval: TimeInterval = 1800
    static let thresholdRange = 5...50

    var canRedeem: Bool { balance >= threshold }

    /// 超过目标后已长出的球数：floor(超时 / 30min)，不为负。
    static func orbsEarned(goalDate: Date, now: Date) -> Int {
        Int(max(0, now.timeIntervalSince(goalDate)) / orbInterval)
    }

    /// 当前可收集的球数：已长出 − 本次已收集，钳位 ≥0（时钟回拨安全）。
    static func orbsAvailable(goalDate: Date, collected: Int, now: Date) -> Int {
        max(0, orbsEarned(goalDate: goalDate, now: now) - collected)
    }

    private static let kBalance = "bonusBalance"
    private static let kThreshold = "bonusThreshold"

    static func load() -> BonusEnergy {
        let d = SharedStore.defaults
        let balance = d.object(forKey: kBalance) != nil ? d.integer(forKey: kBalance) : 0
        let threshold = d.object(forKey: kThreshold) != nil ? d.integer(forKey: kThreshold) : 10
        return BonusEnergy(balance: max(0, balance),
                           threshold: threshold.clamped(to: thresholdRange))
    }

    func save() {
        let d = SharedStore.defaults
        d.set(balance, forKey: Self.kBalance)
        d.set(threshold, forKey: Self.kThreshold)
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
