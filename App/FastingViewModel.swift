import SwiftUI
import SwiftData
import WidgetKit

@MainActor
@Observable
final class FastingViewModel {
    var schedule = Schedule.load()
    private(set) var display = DisplayState.placeholder
    private(set) var completedCount = 0
    private(set) var lastDuration: TimeInterval?

    /// Off during self-check so the test path doesn't write snapshots / schedule notifications / reload widgets.
    var sideEffectsEnabled = true

    private var context: ModelContext?
    private var lastKey = ""

    func bind(_ ctx: ModelContext) {
        context = ctx
        refresh(now: Date(), force: true)
    }

    func tick() { refresh(now: Date(), force: false) }

    /// One-tap: start a fast now, or end the running one. Each tap re-anchors today's cycle.
    func toggle() {
        guard let ctx = context else { return }
        if let active = fetchActive() {
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

    // MARK: - Core

    private func refresh(now: Date, force: Bool) {
        guard let ctx = context else { return }
        let all = (try? ctx.fetch(FetchDescriptor<FastSession>())) ?? []

        let disp = currentDisplay(sessions: all, schedule: schedule, now: now)
        display = disp

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
