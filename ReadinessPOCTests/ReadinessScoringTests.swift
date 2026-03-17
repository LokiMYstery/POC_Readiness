import XCTest
@testable import ReadinessPOC

final class ReadinessScoringTests: XCTestCase {
    private let testTimeZone = TimeZone(identifier: "Asia/Shanghai")!

    func testNightTimeDominatesSleepinessForSameUser() {
        let early = evaluate(now: makeDate(hour: 22, minute: 0), stepsToday: 4200, stepsLast2h: 280, sleepHours: 7.1)
        let late = evaluate(now: makeDate(hour: 1, minute: 30), stepsToday: 4200, stepsLast2h: 280, sleepHours: 7.1)

        XCTAssertEqual(early.mode, .night)
        XCTAssertEqual(late.mode, .night)
        XCTAssertGreaterThan(late.overallScore, early.overallScore + 12)
        XCTAssertGreaterThan(score(for: late, kind: .circadian), score(for: early, kind: .circadian))
    }

    func testEarlyNightWellRestedLowActivityStaysLow() {
        let result = evaluate(now: makeDate(hour: 22, minute: 10), stepsToday: 900, stepsLast2h: 80, sleepHours: 8.4)

        XCTAssertEqual(result.mode, .night)
        XCTAssertLessThan(result.overallScore, 50)
    }

    func testLateNightShortSleepAndAdequateActivityFeelsSleepy() {
        let result = evaluate(now: makeDate(hour: 1, minute: 20), stepsToday: 6200, stepsLast2h: 450, sleepHours: 5.9)

        XCTAssertEqual(result.mode, .night)
        XCTAssertGreaterThan(result.overallScore, 72)
        XCTAssertTrue(result.band == .good || result.band == .high)
    }

    func testDayMorningGentleStartDoesNotLookBroken() {
        let result = evaluate(now: makeDate(hour: 7, minute: 30), stepsToday: 320, stepsLast2h: 120, sleepHours: 7.6)

        XCTAssertEqual(result.mode, .day)
        XCTAssertGreaterThan(result.overallScore, 55)
    }

    func testDayAfternoonPoorRecoveryAndLowActivationDropsClearly() {
        let result = evaluate(now: makeDate(hour: 16, minute: 30), stepsToday: 1800, stepsLast2h: 90, sleepHours: 5.2)

        XCTAssertEqual(result.mode, .day)
        XCTAssertLessThan(result.overallScore, 50)
    }

    func testDebugOverridesAffectModeAndMeasuredFactors() {
        let raw = makeInputs(
            now: makeDate(hour: 14, minute: 0),
            stepsToday: nil,
            stepsLast2h: nil,
            sleepHours: nil,
            activityAvailability: .unavailable(reason: .noData),
            recoveryAvailability: .unavailable(reason: .noData),
            restingHeartRate: nil,
            hrv: nil
        )

        let debug = DebugState()
        debug.isEnabled = true
        debug.modeOverride = nil
        debug.nowOverride = makeDate(hour: 23, minute: 45)
        debug.stepsLast2hOverride = 520
        debug.exerciseMinutesOverride = 30
        debug.restingHROverride = 58
        debug.hrvOverride = 60

        let effective = debug.apply(to: raw)
        let result = ReadinessAggregator.evaluate(inputs: effective)

        XCTAssertEqual(result.mode, .night)
        XCTAssertEqual(effective.activity.availability, .measured)
        XCTAssertEqual(effective.recovery.availability, .measured)
        XCTAssertEqual(effective.global.mode, .night)
    }

    private func evaluate(
        now: Date,
        stepsToday: Double?,
        stepsLast2h: Double?,
        sleepHours: Double?,
        restingHeartRate: Double = 62,
        hrv: Double = 48
    ) -> ReadinessResult {
        ReadinessAggregator.evaluate(inputs: makeInputs(
            now: now,
            stepsToday: stepsToday,
            stepsLast2h: stepsLast2h,
            sleepHours: sleepHours,
            activityAvailability: stepsToday == nil && stepsLast2h == nil ? .unavailable(reason: .noData) : .measured,
            recoveryAvailability: sleepHours == nil ? .unavailable(reason: .noData) : .measured,
            restingHeartRate: sleepHours == nil ? nil : restingHeartRate,
            hrv: sleepHours == nil ? nil : hrv
        ))
    }

    private func makeInputs(
        now: Date,
        stepsToday: Double?,
        stepsLast2h: Double?,
        sleepHours: Double?,
        activityAvailability: Availability,
        recoveryAvailability: Availability,
        restingHeartRate: Double?,
        hrv: Double?
    ) -> ReadinessInputs {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = testTimeZone
        let weekday = calendar.component(.weekday, from: now)
        let mode = ReadinessMode.current(at: now, in: calendar)

        let sunrise = calendar.date(bySettingHour: 6, minute: 30, second: 0, of: now)
        let sunset = calendar.date(bySettingHour: 18, minute: 15, second: 0, of: now)

        return ReadinessInputs(
            global: GlobalContext(
                now: now,
                timezone: testTimeZone,
                weekday: weekday,
                isWeekend: weekday == 1 || weekday == 7,
                isHoliday: false,
                holidayName: nil,
                mode: mode
            ),
            circadian: CircadianInputs(
                availability: .measured,
                location: nil,
                sunrise: sunrise,
                sunset: sunset,
                daylightDuration: nil,
                cloudCover: nil,
                uvIndex: nil,
                condition: nil,
                moonPhase: nil
            ),
            activity: ActivityInputs(
                availability: activityAvailability,
                stepsToday: stepsToday,
                stepsLast2h: stepsLast2h,
                activeEnergyTodayKcal: stepsToday.map { $0 * 0.04 },
                activeEnergyLast2hKcal: stepsLast2h.map { $0 * 0.04 },
                exerciseMinutesToday: stepsToday.map { _ in 25 },
                standHoursToday: nil
            ),
            recovery: RecoveryInputs(
                availability: recoveryAvailability,
                sleepDurationLastNightHours: sleepHours,
                sleepStart: nil,
                sleepEnd: nil,
                wakeUpTime: nil,
                sleepStages: nil,
                restingHeartRate: restingHeartRate,
                hrvSDNN: hrv,
                respiratoryRate: nil
            )
        )
    }

    private func score(for result: ReadinessResult, kind: FactorKind) -> Double {
        result.subScores.first(where: { $0.id == kind })?.value ?? -1
    }

    private func makeDate(hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = testTimeZone
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 17
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)!
    }
}
