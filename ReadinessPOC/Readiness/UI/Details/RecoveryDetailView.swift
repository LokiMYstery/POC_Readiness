import SwiftUI

/// 睡眠与恢复详情页
struct RecoveryDetailView: View {
    let subScore: SubScore?
    let inputs: RecoveryInputs?
    let mode: ReadinessMode
    let explanation: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "bed.double.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("睡眠与恢复")
                        .font(.title2.weight(.bold))
                    Spacer()
                    if let sub = subScore {
                        Text("\(Int(sub.value))")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                    }
                }

                Text(explanation)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Divider()

                // Data
                if let inp = inputs, inp.availability.isAvailable {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("数据详情")
                            .font(.headline)

                        if let duration = inp.sleepDurationLastNightHours {
                            dataRow("昨夜睡眠", value: String(format: "%.1f 小时", duration))

                            // 睡眠时长汇总块
                            sleepDurationBlock(hours: duration)
                        }
                        if let start = inp.sleepStart {
                            dataRow("入睡时间", value: timeString(start))
                        }
                        if let end = inp.sleepEnd {
                            dataRow("醒来时间", value: timeString(end))
                        }

                        // 阶段
                        if let stages = inp.sleepStages {
                            Divider()
                            Text("睡眠阶段")
                                .font(.headline)

                            stageRow("清醒", minutes: stages.awakeMinutes, color: .red)
                            stageRow("浅睡 (Core)", minutes: stages.coreMinutes, color: .cyan)
                            stageRow("深睡 (Deep)", minutes: stages.deepMinutes, color: .blue)
                            stageRow("REM", minutes: stages.remMinutes, color: .purple)
                        }

                        // 生理数据
                        if inp.restingHeartRate != nil || inp.hrvSDNN != nil {
                            Divider()
                            Text("生理指标")
                                .font(.headline)

                            if let hr = inp.restingHeartRate {
                                dataRow("静息心率", value: "\(Int(hr)) bpm")
                            }
                            if let hrv = inp.hrvSDNN {
                                dataRow("HRV (SDNN)", value: String(format: "%.0f ms", hrv))
                            }
                            if let rr = inp.respiratoryRate {
                                dataRow("呼吸频率", value: String(format: "%.1f /min", rr))
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "moon.zzz")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text(mode == .night ? "已根据夜间时段估计" : "未接入睡眠数据")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                }
            }
            .padding(20)
        }
        .navigationTitle("睡眠与恢复")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Sleep Duration Block

    private func sleepDurationBlock(hours: Double) -> some View {
        let maxHours: Double = 10
        let progress = min(hours / maxHours, 1.0)
        let color: Color = hours >= 7.0 ? .blue : (hours >= 6.0 ? .orange : .red)

        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [color.opacity(0.5), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * progress, height: 12)
                }
            }
            .frame(height: 12)

            HStack {
                Text("0h")
                Spacer()
                Text("6h")
                Spacer()
                Text("8h")
                Spacer()
                Text("10h")
            }
            .font(.system(size: 9))
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Stage Row

    private func stageRow(_ label: String, minutes: Double, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(String(format: "%.0f 分钟", minutes))
                .font(.subheadline.weight(.medium))
        }
    }

    private func dataRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
