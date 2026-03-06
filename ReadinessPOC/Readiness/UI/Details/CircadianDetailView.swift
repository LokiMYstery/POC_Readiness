import SwiftUI

/// 节律与日照详情页
struct CircadianDetailView: View {
    let subScore: SubScore?
    let inputs: CircadianInputs?
    let global: GlobalContext?
    let explanation: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 子分与解释
                scoreHeader

                // 数据等级
                availabilityBadge

                Divider()

                // 证据字段
                evidenceSection

                // 极简时间轴（可选）
                if let g = global {
                    timelineSection(global: g)
                }
            }
            .padding(20)
        }
        .navigationTitle("节律与日照")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Score Header

    private var scoreHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("节律与日照")
                    .font(.title2.weight(.bold))
                Spacer()
                if let sub = subScore {
                    Text("\(Int(sub.value))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
            }

            Text(explanation)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Availability Badge

    private var availabilityBadge: some View {
        HStack {
            let avail = subScore?.availability ?? .estimated
            let (text, color): (String, Color) = {
                switch avail {
                case .measured:  return ("实测数据 (L1)", .green)
                case .estimated: return ("时间估计 (L0)", .orange)
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

    // MARK: - Evidence

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("数据详情")
                .font(.headline)

            if let inp = inputs {
                dataRow("位置", value: inp.location != nil ?
                    String(format: "%.2f, %.2f", inp.location!.latitude, inp.location!.longitude) : "无")
                dataRow("日出", value: inp.sunrise.map { timeString($0) } ?? "无")
                dataRow("日落", value: inp.sunset.map { timeString($0) } ?? "无")
                if let dl = inp.daylightDuration {
                    dataRow("日照时长", value: String(format: "%.1f 小时", dl / 3600))
                }
                if let cc = inp.cloudCover {
                    dataRow("云量", value: String(format: "%.0f%%", cc * 100))
                }
                if let uv = inp.uvIndex {
                    dataRow("UV 指数", value: String(format: "%.0f", uv))
                }
                if let cond = inp.condition {
                    dataRow("天气状况", value: cond)
                }
            } else {
                Text("无数据")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let g = global {
                Divider()
                dataRow("当前时间", value: timeString(g.now))
                dataRow("模式", value: g.mode.displayName)
                dataRow("周末", value: g.isWeekend ? "是" : "否")
                if let holiday = g.isHoliday {
                    dataRow("节假日", value: holiday ? (g.holidayName ?? "是") : "否")
                }
            }
        }
    }

    // MARK: - Simple Timeline

    private func timelineSection(global: GlobalContext) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("节律时间轴")
                .font(.headline)

            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    // 背景条
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    // 当前位置
                    let hour = Calendar.current.component(.hour, from: global.now)
                    let minute = Calendar.current.component(.minute, from: global.now)
                    let progress = CGFloat(hour * 60 + minute) / 1440.0

                    Circle()
                        .fill(Color.orange)
                        .frame(width: 12, height: 12)
                        .offset(x: progress * width - 6)
                }
            }
            .frame(height: 16)

            // 时间标签
            HStack {
                Text("00:00")
                Spacer()
                Text("06:00")
                Spacer()
                Text("12:00")
                Spacer()
                Text("18:00")
                Spacer()
                Text("24:00")
            }
            .font(.system(size: 9))
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

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
