import Foundation

enum RecoveryScorer {
    static func score(inputs: RecoveryInputs, mode: ReadinessMode) -> Double {
        guard inputs.availability.isAvailable else { return 0 }
        guard let hours = inputs.sleepDurationLastNightHours else { return 0 }

        switch mode {
        case .day:
            return recoveryScore(hours: hours)
        case .night:
            return sleepPressureScore(hours: hours)
        }
    }

    private static func recoveryScore(hours: Double) -> Double {
        switch hours {
        case ..<6.0:
            return 32
        case 6.0..<7.0:
            return 52
        case 7.0..<8.5:
            return 76
        default:
            return 70
        }
    }

    private static func sleepPressureScore(hours: Double) -> Double {
        switch hours {
        case ..<5.0:
            return 88
        case 5.0..<6.0:
            return 76
        case 6.0..<7.0:
            return 62
        case 7.0..<8.0:
            return 46
        default:
            return 30
        }
    }
}
