import Foundation

/// The fixed 16:8 schedule. Only the eating-window start + its length are configurable;
/// the 16h fasting window is just the rest of the day.
struct Schedule: Equatable {
    var eatStartHour: Int       // 0-23, when the eating window opens
    var eatDurationHours: Int   // default 8

    static let `default` = Schedule(eatStartHour: 12, eatDurationHours: 8)

    var fastDurationHours: Int { 24 - eatDurationHours }   // 16
    var eatEndHour: Int { (eatStartHour + eatDurationHours) % 24 }

    private static let kStart = "eatStartHour"
    private static let kDur = "eatDurationHours"

    static func load() -> Schedule {
        let d = SharedStore.defaults
        guard d.object(forKey: kStart) != nil else { return .default }
        let dur = d.object(forKey: kDur) != nil ? d.integer(forKey: kDur) : 8
        return Schedule(eatStartHour: d.integer(forKey: kStart), eatDurationHours: dur)
    }

    func save() {
        let d = SharedStore.defaults
        d.set(eatStartHour, forKey: Self.kStart)
        d.set(eatDurationHours, forKey: Self.kDur)
    }
}
