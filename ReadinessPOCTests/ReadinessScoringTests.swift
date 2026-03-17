import XCTest
@testable import ReadinessPOC

final class ReadinessScoringTests: XCTestCase {
    private let testTimeZone = TimeZone(identifier: "Asia/Shanghai")!
    private lazy var fixtureDefaultCopyURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("ReadinessPOC/Resources/ReadinessCopy.default.json")

    func testNightTimeDominatesSleepinessForSameUser() throws {
        let early = try evaluate(now: makeDate(hour: 22, minute: 0), stepsToday: 4200, stepsLast2h: 280, sleepHours: 7.1)
        let late = try evaluate(now: makeDate(hour: 1, minute: 30), stepsToday: 4200, stepsLast2h: 280, sleepHours: 7.1)

        XCTAssertEqual(early.mode, .night)
        XCTAssertEqual(late.mode, .night)
        XCTAssertGreaterThan(late.overallScore, early.overallScore + 12)
        XCTAssertGreaterThan(score(for: late, kind: .circadian), score(for: early, kind: .circadian))
    }

    func testEarlyNightWellRestedLowActivityStaysLow() throws {
        let result = try evaluate(now: makeDate(hour: 22, minute: 10), stepsToday: 900, stepsLast2h: 80, sleepHours: 8.4)

        XCTAssertEqual(result.mode, .night)
        XCTAssertLessThan(result.overallScore, 50)
    }

    func testLateNightShortSleepAndAdequateActivityFeelsSleepy() throws {
        let result = try evaluate(now: makeDate(hour: 1, minute: 20), stepsToday: 6200, stepsLast2h: 450, sleepHours: 5.9)

        XCTAssertEqual(result.mode, .night)
        XCTAssertGreaterThan(result.overallScore, 72)
        XCTAssertTrue(result.band == .good || result.band == .high)
    }

    func testDayMorningGentleStartDoesNotLookBroken() throws {
        let result = try evaluate(now: makeDate(hour: 7, minute: 30), stepsToday: 320, stepsLast2h: 120, sleepHours: 7.6)

        XCTAssertEqual(result.mode, .day)
        XCTAssertGreaterThan(result.overallScore, 55)
    }

    func testDayAfternoonPoorRecoveryAndLowActivationDropsClearly() throws {
        let result = try evaluate(now: makeDate(hour: 16, minute: 30), stepsToday: 1800, stepsLast2h: 90, sleepHours: 5.2)

        XCTAssertEqual(result.mode, .day)
        XCTAssertLessThan(result.overallScore, 50)
    }

    func testDebugOverridesAffectModeAndMeasuredFactors() throws {
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
        let result = try evaluate(inputs: effective)

        XCTAssertEqual(result.mode, .night)
        XCTAssertEqual(effective.activity.availability, .measured)
        XCTAssertEqual(effective.recovery.availability, .measured)
        XCTAssertEqual(effective.global.mode, .night)
    }

    func testDefaultCopyIsBootstrappedToSandboxAndUsedForOutput() throws {
        let resolver = try makeResolver()
        let result = try ReadinessAggregator.evaluate(
            inputs: makeInputs(
                now: makeDate(hour: 9, minute: 0),
                stepsToday: 200,
                stepsLast2h: 50,
                sleepHours: 7.2,
                activityAvailability: .measured,
                recoveryAvailability: .measured,
                restingHeartRate: 60,
                hrv: 52
            ),
            textResolver: resolver
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: resolver.store.sandboxFileURL.path))
        XCTAssertEqual(result.text.heroTitle, "状态良好, 适合推进")
        XCTAssertEqual(result.text.heroSubtitle, "这会儿节律状态不错，适合把重要任务往前放一放")
    }

    func testReloadUsesModifiedSandboxJson() throws {
        let resolver = try makeResolver()
        let sandboxURL = resolver.store.sandboxFileURL

        var data = try Data(contentsOf: sandboxURL)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var title = try XCTUnwrap(json["title"] as? [String: Any])
        var day = try XCTUnwrap(title["day"] as? [String: Any])
        var good = try XCTUnwrap(day["good"] as? [String: Any])
        good["status"] = "自定义状态"
        day["good"] = good
        title["day"] = day
        json["title"] = title
        data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: sandboxURL, options: .atomic)

        try resolver.reload()

        let result = try ReadinessAggregator.evaluate(
            inputs: makeInputs(
                now: makeDate(hour: 9, minute: 0),
                stepsToday: 200,
                stepsLast2h: 50,
                sleepHours: 7.2,
                activityAvailability: .measured,
                recoveryAvailability: .measured,
                restingHeartRate: 60,
                hrv: 52
            ),
            textResolver: resolver
        )

        XCTAssertEqual(result.text.heroTitle, "自定义状态, 适合推进")
    }

    func testMissingRequiredFieldFailsStrictly() throws {
        let tempDirectory = makeTemporaryDirectory()
        let invalidURL = tempDirectory.appendingPathComponent("invalid.json")
        try """
        {
          "title": {},
          "reasons": {},
          "missingLabels": {},
          "messages": {}
        }
        """.data(using: .utf8)!.write(to: invalidURL)

        let store = ReadinessCopyStore(
            applicationSupportDirectory: tempDirectory,
            bundledDefaultURLProvider: { invalidURL }
        )

        XCTAssertThrowsError(try store.load()) { error in
            guard case .failedToDecode = error as? ReadinessCopyError else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testOverlappingRangesFailValidation() throws {
        let tempDirectory = makeTemporaryDirectory()
        let invalidURL = tempDirectory.appendingPathComponent("overlap.json")
        try """
        {
          "title": {
            "day": {
              "veryLow": { "status": "a", "action": "a" },
              "low": { "status": "a", "action": "a" },
              "medium": { "status": "a", "action": "a" },
              "good": { "status": "a", "action": "a" },
              "high": { "status": "a", "action": "a" }
            },
            "night": {
              "veryLow": { "status": "a", "action": "a" },
              "low": { "status": "a", "action": "a" },
              "medium": { "status": "a", "action": "a" },
              "good": { "status": "a", "action": "a" },
              "high": { "status": "a", "action": "a" }
            }
          },
          "reasons": {
            "day": {
              "circadian": {
                "ranges": [
                  { "minInclusive": 0, "maxExclusive": 60, "text": "a" },
                  { "minInclusive": 50, "text": "b" }
                ]
              },
              "activity": {
                "ranges": [
                  { "minInclusive": 0, "text": "a" }
                ]
              },
              "recovery": {
                "valueSource": "sleepDurationLastNightHours",
                "ranges": [
                  { "minInclusive": 0, "text": "a" }
                ]
              }
            },
            "night": {
              "circadian": {
                "ranges": [
                  { "minInclusive": 0, "text": "a" }
                ]
              },
              "activity": {
                "ranges": [
                  { "minInclusive": 0, "text": "a" }
                ]
              },
              "recovery": {
                "valueSource": "sleepDurationLastNightHours",
                "ranges": [
                  { "minInclusive": 0, "text": "a" }
                ]
              }
            }
          },
          "missingLabels": {
            "day": { "circadian": "a", "activity": "a", "recovery": "a" },
            "night": { "circadian": "a", "activity": "a", "recovery": "a" }
          },
          "messages": {
            "insufficientData": { "heroSubtitle": "a", "summaryLine": "a" },
            "allHealthDataMissing": "a",
            "partialDataMissingTemplate": "{{labels}}"
          }
        }
        """.data(using: .utf8)!.write(to: invalidURL)

        let store = ReadinessCopyStore(
            applicationSupportDirectory: tempDirectory,
            bundledDefaultURLProvider: { invalidURL }
        )

        XCTAssertThrowsError(try store.load()) { error in
            guard case .invalidConfiguration = error as? ReadinessCopyError else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testMissingHintStillWorksWhenActivityAndRecoveryAreUnavailable() throws {
        let result = try evaluate(
            inputs: makeInputs(
                now: makeDate(hour: 10, minute: 0),
                stepsToday: nil,
                stepsLast2h: nil,
                sleepHours: nil,
                activityAvailability: .unavailable(reason: .noData),
                recoveryAvailability: .unavailable(reason: .noData),
                restingHeartRate: nil,
                hrv: nil
            )
        )

        XCTAssertEqual(result.text.missingHint, "部分数据未接入: 活动, 恢复，当前结果基于可用信息估计。")
    }

    private func evaluate(
        now: Date,
        stepsToday: Double?,
        stepsLast2h: Double?,
        sleepHours: Double?,
        restingHeartRate: Double = 62,
        hrv: Double = 48
    ) throws -> ReadinessResult {
        try evaluate(inputs: makeInputs(
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

    private func evaluate(inputs: ReadinessInputs) throws -> ReadinessResult {
        let resolver = try makeResolver()
        return try ReadinessAggregator.evaluate(inputs: inputs, textResolver: resolver)
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

    private func makeResolver() throws -> ReadinessTextResolver {
        let tempDirectory = makeTemporaryDirectory()
        let store = ReadinessCopyStore(
            applicationSupportDirectory: tempDirectory,
            bundledDefaultURLProvider: { self.fixtureDefaultCopyURL }
        )
        let resolver = ReadinessTextResolver(store: store)
        try resolver.bootstrap()
        return resolver
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
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
