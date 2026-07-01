import Foundation
import ActivityKit

/// The Live Activity for the current window. Static attrs are empty; the live data
/// lives in ContentState so we can update phase / window as it changes.
struct FastActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phaseRaw: Int        // Phase.rawValue
        var windowStart: Date
        var windowEnd: Date

        var phase: Phase { Phase(rawValue: phaseRaw) ?? .eating }
    }
}
