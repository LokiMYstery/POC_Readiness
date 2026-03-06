import SwiftUI

/// Debug 控制面板
struct DebugPanelView: View {
    @ObservedObject var viewModel: ReadinessViewModel
    @ObservedObject private var debug: DebugState

    init(viewModel: ReadinessViewModel) {
        self.viewModel = viewModel
        self._debug = ObservedObject(wrappedValue: viewModel.debugState)
    }

    var body: some View {
        Form {
            // 开关
            Section {
                Toggle("启用 Debug 覆盖", isOn: $debug.isEnabled)
                    .tint(.orange)
            }

            if debug.isEnabled {
                // Global
                globalSection

                // Circadian
                circadianSection

                // Activity
                activitySection

                // Recovery
                recoverySection
            }

            // 输出预览
            outputPreviewSection
        }
        .navigationTitle("Debug 面板")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: debug.isEnabled) { _ in viewModel.recalculate() }
        .onChange(of: debug.modeOverride) { _ in viewModel.recalculate() }
        .onChange(of: debug.nowOverride) { _ in viewModel.recalculate() }
        .onChange(of: debug.isHolidayOverride) { _ in viewModel.recalculate() }
        .onChange(of: debug.weatherKitEnabled) { _ in viewModel.recalculate() }
        .onChange(of: debug.activityEnabled) { _ in viewModel.recalculate() }
        .onChange(of: debug.recoveryEnabled) { _ in viewModel.recalculate() }
        .onChange(of: debug.stepsTodayOverride) { _ in viewModel.recalculate() }
        .onChange(of: debug.sleepDurationOverride) { _ in viewModel.recalculate() }
    }

    // MARK: - Global Section

    private var globalSection: some View {
        Section("全局") {
            Picker("模式", selection: $debug.modeOverride) {
                Text("Auto").tag(Optional<ReadinessMode>.none)
                Text("Day").tag(Optional<ReadinessMode>.some(.day))
                Text("Night").tag(Optional<ReadinessMode>.some(.night))
            }

            DatePicker("时间覆盖", selection: Binding(
                get: { debug.nowOverride ?? .now },
                set: { debug.nowOverride = $0 }
            ))

            Picker("节假日", selection: Binding(
                get: { debug.isHolidayOverride },
                set: { debug.isHolidayOverride = $0 }
            )) {
                Text("未知 (nil)").tag(Optional<Bool>.none)
                Text("是").tag(Optional<Bool>.some(true))
                Text("否").tag(Optional<Bool>.some(false))
            }

            Button("重置时间") {
                debug.nowOverride = nil
                debug.modeOverride = nil
                viewModel.recalculate()
            }
        }
    }

    // MARK: - Circadian Section

    private var circadianSection: some View {
        Section("节律与日照") {
            Toggle("WeatherKit 数据", isOn: $debug.weatherKitEnabled)

            if debug.weatherKitEnabled {
                DatePicker("日出", selection: Binding(
                    get: { debug.sunriseOverride ?? defaultSunrise },
                    set: { debug.sunriseOverride = $0 }
                ), displayedComponents: .hourAndMinute)

                DatePicker("日落", selection: Binding(
                    get: { debug.sunsetOverride ?? defaultSunset },
                    set: { debug.sunsetOverride = $0 }
                ), displayedComponents: .hourAndMinute)
            }
        }
    }

    // MARK: - Activity Section

    private var activitySection: some View {
        Section("活动与代谢") {
            Toggle("活动数据", isOn: $debug.activityEnabled)

            if debug.activityEnabled {
                sliderRow("今日步数", value: Binding(
                    get: { debug.stepsTodayOverride ?? 5000 },
                    set: { debug.stepsTodayOverride = $0 }
                ), range: 0...20000, unit: "步")

                sliderRow("过去2h步数", value: Binding(
                    get: { debug.stepsLast2hOverride ?? 500 },
                    set: { debug.stepsLast2hOverride = $0 }
                ), range: 0...5000, unit: "步")

                sliderRow("活动能量", value: Binding(
                    get: { debug.activeEnergyOverride ?? 200 },
                    set: { debug.activeEnergyOverride = $0 }
                ), range: 0...2000, unit: "千卡")

                sliderRow("运动分钟", value: Binding(
                    get: { debug.exerciseMinutesOverride ?? 30 },
                    set: { debug.exerciseMinutesOverride = $0 }
                ), range: 0...180, unit: "分钟")
            }
        }
    }

    // MARK: - Recovery Section

    private var recoverySection: some View {
        Section("睡眠与恢复") {
            Toggle("睡眠数据", isOn: $debug.recoveryEnabled)

            if debug.recoveryEnabled {
                sliderRow("睡眠时长", value: Binding(
                    get: { debug.sleepDurationOverride ?? 7.5 },
                    set: { debug.sleepDurationOverride = $0 }
                ), range: 0...12, unit: "小时")

                sliderRow("静息心率", value: Binding(
                    get: { debug.restingHROverride ?? 65 },
                    set: { debug.restingHROverride = $0 }
                ), range: 40...100, unit: "bpm")

                sliderRow("HRV", value: Binding(
                    get: { debug.hrvOverride ?? 45 },
                    set: { debug.hrvOverride = $0 }
                ), range: 10...120, unit: "ms")
            }
        }
    }

    // MARK: - Output Preview

    private var outputPreviewSection: some View {
        Section("输出预览") {
            if let result = viewModel.result {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("总分")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(result.overallScore))")
                            .font(.title.weight(.bold))
                    }

                    Divider()

                    ForEach(result.subScores) { sub in
                        HStack {
                            Text(sub.id.displayName)
                            Spacer()
                            Text("\(Int(sub.value))")
                                .fontWeight(.medium)
                            Text("(\(String(format: "%.0f", sub.normalizedWeight * 100))%)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    Text("总览文案")
                        .font(.caption.weight(.semibold))
                    Text(result.text.overviewSentence)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("节律")
                        .font(.caption.weight(.semibold))
                    Text(result.text.circadianExplanation)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("活动")
                        .font(.caption.weight(.semibold))
                    Text(result.text.activityExplanation)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("恢复")
                        .font(.caption.weight(.semibold))
                    Text(result.text.recoveryExplanation)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let hint = result.text.missingHint {
                        Text("缺失提示")
                            .font(.caption.weight(.semibold))
                        Text(hint)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    // Sleep Debt Bonus
                    if result.sleepDebtBonus > 0 {
                        Divider()
                        HStack {
                            Text("Sleep Debt Bonus")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text("+\(String(format: "%.0f", result.sleepDebtBonus))")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.purple)
                        }
                        Text(result.sleepDebtBonusReasons.map(\.rawValue).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("暂无结果")
                    .foregroundColor(.secondary)
            }

            Button("重新计算") {
                viewModel.recalculate()
            }

            Button("重新拉取数据") {
                viewModel.refresh()
            }
        }
    }

    // MARK: - Helpers

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(value.wrappedValue)) \(unit)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    private var defaultSunrise: Date {
        Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: .now) ?? .now
    }

    private var defaultSunset: Date {
        Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: .now) ?? .now
    }
}
