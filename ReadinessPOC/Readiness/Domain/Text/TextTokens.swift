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
                return "现在更适合先放慢一点，从轻任务和基础照顾开始。"
            case .low:
                return "先把节奏放稳一点，给自己一点缓冲，再慢慢提起来。"
            case .medium:
                return "状态还算稳，按现在的节奏往前走会比较舒服。"
            case .good:
                return "这会儿适合推进重点事项，但还是记得给自己留余量。"
            case .high:
                return "现在是比较能出活的时候，可以安排更需要专注的事情。"
            }
        case .night:
            switch band {
            case .veryLow:
                return "这会儿还不用急着睡，先把环境放松下来会更自然。"
            case .low:
                return "可以开始慢慢收尾，让自己舒服地进入休息前的节奏。"
            case .medium:
                return "现在适合把高刺激内容停下来，给自己一点安静的过渡。"
            case .good:
                return "这会儿已经比较适合睡了，尽量别再把自己弄清醒。"
            case .high:
                return "现在就去休息会更顺，也算是在照顾明天的自己。"
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
            if score >= 72 { return "这会儿节律状态不错，适合把重要任务往前放一放" }
            if score >= 58 { return "现在的节奏还算稳，按部就班地推进会比较省力" }
            return "现在还没完全进入最好状态，先从轻一点的事情开始会更顺"
        case (.night, .circadian):
            if score >= 76 { return "现在已经到了比较适合休息的时段，可以安心去睡" }
            if score >= 60 { return "这会儿可以开始收尾，把灯光和注意力一起放下来" }
            return "现在还不算很晚，先别催自己睡，慢慢放松就好"
        case (.day, .activity):
            if score >= 76 { return "身体已经活动开了，这会儿做事会更容易进入状态" }
            if score >= 60 { return "活动量基本够用，先照着现在的节奏继续就可以" }
            return "身体还没完全热起来，先起身动一动会比硬扛更舒服"
        case (.night, .activity):
            if score >= 76 { return "今天身体已经消耗得差不多了，这会儿休息会更容易进入状态" }
            if score >= 58 { return "今天活动量基本够用，先安静下来，睡意通常会更顺一点" }
            return "今天活动偏少一些，先别着急睡，给自己一点放松和缓冲时间"
        case (.day, .recovery):
            let hours = inputs.recovery.sleepDurationLastNightHours ?? 0
            if hours >= 7 { return "昨晚休息得还不错，今天可以更从容地安排事情" }
            if hours >= 6 { return "昨晚恢复一般，今天把节奏放稳一点会更舒服" }
            return "昨晚休息不太够，今天先对自己温和一点，别一开始就拉太满"
        case (.night, .recovery):
            let hours = inputs.recovery.sleepDurationLastNightHours ?? 0
            if hours < 5 { return "昨晚睡得偏少，今晚可以早点收尾，别再硬撑了" }
            if hours < 6 { return "昨晚休息不太够，今晚更适合早点放下事情，优先照顾睡眠" }
            if hours < 7 { return "今晚可以开始收一收，让自己慢慢进入休息状态" }
            return "昨晚睡得还可以，如果现在还不困，也不用给自己太大压力"
        }
    }

    static func softAdvice(band: ReadinessBand, mode: ReadinessMode, primaryKind: FactorKind?) -> String {
        switch (mode, band) {
        case (.day, .veryLow):
            return primaryKind == .recovery ? "先补水、放低一点任务难度，给自己留一个短恢复窗口" : "先起来走一走，再回到不那么费脑的事情上"
        case (.day, .low):
            return "先把节奏放稳，做完一件小事再决定要不要提速"
        case (.day, .medium):
            return "维持现在的节奏，少一点来回切换会更轻松"
        case (.day, .good):
            return "适合推进明确任务，但别一下把精力和体力全用满"
        case (.day, .high):
            return "适合安排高专注任务，也记得给后面留一点缓冲"
        case (.night, .veryLow):
            return "先把环境调得柔和一点，别太早逼自己进入睡眠流程"
        case (.night, .low):
            return "可以先调暗灯光和声音，让身体慢慢放松下来"
        case (.night, .medium):
            return "把高刺激内容停在这一轮，开始做些收尾和安静下来的动作"
        case (.night, .good):
            return "适合去洗漱、关暗一点灯，尽量别再给自己新的兴奋点"
        case (.night, .high):
            return "现在直接去休息会更顺，别再继续提神了"
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
