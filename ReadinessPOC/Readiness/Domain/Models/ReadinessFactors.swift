import Foundation
import CoreLocation

// MARK: - 统一输入容器

struct ReadinessInputs {
    var global: GlobalContext
    var circadian: CircadianInputs
    var activity: ActivityInputs
    var recovery: RecoveryInputs
}

// MARK: - Global

struct GlobalContext {
    var now: Date
    var timezone: TimeZone
    var weekday: Int           // 1–7
    var isWeekend: Bool
    var isHoliday: Bool?
    var holidayName: String?
    var mode: ReadinessMode
}

// MARK: - Circadian (节律与日照)

struct CircadianInputs {
    var availability: Availability = .estimated

    // L1 — WeatherKit
    var location: CLLocationCoordinate2D?
    var sunrise: Date?
    var sunset: Date?
    var daylightDuration: TimeInterval?

    // 可选增强
    var cloudCover: Double?    // 0–1
    var uvIndex: Double?
    var condition: String?
    var moonPhase: Double?     // 0–1
}

// MARK: - Activity (活动与代谢)

struct ActivityInputs {
    var availability: Availability = .unavailable(reason: .noData)

    // L1
    var stepsToday: Double?
    var stepsLast2h: Double?

    // L2
    var activeEnergyTodayKcal: Double?
    var activeEnergyLast2hKcal: Double?
    var exerciseMinutesToday: Double?
    var standHoursToday: Double?
}

// MARK: - Recovery (睡眠与恢复)

struct RecoveryInputs {
    var availability: Availability = .unavailable(reason: .noData)

    // L1
    var sleepDurationLastNightHours: Double?
    var sleepStart: Date?
    var sleepEnd: Date?
    var wakeUpTime: Date?

    // L2
    var sleepStages: SleepStageSummary?
    var restingHeartRate: Double?
    var hrvSDNN: Double?
    var respiratoryRate: Double?
}

struct SleepStageSummary {
    var awakeMinutes: Double
    var remMinutes: Double
    var coreMinutes: Double
    var deepMinutes: Double

    var totalMinutes: Double {
        awakeMinutes + remMinutes + coreMinutes + deepMinutes
    }

    var deepPercent: Double {
        guard totalMinutes > 0 else { return 0 }
        return deepMinutes / totalMinutes
    }
}

// MARK: - Default Factory

extension ReadinessInputs {
    /// 创建一个全缺失的默认输入
    static func makeDefault(now: Date = .now, timezone: TimeZone = .current) -> ReadinessInputs {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let isWeekend = (weekday == 1 || weekday == 7)
        let mode = ReadinessMode.current(at: now, in: calendar)

        return ReadinessInputs(
            global: GlobalContext(
                now: now,
                timezone: timezone,
                weekday: weekday,
                isWeekend: isWeekend,
                isHoliday: nil,
                holidayName: nil,
                mode: mode
            ),
            circadian: CircadianInputs(availability: .estimated),
            activity: ActivityInputs(availability: .unavailable(reason: .noData)),
            recovery: RecoveryInputs(availability: .unavailable(reason: .noData))
        )
    }
}
