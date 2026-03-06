import Foundation

/// 节律分 C 计算
enum CircadianScorer {

    /// 计算节律分
    /// - Parameters:
    ///   - inputs: 节律输入
    ///   - global: 全局上下文
    /// - Returns: 节律分 (0–100)
    static func score(inputs: CircadianInputs, global: GlobalContext) -> Double {
        let calendar: Calendar = {
            var c = Calendar.current
            c.timeZone = global.timezone
            return c
        }()

        // Step 1: 基线曲线
        let base = CircadianCurve.baseScore(at: global.now, mode: global.mode, calendar: calendar)

        // Step 2: 日照校准
        let adjusted = SunlightAdjuster.adjust(
            base: base,
            sunrise: inputs.sunrise,
            sunset: inputs.sunset,
            now: global.now
        )

        // Step 3: 节假日修正
        var result = adjusted
        if global.mode == .day {
            if global.isHoliday == true || global.isWeekend {
                result = min(result + 4, 80)
            }
        }

        return min(max(result, 0), 100)
    }
}
