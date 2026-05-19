import Foundation

public enum MemoryPostureBand: String, Sendable, Codable, Equatable {
    case sampleUnavailable
    case normal
    case watch
    case reliefRecommended
    case reliefApplied
    case elevated
    case critical

    public var reliefEligible: Bool {
        switch self {
        case .reliefRecommended, .reliefApplied, .elevated, .critical:
            return true
        case .sampleUnavailable, .normal, .watch:
            return false
        }
    }
}

public struct MemoryPostureMonitorConfiguration: Sendable, Codable, Equatable {
    public let warmupSeconds: TimeInterval
    public let checkCadenceSeconds: TimeInterval
    public let watchThresholdMB: Double
    public let reliefThresholdMB: Double
    public let elevatedThresholdMB: Double
    public let criticalThresholdMB: Double

    public init(
        warmupSeconds: TimeInterval,
        checkCadenceSeconds: TimeInterval,
        watchThresholdMB: Double,
        reliefThresholdMB: Double,
        elevatedThresholdMB: Double,
        criticalThresholdMB: Double
    ) {
        self.warmupSeconds = warmupSeconds
        self.checkCadenceSeconds = checkCadenceSeconds
        self.watchThresholdMB = watchThresholdMB
        self.reliefThresholdMB = reliefThresholdMB
        self.elevatedThresholdMB = elevatedThresholdMB
        self.criticalThresholdMB = criticalThresholdMB
    }

    public static let conservativeDefault = MemoryPostureMonitorConfiguration(
        warmupSeconds: 30 * 60,
        checkCadenceSeconds: 8 * 60 * 60,
        watchThresholdMB: 600,
        reliefThresholdMB: 750,
        elevatedThresholdMB: 1_024,
        criticalThresholdMB: 1_280
    )

    public var watchThresholdBytes: UInt64 {
        Self.bytes(forMegabytes: watchThresholdMB)
    }

    public var reliefThresholdBytes: UInt64 {
        Self.bytes(forMegabytes: reliefThresholdMB)
    }

    public var elevatedThresholdBytes: UInt64 {
        Self.bytes(forMegabytes: elevatedThresholdMB)
    }

    public var criticalThresholdBytes: UInt64 {
        Self.bytes(forMegabytes: criticalThresholdMB)
    }

    public static func bytes(forMegabytes megabytes: Double) -> UInt64 {
        UInt64((megabytes * 1_024 * 1_024).rounded())
    }
}

public enum MemoryReliefActionMode: String, Sendable, Codable, Equatable {
    case automaticSelfFootprint
    case macOSMemoryPressure
    case systemControlManual
    case ipcForcedDiagnostic
    case ipcDryRun
}

public struct MemoryReliefRequest: Sendable, Codable, Equatable {
    public let dryRun: Bool
    public let force: Bool
    public let reason: String

    public init(dryRun: Bool, force: Bool, reason: String) {
        self.dryRun = dryRun
        self.force = force
        self.reason = reason
    }
}

public struct ProcessMemoryFootprintSample: Sendable, Codable, Equatable {
    public let capturedAt: Date
    public let physicalFootprintBytes: UInt64?
    public let residentSizeBytes: UInt64?
    public let source: String
    public let failureReason: String?

    public init(
        capturedAt: Date,
        physicalFootprintBytes: UInt64?,
        residentSizeBytes: UInt64?,
        source: String,
        failureReason: String?
    ) {
        self.capturedAt = capturedAt
        self.physicalFootprintBytes = physicalFootprintBytes
        self.residentSizeBytes = residentSizeBytes
        self.source = source
        self.failureReason = failureReason
    }

    public var physicalFootprintMB: Double? {
        physicalFootprintBytes.map { Double($0) / 1_024 / 1_024 }
    }

    public var residentSizeMB: Double? {
        residentSizeBytes.map { Double($0) / 1_024 / 1_024 }
    }
}

public struct AllocatorPressureReliefOutcome: Sendable, Codable, Equatable {
    public let attempted: Bool
    public let reclaimedBytes: UInt64?
    public let error: String?

    public init(attempted: Bool, reclaimedBytes: UInt64?, error: String?) {
        self.attempted = attempted
        self.reclaimedBytes = reclaimedBytes
        self.error = error
    }

    public static let notAttempted = AllocatorPressureReliefOutcome(
        attempted: false,
        reclaimedBytes: nil,
        error: nil
    )
}

public struct MemoryReliefActionSummary: Sendable, Codable, Equatable {
    public let mode: MemoryReliefActionMode
    public let reason: String
    public let dryRun: Bool
    public let forced: Bool
    public let startedAt: Date
    public let completedAt: Date
    public let bandBeforeAction: MemoryPostureBand
    public let sample: ProcessMemoryFootprintSample
    public let volatileCategoryCountsBefore: [String: Int]
    public let volatileCategoryCountsAfter: [String: Int]
    public let allocatorRelief: AllocatorPressureReliefOutcome
    public let actionApplied: Bool
    public let summary: String

    public init(
        mode: MemoryReliefActionMode,
        reason: String,
        dryRun: Bool,
        forced: Bool,
        startedAt: Date,
        completedAt: Date,
        bandBeforeAction: MemoryPostureBand,
        sample: ProcessMemoryFootprintSample,
        volatileCategoryCountsBefore: [String: Int],
        volatileCategoryCountsAfter: [String: Int],
        allocatorRelief: AllocatorPressureReliefOutcome,
        actionApplied: Bool,
        summary: String
    ) {
        self.mode = mode
        self.reason = reason
        self.dryRun = dryRun
        self.forced = forced
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.bandBeforeAction = bandBeforeAction
        self.sample = sample
        self.volatileCategoryCountsBefore = volatileCategoryCountsBefore
        self.volatileCategoryCountsAfter = volatileCategoryCountsAfter
        self.allocatorRelief = allocatorRelief
        self.actionApplied = actionApplied
        self.summary = summary
    }
}

public struct MemoryPostureDiagnostics: Sendable, Codable, Equatable {
    public let configuration: MemoryPostureMonitorConfiguration
    public let latestSample: ProcessMemoryFootprintSample?
    public let peakPhysicalFootprintBytes: UInt64?
    public let currentBand: MemoryPostureBand
    public let lastSampleAt: Date?
    public let nextScheduledSampleAt: Date?
    public let lastAction: MemoryReliefActionSummary?
    public let automaticReliefCount: Int
    public let manualReliefCount: Int
    public let memoryPressureReliefCount: Int
    public let allocatorReliefAttemptCount: Int
    public let allocatorReliefTotalReclaimedBytes: UInt64
    public let actionInFlight: Bool

    public init(
        configuration: MemoryPostureMonitorConfiguration,
        latestSample: ProcessMemoryFootprintSample?,
        peakPhysicalFootprintBytes: UInt64?,
        currentBand: MemoryPostureBand,
        lastSampleAt: Date?,
        nextScheduledSampleAt: Date?,
        lastAction: MemoryReliefActionSummary?,
        automaticReliefCount: Int,
        manualReliefCount: Int,
        memoryPressureReliefCount: Int,
        allocatorReliefAttemptCount: Int,
        allocatorReliefTotalReclaimedBytes: UInt64,
        actionInFlight: Bool
    ) {
        self.configuration = configuration
        self.latestSample = latestSample
        self.peakPhysicalFootprintBytes = peakPhysicalFootprintBytes
        self.currentBand = currentBand
        self.lastSampleAt = lastSampleAt
        self.nextScheduledSampleAt = nextScheduledSampleAt
        self.lastAction = lastAction
        self.automaticReliefCount = automaticReliefCount
        self.manualReliefCount = manualReliefCount
        self.memoryPressureReliefCount = memoryPressureReliefCount
        self.allocatorReliefAttemptCount = allocatorReliefAttemptCount
        self.allocatorReliefTotalReclaimedBytes = allocatorReliefTotalReclaimedBytes
        self.actionInFlight = actionInFlight
    }

    public var peakPhysicalFootprintMB: Double? {
        peakPhysicalFootprintBytes.map { Double($0) / 1_024 / 1_024 }
    }
}

public enum MemoryPosturePolicy {
    public static func classify(
        physicalFootprintBytes: UInt64?,
        configuration: MemoryPostureMonitorConfiguration
    ) -> MemoryPostureBand {
        guard let physicalFootprintBytes else {
            return .sampleUnavailable
        }
        if physicalFootprintBytes >= configuration.criticalThresholdBytes {
            return .critical
        }
        if physicalFootprintBytes >= configuration.elevatedThresholdBytes {
            return .elevated
        }
        if physicalFootprintBytes >= configuration.reliefThresholdBytes {
            return .reliefRecommended
        }
        if physicalFootprintBytes >= configuration.watchThresholdBytes {
            return .watch
        }
        return .normal
    }

    public static func nextScheduledSampleDate(
        launchDate: Date,
        lastSampleAt: Date?,
        configuration: MemoryPostureMonitorConfiguration
    ) -> Date {
        if let lastSampleAt {
            return lastSampleAt.addingTimeInterval(configuration.checkCadenceSeconds)
        }
        return launchDate.addingTimeInterval(configuration.warmupSeconds)
    }

    public static func shouldRunScheduledSample(
        now: Date,
        launchDate: Date,
        lastSampleAt: Date?,
        inFlight: Bool,
        configuration: MemoryPostureMonitorConfiguration
    ) -> Bool {
        guard inFlight == false else {
            return false
        }
        return now >= nextScheduledSampleDate(
            launchDate: launchDate,
            lastSampleAt: lastSampleAt,
            configuration: configuration
        )
    }

    public static func shouldApplyRelief(
        band: MemoryPostureBand,
        forced: Bool,
        dryRun: Bool,
        inFlight: Bool
    ) -> Bool {
        guard inFlight == false, dryRun == false else {
            return false
        }
        return forced || band.reliefEligible
    }
}
