import Foundation

/// One calendar day's fasting outcome.
struct DayStat: Identifiable {
    let date: Date          // start of day
    let hours: Double       // hours fasted that day (from the fast crediting to this day)
    let completed: Bool     // hit target
    var id: Date { date }
}

struct StatsSummary {
    var days: [DayStat]          // chronological, one per day that has a fast
    var currentStreak: Int
    var longestStreak: Int
    var completedCount: Int
    var longestFastHours: Double
    var avgFastHours: Double
    var thisWeekRate: Double     // completed / days-with-fast this 7d
    var lastWeekRate: Double

    static let empty = StatsSummary(days: [], currentStreak: 0, longestStreak: 0,
                                    completedCount: 0, longestFastHours: 0, avgFastHours: 0,
                                    thisWeekRate: 0, lastWeekRate: 0)
}

/// Pure aggregation over finished sessions. A fast is credited to the calendar day it STARTED.
struct StatsEngine {
    var calendar = Calendar.current

    func summarize(_ sessions: [FastSession], now: Date) -> StatsSummary {
        let finished = sessions.filter { !$0.isActive }
        guard !finished.isEmpty else { return .empty }

        // Best fast per starting day.
        var byDay: [Date: (hours: Double, completed: Bool)] = [:]
        for s in finished {
            let day = calendar.startOfDay(for: s.start)
            let hours = s.duration / 3600
            let cur = byDay[day]
            if cur == nil || hours > cur!.hours {
                byDay[day] = (hours, s.completed)
            }
        }
        let days = byDay.keys.sorted().map { DayStat(date: $0, hours: byDay[$0]!.hours, completed: byDay[$0]!.completed) }

        // Streak: consecutive days (ending today/yesterday) that hit target.
        let completedDays = Set(byDay.filter { $0.value.completed }.keys)
        let current = streakEndingToday(completedDays, now: now)
        let longest = longestRun(completedDays)

        let completedCount = completedDays.count
        let longest1 = finished.map { $0.duration / 3600 }.max() ?? 0
        let avg = finished.map { $0.duration / 3600 }.reduce(0, +) / Double(finished.count)

        let thisWeek = rate(completedDays: completedDays, allDays: Set(byDay.keys), from: daysAgo(7, now), to: now)
        let lastWeek = rate(completedDays: completedDays, allDays: Set(byDay.keys), from: daysAgo(14, now), to: daysAgo(7, now))

        return StatsSummary(days: days, currentStreak: current, longestStreak: longest,
                            completedCount: completedCount, longestFastHours: longest1, avgFastHours: avg,
                            thisWeekRate: thisWeek, lastWeekRate: lastWeek)
    }

    private func daysAgo(_ n: Int, _ now: Date) -> Date {
        calendar.date(byAdding: .day, value: -n, to: calendar.startOfDay(for: now))!
    }

    private func streakEndingToday(_ completed: Set<Date>, now: Date) -> Int {
        var day = calendar.startOfDay(for: now)
        // allow the streak to count from yesterday if today has no fast yet
        if !completed.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day)! }
        var n = 0
        while completed.contains(day) {
            n += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return n
    }

    private func longestRun(_ completed: Set<Date>) -> Int {
        guard !completed.isEmpty else { return 0 }
        var best = 0
        for d in completed {
            // count a run only from its start (previous day not completed)
            let prev = calendar.date(byAdding: .day, value: -1, to: d)!
            if completed.contains(prev) { continue }
            var n = 0, cur = d
            while completed.contains(cur) {
                n += 1
                cur = calendar.date(byAdding: .day, value: 1, to: cur)!
            }
            best = max(best, n)
        }
        return best
    }

    private func rate(completedDays: Set<Date>, allDays: Set<Date>, from: Date, to: Date) -> Double {
        let inRange = allDays.filter { $0 >= from && $0 < to }
        guard !inRange.isEmpty else { return 0 }
        let hit = inRange.filter { completedDays.contains($0) }.count
        return Double(hit) / Double(inRange.count)
    }
}
