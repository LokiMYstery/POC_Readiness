import Foundation

struct ReadinessTextOutput {
    let heroTitle: String
    let heroSubtitle: String
    let summaryLine: String
    let missingHint: String?
}

struct ReadinessCopyConfiguration: Decodable {
    let title: ReadinessCopyTitles
    let reasons: ReadinessCopyReasonModes
    let missingLabels: ReadinessCopyMissingLabelModes
    let messages: ReadinessCopyMessages

    func validate() throws {
        try reasons.validate()
    }
}

struct ReadinessCopyTitles: Decodable {
    let day: ReadinessCopyBandTitles
    let night: ReadinessCopyBandTitles

    func titles(for mode: ReadinessMode) -> ReadinessCopyBandTitles {
        mode == .day ? day : night
    }
}

struct ReadinessCopyBandTitles: Decodable {
    let veryLow: ReadinessCopyTitleParts
    let low: ReadinessCopyTitleParts
    let medium: ReadinessCopyTitleParts
    let good: ReadinessCopyTitleParts
    let high: ReadinessCopyTitleParts

    func parts(for band: ReadinessBand) -> ReadinessCopyTitleParts {
        switch band {
        case .veryLow:
            return veryLow
        case .low:
            return low
        case .medium:
            return medium
        case .good:
            return good
        case .high:
            return high
        }
    }
}

struct ReadinessCopyTitleParts: Decodable {
    let status: String
    let action: String
}

struct ReadinessCopyReasonModes: Decodable {
    let day: ReadinessCopyFactorReasons
    let night: ReadinessCopyFactorReasons

    func reasons(for mode: ReadinessMode) -> ReadinessCopyFactorReasons {
        mode == .day ? day : night
    }

    func validate() throws {
        try day.validate(mode: .day)
        try night.validate(mode: .night)
    }
}

struct ReadinessCopyFactorReasons: Decodable {
    let circadian: ReadinessCopyFactorReasonSet
    let activity: ReadinessCopyFactorReasonSet
    let recovery: ReadinessCopyFactorReasonSet

    func reasonSet(for factor: FactorKind) -> ReadinessCopyFactorReasonSet {
        switch factor {
        case .circadian:
            return circadian
        case .activity:
            return activity
        case .recovery:
            return recovery
        }
    }

    func validate(mode: ReadinessMode) throws {
        try circadian.validate(mode: mode, factor: .circadian)
        try activity.validate(mode: mode, factor: .activity)
        try recovery.validate(mode: mode, factor: .recovery)
    }
}

struct ReadinessCopyFactorReasonSet: Decodable {
    let valueSource: ReadinessCopyValueSource?
    let ranges: [ReadinessCopyRange]

    func validate(mode: ReadinessMode, factor: FactorKind) throws {
        guard !ranges.isEmpty else {
            throw ReadinessCopyError.invalidConfiguration("Missing ranges for \(mode.rawValue).\(factor.rawValue)")
        }

        let source = valueSource ?? .score
        let sorted = ranges.sorted { $0.minInclusive < $1.minInclusive }
        guard sorted.map(\.minInclusive) == ranges.map(\.minInclusive) else {
            throw ReadinessCopyError.invalidConfiguration("Ranges must be sorted for \(mode.rawValue).\(factor.rawValue)")
        }

        guard let first = sorted.first, first.minInclusive <= 0 else {
            throw ReadinessCopyError.invalidConfiguration("Ranges must start at or below 0 for \(mode.rawValue).\(factor.rawValue)")
        }

        for (index, current) in sorted.enumerated() {
            if let max = current.maxExclusive, max <= current.minInclusive {
                throw ReadinessCopyError.invalidConfiguration("Invalid range bounds for \(mode.rawValue).\(factor.rawValue) at index \(index)")
            }

            if index < sorted.count - 1 {
                guard let currentMax = current.maxExclusive else {
                    throw ReadinessCopyError.invalidConfiguration("Only final range may omit maxExclusive for \(mode.rawValue).\(factor.rawValue)")
                }

                let next = sorted[index + 1]
                guard abs(currentMax - next.minInclusive) < 0.000_001 else {
                    throw ReadinessCopyError.invalidConfiguration("Ranges must be contiguous for \(mode.rawValue).\(factor.rawValue)")
                }
            }
        }

        if sorted.last?.maxExclusive != nil {
            throw ReadinessCopyError.invalidConfiguration("Final range must omit maxExclusive for \(mode.rawValue).\(factor.rawValue)")
        }

        if factor != .recovery && source != .score {
            throw ReadinessCopyError.invalidConfiguration("Only recovery may use non-score valueSource")
        }
    }
}

struct ReadinessCopyRange: Decodable {
    let minInclusive: Double
    let maxExclusive: Double?
    let text: String

    func contains(_ value: Double) -> Bool {
        guard value >= minInclusive else { return false }
        guard let maxExclusive else { return true }
        return value < maxExclusive
    }
}

enum ReadinessCopyValueSource: String, Decodable {
    case score
    case sleepDurationLastNightHours
}

struct ReadinessCopyMissingLabelModes: Decodable {
    let day: ReadinessCopyMissingLabels
    let night: ReadinessCopyMissingLabels

    func labels(for mode: ReadinessMode) -> ReadinessCopyMissingLabels {
        mode == .day ? day : night
    }
}

struct ReadinessCopyMissingLabels: Decodable {
    let circadian: String
    let activity: String
    let recovery: String

    func label(for factor: FactorKind) -> String {
        switch factor {
        case .circadian:
            return circadian
        case .activity:
            return activity
        case .recovery:
            return recovery
        }
    }
}

struct ReadinessCopyMessages: Decodable {
    let insufficientData: ReadinessCopyInsufficientDataMessage
    let allHealthDataMissing: String
    let partialDataMissingTemplate: String
}

struct ReadinessCopyInsufficientDataMessage: Decodable {
    let heroSubtitle: String
    let summaryLine: String
}

enum ReadinessCopyError: Error, LocalizedError, Equatable {
    case defaultResourceMissing
    case failedToCreateApplicationSupportDirectory(String)
    case failedToCopyDefaultFile(String)
    case failedToLoadSandboxFile(String)
    case failedToDecode(String)
    case invalidConfiguration(String)
    case unresolvedReason(mode: ReadinessMode, factor: FactorKind, value: Double)

    var errorDescription: String? {
        switch self {
        case .defaultResourceMissing:
            return "Bundle 中缺少默认文案 JSON 资源。"
        case .failedToCreateApplicationSupportDirectory(let detail):
            return "创建文案目录失败: \(detail)"
        case .failedToCopyDefaultFile(let detail):
            return "复制默认文案文件失败: \(detail)"
        case .failedToLoadSandboxFile(let detail):
            return "读取沙盒文案文件失败: \(detail)"
        case .failedToDecode(let detail):
            return "解析文案 JSON 失败: \(detail)"
        case .invalidConfiguration(let detail):
            return "文案配置不合法: \(detail)"
        case let .unresolvedReason(mode, factor, value):
            return "无法解析 \(mode.rawValue).\(factor.rawValue) 的文案区间: \(value)"
        }
    }
}
