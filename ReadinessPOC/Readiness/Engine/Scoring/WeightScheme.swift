import Foundation

struct WeightScheme {
    let circadian: Double
    let activity: Double
    let recovery: Double

    static let day = WeightScheme(circadian: 0.40, activity: 0.20, recovery: 0.40)
    static let night = WeightScheme(circadian: 0.35, activity: 0.20, recovery: 0.45)

    static func scheme(for mode: ReadinessMode) -> WeightScheme {
        switch mode {
        case .day:
            return .day
        case .night:
            return .night
        }
    }
}
