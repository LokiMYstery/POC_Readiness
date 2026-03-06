import Foundation

/// 日照校准：日出 Boost / 日落 Decay
enum SunlightAdjuster {

    struct Config {
        /// 日出后提升持续时间（分钟）
        var afterSunriseBoostDuration: Double = 120
        /// 日出后最大提升
        var afterSunriseMaxBoost: Double = 5

        /// 日落后下降持续时间（分钟）
        var afterSunsetDecayDuration: Double = 180
        /// 日落后最大下降
        var afterSunsetMaxDecay: Double = -8

        static let `default` = Config()
    }

    /// 根据日出/日落校准基线分数
    /// - Parameters:
    ///   - base: 基线分数
    ///   - sunrise: 日出时间（可选）
    ///   - sunset: 日落时间（可选）
    ///   - now: 当前时间
    ///   - config: 校准配置
    /// - Returns: 校准后的分数
    static func adjust(
        base: Double,
        sunrise: Date?,
        sunset: Date?,
        now: Date,
        config: Config = .default
    ) -> Double {
        guard sunrise != nil || sunset != nil else {
            return base  // 无日照数据，不校准
        }

        var adjustment: Double = 0

        // 日出后 Boost
        if let sr = sunrise, now > sr {
            let minutesSinceSunrise = now.timeIntervalSince(sr) / 60.0
            if minutesSinceSunrise <= config.afterSunriseBoostDuration {
                let progress = minutesSinceSunrise / config.afterSunriseBoostDuration
                adjustment += config.afterSunriseMaxBoost * progress
            } else {
                adjustment += config.afterSunriseMaxBoost
            }
        }

        // 日落后 Decay
        if let ss = sunset, now > ss {
            let minutesSinceSunset = now.timeIntervalSince(ss) / 60.0
            if minutesSinceSunset <= config.afterSunsetDecayDuration {
                let progress = minutesSinceSunset / config.afterSunsetDecayDuration
                adjustment += config.afterSunsetMaxDecay * progress
            } else {
                adjustment += config.afterSunsetMaxDecay
            }
        }

        return min(max(base + adjustment, 0), 100)
    }
}
