import Foundation

/// 子分数
struct SubScore: Identifiable {
    let id: FactorKind
    /// 0–100
    let value: Double
    /// 在总分中的权重（归一化后）
    let normalizedWeight: Double
    /// 贡献度百分比 (contrib_i / sum)
    let contributionPercent: Double
    let availability: Availability
}

/// 因子类型
enum FactorKind: String, CaseIterable, Identifiable {
    case circadian = "circadian"
    case activity  = "activity"
    case recovery  = "recovery"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .circadian: return "节律与日照"
        case .activity:  return "活动与代谢"
        case .recovery:  return "睡眠与恢复"
        }
    }

    var iconName: String {
        switch self {
        case .circadian: return "sun.max.fill"
        case .activity:  return "figure.walk"
        case .recovery:  return "bed.double.fill"
        }
    }
}

/// 总分结果
struct ReadinessResult {
    let mode: ReadinessMode
    let overallScore: Double          // 0–100 (含 sleepDebtBonus)
    let sleepDebtBonus: Double        // 0–8, 仅 Night Mode 有值
    let sleepDebtBonusReasons: [SleepDebtBonusReason]
    let subScores: [SubScore]         // 长度 ≤ 3
    let text: ReadinessTextOutput
    let timestamp: Date
}
