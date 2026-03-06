import Foundation

/// 聚合评分 + 文案生成
enum ReadinessAggregator {

    /// 从 ReadinessInputs 计算完整结果
    static func evaluate(inputs: ReadinessInputs) -> ReadinessResult {
        let mode = inputs.global.mode
        let scheme = WeightScheme.scheme(for: mode)

        // 1. 计算各子分
        let cScore = CircadianScorer.score(inputs: inputs.circadian, global: inputs.global)
        let aScore = ActivityScorer.score(inputs: inputs.activity, mode: mode)
        let sScore = RecoveryScorer.score(inputs: inputs.recovery, mode: mode)

        // 2. 收集可用因子
        struct FactorEntry {
            let kind: FactorKind
            let score: Double
            let weight: Double
            let availability: Availability
        }

        var factors: [FactorEntry] = []

        // 节律：总是至少 estimated
        factors.append(FactorEntry(
            kind: .circadian, score: cScore,
            weight: scheme.circadian,
            availability: inputs.circadian.availability
        ))

        // 活动
        if inputs.activity.availability.isAvailable {
            factors.append(FactorEntry(
                kind: .activity, score: aScore,
                weight: scheme.activity,
                availability: inputs.activity.availability
            ))
        }

        // 恢复
        if inputs.recovery.availability.isAvailable {
            factors.append(FactorEntry(
                kind: .recovery, score: sScore,
                weight: scheme.recovery,
                availability: inputs.recovery.availability
            ))
        }

        // 3. 归一化权重
        let totalWeight = factors.reduce(0.0) { $0 + $1.weight }
        guard totalWeight > 0 else {
            // 极端情况：无任何数据
            return ReadinessResult(
                mode: mode,
                overallScore: 50,
                sleepDebtBonus: 0,
                sleepDebtBonusReasons: [.none],
                subScores: [],
                text: fallbackText(mode: mode),
                timestamp: inputs.global.now
            )
        }

        // 4. 加权求和
        var overallScore: Double = 0
        var contribs: [(FactorKind, Double)] = []

        for f in factors {
            let nw = f.weight / totalWeight
            let contrib = nw * f.score
            overallScore += contrib
            contribs.append((f.kind, contrib))
        }

        let contribSum = contribs.reduce(0.0) { $0 + $1.1 }

        // 5. 生成 SubScore 数组
        let subScores: [SubScore] = factors.map { f in
            let nw = f.weight / totalWeight
            let contrib = nw * f.score
            let pct = contribSum > 0 ? (contrib / contribSum) * 100 : 0
            return SubScore(
                id: f.kind,
                value: f.score,
                normalizedWeight: nw,
                contributionPercent: pct,
                availability: f.availability
            )
        }

        // 6. Sleep Debt Bonus（仅 Night Mode）
        let bonusResult = SleepDebtBonusCalculator.calculate(
            mode: mode,
            sleepDuration: inputs.recovery.sleepDurationLastNightHours,
            stepsToday: inputs.activity.stepsToday,
            activeEnergy: inputs.activity.activeEnergyTodayKcal
        )
        let finalScore = min(max(overallScore + bonusResult.bonus, 0), 100)

        // 7. 生成文案
        let text = generateText(
            mode: mode,
            overall: finalScore,
            subScores: subScores,
            inputs: inputs,
            bonusResult: bonusResult
        )

        return ReadinessResult(
            mode: mode,
            overallScore: finalScore,
            sleepDebtBonus: bonusResult.bonus,
            sleepDebtBonusReasons: bonusResult.reasons,
            subScores: subScores,
            text: text,
            timestamp: inputs.global.now
        )
    }

    // MARK: - 文案生成

    private static func generateText(
        mode: ReadinessMode,
        overall: Double,
        subScores: [SubScore],
        inputs: ReadinessInputs,
        bonusResult: SleepDebtBonusResult
    ) -> ReadinessTextOutput {
        // 总览句
        let overviewSentence = buildOverviewSentence(
            mode: mode, overall: overall, subScores: subScores,
            inputs: inputs, bonusResult: bonusResult
        )

        // 三卡小解释
        let circadianExpl = buildCircadianExplanation(
            subScores: subScores, inputs: inputs
        )
        let activityExpl = buildActivityExplanation(
            subScores: subScores, inputs: inputs, mode: mode
        )
        let recoveryExpl = buildRecoveryExplanation(
            subScores: subScores, inputs: inputs, mode: mode
        )

        // 缺失提示
        let missingKinds = missingFactors(inputs: inputs)
        let missingHint: String? = missingKinds.isEmpty ? nil :
            "部分健康数据未接入，总分基于可用数据估计"

        return ReadinessTextOutput(
            overviewSentence: overviewSentence,
            circadianExplanation: circadianExpl,
            activityExplanation: activityExpl,
            recoveryExplanation: recoveryExpl,
            missingHint: missingHint
        )
    }

    // MARK: 总览句

    private static func buildOverviewSentence(
        mode: ReadinessMode,
        overall: Double,
        subScores: [SubScore],
        inputs: ReadinessInputs,
        bonusResult: SleepDebtBonusResult
    ) -> String {
        let prefix = TextTokens.modePrefix(mode)
        let judgment = TextTokens.overallJudgment(score: overall, mode: mode)

        // 排出主因（measured 优先，按贡献度排序）
        let measured = subScores
            .filter { $0.availability.isMeasured }
            .sorted { $0.contributionPercent > $1.contributionPercent }

        let estimated = subScores
            .filter { !$0.availability.isMeasured && $0.availability.isAvailable }
            .sorted { $0.contributionPercent > $1.contributionPercent }

        let ranked = measured + estimated
        let missing = missingFactors(inputs: inputs)

        var parts: [String] = []
        parts.append("\(prefix) \(Int(overall))")
        parts.append(judgment)

        if let first = ranked.first {
            let label = TextTokens.primaryReason(for: first.id, score: first.value, mode: mode)
            parts.append("主要来自\(label)")

            if ranked.count > 1 {
                let second = ranked[1]
                let label2 = TextTokens.primaryReason(for: second.id, score: second.value, mode: mode)
                parts.append("其次是\(label2)")
            } else if !missing.isEmpty {
                parts.append(TextTokens.missingPhrase(for: missing.first!))
            }
        } else if !missing.isEmpty {
            parts.append(TextTokens.missingPhrase(for: missing.first!))
        }

        var sentence = parts.joined(separator: "，") + "。"

        // Sleep Debt Bonus 追加短句
        if mode == .night && bonusResult.bonus > 0 {
            let isDiscounted = bonusResult.reasons.contains(.discountedForLowActivity)
            if isDiscounted {
                sentence += " 昨夜睡眠偏少，但今日活动偏低，该影响已保守处理。"
            } else if bonusResult.reasons.contains(.shortSleepBelow5) {
                sentence += " 昨夜睡眠明显偏少，困倦概率更高。"
            } else if bonusResult.reasons.contains(.shortSleep5to6) {
                sentence += " 昨夜睡眠偏少，睡眠压力可能更高。"
            }
        }

        return sentence
    }

    // MARK: 卡片解释

    private static func buildCircadianExplanation(
        subScores: [SubScore],
        inputs: ReadinessInputs
    ) -> String {
        let sub = subScores.first { $0.id == .circadian }
        let score = sub?.value ?? 50
        let mode = inputs.global.mode

        let label = TextTokens.circadianLabel(score: score, mode: mode)
        let evidence = TextTokens.circadianEvidence(
            sunrise: inputs.circadian.sunrise,
            sunset: inputs.circadian.sunset,
            now: inputs.global.now
        )

        var text = "\(label)，\(evidence)"

        // 节假日补充
        if inputs.global.isHoliday == true {
            text += " 今天为节假日，压力因子较低。"
        }

        return text
    }

    private static func buildActivityExplanation(
        subScores: [SubScore],
        inputs: ReadinessInputs,
        mode: ReadinessMode
    ) -> String {
        guard inputs.activity.availability.isAvailable else {
            return "未接入活动数据，因此该项未计入。"
        }

        let sub = subScores.first { $0.id == .activity }
        let score = sub?.value ?? 50

        let label = TextTokens.activityLabel(score: score, mode: mode)
        let evidence = TextTokens.activityEvidence(
            steps: inputs.activity.stepsToday,
            kcal: inputs.activity.activeEnergyTodayKcal,
            mode: mode
        )

        return "\(label)，\(evidence)"
    }

    private static func buildRecoveryExplanation(
        subScores: [SubScore],
        inputs: ReadinessInputs,
        mode: ReadinessMode
    ) -> String {
        guard inputs.recovery.availability.isAvailable else {
            if mode == .night {
                return "已根据夜间时段估计入睡准备程度。"
            }
            return "未接入睡眠数据，因此恢复项未计入。"
        }

        let sub = subScores.first { $0.id == .recovery }
        let score = sub?.value ?? 50

        let label = TextTokens.recoveryLabel(score: score)
        let evidence = TextTokens.recoveryEvidence(
            hours: inputs.recovery.sleepDurationLastNightHours,
            deepPercent: inputs.recovery.sleepStages?.deepPercent,
            mode: mode
        )

        return "\(label)，\(evidence)"
    }

    // MARK: 缺失因子

    private static func missingFactors(inputs: ReadinessInputs) -> [FactorKind] {
        var missing: [FactorKind] = []
        if !inputs.activity.availability.isAvailable { missing.append(.activity) }
        if !inputs.recovery.availability.isAvailable { missing.append(.recovery) }
        // 节律总是至少 estimated，不算 missing
        return missing
    }

    // MARK: Fallback

    private static func fallbackText(mode: ReadinessMode) -> ReadinessTextOutput {
        ReadinessTextOutput(
            overviewSentence: "\(TextTokens.modePrefix(mode)) --，数据不足，无法评估。",
            circadianExplanation: "暂无数据。",
            activityExplanation: "暂无数据。",
            recoveryExplanation: "暂无数据。",
            missingHint: "所有健康数据均未接入"
        )
    }
}
