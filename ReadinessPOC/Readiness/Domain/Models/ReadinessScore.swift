import Foundation

enum ReadinessBand: Int, CaseIterable, Identifiable {
    case veryLow = 1
    case low = 2
    case medium = 3
    case good = 4
    case high = 5

    var id: Int { rawValue }

    init(score: Double) {
        switch score {
        case ..<35:
            self = .veryLow
        case ..<50:
            self = .low
        case ..<65:
            self = .medium
        case ..<80:
            self = .good
        default:
            self = .high
        }
    }
}

struct SubScore: Identifiable {
    let id: FactorKind
    let value: Double
    let normalizedWeight: Double
    let contributionPercent: Double
    let availability: Availability
}

enum FactorKind: String, CaseIterable, Identifiable {
    case circadian = "circadian"
    case activity = "activity"
    case recovery = "recovery"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .circadian:
            return "节律与日照"
        case .activity:
            return "活动与代谢"
        case .recovery:
            return "睡眠与恢复"
        }
    }

    var iconName: String {
        switch self {
        case .circadian:
            return "sun.max.fill"
        case .activity:
            return "figure.walk"
        case .recovery:
            return "bed.double.fill"
        }
    }
}

struct ReadinessResult {
    let mode: ReadinessMode
    let overallScore: Double
    let band: ReadinessBand
    let subScores: [SubScore]
    let text: ReadinessTextOutput
    let timestamp: Date
}
