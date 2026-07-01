import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FastSession.start) private var sessions: [FastSession]
    private let cal = Calendar.current

    private var summary: StatsSummary { StatsEngine(calendar: cal).summarize(sessions, now: Date()) }
    private var dayMap: [Date: DayStat] {
        Dictionary(summary.days.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroRow
                    weekDelta
                    card("每日断食时长（近 30 天）") { barChart }
                    card("打卡热力图（近 5 周）") { heatmap }
                    statCards
                }
                .padding()
            }
            .navigationTitle("统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
    }

    // MARK: Hero

    private var heroRow: some View {
        HStack(spacing: 12) {
            bigStat(value: "\(summary.currentStreak)", unit: "天", label: "当前连胜 🔥", tint: .orange)
            bigStat(value: "\(summary.longestStreak)", unit: "天", label: "最长连胜", tint: .pink)
        }
    }

    private var weekDelta: some View {
        let delta = summary.thisWeekRate - summary.lastWeekRate
        let up = delta >= 0
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("本周达成率").font(.subheadline).foregroundStyle(.secondary)
                Text("\(Int(summary.thisWeekRate * 100))%").font(.title2.bold())
            }
            Spacer()
            Label("\(up ? "+" : "")\(Int(delta * 100))% vs 上周",
                  systemImage: up ? "arrow.up.right" : "arrow.down.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(up ? .green : .red)
        }
        .padding()
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: Bar chart

    private var recentDays: [DayStat] {
        let today = cal.startOfDay(for: Date())
        return (0..<30).reversed().map { i in
            let d = cal.date(byAdding: .day, value: -i, to: today)!
            return dayMap[d] ?? DayStat(date: d, hours: 0, completed: false)
        }
    }

    private var barChart: some View {
        Chart {
            ForEach(recentDays) { d in
                BarMark(x: .value("日", d.date, unit: .day),
                        y: .value("小时", d.hours))
                    .foregroundStyle(d.completed ? Color.orange
                                     : (d.hours > 0 ? Color.orange.opacity(0.4) : Color.gray.opacity(0.22)))
                    .cornerRadius(3)
            }
            RuleMark(y: .value("目标", 16.0))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(.orange.opacity(0.8))
                .annotation(position: .top, alignment: .trailing) {
                    Text("目标 16h").font(.caption2).foregroundStyle(.secondary)
                }
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: 7 * 86_400)
        .chartScrollPosition(initialX: cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date()))!)
        .chartYScale(domain: 0...20)
        .frame(height: 170)
    }

    // MARK: Heatmap

    private var heatmapCells: [Date?] {
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -34, to: today)!
        let leading = (cal.component(.weekday, from: start) - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for i in 0..<35 { cells.append(cal.date(byAdding: .day, value: i, to: start)!) }
        return cells
    }

    private func heatColor(_ d: Date) -> Color {
        if d > cal.startOfDay(for: Date()) { return Color.gray.opacity(0.08) }
        guard let s = dayMap[d] else { return Color.gray.opacity(0.12) }
        if s.completed { return .orange }
        if s.hours > 0 { return .orange.opacity(0.4) }
        return Color.gray.opacity(0.12)
    }

    private var heatmap: some View {
        let cells = heatmapCells
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                if let day {
                    RoundedRectangle(cornerRadius: 4).fill(heatColor(day)).frame(height: 26)
                } else {
                    Color.clear.frame(height: 26)
                }
            }
        }
    }

    // MARK: Stat cards

    private var statCards: some View {
        HStack(spacing: 10) {
            smallStat("\(summary.completedCount)", "达标天")
            smallStat(fmt(summary.longestFastHours), "最长(h)")
            smallStat(fmt(summary.avgFastHours), "平均(h)")
        }
    }

    // MARK: Bits

    private func bigStat(value: String, unit: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(tint)
                Text(unit).font(.headline).foregroundStyle(tint.opacity(0.8))
            }
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
    }

    private func smallStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private func card<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.semibold))
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
    }

    private func fmt(_ h: Double) -> String { String(format: "%.1f", h) }
}
