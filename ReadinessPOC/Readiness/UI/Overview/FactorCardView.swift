import SwiftUI

/// 证据卡片组件
struct FactorCardView: View {
    let factorKind: FactorKind
    let subScore: SubScore?
    let explanation: String
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: 14) {
            // 左侧图标
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconBackground)
                    .frame(width: 44, height: 44)

                Image(systemName: factorKind.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            // 中间文字
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(factorKind.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)

                    if !isAvailable {
                        Text("未接入")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.gray))
                    }
                }

                Text(explanation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // Tags
                if isAvailable, let sub = subScore {
                    HStack(spacing: 6) {
                        TagView(text: "贡献 \(Int(sub.contributionPercent))%", color: iconColor)
                        if let avail = availabilityTag(sub.availability) {
                            TagView(text: avail, color: .gray)
                        }
                    }
                }
            }

            Spacer()

            // 右侧分数
            if let sub = subScore, isAvailable {
                VStack(spacing: 2) {
                    Text("\(Int(sub.value))")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundColor(scoreColor(sub.value))
                    Text("分")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.4))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
    }

    // MARK: - Helpers

    private var iconBackground: Color {
        switch factorKind {
        case .circadian: return .orange.opacity(0.12)
        case .activity:  return .green.opacity(0.12)
        case .recovery:  return .blue.opacity(0.12)
        }
    }

    private var iconColor: Color {
        switch factorKind {
        case .circadian: return .orange
        case .activity:  return .green
        case .recovery:  return .blue
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 70 { return .green }
        if score >= 50 { return .orange }
        return .red
    }

    private func availabilityTag(_ availability: Availability) -> String? {
        switch availability {
        case .measured:  return nil
        case .estimated: return "估计"
        case .unavailable: return "缺失"
        }
    }
}

/// 小标签
struct TagView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(color.opacity(0.1))
            )
    }
}
