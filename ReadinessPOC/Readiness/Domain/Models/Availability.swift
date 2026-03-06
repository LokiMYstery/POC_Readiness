import Foundation

/// 数据可用性等级
enum Availability: Equatable {
    /// 数据不可用（含原因）
    case unavailable(reason: MissingReason)
    /// 仅时间因子估计（L0）
    case estimated
    /// 实际测量数据（L1/L2）
    case measured

    var isMeasured: Bool {
        if case .measured = self { return true }
        return false
    }

    var isAvailable: Bool {
        switch self {
        case .unavailable: return false
        default: return true
        }
    }
}

/// 缺失原因
enum MissingReason: String {
    case notAuthorized    = "未授权"
    case noData           = "无数据"
    case notAvailable     = "不可用"
    case locationDenied   = "定位未授权"
    case weatherKitFailed = "WeatherKit 不可用"
}
