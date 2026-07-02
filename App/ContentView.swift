import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var vm = FastingViewModel()
    @State private var now = Date()
    @State private var mascotStyle: MascotStyle = MascotStyle.load()
    @State private var showSettings = false
    @State private var showStats = false
    @State private var showConfirm = false
    @State private var showRedeemConfirm = false

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let d = vm.display
        let fasting = d.phase == .fasting

        ZStack {
            LinearGradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                header(fasting: fasting)
                MascotView(display: d, now: now, style: mascotStyle,
                           bonusOrbs: vm.availableOrbs, bonusCollected: vm.collectedThisSession,
                           onCollectOrb: { vm.collectOrb() })
                actionButton(d: d)
                recap
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            topBar
        }
        .onAppear { vm.bind(context) }
        .onReceive(tick) { now = $0; vm.tick() }
        .onChange(of: scenePhase) { _, p in if p == .active { vm.tick() } }
        .sheet(isPresented: $showSettings) {
            ScheduleSheet(schedule: vm.schedule, onPick: { vm.setSchedule($0) },
                          mascotStyle: mascotStyle, onPickStyle: { mascotStyle = $0; $0.save() },
                          energyThreshold: vm.energy.threshold,
                          onPickThreshold: { vm.setEnergyThreshold($0) })
                .presentationDetents([.height(580)])
        }
        .sheet(isPresented: $showStats) { StatsView() }
        .alert(confirmTitle(d), isPresented: $showConfirm) {
            Button(d.hasRunningFast ? "开始吃第一口" : "现在开始不吃", role: .destructive) { vm.toggle() }
            Button("再等等", role: .cancel) { }
        } message: {
            Text(confirmMessage(d))
        }
        .alert("能量满啦 ✨", isPresented: Bindable(vm).showCheatMealEarned) {
            Button("马上兑换") { vm.redeemCheatMeal() }
            Button("先存着", role: .cancel) { }
        } message: {
            Text("自噬能量攒够 \(vm.energy.threshold) 点，可以兑换一顿放纵餐了。")
        }
        .alert("兑换放纵餐？", isPresented: $showRedeemConfirm) {
            Button("兑换") { vm.redeemCheatMeal() }
            Button("再等等", role: .cancel) { }
        } message: {
            Text("将消耗 \(vm.energy.threshold) 点能量，好好享受这一顿。")
        }
    }

    // MARK: - Pieces

    private func header(fasting: Bool) -> some View {
        VStack(spacing: 6) {
            Text(fasting ? "断食中" : "进食中")
                .font(.title2.weight(.semibold))
                .foregroundStyle(fasting ? Color.orange : Color.green)
            // The cycle chains from the last tap, not a fixed clock window — so only the
            // fast's duration target is meaningful to show; never a fixed 12:00–20:00 range.
            if fasting {
                Text("目标 \(vm.schedule.fastDurationHours) 小时")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func actionButton(d: DisplayState) -> some View {
        // fasting → "开始吃第一口" (green, go eat); eating → "现在开始不吃" (orange, start fasting)
        let goEat = d.hasRunningFast
        return Button {
            if targetMet(d) { vm.toggle() } else { showConfirm = true }   // off-target tap → confirm the cycle change
        } label: {
            Text(goEat ? "开始吃第一口" : "现在开始不吃")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(goEat ? Color.green : Color.orange,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)
        }
    }

    /// The current window's natural target is reached (16h fasted / eating window elapsed).
    private func targetMet(_ d: DisplayState) -> Bool { now >= d.end }

    private func confirmTitle(_ d: DisplayState) -> String {
        d.hasRunningFast ? "还没到 \(vm.schedule.fastDurationHours) 小时" : "进食还没结束"
    }
    private func confirmMessage(_ d: DisplayState) -> String {
        let left = max(d.end.timeIntervalSince(now), 0)
        return d.hasRunningFast
            ? "距达标还差 \(hms(left))。现在开始吃会提前结束这次断食，并从这一刻接上新的循环。"
            : "距进食结束还有 \(hms(left))。现在开始不吃会提前进入断食，并从这一刻接上新的循环。"
    }

    private var recap: some View {
        HStack(spacing: 12) {
            stat(value: "\(vm.completedCount)", label: "达标次数")
            stat(value: vm.lastDuration.map(hShort) ?? "—", label: "上次时长")
            energyStat
        }
    }

    /// 自噬能量卡：达到阈值后翻成橙色「可兑换」态，点击兑换。
    private var energyStat: some View {
        let redeemable = vm.energy.canRedeem
        return VStack(spacing: 4) {
            Text("\(vm.energy.balance)").font(.title3.weight(.semibold)).monospacedDigit()
            Text(redeemable ? "可兑换放纵餐" : "自噬能量")
                .font(.caption)
                .foregroundStyle(redeemable ? Color.orange : Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(redeemable ? Color.orange.opacity(0.18) : Color.primary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(redeemable ? Color.orange : .clear, lineWidth: 2))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture { if redeemable { showRedeemConfirm = true } }
        .animation(.easeInOut(duration: 0.3), value: redeemable)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var topBar: some View {
        VStack {
            HStack {
                Button { showStats = true } label: {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.title3).foregroundStyle(.secondary).padding(10)
                }
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3).foregroundStyle(.secondary).padding(10)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Formatting

    private func hms(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
    private func hShort(_ t: TimeInterval) -> String {
        let m = Int(t.rounded()) / 60
        return "\(m / 60)h \(m % 60)m"
    }
}

/// Pick the fasting rhythm (ratio). The cycle anchors to your taps, so there's no fixed
/// clock window to set — only how long to fast vs eat.
struct ScheduleSheet: View {
    let schedule: Schedule
    let onPick: (Schedule) -> Void
    let mascotStyle: MascotStyle
    let onPickStyle: (MascotStyle) -> Void
    let energyThreshold: Int
    let onPickThreshold: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    // (fastHours, eatHours) — must sum to 24
    private let options = [(16, 8), (18, 6), (20, 4)]

    var body: some View {
        VStack(spacing: 20) {
            Text("断食节律")
                .font(.headline)
            Text("循环从你点下的那一刻接上，不必设定钟点")
                .font(.footnote).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(options, id: \.0) { fast, eat in
                    let selected = schedule.fastDurationHours == fast
                    Button {
                        onPick(Schedule(eatStartHour: schedule.eatStartHour, eatDurationHours: eat))
                        dismiss()
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(fast):\(eat)").font(.title3.weight(.bold))
                            Text("断食 \(fast)h · 进食 \(eat)h")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(selected ? Color.orange.opacity(0.18) : Color.primary.opacity(0.05),
                                    in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(selected ? Color.orange : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("松鼠皮肤")
                .font(.headline)
            HStack(spacing: 12) {
                ForEach(MascotStyle.allCases, id: \.self) { s in
                    let selected = mascotStyle == s
                    Button {
                        onPickStyle(s)
                    } label: {
                        VStack(spacing: 8) {
                            Text(s.label)
                                .font(.subheadline.weight(.semibold))
                            // Same pose (feeding) in both styles, so the thumbnail compares
                            // art style, not pose.
                            Image(LoopStage.feeding.asset(style: s))
                                .resizable()
                                .scaledToFit()
                                .frame(height: 64)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selected ? Color.orange.opacity(0.18) : Color.primary.opacity(0.05),
                                    in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(selected ? Color.orange : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("放纵餐")
                .font(.headline)
            Text("每攒 \(energyThreshold) 点自噬能量，奖励自己一顿")
                .font(.footnote).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                thresholdButton("minus", enabled: energyThreshold > BonusEnergy.thresholdRange.lowerBound) {
                    onPickThreshold(energyThreshold - 5)
                }
                Text("\(energyThreshold) 点")
                    .font(.title3.weight(.bold)).monospacedDigit()
                    .frame(maxWidth: .infinity)
                thresholdButton("plus", enabled: energyThreshold < BonusEnergy.thresholdRange.upperBound) {
                    onPickThreshold(energyThreshold + 5)
                }
            }

            Spacer()
        }
        .padding(24)
    }

    private func thresholdButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline)
                .frame(width: 64, height: 44)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: FastSession.self, inMemory: true)
}
