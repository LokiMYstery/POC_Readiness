import Foundation
import HealthKit

/// 活动数据提供者
final class ActivityProvider {
    private let store: HKHealthStore

    init(store: HKHealthStore = HKAuthorizationManager.shared.healthStore) {
        self.store = store
    }

    /// 拉取活动输入
    func fetch(now: Date, calendar: Calendar) async -> ActivityInputs {
        guard HKHealthStore.isHealthDataAvailable() else {
            return ActivityInputs(availability: .unavailable(reason: .notAvailable))
        }

        let startOfDay = calendar.startOfDay(for: now)
        let twoHoursAgo = calendar.date(byAdding: .hour, value: -2, to: now) ?? now

        do {
            // 今日步数
            let stepsToday = try await HKQueries.cumulativeSum(
                store: store,
                identifier: .stepCount,
                unit: .count(),
                start: startOfDay,
                end: now
            )

            // 过去 2h 步数
            let stepsLast2h = try await HKQueries.cumulativeSum(
                store: store,
                identifier: .stepCount,
                unit: .count(),
                start: twoHoursAgo,
                end: now
            )

            // 今日活动能量
            let activeEnergy = try await HKQueries.cumulativeSum(
                store: store,
                identifier: .activeEnergyBurned,
                unit: .kilocalorie(),
                start: startOfDay,
                end: now
            )

            // 过去 2h 活动能量
            let activeEnergyLast2h = try await HKQueries.cumulativeSum(
                store: store,
                identifier: .activeEnergyBurned,
                unit: .kilocalorie(),
                start: twoHoursAgo,
                end: now
            )

            // 今日运动分钟
            let exerciseMinutes = try await HKQueries.cumulativeSum(
                store: store,
                identifier: .appleExerciseTime,
                unit: .minute(),
                start: startOfDay,
                end: now
            )

            let hasAnyData = [stepsToday, activeEnergy, exerciseMinutes].compactMap { $0 }.count > 0
            let availability: Availability = hasAnyData ? .measured : .unavailable(reason: .noData)

            return ActivityInputs(
                availability: availability,
                stepsToday: stepsToday,
                stepsLast2h: stepsLast2h,
                activeEnergyTodayKcal: activeEnergy,
                activeEnergyLast2hKcal: activeEnergyLast2h,
                exerciseMinutesToday: exerciseMinutes,
                standHoursToday: nil
            )
        } catch {
            print("ActivityProvider error: \(error)")
            return ActivityInputs(availability: .unavailable(reason: .noData))
        }
    }
}
