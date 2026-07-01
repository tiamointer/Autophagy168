import Foundation
import SwiftData

/// One fasting session. Store only the raw facts (start / end / target) and derive
/// the rest, so records stay honest if the target ever changes.
@Model
final class FastSession {
    var id: UUID
    var start: Date
    var end: Date?
    var targetHours: Double

    init(start: Date = .now, end: Date? = nil, targetHours: Double = 16) {
        self.id = UUID()
        self.start = start
        self.end = end
        self.targetHours = targetHours
    }

    var isActive: Bool { end == nil }
    var target: TimeInterval { targetHours * 3600 }
    var duration: TimeInterval { (end ?? .now).timeIntervalSince(start) }
    var completed: Bool { end != nil && duration >= target }
    /// Clock time the target is reached — drives the ring and notifications.
    var goalDate: Date { start.addingTimeInterval(target) }
}
