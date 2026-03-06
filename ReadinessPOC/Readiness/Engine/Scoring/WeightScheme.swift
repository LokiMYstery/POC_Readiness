import Foundation

/// Day / Night 权重方案
struct WeightScheme {
    let circadian: Double
    let activity: Double
    let recovery: Double

    /// Day Mode: S=0.55, C=0.30, A=0.15
    static let day = WeightScheme(circadian: 0.30, activity: 0.15, recovery: 0.55)

    /// Night Mode: A=0.50, C=0.35, S=0.15
    static let night = WeightScheme(circadian: 0.35, activity: 0.50, recovery: 0.15)

    static func scheme(for mode: ReadinessMode) -> WeightScheme {
        switch mode {
        case .day:   return .day
        case .night: return .night
        }
    }
}
