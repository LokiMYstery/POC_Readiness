import Foundation

enum ActivityScorer {
    private struct DayTarget {
        let range: ClosedRange<Int>
        let lowerFloor: Double
        let peak: Double
        let upperFloor: Double
    }

    static func dayScore(inputs: ActivityInputs, global: GlobalContext) -> Double {
        guard inputs.availability.isAvailable else { return 0 }

        let steps = inputs.stepsToday ?? 0
        let hour = calendarHour(from: global)
        let target = dayTarget(for: hour)
        let lower = Double(target.range.lowerBound)
        let upper = Double(target.range.upperBound)
        let midpoint = (lower + upper) / 2

        let baseScore: Double
        if steps < lower {
            let progress = lower > 0 ? steps / lower : 1
            baseScore = target.lowerFloor + (target.peak - target.lowerFloor) * progress
        } else if steps <= upper {
            let distance = abs(steps - midpoint)
            let halfWidth = max((upper - lower) / 2, 1)
            let closeness = 1 - min(distance / halfWidth, 1)
            baseScore = (target.peak - 6) + closeness * 6
        } else {
            let overflow = min((steps - upper) / max(upper, 1), 1)
            baseScore = target.peak - (target.peak - target.upperFloor) * overflow
        }

        var score = baseScore

        if let last2h = inputs.stepsLast2h {
            if hour >= 10 && last2h < 80 {
                score -= 6
            } else if hour >= 10 && last2h < 180 {
                score -= 3
            } else if last2h > 3200 {
                score -= 4
            } else if last2h > 2200 {
                score -= 2
            } else if hour >= 10 && last2h >= 400 && last2h <= 1800 {
                score += 2
            }
        }

        return min(max(score, 0), 100)
    }

    static func nightScore(inputs: ActivityInputs) -> Double {
        guard inputs.availability.isAvailable else { return 0 }

        let steps = inputs.stepsToday ?? 0

        if let energy = inputs.activeEnergyTodayKcal, steps == 0 {
            switch energy {
            case ..<120:
                return 35
            case 120..<260:
                return 52
            case 260..<420:
                return 68
            case 420..<650:
                return 80
            default:
                return 84
            }
        }

        switch steps {
        case ..<1500:
            return 35
        case 1500..<3500:
            return 50
        case 3500..<6500:
            return 65
        case 6500..<9500:
            return 78
        default:
            return 84
        }
    }

    static func score(inputs: ActivityInputs, mode: ReadinessMode, global: GlobalContext) -> Double {
        switch mode {
        case .day:
            return dayScore(inputs: inputs, global: global)
        case .night:
            return nightScore(inputs: inputs)
        }
    }

    private static func dayTarget(for hour: Int) -> DayTarget {
        switch hour {
        case 6..<10:
            return DayTarget(range: 300...1200, lowerFloor: 60, peak: 78, upperFloor: 70)
        case 10..<14:
            return DayTarget(range: 1500...3500, lowerFloor: 52, peak: 76, upperFloor: 68)
        case 14..<18:
            return DayTarget(range: 4000...7000, lowerFloor: 42, peak: 80, upperFloor: 70)
        default:
            return DayTarget(range: 6000...9000, lowerFloor: 40, peak: 78, upperFloor: 72)
        }
    }

    private static func calendarHour(from global: GlobalContext) -> Int {
        var calendar = Calendar.current
        calendar.timeZone = global.timezone
        return calendar.component(.hour, from: global.now)
    }
}
