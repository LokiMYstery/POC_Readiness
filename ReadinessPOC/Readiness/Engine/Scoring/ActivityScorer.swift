import Foundation

enum ActivityScorer {
    private struct DayTarget {
        let minuteOfDay: Double
        let lower: Double
        let upper: Double
        let lowerFloor: Double
        let peak: Double
        let upperFloor: Double
    }

    private struct ScoreAnchor {
        let value: Double
        let score: Double
    }

    private static let dayTargets: [DayTarget] = [
        DayTarget(minuteOfDay: 360, lower: 200, upper: 1000, lowerFloor: 58, peak: 74, upperFloor: 68),
        DayTarget(minuteOfDay: 600, lower: 1200, upper: 2800, lowerFloor: 50, peak: 80, upperFloor: 72),
        DayTarget(minuteOfDay: 840, lower: 3200, upper: 6000, lowerFloor: 40, peak: 84, upperFloor: 74),
        DayTarget(minuteOfDay: 1080, lower: 5200, upper: 8500, lowerFloor: 38, peak: 82, upperFloor: 72),
        DayTarget(minuteOfDay: 1320, lower: 6500, upper: 9500, lowerFloor: 44, peak: 76, upperFloor: 70),
    ]

    private static let nightStepAnchors: [ScoreAnchor] = [
        ScoreAnchor(value: 0, score: 28),
        ScoreAnchor(value: 1500, score: 42),
        ScoreAnchor(value: 3500, score: 58),
        ScoreAnchor(value: 6500, score: 74),
        ScoreAnchor(value: 8000, score: 82),
        ScoreAnchor(value: 11000, score: 84),
    ]

    private static let nightEnergyAnchors: [ScoreAnchor] = [
        ScoreAnchor(value: 0, score: 30),
        ScoreAnchor(value: 120, score: 42),
        ScoreAnchor(value: 260, score: 58),
        ScoreAnchor(value: 420, score: 72),
        ScoreAnchor(value: 650, score: 82),
        ScoreAnchor(value: 900, score: 84),
    ]

    static func dayScore(inputs: ActivityInputs, global: GlobalContext) -> Double {
        guard inputs.availability.isAvailable else { return 0 }

        let steps = inputs.stepsToday ?? 0
        let minuteOfDay = minuteOfDay(from: global)
        let target = dayTarget(at: minuteOfDay)
        let score = dayBaseScore(steps: steps, target: target) + recentActivityAdjustment(stepsLast2h: inputs.stepsLast2h, minuteOfDay: minuteOfDay)

        return min(max(score, 0), 100)
    }

    static func nightScore(inputs: ActivityInputs) -> Double {
        guard inputs.availability.isAvailable else { return 0 }

        if let steps = inputs.stepsToday {
            return interpolatedScore(for: steps, anchors: nightStepAnchors)
        }

        if let energy = inputs.activeEnergyTodayKcal {
            return interpolatedScore(for: energy, anchors: nightEnergyAnchors)
        }

        return 0
    }

    static func score(inputs: ActivityInputs, mode: ReadinessMode, global: GlobalContext) -> Double {
        switch mode {
        case .day:
            return dayScore(inputs: inputs, global: global)
        case .night:
            return nightScore(inputs: inputs)
        }
    }

    private static func dayTarget(at minuteOfDay: Double) -> DayTarget {
        let clampedMinute = min(max(minuteOfDay, dayTargets.first?.minuteOfDay ?? minuteOfDay), dayTargets.last?.minuteOfDay ?? minuteOfDay)

        guard let upperIndex = dayTargets.firstIndex(where: { clampedMinute <= $0.minuteOfDay }) else {
            return dayTargets.last ?? DayTarget(minuteOfDay: clampedMinute, lower: 6500, upper: 9500, lowerFloor: 44, peak: 76, upperFloor: 70)
        }
        guard upperIndex > 0 else { return dayTargets[upperIndex] }

        let lowerAnchor = dayTargets[upperIndex - 1]
        let upperAnchor = dayTargets[upperIndex]
        let range = upperAnchor.minuteOfDay - lowerAnchor.minuteOfDay
        guard range > 0 else { return upperAnchor }

        let progress = smoothstep((clampedMinute - lowerAnchor.minuteOfDay) / range)
        return DayTarget(
            minuteOfDay: clampedMinute,
            lower: interpolate(lowerAnchor.lower, upperAnchor.lower, progress),
            upper: interpolate(lowerAnchor.upper, upperAnchor.upper, progress),
            lowerFloor: interpolate(lowerAnchor.lowerFloor, upperAnchor.lowerFloor, progress),
            peak: interpolate(lowerAnchor.peak, upperAnchor.peak, progress),
            upperFloor: interpolate(lowerAnchor.upperFloor, upperAnchor.upperFloor, progress)
        )
    }

    private static func dayBaseScore(steps: Double, target: DayTarget) -> Double {
        let lower = target.lower
        let upper = target.upper
        let midpoint = (lower + upper) / 2
        let inRangeFloor = target.peak - 4

        if steps < lower {
            let progress = lower > 0 ? min(max(steps / lower, 0), 1) : 1
            return interpolate(target.lowerFloor, inRangeFloor, smoothstep(progress))
        }

        if steps <= upper {
            let halfWidth = max((upper - lower) / 2, 1)
            let distanceRatio = min(abs(steps - midpoint) / halfWidth, 1)
            let closeness = 1 - distanceRatio
            return inRangeFloor + smoothstep(closeness) * (target.peak - inRangeFloor)
        }

        let overflowWindow = max((upper - lower) * 0.9, 1800)
        let overflow = min(max((steps - upper) / overflowWindow, 0), 1)
        return target.peak - smoothstep(overflow) * (target.peak - target.upperFloor)
    }

    private static func recentActivityAdjustment(stepsLast2h: Double?, minuteOfDay: Double) -> Double {
        guard let stepsLast2h else { return 0 }
        guard minuteOfDay >= 600 else { return 0 }

        let lowActivityPenaltyFloor: Double
        if minuteOfDay >= 1080 {
            lowActivityPenaltyFloor = -12
        } else if minuteOfDay >= 840 {
            lowActivityPenaltyFloor = -10
        } else {
            lowActivityPenaltyFloor = -8
        }

        switch stepsLast2h {
        case ..<200:
            return interpolate(lowActivityPenaltyFloor, 0, min(max(stepsLast2h / 200, 0), 1))
        case 200..<1200:
            return interpolate(0, 4, min(max((stepsLast2h - 200) / 1000, 0), 1))
        case 1200..<2200:
            return interpolate(4, 0, min(max((stepsLast2h - 1200) / 1000, 0), 1))
        default:
            let overflow = min(max((stepsLast2h - 2200) / 1800, 0), 1)
            return interpolate(0, -4, overflow)
        }
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
        return interpolate(lowerAnchor.score, upperAnchor.score, progress)
    }

    private static func minuteOfDay(from global: GlobalContext) -> Double {
        var calendar = Calendar.current
        calendar.timeZone = global.timezone
        let hour = calendar.component(.hour, from: global.now)
        let minute = calendar.component(.minute, from: global.now)
        return Double(hour * 60 + minute)
    }

    private static func interpolate(_ start: Double, _ end: Double, _ progress: Double) -> Double {
        start + (end - start) * progress
    }

    private static func smoothstep(_ progress: Double) -> Double {
        let clamped = min(max(progress, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }
}
