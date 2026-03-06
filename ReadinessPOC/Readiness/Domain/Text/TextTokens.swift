import Foundation

// MARK: - 文案 Token 表

enum TextTokens {

    // MARK: 总体判断词（按分档）

    static func overallJudgment(score: Double, mode: ReadinessMode) -> String {
        switch score {
        case ..<40:  return "当前偏低"
        case 40..<60: return "处于一般水平"
        case 60..<80:
            switch mode {
            case .day:   return "处于可用水平"
            case .night: return "处于可入睡水平"
            }
        default:
            switch mode {
            case .day:   return "处于良好水平"
            case .night: return "处于良好水平"
            }
        }
    }

    // MARK: 模式前缀

    static func modePrefix(_ mode: ReadinessMode) -> String {
        switch mode {
        case .day:   return "清醒就绪度"
        case .night: return "睡眠就绪度"
        }
    }

    // MARK: 主因短语

    static func primaryReason(for kind: FactorKind, score: Double, mode: ReadinessMode) -> String {
        switch kind {
        case .circadian:
            return circadianLabel(score: score, mode: mode)
        case .activity:
            return activityLabel(score: score, mode: mode)
        case .recovery:
            return recoveryLabel(score: score)
        }
    }

    // MARK: 节律标签

    static func circadianLabel(score: Double, mode: ReadinessMode) -> String {
        if mode == .night {
            if score >= 70 { return "夜间下行窗口已形成" }
            if score >= 50 { return "夜间节律窗口一般" }
            return "夜间节律窗口偏不利"
        }
        if score >= 70 { return "节律窗口偏有利" }
        if score >= 50 { return "节律窗口一般" }
        return "节律窗口偏不利"
    }

    // MARK: 活动标签

    static func activityLabel(score: Double, mode: ReadinessMode) -> String {
        if mode == .night {
            if score >= 75 { return "活动消耗到位" }
            if score >= 50 { return "活动消耗偏少" }
            return "活动消耗不足"
        }
        if score >= 65 { return "活动水平适中" }
        if score >= 50 { return "活动偏低" }
        return "活动偏高或不足"
    }

    // MARK: 恢复标签

    static func recoveryLabel(score: Double) -> String {
        if score >= 70 { return "睡眠恢复较好" }
        if score >= 50 { return "睡眠恢复一般" }
        return "睡眠恢复不足"
    }

    // MARK: 缺失提示

    static let sleepMissing   = "睡眠数据未接入"
    static let activityMissing = "活动数据未接入"
    static let sunlightMissing = "日照数据未接入（已基于时间节律估计）"

    static func missingPhrase(for kind: FactorKind) -> String {
        switch kind {
        case .circadian: return sunlightMissing
        case .activity:  return activityMissing
        case .recovery:  return sleepMissing
        }
    }

    // MARK: 证据短语

    static func circadianEvidence(sunrise: Date?, sunset: Date?, now: Date) -> String {
        if let sr = sunrise, let ss = sunset {
            if now > sr && now < ss {
                return "当前位于日出后与日落前的主要清醒区间。"
            } else if now > ss {
                return "当前已过日落，光照减弱。"
            } else {
                return "当前为日出前，光照较暗。"
            }
        }
        return "已基于本地时间估计节律位置。"
    }

    static func activityEvidence(steps: Double?, kcal: Double?, mode: ReadinessMode) -> String {
        if let s = steps {
            return "今日已累计 \(Int(s)) 步。"
        }
        if let k = kcal {
            return "今日活动能量 \(Int(k)) 千卡。"
        }
        return "未接入活动数据，因此该项未计入。"
    }

    static func recoveryEvidence(hours: Double?, deepPercent: Double?, mode: ReadinessMode) -> String {
        if let h = hours {
            var text = "昨夜睡眠 \(String(format: "%.1f", h)) 小时。"
            if let dp = deepPercent {
                let level = dp > 0.2 ? "高" : (dp > 0.1 ? "中" : "低")
                text += " 深睡占比处于\(level)。"
            }
            return text
        }
        if mode == .night {
            return "已根据夜间时段估计入睡准备程度。"
        }
        return "未接入睡眠数据，因此恢复项未计入。"
    }
}
