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

        let stepsToday = await querySum(
            identifier: .stepCount,
            unit: .count(),
            start: startOfDay,
            end: now
        )
        let stepsLast2h = await querySum(
            identifier: .stepCount,
            unit: .count(),
            start: twoHoursAgo,
            end: now
        )
        let activeEnergy = await querySum(
            identifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            start: startOfDay,
            end: now
        )
        let activeEnergyLast2h = await querySum(
            identifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            start: twoHoursAgo,
            end: now
        )
        let exerciseMinutes = await querySum(
            identifier: .appleExerciseTime,
            unit: .minute(),
            start: startOfDay,
            end: now
        )

        let availability: Availability
        if [stepsToday, stepsLast2h, activeEnergy, activeEnergyLast2h, exerciseMinutes].contains(where: { $0 != nil }) {
            availability = .measured
        } else {
            availability = .unavailable(reason: .noData)
        }

        return ActivityInputs(
            availability: availability,
            stepsToday: stepsToday,
            stepsLast2h: stepsLast2h,
            activeEnergyTodayKcal: activeEnergy,
            activeEnergyLast2hKcal: activeEnergyLast2h,
            exerciseMinutesToday: exerciseMinutes,
            standHoursToday: nil
        )
    }

    private func querySum(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async -> Double? {
        do {
            return try await HKQueries.cumulativeSum(
                store: store,
                identifier: identifier,
                unit: unit,
                start: start,
                end: end
            )
        } catch {
            print("ActivityProvider query error [\(identifier.rawValue)]: \(error)")
            return nil
        }
    }
}
