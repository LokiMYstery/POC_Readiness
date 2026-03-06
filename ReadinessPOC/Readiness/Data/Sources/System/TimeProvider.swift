import Foundation

/// 系统时间提供者
struct TimeProvider {
    let now: Date
    let timezone: TimeZone
    let calendar: Calendar

    init(now: Date = .now, timezone: TimeZone = .current) {
        self.now = now
        self.timezone = timezone
        var cal = Calendar.current
        cal.timeZone = timezone
        self.calendar = cal
    }

    var weekday: Int {
        calendar.component(.weekday, from: now)
    }

    var isWeekend: Bool {
        weekday == 1 || weekday == 7  // Sunday=1, Saturday=7
    }

    var hour: Int {
        calendar.component(.hour, from: now)
    }

    var minute: Int {
        calendar.component(.minute, from: now)
    }
}
