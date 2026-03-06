import SwiftUI

/// 活动与代酣详情页
struct ActivityDetailView: View {
    let subScore: SubScore?
    let inputs: ActivityInputs?
    let mode: ReadinessMode
    let explanation: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "figure.walk")
                        .font(.title2)
                        .foregroundColor(.green)
                    Text("活动与代谢")
                        .font(.title2.weight(.bold))
                    Spacer()
                    if let sub = subScore {
                        Text("\(Int(sub.value))")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                }

                Text(explanation)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Availability
                availabilityBadge

                Divider()

                // Data
                if let inp = inputs, inp.availability.isAvailable {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("数据详情")
                            .font(.headline)

                        if let steps = inp.stepsToday {
                            dataRow("今日步数", value: "\(Int(steps))")

                            // 简易步数条
                            stepsBar(steps: steps)
                        }
                        if let steps2h = inp.stepsLast2h {
                            dataRow("过去2小时步数", value: "\(Int(steps2h))")
                        }
                        if let energy = inp.activeEnergyTodayKcal {
                            dataRow("今日活动能量", value: "\(Int(energy)) 千卡")
                        }
                        if let energy2h = inp.activeEnergyLast2hKcal {
                            dataRow("过去2小时能量", value: "\(Int(energy2h)) 千卡")
                        }
                        if let exercise = inp.exerciseMinutesToday {
                            dataRow("今日运动", value: "\(Int(exercise)) 分钟")
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "heart.slash")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("未接入活动数据")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("请在设置中允许 HealthKit 访问活动数据")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                }
            }
            .padding(20)
        }
        .navigationTitle("活动与代谢")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Steps Bar

    private func stepsBar(steps: Double) -> some View {
        let maxSteps: Double = 15000
        let progress = min(steps / maxSteps, 1.0)

        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [.green.opacity(0.6), .green],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * progress, height: 12)
                }
            }
            .frame(height: 12)

            HStack {
                Text("0")
                Spacer()
                Text("7,000")
                Spacer()
                Text("15,000")
            }
            .font(.system(size: 9))
            .foregroundColor(.secondary)
        }
    }

    private var availabilityBadge: some View {
        HStack {
            let avail = subScore?.availability ?? .unavailable(reason: .noData)
            let (text, color): (String, Color) = {
                switch avail {
                case .measured:  return ("实测数据", .green)
                case .estimated: return ("估计", .orange)
                case .unavailable: return ("不可用", .red)
                }
            }()

            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundColor(color)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundColor(color)
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
}
