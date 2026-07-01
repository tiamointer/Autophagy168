import Foundation
import SwiftData

/// A tiny snapshot of the current phase the app writes to shared defaults so the
/// widget can render without touching SwiftData.
struct StatusSnapshot: Codable {
    var phaseRaw: Int        // Phase.rawValue
    var windowStart: Date
    var windowEnd: Date
}

enum SharedStore {
    /// Shared with the widget via the App Group; falls back to standard defaults if unavailable.
    static let defaults = UserDefaults(suiteName: AppGroup.id) ?? .standard

    @MainActor
    static func makeContainer() -> ModelContainer {
        let schema = Schema([FastSession.self])
        do {
            let config = ModelConfiguration(schema: schema, groupContainer: .identifier(AppGroup.id))
            let c = try ModelContainer(for: schema, configurations: config)
            print("[SharedStore] app-group store OK")
            return c
        } catch {
            print("[SharedStore] app-group store unavailable (\(error)); using local store")
            return try! ModelContainer(for: schema)
        }
    }

    private static let snapshotKey = "statusSnapshot"

    static func writeSnapshot(_ s: StatusSnapshot) {
        if let data = try? JSONEncoder().encode(s) {
            defaults.set(data, forKey: snapshotKey)
        }
    }

    static func readSnapshot() -> StatusSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(StatusSnapshot.self, from: data)
    }
}
