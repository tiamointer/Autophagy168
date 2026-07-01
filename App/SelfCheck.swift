#if DEBUG
import Foundation
import SwiftData

/// Runnable launch-time checks. assert() aborts on failure, so if the app launches
/// at all, every check below passed. Pure / in-memory / restores any shared state it touches.
@MainActor
enum SelfCheck {
    static func run() {
        engine()
        schedule()
        session()
        notifier()
        eatingAnchor()
        viewModelToggle()
        stats()
        // intentToggle() is async (the intent API now awaits the Live Activity update); run it
        // detached with side effects off so it never touches the user's real notifications.
        Task { await intentToggle(); print("[SelfCheck] all passed") }
    }

    private static func engine() {
        let cal = Calendar(identifier: .gregorian)
        let e = FastingEngine(schedule: .default, calendar: cal) // eat 12–20
        func at(_ h: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: h))! }
        assert(e.state(at: at(13)).phase == .eating)
        assert(e.state(at: at(22)).phase == .fasting)
        assert(e.state(at: at(8)).phase == .fasting)
        let s = e.state(at: at(22))
        assert(abs(s.windowEnd.timeIntervalSince(s.windowStart) / 3600 - 16) < 0.001, "fast window must be 16h")
    }

    private static func schedule() {
        assert(Schedule.default.fastDurationHours == 16)
        assert(Schedule.default.eatEndHour == 20)
        // persistence round-trip, restoring whatever was there
        let saved = Schedule.load()
        Schedule(eatStartHour: 9, eatDurationHours: 8).save()
        assert(Schedule.load().eatStartHour == 9, "schedule must persist")
        saved.save()
    }

    private static func session() {
        let s = FastSession(start: .now.addingTimeInterval(-17 * 3600), end: .now, targetHours: 16)
        assert(s.completed, "17h fast vs 16h target should be completed")
        let short = FastSession(start: .now.addingTimeInterval(-2 * 3600), end: .now, targetHours: 16)
        assert(!short.completed, "2h fast should not be completed")
    }

    private static func notifier() {
        let cal = Calendar(identifier: .gregorian)
        func at(_ h: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: h))! }
        let fasting = FastNotifier.plan(phase: .fasting, windowEnd: at(12), fastHours: 16, now: at(4))
        assert(fasting.contains { $0.id == "fastComplete" }, "fasting should plan a completion reminder")
        let eating = FastNotifier.plan(phase: .eating, windowEnd: at(20), fastHours: 16, now: at(13))
        assert(eating.contains { $0.id == "fastingStart" }, "eating should plan a fasting-start reminder")
    }

    /// Regression for the reported bug: after a fast ends, the eating window must anchor to the
    /// END moment (+ eat duration), NOT snap back to the fixed schedule clock time.
    private static func eatingAnchor() {
        let cal = Calendar(identifier: .gregorian)
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 29, hour: 15))! // 15:00
        // Default schedule eats 12–20; user actually ended a fast at 15:00.
        let ended = FastSession(start: now.addingTimeInterval(-3 * 3600), end: now, targetHours: 16)
        let disp = currentDisplay(sessions: [ended], schedule: .default, now: now)
        assert(disp.phase == .eating, "no active fast → eating")
        let expected = now.addingTimeInterval(8 * 3600) // 23:00, NOT the schedule's 20:00
        assert(abs(disp.end.timeIntervalSince(expected)) < 1,
               "eating must anchor to lastEnd+8h (23:00), not fixed schedule 20:00")

        // And a running fast drives the window from its own start, ignoring the schedule.
        let active = FastSession(start: now, end: nil, targetHours: 16)
        let d2 = currentDisplay(sessions: [ended, active], schedule: .default, now: now)
        assert(d2.phase == .fasting && d2.hasRunningFast, "active session → fasting")
        assert(abs(d2.end.timeIntervalSince(now.addingTimeInterval(16 * 3600))) < 1,
               "fasting window = session.start + 16h")
    }

    private static func viewModelToggle() {
        let container = try! ModelContainer(
            for: FastSession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let vm = FastingViewModel()
        vm.sideEffectsEnabled = false
        vm.bind(container.mainContext)

        let before = vm.display.hasRunningFast
        vm.toggle()
        assert(vm.display.hasRunningFast != before, "toggle should flip the running state")
        vm.toggle()
        assert(vm.display.hasRunningFast == before, "double toggle should return to original")
    }

    /// The Control Center / Shortcut intent path runs on the same store logic.
    private static func intentToggle() async {
        let container = try! ModelContainer(
            for: FastSession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let a = await IntentToggle.run(container: container, sideEffects: false)
        let b = await IntentToggle.run(container: container, sideEffects: false)
        assert(a != b, "intent toggle should flip running state each call")
        await IntentToggle.set(fasting: true, container: container, sideEffects: false)
        await IntentToggle.set(fasting: true, container: container, sideEffects: false) // idempotent
        let cnt = (try? container.mainContext.fetch(
            FetchDescriptor<FastSession>(predicate: #Predicate { $0.end == nil })))?.count ?? 0
        assert(cnt == 1, "set(fasting:true) should leave exactly one running fast, got \(cnt)")
    }

    private static func stats() {
        let cal = Calendar(identifier: .gregorian)
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 13))!
        let today = cal.startOfDay(for: now)
        func fast(daysAgo i: Int, hours: Double) -> FastSession {
            let day = cal.date(byAdding: .day, value: -i, to: today)!
            let start = cal.date(bySettingHour: 20, minute: 0, second: 0, of: day)!
            return FastSession(start: start, end: start.addingTimeInterval(hours * 3600), targetHours: 16)
        }
        // completed days at -1,-2,-3 then a gap at -4 then -5,-6
        let sessions = [fast(daysAgo: 1, hours: 16), fast(daysAgo: 2, hours: 16.5), fast(daysAgo: 3, hours: 16),
                        fast(daysAgo: 5, hours: 17), fast(daysAgo: 6, hours: 16)]
        let s = StatsEngine(calendar: cal).summarize(sessions, now: now)
        assert(s.currentStreak == 3, "current streak should be 3, got \(s.currentStreak)")
        assert(s.longestStreak == 3, "longest streak should be 3, got \(s.longestStreak)")
        assert(s.completedCount == 5, "completed count should be 5, got \(s.completedCount)")
        assert(s.longestFastHours >= 16.9, "longest fast should be ~17h, got \(s.longestFastHours)")
    }
}
#endif
