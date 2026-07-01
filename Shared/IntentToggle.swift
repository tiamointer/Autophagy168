import Foundation
import SwiftData
import WidgetKit

/// Cross-process toggle used by the Control Center control and App Shortcut, which run
/// in the widget/extension process — so it operates directly on the shared app-group store,
/// then writes the snapshot (via the same `currentDisplay` logic as the app) + reloads widgets.
@MainActor
enum IntentToggle {
    /// `sideEffects: false` mutates the store only (no snapshot / notifications / Live Activity /
    /// widget reload) — used by the launch self-check so it never clobbers the user's real state.
    @discardableResult
    static func run(container: ModelContainer? = nil, sideEffects: Bool = true) async -> Bool {
        let ctx = (container ?? SharedStore.makeContainer()).mainContext
        let schedule = Schedule.load()
        if let active = activeSession(ctx) {
            active.end = .now
        } else {
            ctx.insert(FastSession(start: .now, targetHours: Double(schedule.fastDurationHours)))
        }
        try? ctx.save()
        let running = activeSession(ctx) != nil
        if sideEffects { await sync(ctx: ctx, schedule: schedule) }
        return running
    }

    static func set(fasting: Bool, container: ModelContainer? = nil, sideEffects: Bool = true) async {
        let ctx = (container ?? SharedStore.makeContainer()).mainContext
        let schedule = Schedule.load()
        let active = activeSession(ctx)
        if fasting, active == nil {
            ctx.insert(FastSession(start: .now, targetHours: Double(schedule.fastDurationHours)))
        } else if !fasting, let active {
            active.end = .now
        }
        try? ctx.save()
        if sideEffects { await sync(ctx: ctx, schedule: schedule) }
    }

    private static func activeSession(_ ctx: ModelContext) -> FastSession? {
        (try? ctx.fetch(FetchDescriptor<FastSession>(predicate: #Predicate { $0.end == nil })))?.first
    }

    /// Mirror the foreground app's side effects so a background toggle (Control Center / Action
    /// Button / Siri) doesn't leave the lock-screen + notch countdown and the reminders stuck on
    /// the old window. Previously this only wrote the snapshot + reloaded widgets — the Live
    /// Activity and notifications kept showing the already-elapsed eating countdown.
    private static func sync(ctx: ModelContext, schedule: Schedule) async {
        let all = (try? ctx.fetch(FetchDescriptor<FastSession>())) ?? []
        let disp = currentDisplay(sessions: all, schedule: schedule, now: .now)
        SharedStore.writeSnapshot(StatusSnapshot(phaseRaw: disp.phase.rawValue,
                                                 windowStart: disp.start, windowEnd: disp.end))
        FastNotifier.reschedule(phase: disp.phase, windowEnd: disp.end,
                                fastHours: schedule.fastDurationHours, now: .now)
        await LiveActivityController.sync(phase: disp.phase, windowStart: disp.start, windowEnd: disp.end)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
