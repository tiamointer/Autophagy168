import SwiftUI
import SwiftData

@main
struct Autophagy168App: App {
    let container = SharedStore.makeContainer()

    private var args: [String] { CommandLine.arguments }
    private var uiTest: Bool { args.contains("-uiTest") }
    private var widgetGallery: Bool { args.contains("-widgetGallery") }

    init() {
        #if DEBUG
        SelfCheck.run()
        if args.contains("-seedHistory") { SampleData.seed(into: container) }
        if args.contains("-seedActiveFast") { SampleData.seedActiveFast(into: container, hoursAgo: 10) }
        if args.contains("-seedDigest") { SampleData.seedActiveFast(into: container, hoursAgo: 4) }   // ~0.25 → 消化期
        if args.contains("-seedAutophagy") { SampleData.seedActiveFast(into: container, hoursAgo: 15) } // ~0.94 → 自噬期
        if args.contains("-seedEating") { SampleData.seedEating(into: container, endedHoursAgo: 1) }
        if args.contains("-mascotVector") { MascotStyle.vector.save() }
        if args.contains("-mascotClassic") { MascotStyle.classic.save() }
        #endif
        if !uiTest {
            Task { await FastNotifier.requestAuth() }
        }
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if widgetGallery {
                WidgetGallery()
            } else if args.contains("-statsView") {
                StatsView()
            } else if args.contains("-settingsView") {
                ScheduleSheet(schedule: .default, onPick: { _ in }, mascotStyle: .classic, onPickStyle: { _ in })
            } else {
                ContentView()
            }
            #else
            ContentView()
            #endif
        }
        .modelContainer(container)
    }
}
