import Foundation

/// 聚合所有数据源 → 统一 ReadinessInputs
final class ReadinessRepository {
    private let activityProvider = ActivityProvider()
    private let sleepProvider = SleepProvider()
    private let weatherProvider = WeatherProvider()
    private let calendarProvider = CalendarProvider()

    /// 拉取全部输入
    func fetchInputs(now: Date = .now, timezone: TimeZone = .current) async -> ReadinessInputs {
        let timeProvider = TimeProvider(now: now, timezone: timezone)
        let mode = ReadinessMode.current(at: now, in: timeProvider.calendar)

        // 并发拉取三个数据源
        async let circadianResult = weatherProvider.fetch(now: now)
        async let activityResult = activityProvider.fetch(now: now, calendar: timeProvider.calendar)
        async let recoveryResult = sleepProvider.fetch(now: now, calendar: timeProvider.calendar)

        let circadian = await circadianResult
        let activity = await activityResult
        let recovery = await recoveryResult

        return ReadinessInputs(
            global: GlobalContext(
                now: now,
                timezone: timezone,
                weekday: timeProvider.weekday,
                isWeekend: timeProvider.isWeekend,
                isHoliday: calendarProvider.isHoliday,
                holidayName: calendarProvider.holidayName,
                mode: mode
            ),
            circadian: circadian,
            activity: activity,
            recovery: recovery
        )
    }
}
