import Foundation

/// 基线节律曲线 — 锚点 + smoothstep 插值
enum CircadianCurve {

    // MARK: - 锚点结构

    struct Anchor {
        let minuteOfDay: Double  // 0–1440+ (Night Mode 可跨午夜用 1440+)
        let score: Double
    }

    // MARK: - Day Mode 锚点

    static let dayAnchors: [Anchor] = [
        Anchor(minuteOfDay: 360,  score: 55),  // 06:00
        Anchor(minuteOfDay: 540,  score: 75),  // 09:00
        Anchor(minuteOfDay: 690,  score: 70),  // 11:30
        Anchor(minuteOfDay: 840,  score: 60),  // 14:00
        Anchor(minuteOfDay: 1050, score: 70),  // 17:30
        Anchor(minuteOfDay: 1230, score: 60),  // 20:30
        Anchor(minuteOfDay: 1320, score: 50),  // 22:00
        Anchor(minuteOfDay: 1440, score: 45),  // 24:00
    ]

    // MARK: - Night Mode 锚点 (使用 1320+ 时间轴)

    static let nightAnchors: [Anchor] = [
        Anchor(minuteOfDay: 1320, score: 60),  // 22:00
        Anchor(minuteOfDay: 1410, score: 75),  // 23:30
        Anchor(minuteOfDay: 1530, score: 85),  // 01:30 (= 25:30 h = 1530 min)
        Anchor(minuteOfDay: 1620, score: 80),  // 03:00 (= 27:00 h = 1620 min)
        Anchor(minuteOfDay: 1800, score: 65),  // 06:00 (= 30:00 h = 1800 min)
    ]

    // MARK: - 插值

    /// 计算给定时间的基线节律分数
    /// - Parameters:
    ///   - now: 当前时间
    ///   - mode: Day/Night
    ///   - calendar: 日历
    /// - Returns: 基线分数 (0–100)
    static func baseScore(at now: Date, mode: ReadinessMode, calendar: Calendar) -> Double {
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        var minuteOfDay = Double(hour * 60 + minute)

        let anchors: [Anchor]
        switch mode {
        case .day:
            anchors = dayAnchors
            // Day Mode: 06:00 – 24:00
            // 若在 00:00–06:00（理论上不会发生在 Day 模式), clamp
            minuteOfDay = max(minuteOfDay, anchors.first!.minuteOfDay)
            minuteOfDay = min(minuteOfDay, anchors.last!.minuteOfDay)

        case .night:
            anchors = nightAnchors
            // Night Mode: 22:00 – 06:00，跨午夜映射
            // 00:00–06:00 → 1440–1800
            if hour < 6 {
                minuteOfDay += 1440
            }
            minuteOfDay = max(minuteOfDay, anchors.first!.minuteOfDay)
            minuteOfDay = min(minuteOfDay, anchors.last!.minuteOfDay)
        }

        return interpolate(minuteOfDay: minuteOfDay, anchors: anchors)
    }

    // MARK: - Smoothstep 插值

    private static func interpolate(minuteOfDay: Double, anchors: [Anchor]) -> Double {
        // 边界处理
        if minuteOfDay <= anchors.first!.minuteOfDay {
            return anchors.first!.score
        }
        if minuteOfDay >= anchors.last!.minuteOfDay {
            return anchors.last!.score
        }

        // 找到相邻锚点
        for i in 0..<(anchors.count - 1) {
            let a = anchors[i]
            let b = anchors[i + 1]
            if minuteOfDay >= a.minuteOfDay && minuteOfDay <= b.minuteOfDay {
                let range = b.minuteOfDay - a.minuteOfDay
                guard range > 0 else { return a.score }
                let p = (minuteOfDay - a.minuteOfDay) / range
                let smooth = smoothstep(p)
                return a.score + (b.score - a.score) * smooth
            }
        }

        return anchors.last!.score
    }

    /// smoothstep: p² × (3 − 2p)
    private static func smoothstep(_ p: Double) -> Double {
        let clamped = min(max(p, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }
}
