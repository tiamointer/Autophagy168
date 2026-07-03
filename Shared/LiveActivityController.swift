import Foundation
import ActivityKit

/// Starts / updates / ends the fasting Live Activity. Per the chosen design it is short-lived
/// and trigger-based: started/updated whenever the app is active or the phase changes, so the
/// 8h Live Activity cap never bites (we never need a continuous 16h activity).
@MainActor
enum LiveActivityController {
    /// Awaitable so background App Intents can ensure the update lands before the process
    /// suspends. The `areActivitiesEnabled` guard also keeps this safe to call from the
    /// Control-Center extension (where starting an activity isn't permitted): it early-returns.
    static func sync(phase: Phase, windowStart: Date, windowEnd: Date) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            record(count: 0, enabled: false, note: "disabled")
            return
        }
        let state = FastActivityAttributes.ContentState(
            phaseRaw: phase.rawValue, windowStart: windowStart, windowEnd: windowEnd)
        let content = ActivityContent(state: state, staleDate: windowEnd)

        // Reinstalls and the system's 8h cap leave ZOMBIE activities in the list:
        // ended/dismissed instances accept update() as a silent no-op, and their mere
        // presence used to satisfy the isEmpty check so a fresh activity was never
        // requested — the lock screen kept counting down an old window (the "ended
        // eating early but 息屏 stayed on the old countdown" bug). So: update the
        // first ALIVE activity, sweep everything else, request anew if none is alive.
        var updatedAlive = false
        for act in Activity<FastActivityAttributes>.activities {
            let alive = act.activityState == .active || act.activityState == .stale
            if alive && !updatedAlive {
                await act.update(content)
                updatedAlive = true
            } else {
                await act.end(nil, dismissalPolicy: .immediate)
            }
        }
        if !updatedAlive {
            do {
                _ = try Activity.request(attributes: FastActivityAttributes(), content: content)
            } catch {
                print("[LiveActivity] request failed: \(error)")
                record(count: 0, enabled: true, note: "request failed: \(error)")
                return
            }
        }
        record(count: Activity<FastActivityAttributes>.activities.count, enabled: true,
               note: updatedAlive ? "updated" : "requested")
    }

    static func endAll() {
        for act in Activity<FastActivityAttributes>.activities {
            Task { await act.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private static func record(count: Int, enabled: Bool, note: String = "") {
        #if DEBUG
        SharedStore.defaults.set(count, forKey: "liveActivityCount")
        SharedStore.defaults.set(enabled, forKey: "liveActivitiesEnabled")
        SharedStore.defaults.set("\(Date.now.formatted(date: .omitted, time: .standard)) \(note)",
                                 forKey: "liveActivityLastSync")
        #endif
    }
}
