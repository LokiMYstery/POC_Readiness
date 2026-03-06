import Foundation

/// 日历与假期提供者（POC 先占位）
struct CalendarProvider {
    /// POC 阶段先返回 nil（无后端节假日数据）
    var isHoliday: Bool? { nil }
    var holidayName: String? { nil }
}
