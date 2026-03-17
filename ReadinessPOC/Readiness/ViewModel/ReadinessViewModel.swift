import Foundation
import SwiftUI

/// 主 ViewModel — 绑定 Repository → Engine → UI
@MainActor
final class ReadinessViewModel: ObservableObject {
    // MARK: Published State
    @Published var result: ReadinessResult?
    @Published var isLoading: Bool = false
    @Published var rawInputs: ReadinessInputs?
    /// Debug 覆盖后的 inputs，供详情页使用
    @Published var effectiveInputs: ReadinessInputs?

    // MARK: Dependencies
    private let repository = ReadinessRepository()
    let debugState = DebugState()

    // MARK: - Load

    func load() {
        Task {
            isLoading = true
            defer { isLoading = false }

            // 请求 HealthKit 授权
            try? await HKAuthorizationManager.shared.requestAuthorization()

            // 拉取数据
            var inputs = await repository.fetchInputs()
            rawInputs = inputs

            // 应用 Debug 覆盖
            inputs = debugState.apply(to: inputs)
            effectiveInputs = inputs

            // 计算结果
            do {
                result = try ReadinessAggregator.evaluate(inputs: inputs)
            } catch {
                handleCopyFailure(error)
            }
        }
    }

    /// Debug 参数变更后重新计算（不重新拉取数据）
    func recalculate() {
        var inputs = rawInputs ?? ReadinessInputs.makeDefault(now: debugState.nowOverride ?? .now)
        inputs = debugState.apply(to: inputs)
        effectiveInputs = inputs
        do {
            result = try ReadinessAggregator.evaluate(inputs: inputs)
        } catch {
            handleCopyFailure(error)
        }
    }

    /// 强制刷新（重新拉取 + 计算）
    func refresh() {
        load()
    }

    private func handleCopyFailure(_ error: Error) {
        result = nil
        #if DEBUG
        assertionFailure("Readiness copy loading failed: \(error.localizedDescription)")
        #else
        NSLog("Readiness copy loading failed: %@", error.localizedDescription)
        #endif
    }
}
