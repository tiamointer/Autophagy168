import Foundation

enum Phase: Int { case fasting = 0, eating = 1 }

struct WindowState {
    var phase: Phase
    var windowStart: Date
    var windowEnd: Date
}

/// Pure schedule math: given a clock time, which window are we in and when does it end.
struct FastingEngine {
    var schedule: Schedule
    var calendar = Calendar.current

    func state(at now: Date) -> WindowState {
        let eatStart = at(hour: schedule.eatStartHour, now: now)
        let eatEnd = eatStart.addingTimeInterval(Double(schedule.eatDurationHours) * 3600)

        if now >= eatStart && now < eatEnd {
            return WindowState(phase: .eating, windowStart: eatStart, windowEnd: eatEnd)
        }
        if now < eatStart {
            // before today's eating window: fasting since yesterday's eat end
            let prevEatEnd = eatEnd.addingTimeInterval(-86_400)
            return WindowState(phase: .fasting, windowStart: prevEatEnd, windowEnd: eatStart)
        }
        // after today's eat end: fasting until tomorrow's eat start
        let nextEatStart = eatStart.addingTimeInterval(86_400)
        return WindowState(phase: .fasting, windowStart: eatEnd, windowEnd: nextEatStart)
    }

    private func at(hour: Int, now: Date) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
    }
}
