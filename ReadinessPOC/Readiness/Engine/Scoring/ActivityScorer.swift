import Foundation

/// 活动分 A 计算
enum ActivityScorer {

    /// Day Mode 活动分 (倒 U 型)
    static func dayScore(inputs: ActivityInputs) -> Double {
        guard inputs.availability.isAvailable else { return 0 }

        let steps = inputs.stepsToday ?? 0
        var score: Double

        switch steps {
        case ..<1500:
            score = 45
        case 1500..<7000:
            score = 70
        case 7000..<12000:
            score = 65
        default:
            score = 55
        }

        // 2h 微调
        if let last2h = inputs.stepsLast2h {
            if last2h < 50 {
                score -= 5   // 极低
            } else if last2h > 3000 {
                score -= 5   // 极高
            }
        }

        return min(max(score, 0), 100)
    }

    /// Night Mode 活动分 (饱和上限)
    static func nightScore(inputs: ActivityInputs) -> Double {
        guard inputs.availability.isAvailable else { return 0 }

        let steps = inputs.stepsToday ?? 0

        switch steps {
        case ..<1500:
            return 40
        case 1500..<7000:
            return 65
        case 7000..<12000:
            return 80
        default:
            return 80  // 封顶
        }
    }

    /// 根据模式计算活动分
    static func score(inputs: ActivityInputs, mode: ReadinessMode) -> Double {
        switch mode {
        case .day:   return dayScore(inputs: inputs)
        case .night: return nightScore(inputs: inputs)
        }
    }
}
