import Foundation
import HealthKit

/// 睡眠与恢复数据提供者
final class SleepProvider {
    private let store: HKHealthStore

    init(store: HKHealthStore = HKAuthorizationManager.shared.healthStore) {
        self.store = store
    }

    /// 拉取恢复输入
    func fetch(now: Date, calendar: Calendar) async -> RecoveryInputs {
        guard HKHealthStore.isHealthDataAvailable() else {
            return RecoveryInputs(availability: .unavailable(reason: .notAvailable))
        }

        do {
            // 查询窗口：昨天 18:00 到今天 12:00
            let today = calendar.startOfDay(for: now)
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            let queryStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday)!
            let queryEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today)!

            // 获取睡眠样本
            let sleepResult = try await fetchSleepAnalysis(start: queryStart, end: queryEnd)

            // 获取 HR / HRV (过去 24h)
            let dayAgo = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            let restingHR = try await HKQueries.mostRecentSample(
                store: store,
                identifier: .restingHeartRate,
                unit: HKUnit(from: "count/min"),
                start: dayAgo,
                end: now
            )
            let hrv = try await HKQueries.mostRecentSample(
                store: store,
                identifier: .heartRateVariabilitySDNN,
                unit: .secondUnit(with: .milli),
                start: dayAgo,
                end: now
            )

            var inputs = sleepResult
            inputs.restingHeartRate = restingHR
            inputs.hrvSDNN = hrv

            return inputs
        } catch {
            print("SleepProvider error: \(error)")
            return RecoveryInputs(availability: .unavailable(reason: .noData))
        }
    }

    // MARK: - Sleep Analysis

    private func fetchSleepAnalysis(start: Date, end: Date) async throws -> RecoveryInputs {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return RecoveryInputs(availability: .unavailable(reason: .notAvailable))
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }

        guard !samples.isEmpty else {
            return RecoveryInputs(availability: .unavailable(reason: .noData))
        }

        // 过滤掉 InBed 之外的 asleep 类型
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        ]

        let sleepSamples = samples.filter { asleepValues.contains($0.value) }
        guard !sleepSamples.isEmpty else {
            return RecoveryInputs(availability: .unavailable(reason: .noData))
        }

        let sleepStart = sleepSamples.first!.startDate
        let sleepEnd = sleepSamples.last!.endDate
        let totalDuration = sleepSamples.reduce(0.0) { sum, sample in
            sum + sample.endDate.timeIntervalSince(sample.startDate)
        }
        let durationHours = totalDuration / 3600.0

        // 阶段汇总
        var stages = SleepStageSummary(awakeMinutes: 0, remMinutes: 0, coreMinutes: 0, deepMinutes: 0)
        var hasStageData = false

        for sample in samples {
            let mins = sample.endDate.timeIntervalSince(sample.startDate) / 60.0
            switch sample.value {
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                stages.awakeMinutes += mins
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                stages.remMinutes += mins
                hasStageData = true
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                stages.coreMinutes += mins
                hasStageData = true
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                stages.deepMinutes += mins
                hasStageData = true
            default:
                break
            }
        }

        return RecoveryInputs(
            availability: .measured,
            sleepDurationLastNightHours: durationHours,
            sleepStart: sleepStart,
            sleepEnd: sleepEnd,
            wakeUpTime: sleepEnd,
            sleepStages: hasStageData ? stages : nil,
            restingHeartRate: nil,
            hrvSDNN: nil,
            respiratoryRate: nil
        )
    }
}
