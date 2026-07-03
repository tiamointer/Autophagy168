import SwiftUI
import SwiftData
import WidgetKit

@MainActor
@Observable
final class FastingViewModel {
    var schedule = Schedule.load()
    var energy = BonusEnergy.load()   // settable so SelfCheck can reset it
    private(set) var display = DisplayState.placeholder
    private(set) var completedCount = 0
    private(set) var lastDuration: TimeInterval?
    private(set) var availableOrbs = 0
    private(set) var collectedThisSession = 0
    var showCheatMealEarned = false

    /// Off during self-check so the test path doesn't write snapshots / schedule notifications / reload widgets.
    var sideEffectsEnabled = true

    private var context: ModelContext?
    private var lastKey = ""

    func bind(_ ctx: ModelContext) {
        context = ctx
        refresh(now: Date(), force: true)
    }

    func tick() { refresh(now: Date(), force: false) }

    /// Call on return to foreground. Live Activities can only be REQUESTED while the
    /// app is frontmost — a sync that failed in the background (or was dropped on
    /// suspension) heals itself here by forcing the side-effect pass.
    func foregroundRefresh() { refresh(now: Date(), force: true) }

    /// One-tap: start a fast now, or end the running one. Each tap re-anchors today's cycle.
    func toggle() {
        guard let ctx = context else { return }
        if let active = fetchActive() {
            // Settle uncollected orbs BEFORE ending, so no earned energy is lost.
            let leftover = BonusEnergy.orbsAvailable(goalDate: active.goalDate,
                                                     collected: active.bonusCollected, now: Date())
            if leftover > 0 {
                active.bonusCollected += leftover
                addEnergy(leftover)
            }
            active.end = Date()
        } else {
            ctx.insert(FastSession(start: Date(), targetHours: Double(schedule.fastDurationHours)))
        }
        try? ctx.save()
        refresh(now: Date(), force: true)
    }

    func setSchedule(_ s: Schedule) {
        schedule = s
        s.save()
        refresh(now: Date(), force: true)
    }

    // MARK: - Bonus energy

    /// Collect one floating orb: credit the session and the balance.
    func collectOrb() {
        guard let ctx = context, let active = fetchActive(),
              BonusEnergy.orbsAvailable(goalDate: active.goalDate,
                                        collected: active.bonusCollected, now: Date()) > 0 else { return }
        active.bonusCollected += 1
        addEnergy(1)
        try? ctx.save()
        refresh(now: Date(), force: false)
    }

    /// Spend `threshold` points on a cheat meal. Balance never goes negative.
    func redeemCheatMeal() {
        guard energy.canRedeem else { return }
        energy.balance -= energy.threshold
        persistEnergy()
    }

    func setEnergyThreshold(_ n: Int) {
        energy.threshold = min(max(n, BonusEnergy.thresholdRange.lowerBound),
                               BonusEnergy.thresholdRange.upperBound)
        persistEnergy()
    }

    /// Celebrate only when an INCREASE crosses the threshold — editing the threshold
    /// or sitting above it never re-fires the alert.
    private func addEnergy(_ n: Int) {
        let was = energy.canRedeem
        energy.balance += n
        if !was && energy.canRedeem { showCheatMealEarned = true }
        persistEnergy()
    }

    private func persistEnergy() {
        if sideEffectsEnabled { energy.save() }
    }

    // MARK: - Core

    private func refresh(now: Date, force: Bool) {
        guard let ctx = context else { return }
        let all = (try? ctx.fetch(FetchDescriptor<FastSession>())) ?? []

        let disp = currentDisplay(sessions: all, schedule: schedule, now: now)
        display = disp

        // Orb counts are pure derivations — recomputed every tick, restart-safe.
        let active = all.first { $0.isActive }
        availableOrbs = active.map {
            BonusEnergy.orbsAvailable(goalDate: $0.goalDate, collected: $0.bonusCollected, now: now)
        } ?? 0
        collectedThisSession = active?.bonusCollected ?? 0

        completedCount = all.filter { $0.completed }.count
        lastDuration = all.filter { !$0.isActive }
            .max { ($0.end ?? .distantPast) < ($1.end ?? .distantPast) }?.duration

        // Side effects only when the phase/window actually changes (or forced).
        let key = "\(disp.phase.rawValue)@\(Int(disp.end.timeIntervalSince1970))"
        if sideEffectsEnabled && (force || key != lastKey) {
            lastKey = key
            SharedStore.writeSnapshot(StatusSnapshot(phaseRaw: disp.phase.rawValue,
                                                     windowStart: disp.start, windowEnd: disp.end))
            FastNotifier.reschedule(phase: disp.phase, windowEnd: disp.end,
                                    fastHours: schedule.fastDurationHours, now: now)
            Task { await LiveActivityController.sync(phase: disp.phase, windowStart: disp.start, windowEnd: disp.end) }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func fetchActive() -> FastSession? {
        guard let ctx = context else { return nil }
        let d = FetchDescriptor<FastSession>(predicate: #Predicate { $0.end == nil })
        return (try? ctx.fetch(d))?.first
    }
}
