import Foundation
import SwiftUI
import Combine

/// Debug 可覆盖状态
final class DebugState: ObservableObject {
    @Published var isEnabled: Bool = false

    // MARK: Global
    @Published var modeOverride: ReadinessMode?     // nil = auto
    @Published var nowOverride: Date?
    @Published var isHolidayOverride: Bool?          // nil = auto

    // MARK: Circadian
    @Published var weatherKitEnabled: Bool = true
    @Published var sunriseOverride: Date?
    @Published var sunsetOverride: Date?

    // MARK: Activity
    @Published var activityEnabled: Bool = true
    @Published var stepsTodayOverride: Double?
    @Published var stepsLast2hOverride: Double?
    @Published var activeEnergyOverride: Double?
    @Published var exerciseMinutesOverride: Double?

    // MARK: Recovery
    @Published var recoveryEnabled: Bool = true
    @Published var sleepDurationOverride: Double?
    @Published var sleepStartOverride: Date?
    @Published var sleepEndOverride: Date?
    @Published var restingHROverride: Double?
    @Published var hrvOverride: Double?

    init() {
        #if targetEnvironment(simulator)
        // 模拟器没有 HealthKit 真实数据，自动启用 Debug 并填入合理默认值
        isEnabled = true
        stepsTodayOverride = 6800
        stepsLast2hOverride = 850
        activeEnergyOverride = 320
        exerciseMinutesOverride = 25
        sleepDurationOverride = 7.2
        restingHROverride = 62
        hrvOverride = 48
        let cal = Calendar.current
        sunriseOverride = cal.date(bySettingHour: 6, minute: 30, second: 0, of: .now)
        sunsetOverride  = cal.date(bySettingHour: 18, minute: 15, second: 0, of: .now)
        #endif
    }

    /// 将 Debug 覆盖应用到 inputs
    func apply(to inputs: ReadinessInputs) -> ReadinessInputs {
        guard isEnabled else { return inputs }

        var result = inputs

        // Global
        if let modeOvr = modeOverride {
            result.global.mode = modeOvr
        }
        if let nowOvr = nowOverride {
            result.global.now = nowOvr
            let cal = Calendar.current
            result.global.weekday = cal.component(.weekday, from: nowOvr)
            result.global.isWeekend = (result.global.weekday == 1 || result.global.weekday == 7)
            if modeOverride == nil {
                result.global.mode = ReadinessMode.current(at: nowOvr, in: cal)
            }
        }
        if isHolidayOverride != nil {
            result.global.isHoliday = isHolidayOverride
        }

        // Circadian
        if !weatherKitEnabled {
            result.circadian = CircadianInputs(availability: .estimated)
        } else {
            if let sr = sunriseOverride { result.circadian.sunrise = sr }
            if let ss = sunsetOverride { result.circadian.sunset = ss }
            if result.circadian.sunrise != nil || result.circadian.sunset != nil {
                result.circadian.availability = .measured
            }
        }

        // Activity
        if !activityEnabled {
            result.activity = ActivityInputs(availability: .unavailable(reason: .notAuthorized))
        } else {
            if let s = stepsTodayOverride { result.activity.stepsToday = s }
            if let s = stepsLast2hOverride { result.activity.stepsLast2h = s }
            if let e = activeEnergyOverride { result.activity.activeEnergyTodayKcal = e }
            if let m = exerciseMinutesOverride { result.activity.exerciseMinutesToday = m }
            // 如果有任何覆盖数据，标记为 measured
            if stepsTodayOverride != nil || activeEnergyOverride != nil {
                result.activity.availability = .measured
            }
        }

        // Recovery
        if !recoveryEnabled {
            result.recovery = RecoveryInputs(availability: .unavailable(reason: .notAuthorized))
        } else {
            if let d = sleepDurationOverride { result.recovery.sleepDurationLastNightHours = d }
            if let s = sleepStartOverride { result.recovery.sleepStart = s }
            if let e = sleepEndOverride { result.recovery.sleepEnd = e }
            if let hr = restingHROverride { result.recovery.restingHeartRate = hr }
            if let hrv = hrvOverride { result.recovery.hrvSDNN = hrv }
            if sleepDurationOverride != nil {
                result.recovery.availability = .measured
            }
        }

        return result
    }
}
