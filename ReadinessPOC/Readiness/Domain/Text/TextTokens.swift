import Foundation

enum TextTokens {
    static func titleStatus(band: ReadinessBand, mode: ReadinessMode) -> String {
        switch (mode, band) {
        case (.day, .veryLow): return "状态明显下滑"
        case (.day, .low): return "状态偏低"
        case (.day, .medium): return "状态平稳"
        case (.day, .good): return "状态良好"
        case (.day, .high): return "状态饱满"
        case (.night, .veryLow): return "还不太困"
        case (.night, .low): return "开始放松"
        case (.night, .medium): return "有些睡意"
        case (.night, .good): return "适合入睡"
        case (.night, .high): return "睡意很强"
        }
    }

    static func titleAction(band: ReadinessBand, mode: ReadinessMode) -> String {
        switch (mode, band) {
        case (.day, .veryLow): return "先降负荷"
        case (.day, .low): return "先补能量"
        case (.day, .medium): return "维持节奏"
        case (.day, .good): return "适合推进"
        case (.day, .high): return "可以释放能量"
        case (.night, .veryLow): return "先别硬睡"
        case (.night, .low): return "慢慢收尾"
        case (.night, .medium): return "可以准备收尾"
        case (.night, .good): return "建议尽快收尾"
        case (.night, .high): return "尽快去休息"
        }
    }

    static func summaryLine(band: ReadinessBand, mode: ReadinessMode) -> String {
        switch mode {
        case .day:
            switch band {
            case .veryLow:
                return "当前清醒状态偏低，先用更轻的节奏把身体和注意力带起来。"
            case .low:
                return "当前清醒状态略弱，适合先把自己拉回稳定区间。"
            case .medium:
                return "当前清醒状态稳定，适合维持手头节奏。"
            case .good:
                return "当前清醒状态良好，适合推进有明确目标的任务。"
            case .high:
                return "当前清醒状态很饱满，适合处理需要集中度的事情。"
            }
        case .night:
            switch band {
            case .veryLow:
                return "当前睡意还弱，先别强迫自己立刻入睡。"
            case .low:
                return "当前已经进入放松区间，可以开始把节奏往下收。"
            case .medium:
                return "当前睡意正在累积，适合结束高刺激内容。"
            case .good:
                return "当前已经比较适合入睡，尽量别再把身体提起来。"
            case .high:
                return "当前睡意很强，直接进入休息流程会更顺。"
            }
        }
    }

    static func missingHint(for kinds: [FactorKind], mode: ReadinessMode) -> String? {
        guard !kinds.isEmpty else { return nil }
        let labels = kinds.map { missingLabel(for: $0, mode: mode) }
        return "部分数据未接入: \(labels.joined(separator: ", "))，当前结果基于可用信息估计。"
    }

    static func reasonText(
        for kind: FactorKind,
        score: Double,
        mode: ReadinessMode,
        inputs: ReadinessInputs
    ) -> String {
        switch (mode, kind) {
        case (.day, .circadian):
            if score >= 72 { return "当前节律窗口已经打开，清醒感在托着状态" }
            if score >= 58 { return "当前节律处在可用区间，足够维持正常推进" }
            return "当前节律还没完全撑起来，启动感会偏弱"
        case (.night, .circadian):
            if score >= 76 { return "夜间下行窗口已经形成，身体更容易往休息状态走" }
            if score >= 60 { return "夜间节律正在往下收，已经开始有入睡条件" }
            return "现在还没完全进入夜间窗口，困意不会那么顺"
        case (.day, .activity):
            if score >= 76 { return "身体已经被适度激活，能量和清醒感更容易维持" }
            if score >= 60 { return "当前活动量足够托住清醒状态，不需要额外补太多刺激" }
            return "身体还没完全被激活，能量感会有点发沉"
        case (.night, .activity):
            if score >= 76 { return "今天身体消耗已经到位，入睡阻力会更小" }
            if score >= 58 { return "今天的活动量基本够用，睡意会慢慢接上来" }
            return "今天身体消耗还不够，睡意累积会偏慢"
        case (.day, .recovery):
            let hours = inputs.recovery.sleepDurationLastNightHours ?? 0
            if hours >= 7 { return "昨夜恢复给今天托了底，状态不太容易一下掉下去" }
            if hours >= 6 { return "昨夜恢复一般，今天需要更依赖节奏和轻激活来维持" }
            return "昨夜恢复不足，今天更容易出现发沉和起不来的感觉"
        case (.night, .recovery):
            let hours = inputs.recovery.sleepDurationLastNightHours ?? 0
            if hours < 5 { return "昨夜睡得偏少，睡眠压力现在已经很明显了" }
            if hours < 6 { return "昨夜睡眠偏少，困意会比平时更早接上来" }
            if hours < 7 { return "睡意正在按正常速度累积，已经开始适合收尾" }
            return "昨夜睡得比较足，现在的睡意主要还得靠节律往下带"
        }
    }

    static func softAdvice(band: ReadinessBand, mode: ReadinessMode, primaryKind: FactorKind?) -> String {
        switch (mode, band) {
        case (.day, .veryLow):
            return primaryKind == .recovery ? "先补水、降低任务难度，给自己一个短恢复窗口" : "先站起来走一走，再回到低认知任务"
        case (.day, .low):
            return "先把节奏拉稳，清掉一件小任务后再决定要不要加速"
        case (.day, .medium):
            return "先维持当前节奏，尽量减少频繁切换"
        case (.day, .good):
            return "适合推进明确的任务，但别一下把体力和注意力都打满"
        case (.day, .high):
            return "适合处理高集中度任务，也记得给后面留一点余量"
        case (.night, .veryLow):
            return "先保持低刺激环境，别太早把自己按进睡眠流程"
        case (.night, .low):
            return "可以先调暗灯光和声音，把身体慢慢带进放松状态"
        case (.night, .medium):
            return "把高刺激内容停在这一轮，开始进入收尾流程"
        case (.night, .good):
            return "适合洗漱、调暗灯光，尽量不要再补新的兴奋点"
        case (.night, .high):
            return "现在直接去休息会更顺，别再给自己额外提神"
        }
    }

    static func missingLabel(for kind: FactorKind, mode: ReadinessMode) -> String {
        switch (mode, kind) {
        case (_, .circadian):
            return "节律"
        case (_, .activity):
            return "活动"
        case (.day, .recovery):
            return "恢复"
        case (.night, .recovery):
            return "睡眠压力"
        }
    }
}
