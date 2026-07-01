#if DEBUG
import Foundation
import SwiftData

/// Deterministic 40-day history for screenshots / QA. Gated by the -seedHistory launch arg.
enum SampleData {
    @MainActor
    static func seed(into container: ModelContainer) {
        let ctx = container.mainContext
        if let all = try? ctx.fetch(FetchDescriptor<FastSession>()) {
            for s in all { ctx.delete(s) }
        }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        for i in 1...40 {
            let day = cal.date(byAdding: .day, value: -i, to: today)!
            let start = cal.date(bySettingHour: 20, minute: 0, second: 0, of: day)!
            let r = (i * 7) % 10
            if r == 3 || r == 8 { continue }                       // missed days → gaps
            let hours: Double = (r == 5) ? 12.5 : (r == 1 ? 14.0 : 16.0 + Double(i % 3) * 0.5)
            ctx.insert(FastSession(start: start, end: start.addingTimeInterval(hours * 3600), targetHours: 16))
        }
        try? ctx.save()
    }

    /// Seed a fast that started `hoursAgo` ago so the main screen shows a mid-fast mascot state.
    /// Wipes first — closing a prior active fast at its (future) goalDate would leave a stale
    /// future end-date that the eating-window anchor (max end) would wrongly latch onto.
    @MainActor
    static func seedActiveFast(into container: ModelContainer, hoursAgo: Double) {
        let ctx = container.mainContext
        if let all = try? ctx.fetch(FetchDescriptor<FastSession>()) { for s in all { ctx.delete(s) } }
        ctx.insert(FastSession(start: .now.addingTimeInterval(-hoursAgo * 3600), targetHours: 16))
        try? ctx.save()
    }

    /// Seed a clean EATING state: one completed fast that ended `endedHoursAgo` ago, nothing active.
    /// The eating window should anchor to that end (+ eat duration), proving the countdown is
    /// ≤ the eat window, never the old fixed clock.
    @MainActor
    static func seedEating(into container: ModelContainer, endedHoursAgo: Double) {
        let ctx = container.mainContext
        if let all = try? ctx.fetch(FetchDescriptor<FastSession>()) { for s in all { ctx.delete(s) } }
        let end = Date.now.addingTimeInterval(-endedHoursAgo * 3600)
        ctx.insert(FastSession(start: end.addingTimeInterval(-16 * 3600), end: end, targetHours: 16))
        try? ctx.save()
    }
}
#endif
