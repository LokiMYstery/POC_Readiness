import Foundation

/// 可配置常量
enum AppConfig {
    /// POC 版本
    static let version = "1.0.0-poc"

    /// 权重（可覆盖）
    static let dayWeights = WeightScheme.day
    static let nightWeights = WeightScheme.night
}
