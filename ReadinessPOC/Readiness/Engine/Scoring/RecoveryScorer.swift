import Foundation

enum RecoveryScorer {
    private struct ScoreAnchor {
        let value: Double
        let score: Double
    }

    private static let dayAnchors: [ScoreAnchor] = [
        ScoreAnchor(value: 4.5, score: 28),
        ScoreAnchor(value: 5.5, score: 40),
        ScoreAnchor(value: 6.5, score: 56),
        ScoreAnchor(value: 7.5, score: 74),
        ScoreAnchor(value: 8.5, score: 82),
        ScoreAnchor(value: 9.5, score: 74),
    ]

    private static let nightAnchors: [ScoreAnchor] = [
        ScoreAnchor(value: 4.5, score: 90),
        ScoreAnchor(value: 5.5, score: 80),
        ScoreAnchor(value: 6.5, score: 65),
        ScoreAnchor(value: 7.5, score: 48),
        ScoreAnchor(value: 8.5, score: 32),
        ScoreAnchor(value: 9.5, score: 24),
    ]

    static func score(inputs: RecoveryInputs, mode: ReadinessMode) -> Double {
        guard inputs.availability.isAvailable else { return 0 }

        switch mode {
        case .day:
            return dayScore(inputs: inputs)
        case .night:
            return nightScore(inputs: inputs)
        }
    }

    private static func dayScore(inputs: RecoveryInputs) -> Double {
        let base = inputs.sleepDurationLastNightHours.map { interpolatedScore(for: $0, anchors: dayAnchors) } ?? 58
        let adjustment = combinedAdjustment(restingHeartRate: inputs.restingHeartRate, hrvSDNN: inputs.hrvSDNN, hrCap: 3, hrvCap: 3, totalCap: 6)
        return min(max(base + adjustment, 0), 100)
    }

    private static func nightScore(inputs: RecoveryInputs) -> Double {
        let base = inputs.sleepDurationLastNightHours.map { interpolatedScore(for: $0, anchors: nightAnchors) } ?? 50
        let adjustment = combinedAdjustment(restingHeartRate: inputs.restingHeartRate, hrvSDNN: inputs.hrvSDNN, hrCap: 2, hrvCap: 2, totalCap: 4)
        return min(max(base + adjustment, 0), 100)
    }

    private static func combinedAdjustment(
        restingHeartRate: Double?,
        hrvSDNN: Double?,
        hrCap: Double,
        hrvCap: Double,
        totalCap: Double
    ) -> Double {
        let hrAdjustment = restingHeartRate.map { interpolatedValueAdjustment(for: $0, favorableRange: 52...62, supportedRange: 48...84, cap: hrCap, invert: true) } ?? 0
        let hrvAdjustment = hrvSDNN.map { interpolatedValueAdjustment(for: $0, favorableRange: 48...70, supportedRange: 20...90, cap: hrvCap, invert: false) } ?? 0
        return min(max(hrAdjustment + hrvAdjustment, -totalCap), totalCap)
    }

    private static func interpolatedValueAdjustment(
        for value: Double,
        favorableRange: ClosedRange<Double>,
        supportedRange: ClosedRange<Double>,
        cap: Double,
        invert: Bool
    ) -> Double {
        let normalized: Double
        if value <= supportedRange.lowerBound {
            normalized = invert ? 1 : 0
        } else if value >= supportedRange.upperBound {
            normalized = invert ? 0 : 1
        } else {
            normalized = (value - supportedRange.lowerBound) / (supportedRange.upperBound - supportedRange.lowerBound)
        }

        let favorableMidpoint = (favorableRange.lowerBound + favorableRange.upperBound) / 2
        let supportedMidpoint = (supportedRange.lowerBound + supportedRange.upperBound) / 2
        let midpointNormalized = supportedMidpoint == supportedRange.lowerBound ? 0.5 : (favorableMidpoint - supportedRange.lowerBound) / (supportedRange.upperBound - supportedRange.lowerBound)
        let centered = invert ? midpointNormalized - normalized : normalized - midpointNormalized
        let scaled = centered / max(midpointNormalized, 1 - midpointNormalized)
        return min(max(scaled, -1), 1) * cap
    }

    private static func interpolatedScore(for value: Double, anchors: [ScoreAnchor]) -> Double {
        let clampedValue = min(max(value, anchors.first?.value ?? value), anchors.last?.value ?? value)

        guard let upperIndex = anchors.firstIndex(where: { clampedValue <= $0.value }) else {
            return anchors.last?.score ?? 0
        }
        guard upperIndex > 0 else { return anchors[upperIndex].score }

        let lowerAnchor = anchors[upperIndex - 1]
        let upperAnchor = anchors[upperIndex]
        let range = upperAnchor.value - lowerAnchor.value
        guard range > 0 else { return upperAnchor.score }

        let progress = smoothstep((clampedValue - lowerAnchor.value) / range)
        return lowerAnchor.score + (upperAnchor.score - lowerAnchor.score) * progress
    }

    private static func smoothstep(_ progress: Double) -> Double {
        let clamped = min(max(progress, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }
}
