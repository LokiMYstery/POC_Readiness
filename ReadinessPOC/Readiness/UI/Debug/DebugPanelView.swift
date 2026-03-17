import SwiftUI

struct DebugPanelView: View {
    @ObservedObject var viewModel: ReadinessViewModel
    @ObservedObject private var debug: DebugState

    init(viewModel: ReadinessViewModel) {
        self.viewModel = viewModel
        self._debug = ObservedObject(wrappedValue: viewModel.debugState)
    }

    var body: some View {
        Form {
            Section {
                Toggle("启用 Debug 覆盖", isOn: debugBinding(
                    get: { debug.isEnabled },
                    set: { debug.isEnabled = $0 }
                ))
                    .tint(.orange)
            }

            if debug.isEnabled {
                globalSection
                circadianSection
                activitySection
                recoverySection
            }

            outputPreviewSection
        }
        .navigationTitle("Debug 面板")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var globalSection: some View {
        Section("全局") {
            Picker("模式", selection: debugBinding(
                get: { debug.modeOverride },
                set: { debug.modeOverride = $0 }
            )) {
                Text("Auto").tag(Optional<ReadinessMode>.none)
                Text("Day").tag(Optional<ReadinessMode>.some(.day))
                Text("Night").tag(Optional<ReadinessMode>.some(.night))
            }

            DatePicker("时间覆盖", selection: debugBinding(
                get: { debug.nowOverride ?? currentInputs.global.now },
                set: { debug.nowOverride = $0 }
            ))

            Picker("节假日", selection: debugBinding(
                get: { debug.isHolidayOverride },
                set: { debug.isHolidayOverride = $0 }
            )) {
                Text("未知 (nil)").tag(Optional<Bool>.none)
                Text("是").tag(Optional<Bool>.some(true))
                Text("否").tag(Optional<Bool>.some(false))
            }

            Button("重置全局覆盖") {
                applyAndRecalculate {
                    debug.resetGlobalOverrides()
                }
            }
        }
    }

    private var circadianSection: some View {
        Section("节律与日照") {
            Toggle("WeatherKit 数据", isOn: debugBinding(
                get: { debug.weatherKitEnabled },
                set: { debug.weatherKitEnabled = $0 }
            ))

            if debug.weatherKitEnabled {
                DatePicker("日出", selection: debugBinding(
                    get: { debug.sunriseOverride ?? currentInputs.circadian.sunrise ?? defaultSunrise },
                    set: { debug.sunriseOverride = $0 }
                ), displayedComponents: .hourAndMinute)

                DatePicker("日落", selection: debugBinding(
                    get: { debug.sunsetOverride ?? currentInputs.circadian.sunset ?? defaultSunset },
                    set: { debug.sunsetOverride = $0 }
                ), displayedComponents: .hourAndMinute)
            }

            Button("重置节律覆盖") {
                applyAndRecalculate {
                    debug.resetCircadianOverrides()
                }
            }
        }
    }

    private var activitySection: some View {
        Section("活动与代谢") {
            Toggle("活动数据", isOn: debugBinding(
                get: { debug.activityEnabled },
                set: { debug.activityEnabled = $0 }
            ))

            if debug.activityEnabled {
                numberRow(
                    "今日步数",
                    value: debugBinding(
                        get: { debug.stepsTodayOverride ?? currentInputs.activity.stepsToday ?? 5000 },
                        set: { debug.stepsTodayOverride = $0 }
                    ),
                    range: 0...20000,
                    step: 100,
                    unit: "步"
                )

                numberRow(
                    "过去2h步数",
                    value: debugBinding(
                        get: { debug.stepsLast2hOverride ?? currentInputs.activity.stepsLast2h ?? 500 },
                        set: { debug.stepsLast2hOverride = $0 }
                    ),
                    range: 0...5000,
                    step: 50,
                    unit: "步"
                )

                numberRow(
                    "活动能量",
                    value: debugBinding(
                        get: { debug.activeEnergyOverride ?? currentInputs.activity.activeEnergyTodayKcal ?? 200 },
                        set: { debug.activeEnergyOverride = $0 }
                    ),
                    range: 0...2000,
                    step: 10,
                    unit: "千卡"
                )

                numberRow(
                    "运动分钟",
                    value: debugBinding(
                        get: { debug.exerciseMinutesOverride ?? currentInputs.activity.exerciseMinutesToday ?? 30 },
                        set: { debug.exerciseMinutesOverride = $0 }
                    ),
                    range: 0...180,
                    step: 5,
                    unit: "分钟"
                )
            }

            Button("重置活动覆盖") {
                applyAndRecalculate {
                    debug.resetActivityOverrides()
                }
            }
        }
    }

    private var recoverySection: some View {
        Section("睡眠与恢复") {
            Toggle("睡眠数据", isOn: debugBinding(
                get: { debug.recoveryEnabled },
                set: { debug.recoveryEnabled = $0 }
            ))

            if debug.recoveryEnabled {
                numberRow(
                    "睡眠时长",
                    value: debugBinding(
                        get: { debug.sleepDurationOverride ?? currentInputs.recovery.sleepDurationLastNightHours ?? 7.5 },
                        set: { debug.sleepDurationOverride = $0 }
                    ),
                    range: 0...12,
                    step: 0.1,
                    unit: "小时",
                    decimals: 1
                )

                numberRow(
                    "静息心率",
                    value: debugBinding(
                        get: { debug.restingHROverride ?? currentInputs.recovery.restingHeartRate ?? 65 },
                        set: { debug.restingHROverride = $0 }
                    ),
                    range: 40...100,
                    step: 1,
                    unit: "bpm"
                )

                numberRow(
                    "HRV",
                    value: debugBinding(
                        get: { debug.hrvOverride ?? currentInputs.recovery.hrvSDNN ?? 45 },
                        set: { debug.hrvOverride = $0 }
                    ),
                    range: 10...120,
                    step: 1,
                    unit: "ms"
                )
            }

            Button("重置恢复覆盖") {
                applyAndRecalculate {
                    debug.resetRecoveryOverrides()
                }
            }
        }
    }

    private var outputPreviewSection: some View {
        Section("输出预览") {
            if let result = viewModel.result {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("生效时间")
                        Spacer()
                        Text(debugTimeString)
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("生效模式")
                        Spacer()
                        Text(result.mode.displayName)
                            .fontWeight(.medium)
                    }

                    Divider()

                    HStack {
                        Text("总分")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(result.overallScore))")
                            .font(.title.weight(.bold))
                    }

                    HStack {
                        Text("档位")
                        Spacer()
                        Text("\(result.band.rawValue) / 5")
                            .fontWeight(.medium)
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

                    Text("标题")
                        .font(.caption.weight(.semibold))
                    Text(result.text.heroTitle)
                        .font(.caption)
                        .foregroundColor(.primary)

                    Text("副文案")
                        .font(.caption.weight(.semibold))
                    Text(result.text.heroSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("摘要")
                        .font(.caption.weight(.semibold))
                    Text(result.text.summaryLine)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let hint = result.text.missingHint {
                        Text("缺失提示")
                            .font(.caption.weight(.semibold))
                        Text(hint)
                            .font(.caption)
                            .foregroundColor(.orange)
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

    private var currentInputs: ReadinessInputs {
        viewModel.effectiveInputs ?? viewModel.rawInputs ?? ReadinessInputs.makeDefault()
    }

    private func debugBinding<Value>(get: @escaping () -> Value, set: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(
            get: get,
            set: { newValue in
                set(newValue)
                viewModel.recalculate()
            }
        )
    }

    private func applyAndRecalculate(_ updates: () -> Void) {
        updates()
        viewModel.recalculate()
    }

    private func numberRow(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String,
        decimals: Int = 0
    ) -> some View {
        DebugNumericFieldRow(
            label: label,
            unit: unit,
            value: value,
            range: range,
            step: step,
            decimals: decimals
        )
    }

    private var defaultSunrise: Date {
        Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: currentInputs.global.now) ?? currentInputs.global.now
    }

    private var defaultSunset: Date {
        Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: currentInputs.global.now) ?? currentInputs.global.now
    }

    private var debugTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: currentInputs.global.now)
    }
}

private struct DebugNumericFieldRow: View {
    let label: String
    let unit: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let decimals: Int

    @State private var text: String

    init(
        label: String,
        unit: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        decimals: Int
    ) {
        self.label = label
        self.unit = unit
        self._value = value
        self.range = range
        self.step = step
        self.decimals = decimals
        self._text = State(initialValue: Self.format(value.wrappedValue, decimals: decimals))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.subheadline)
                Spacer()
                TextField("", text: $text)
                    .keyboardType(decimals == 0 ? .numberPad : .decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 84)
                    .textFieldStyle(.roundedBorder)
                Text(unit)
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            Stepper(value: stepperBinding, in: range, step: step) {
                Text(Self.format(value, decimals: decimals))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
        .onChange(of: text) { newValue in
            applyText(newValue)
        }
        .onChange(of: value) { newValue in
            let formatted = Self.format(newValue, decimals: decimals)
            if text != formatted {
                text = formatted
            }
        }
    }

    private var stepperBinding: Binding<Double> {
        Binding(
            get: { value },
            set: { newValue in
                value = clampedAndRounded(newValue)
                text = Self.format(value, decimals: decimals)
            }
        )
    }

    private func applyText(_ raw: String) {
        guard let parsed = Double(raw.filter { "0123456789.-".contains($0) }), raw != "-", raw != ".", raw != "-." else {
            return
        }
        let adjusted = clampedAndRounded(parsed)
        if adjusted != value {
            value = adjusted
        }
    }

    private func clampedAndRounded(_ newValue: Double) -> Double {
        let clamped = min(max(newValue, range.lowerBound), range.upperBound)
        guard step > 0 else { return clamped }
        let stepped = (clamped / step).rounded() * step
        let precision = pow(10.0, Double(decimals))
        return (stepped * precision).rounded() / precision
    }

    private static func format(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f", value)
    }
}
