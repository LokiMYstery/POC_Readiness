import Foundation

/// 文案输出模型
struct ReadinessTextOutput {
    /// 总览解释句（一句话）
    let overviewSentence: String
    /// 三张卡的小解释
    let circadianExplanation: String
    let activityExplanation: String
    let recoveryExplanation: String
    /// 缺失提示（底部横条）
    let missingHint: String?
}
