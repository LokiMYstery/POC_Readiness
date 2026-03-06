import Foundation

/// Day / Night 就绪度模式
enum ReadinessMode: String, CaseIterable, Identifiable {
    case day   // 清醒就绪度
    case night // 睡眠就绪度

    var id: String { rawValue }

    /// 22:00–05:59 → Night, 06:00–21:59 → Day
    static func current(at date: Date = .now, in calendar: Calendar = .current) -> ReadinessMode {
        let hour = calendar.component(.hour, from: date)
        return (hour >= 22 || hour < 6) ? .night : .day
    }

    var displayName: String {
        switch self {
        case .day:   return "清醒"
        case .night: return "睡眠"
        }
    }
}
