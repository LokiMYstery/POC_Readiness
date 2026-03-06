import Foundation

/// 睡眠恢复分 S 计算
enum RecoveryScorer {

    /// 根据睡眠时长分档计算恢复分
    static func score(inputs: RecoveryInputs, mode: ReadinessMode) -> Double {
        guard inputs.availability.isAvailable else { return 0 }

        if let hours = inputs.sleepDurationLastNightHours {
            return durationScore(hours: hours)
        }

        // Night Mode L0: 基于时间因子估计
        // 在 availability 为 .estimated 且无 HealthKit 数据时
        return 0
    }

    /// 睡眠时长分档
    private static func durationScore(hours: Double) -> Double {
        switch hours {
        case ..<6.0:
            return 35
        case 6.0..<7.0:
            return 55
        case 7.0..<8.5:
            return 75
        default:
            return 70  // 过长轻微回落
        }
    }
}
