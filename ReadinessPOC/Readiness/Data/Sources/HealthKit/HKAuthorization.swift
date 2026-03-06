import Foundation
import HealthKit

/// HealthKit 授权管理
final class HKAuthorizationManager {
    static let shared = HKAuthorizationManager()
    
    let healthStore = HKHealthStore()
    
    /// HealthKit 是否可用
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    /// 需要读取的数据类型
    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        
        // Activity
        if let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepCount)
        }
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let exerciseTime = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exerciseTime)
        }
        if let standHours = HKObjectType.quantityType(forIdentifier: .appleStandTime) {
            types.insert(standHours)
        }
        
        // Sleep
        if let sleepAnalysis = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepAnalysis)
        }
        
        // Recovery
        if let restingHR = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHR)
        }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }
        if let respRate = HKObjectType.quantityType(forIdentifier: .respiratoryRate) {
            types.insert(respRate)
        }
        
        return types
    }
    
    /// 请求权限
    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }
}
