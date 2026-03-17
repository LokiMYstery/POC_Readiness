import Foundation

enum ReadinessAggregator {
    static func evaluate(inputs: ReadinessInputs) -> ReadinessResult {
        let mode = inputs.global.mode
        let scheme = WeightScheme.scheme(for: mode)

        let cScore = CircadianScorer.score(inputs: inputs.circadian, global: inputs.global)
        let aScore = ActivityScorer.score(inputs: inputs.activity, mode: mode, global: inputs.global)
        let sScore = RecoveryScorer.score(inputs: inputs.recovery, mode: mode)

        struct FactorEntry {
            let kind: FactorKind
            let score: Double
            let weight: Double
            let availability: Availability
        }

        var factors: [FactorEntry] = [
            FactorEntry(
                kind: .circadian,
                score: cScore,
                weight: scheme.circadian,
                availability: inputs.circadian.availability
            )
        ]

        if inputs.activity.availability.isAvailable {
            factors.append(FactorEntry(
                kind: .activity,
                score: aScore,
                weight: scheme.activity,
                availability: inputs.activity.availability
            ))
        }

        if inputs.recovery.availability.isAvailable {
            factors.append(FactorEntry(
                kind: .recovery,
                score: sScore,
                weight: scheme.recovery,
                availability: inputs.recovery.availability
            ))
        }

        let totalWeight = factors.reduce(0.0) { $0 + $1.weight }
        guard totalWeight > 0 else {
            let band = ReadinessBand(score: 50)
            return ReadinessResult(
                mode: mode,
                overallScore: 50,
                band: band,
                subScores: [],
                text: fallbackText(mode: mode, band: band),
                timestamp: inputs.global.now
            )
        }

        var overallScore: Double = 0
        var contributions: [(FactorKind, Double)] = []

        for factor in factors {
            let normalizedWeight = factor.weight / totalWeight
            let contribution = normalizedWeight * factor.score
            overallScore += contribution
            contributions.append((factor.kind, contribution))
        }

        let contributionSum = contributions.reduce(0.0) { $0 + $1.1 }
        let subScores = factors.map { factor in
            let normalizedWeight = factor.weight / totalWeight
            let contribution = normalizedWeight * factor.score
            let contributionPercent = contributionSum > 0 ? (contribution / contributionSum) * 100 : 0
            return SubScore(
                id: factor.kind,
                value: factor.score,
                normalizedWeight: normalizedWeight,
                contributionPercent: contributionPercent,
                availability: factor.availability
            )
        }

        let finalScore = min(max(overallScore, 0), 100)
        let band = ReadinessBand(score: finalScore)

        return ReadinessResult(
            mode: mode,
            overallScore: finalScore,
            band: band,
            subScores: subScores,
            text: generateText(mode: mode, band: band, subScores: subScores, inputs: inputs),
            timestamp: inputs.global.now
        )
    }

    private static func generateText(
        mode: ReadinessMode,
        band: ReadinessBand,
        subScores: [SubScore],
        inputs: ReadinessInputs
    ) -> ReadinessTextOutput {
        let ranked = prioritizedFactors(subScores: subScores)
        let primary = ranked.first

        let heroTitle = "\(TextTokens.titleStatus(band: band, mode: mode)), \(TextTokens.titleAction(band: band, mode: mode))"
        let primaryExplanation: String = {
            guard let primary else {
                return "当前可用数据不足，先用更轻的节奏观察身体反馈。"
            }

            return TextTokens.reasonText(
                for: primary.id,
                score: primary.value,
                mode: mode,
                inputs: inputs
            )
        }()

        return ReadinessTextOutput(
            heroTitle: heroTitle,
            heroSubtitle: primaryExplanation,
            summaryLine: primaryExplanation,
            missingHint: TextTokens.missingHint(for: missingFactors(inputs: inputs), mode: mode)
        )
    }

    private static func missingFactors(inputs: ReadinessInputs) -> [FactorKind] {
        var missing: [FactorKind] = []
        if !inputs.activity.availability.isAvailable {
            missing.append(.activity)
        }
        if !inputs.recovery.availability.isAvailable {
            missing.append(.recovery)
        }
        return missing
    }

    private static func prioritizedFactors(subScores: [SubScore]) -> [SubScore] {
        let measured = subScores
            .filter { $0.availability.isMeasured }
            .sorted { $0.contributionPercent > $1.contributionPercent }
        let estimated = subScores
            .filter { !$0.availability.isMeasured && $0.availability.isAvailable }
            .sorted { $0.contributionPercent > $1.contributionPercent }
        return measured + estimated
    }

    private static func fallbackText(mode: ReadinessMode, band: ReadinessBand) -> ReadinessTextOutput {
        ReadinessTextOutput(
            heroTitle: "\(TextTokens.titleStatus(band: band, mode: mode)), \(TextTokens.titleAction(band: band, mode: mode))",
            heroSubtitle: "当前可用数据不足，先用更轻的节奏观察身体反馈。",
            summaryLine: "当前结果基于非常有限的数据，先把它当成趋势提示而不是绝对判断。",
            missingHint: "所有健康数据均未接入。"
        )
    }
}
