import Foundation
import UserNotifications

struct PlannedNotice: Equatable {
    let id: String
    let title: String
    let body: String
    let date: Date
}

/// Local, time-sensitive reminders for the upcoming transition of the CURRENT (anchored) window.
enum FastNotifier {
    static func requestAuth() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Pure: what to schedule given the current phase + when this window ends. No side effects.
    static func plan(phase: Phase, windowEnd: Date, fastHours: Int, now: Date) -> [PlannedNotice] {
        var out: [PlannedNotice] = []
        if phase == .fasting {
            if windowEnd > now {
                out.append(PlannedNotice(id: "fastComplete", title: "断食达成 🎉",
                                         body: "\(fastHours) 小时完成，可以开始进食了。", date: windowEnd))
            }
        } else {
            let closeSoon = windowEnd.addingTimeInterval(-3600)
            if closeSoon > now {
                out.append(PlannedNotice(id: "eatingClosing", title: "进食窗口还有 1 小时",
                                         body: "准备收尾，接下来进入断食。", date: closeSoon))
            }
            if windowEnd > now {
                out.append(PlannedNotice(id: "fastingStart", title: "该断食了 ⏳",
                                         body: "进食窗口结束，开始下一段断食。", date: windowEnd))
            }
        }
        return out
    }

    static func reschedule(phase: Phase, windowEnd: Date, fastHours: Int, now: Date) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for n in plan(phase: phase, windowEnd: windowEnd, fastHours: fastHours, now: now) {
            let c = UNMutableNotificationContent()
            c.title = n.title; c.body = n.body; c.sound = .default
            c.interruptionLevel = .timeSensitive
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: n.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: n.id, content: c, trigger: trigger))
        }
    }
}
