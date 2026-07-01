import Foundation

/// Which squirrel art style to render, persisted like `Schedule`.
enum MascotStyle: Int, CaseIterable {
    case classic, vector

    var label: String { self == .classic ? "经典" : "矢量" }

    private static let key = "mascotStyle"

    static func load() -> MascotStyle {
        let raw = SharedStore.defaults.object(forKey: key) as? Int
        return raw.flatMap(MascotStyle.init(rawValue:)) ?? .classic
    }

    func save() {
        SharedStore.defaults.set(rawValue, forKey: Self.key)
    }
}
