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
            record(count: 0, enabled: false)
            return
        }
        let state = FastActivityAttributes.ContentState(
            phaseRaw: phase.rawValue, windowStart: windowStart, windowEnd: windowEnd)
        let content = ActivityContent(state: state, staleDate: windowEnd)

        let acts = Activity<FastActivityAttributes>.activities
        if acts.isEmpty {
            do {
                _ = try Activity.request(attributes: FastActivityAttributes(), content: content)
            } catch {
                print("[LiveActivity] request failed: \(error)")
            }
        } else {
            // Update EVERY activity, not just `.first`. Nothing ever ended these, so they
            // accumulated across launches; updating only the first meant a stale leftover
            // could be the one actually on the lock screen — the "tapped but 息屏 didn't
            // change" bug. Refresh them all, then collapse duplicates down to one.
            for act in acts { await act.update(content) }
            for extra in acts.dropFirst() {
                await extra.end(nil, dismissalPolicy: .immediate)
            }
        }
        record(count: Activity<FastActivityAttributes>.activities.count, enabled: true)
    }

    static func endAll() {
        for act in Activity<FastActivityAttributes>.activities {
            Task { await act.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private static func record(count: Int, enabled: Bool) {
        #if DEBUG
        SharedStore.defaults.set(count, forKey: "liveActivityCount")
        SharedStore.defaults.set(enabled, forKey: "liveActivitiesEnabled")
        #endif
    }
}
