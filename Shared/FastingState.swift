import Foundation

/// What the main screen / widget draws right now.
struct DisplayState {
    var phase: Phase
    var start: Date          // current window/session start
    var end: Date            // goal / window end
    var hasRunningFast: Bool // a fast is actively running (button becomes "结束断食")

    static let placeholder = DisplayState(phase: .eating, start: .now,
                                          end: .now.addingTimeInterval(8 * 3600), hasRunningFast: false)
}

/// Single source of truth for the live state. Actual sessions drive everything; the fixed
/// schedule is only a bootstrap for a brand-new user with no history. Crucially, the eating
/// window anchors to WHEN THE LAST FAST ENDED (+ eat duration) — never snaps back to a fixed
/// clock time — so the user's taps actually control today's cycle.
func currentDisplay(sessions: [FastSession], schedule: Schedule, now: Date) -> DisplayState {
    if let active = sessions.first(where: { $0.isActive }) {
        // Fasting: driven by the running session (counts past goal as overtime).
        return DisplayState(phase: .fasting, start: active.start, end: active.goalDate, hasRunningFast: true)
    }
    if let lastEnd = sessions.compactMap({ $0.end }).max() {
        // Eating: anchored to the moment the last fast ended.
        let eatEnd = lastEnd.addingTimeInterval(Double(schedule.eatDurationHours) * 3600)
        return DisplayState(phase: .eating, start: lastEnd, end: eatEnd, hasRunningFast: false)
    }
    // No history yet: bootstrap from the schedule so a fresh launch shows something sensible.
    let st = FastingEngine(schedule: schedule).state(at: now)
    return DisplayState(phase: st.phase, start: st.windowStart, end: st.windowEnd, hasRunningFast: false)
}
