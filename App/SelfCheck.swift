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
        bonus()
        bonusFlow()
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

    /// Orb math edges + threshold clamping + persistence round-trip.
    private static func bonus() {
        let goal = Date(timeIntervalSinceReferenceDate: 800_000_000)
        func at(_ m: Double) -> Date { goal.addingTimeInterval(m * 60) }
        assert(BonusEnergy.orbsEarned(goalDate: goal, now: at(-1)) == 0, "before goal → 0 orbs")
        assert(BonusEnergy.orbsEarned(goalDate: goal, now: goal) == 0, "at goal → 0 orbs")
        assert(BonusEnergy.orbsEarned(goalDate: goal, now: at(29.99)) == 0, "goal+29m59s → 0 orbs")
        assert(BonusEnergy.orbsEarned(goalDate: goal, now: at(30)) == 1, "goal+30m → 1 orb")
        assert(BonusEnergy.orbsEarned(goalDate: goal, now: at(75)) == 2, "goal+75m → 2 orbs")
        assert(BonusEnergy.orbsAvailable(goalDate: goal, collected: 1, now: at(75)) == 1)
        assert(BonusEnergy.orbsAvailable(goalDate: goal, collected: 5, now: at(30)) == 0,
               "over-collected (clock rollback) must clamp to 0, never negative")

        // persistence round-trip, restoring whatever was there
        let saved = BonusEnergy.load()
        BonusEnergy(balance: 7, threshold: 25).save()
        assert(BonusEnergy.load() == BonusEnergy(balance: 7, threshold: 25), "energy must persist")
        BonusEnergy(balance: 3, threshold: 999).save()
        assert(BonusEnergy.load().threshold == BonusEnergy.thresholdRange.upperBound, "threshold clamps on load")
        saved.save()
    }

    /// Collect → settle-on-end → threshold crossing → redeem, all through the vm
    /// with side effects off so the user's real balance is never touched.
    private static func bonusFlow() {
        let container = try! ModelContainer(
            for: FastSession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let vm = FastingViewModel()
        vm.sideEffectsEnabled = false
        vm.energy = .default

        // Fast started 16h + 61.7min ago → 2 orbs ripe.
        container.mainContext.insert(
            FastSession(start: .now.addingTimeInterval(-(16 * 3600 + 61.7 * 60)), targetHours: 16))
        vm.bind(container.mainContext)
        assert(vm.availableOrbs == 2, "16h+61.7m overtime → 2 orbs, got \(vm.availableOrbs)")

        vm.collectOrb()
        assert(vm.energy.balance == 1 && vm.availableOrbs == 1 && vm.collectedThisSession == 1,
               "collect: balance 1 / available 1 / collected 1")

        vm.toggle() // end fast → leftover orb auto-settles
        assert(vm.energy.balance == 2, "settle on end: balance should be 2, got \(vm.energy.balance)")
        assert(vm.availableOrbs == 0 && !vm.display.hasRunningFast, "ended fast → no orbs")

        // Threshold crossing fires exactly on the increase that crosses.
        vm.energy = BonusEnergy(balance: 9, threshold: 10)
        vm.showCheatMealEarned = false
        container.mainContext.insert(
            FastSession(start: .now.addingTimeInterval(-(16 * 3600 + 31 * 60)), targetHours: 16))
        vm.tick()
        vm.collectOrb()
        assert(vm.energy.canRedeem && vm.showCheatMealEarned, "crossing 9→10 must celebrate")

        vm.redeemCheatMeal()
        assert(vm.energy.balance == 0, "redeem subtracts threshold")
        vm.redeemCheatMeal()
        assert(vm.energy.balance == 0, "redeem below threshold is a no-op, never negative")
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
