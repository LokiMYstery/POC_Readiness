import Foundation

final class ReadinessCopyStore {
    static let shared = ReadinessCopyStore()

    private let fileManager: FileManager
    private let applicationSupportDirectory: URL
    private let bundledDefaultURLProvider: () -> URL?
    private var cachedConfiguration: ReadinessCopyConfiguration?

    init(
        fileManager: FileManager = .default,
        applicationSupportDirectory: URL? = nil,
        bundledDefaultURLProvider: @escaping () -> URL? = {
            Bundle.main.url(forResource: "ReadinessCopy.default", withExtension: "json")
        }
    ) {
        self.fileManager = fileManager
        self.applicationSupportDirectory = applicationSupportDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.bundledDefaultURLProvider = bundledDefaultURLProvider
    }

    var sandboxFileURL: URL {
        applicationSupportDirectory
            .appendingPathComponent(AppConfig.readinessCopyDirectoryName, isDirectory: true)
            .appendingPathComponent(AppConfig.readinessCopyFileName, isDirectory: false)
    }

    func ensurePrepared() throws {
        let directoryURL = sandboxFileURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw ReadinessCopyError.failedToCreateApplicationSupportDirectory(error.localizedDescription)
        }

        guard !fileManager.fileExists(atPath: sandboxFileURL.path) else {
            return
        }

        guard let defaultURL = bundledDefaultURLProvider() else {
            throw ReadinessCopyError.defaultResourceMissing
        }

        do {
            try fileManager.copyItem(at: defaultURL, to: sandboxFileURL)
        } catch {
            throw ReadinessCopyError.failedToCopyDefaultFile(error.localizedDescription)
        }
    }

    func load(forceReload: Bool = false) throws -> ReadinessCopyConfiguration {
        try ensurePrepared()

        if !forceReload, let cachedConfiguration {
            return cachedConfiguration
        }

        let data: Data
        do {
            data = try Data(contentsOf: sandboxFileURL)
        } catch {
            throw ReadinessCopyError.failedToLoadSandboxFile(error.localizedDescription)
        }

        let configuration: ReadinessCopyConfiguration
        do {
            configuration = try JSONDecoder().decode(ReadinessCopyConfiguration.self, from: data)
        } catch {
            throw ReadinessCopyError.failedToDecode(error.localizedDescription)
        }

        try configuration.validate()
        cachedConfiguration = configuration
        return configuration
    }

    func invalidateCache() {
        cachedConfiguration = nil
    }
}

struct ReadinessTextResolver {
    static let shared = ReadinessTextResolver()

    let store: ReadinessCopyStore

    init(store: ReadinessCopyStore = .shared) {
        self.store = store
    }

    func bootstrap() throws {
        _ = try store.load()
    }

    func reload() throws {
        store.invalidateCache()
        _ = try store.load(forceReload: true)
    }

    func resolve(
        mode: ReadinessMode,
        band: ReadinessBand,
        primaryFactor: SubScore?,
        missingFactors: [FactorKind],
        inputs: ReadinessInputs
    ) throws -> ReadinessTextOutput {
        let configuration = try store.load()
        let titleParts = configuration.title.titles(for: mode).parts(for: band)

        let heroSubtitle: String
        let summaryLine: String
        if let primaryFactor {
            let value = metricValue(for: primaryFactor, mode: mode, inputs: inputs, configuration: configuration)
            heroSubtitle = try resolveReasonText(
                configuration: configuration,
                mode: mode,
                factor: primaryFactor.id,
                value: value
            )
            summaryLine = heroSubtitle
        } else {
            heroSubtitle = configuration.messages.insufficientData.heroSubtitle
            summaryLine = configuration.messages.insufficientData.summaryLine
        }

        return ReadinessTextOutput(
            heroTitle: "\(titleParts.status), \(titleParts.action)",
            heroSubtitle: heroSubtitle,
            summaryLine: summaryLine,
            missingHint: missingHint(for: missingFactors, mode: mode, configuration: configuration)
        )
    }

    private func resolveReasonText(
        configuration: ReadinessCopyConfiguration,
        mode: ReadinessMode,
        factor: FactorKind,
        value: Double
    ) throws -> String {
        let reasonSet = configuration.reasons.reasons(for: mode).reasonSet(for: factor)
        guard let matchedRange = reasonSet.ranges.first(where: { $0.contains(value) }) else {
            throw ReadinessCopyError.unresolvedReason(mode: mode, factor: factor, value: value)
        }
        return matchedRange.text
    }

    private func metricValue(
        for primaryFactor: SubScore,
        mode: ReadinessMode,
        inputs: ReadinessInputs,
        configuration: ReadinessCopyConfiguration
    ) -> Double {
        let reasonSet = configuration.reasons.reasons(for: mode).reasonSet(for: primaryFactor.id)
        switch reasonSet.valueSource ?? .score {
        case .score:
            return primaryFactor.value
        case .sleepDurationLastNightHours:
            return inputs.recovery.sleepDurationLastNightHours ?? 0
        }
    }

    private func missingHint(
        for factors: [FactorKind],
        mode: ReadinessMode,
        configuration: ReadinessCopyConfiguration
    ) -> String? {
        guard !factors.isEmpty else { return nil }

        let labels = factors.map { configuration.missingLabels.labels(for: mode).label(for: $0) }
        let joinedLabels = labels.joined(separator: ", ")
        return configuration.messages.partialDataMissingTemplate.replacingOccurrences(
            of: "{{labels}}",
            with: joinedLabels
        )
    }
}
