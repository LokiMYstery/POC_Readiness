import Foundation

struct WeightScheme {
    let circadian: Double
    let activity: Double
    let recovery: Double

    static let day = WeightScheme(circadian: 0.28, activity: 0.40, recovery: 0.32)
    static let night = WeightScheme(circadian: 0.45, activity: 0.15, recovery: 0.40)

    static func scheme(for mode: ReadinessMode) -> WeightScheme {
        switch mode {
        case .day:
            return .day
        case .night:
            return .night
        }
    }
}
