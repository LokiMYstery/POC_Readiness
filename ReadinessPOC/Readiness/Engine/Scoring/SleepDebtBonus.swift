import Foundation

// MARK: - Sleep Debt Bonus Reason

/// bonus 产生的原因
enum SleepDebtBonusReason: String, CaseIterable {
    case none                       // 无 bonus
    case shortSleep5to6             // 5–6h
    case shortSleepBelow5           // <5h
    case discountedForLowActivity   // 活动过低打折
}

// MARK: - Sleep Debt Bonus Result

/// bonus 计算结果（供 Debug 面板和文案层使用）
struct SleepDebtBonusResult {
    let bonus: Double                         // 0–8
    let reasons: [SleepDebtBonusReason]       // 可能多条（基础 + 打折）
}

// MARK: - Calculator

enum SleepDebtBonusCalculator {

    /// 计算 Night Mode Sleep Debt Bonus
    /// - Parameters:
    ///   - mode: 当前模式（仅 .night 生效）
    ///   - sleepDuration: 昨夜睡眠时长（小时），nil 表示缺失
    ///   - stepsToday: 今日步数（可选）
    ///   - activeEnergy: 今日活动能量 kcal（可选，步数不可用时作备选）
    static func calculate(
        mode: ReadinessMode,
        sleepDuration: Double?,
        stepsToday: Double?,
        activeEnergy: Double?
    ) -> SleepDebtBonusResult {

        // 1) 仅 Night Mode
        guard mode == .night else {
            return SleepDebtBonusResult(bonus: 0, reasons: [.none])
        }

        // 2) 睡眠数据缺失
        guard let T = sleepDuration else {
            return SleepDebtBonusResult(bonus: 0, reasons: [.none])
        }

        // 3) 基础 bonus
        var bonus: Double
        var reasons: [SleepDebtBonusReason]

        if T >= 6.0 {
            return SleepDebtBonusResult(bonus: 0, reasons: [.none])
        } else if T >= 5.0 {
            bonus = 5.0
            reasons = [.shortSleep5to6]
        } else {
            bonus = 8.0
            reasons = [.shortSleepBelow5]
        }

        // 4) 活动过低打折
        var discounted = false
        if let steps = stepsToday {
            if steps < 1500 {
                discounted = true
            }
        } else if let energy = activeEnergy {
            if energy < 120 {
                discounted = true
            }
        }
        // 两者都不可用 → 不打折

        if discounted {
            bonus *= 0.5
            reasons.append(.discountedForLowActivity)
        }

        // 5) 封顶
        bonus = min(max(bonus, 0), 8)

        return SleepDebtBonusResult(bonus: bonus, reasons: reasons)
    }
}
