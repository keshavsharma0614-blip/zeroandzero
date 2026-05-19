import Foundation
import Testing
@testable import TradingKit

@Test("Memory posture bands classify conservative self-footprint thresholds")
func memoryPostureBandsClassifyThresholds() {
    let config = MemoryPostureMonitorConfiguration(
        warmupSeconds: 1_800,
        checkCadenceSeconds: 28_800,
        watchThresholdMB: 600,
        reliefThresholdMB: 750,
        elevatedThresholdMB: 1_024,
        criticalThresholdMB: 1_280
    )

    #expect(MemoryPosturePolicy.classify(physicalFootprintBytes: nil, configuration: config) == .sampleUnavailable)
    #expect(MemoryPosturePolicy.classify(physicalFootprintBytes: MemoryPostureMonitorConfiguration.bytes(forMegabytes: 512), configuration: config) == .normal)
    #expect(MemoryPosturePolicy.classify(physicalFootprintBytes: MemoryPostureMonitorConfiguration.bytes(forMegabytes: 650), configuration: config) == .watch)
    #expect(MemoryPosturePolicy.classify(physicalFootprintBytes: MemoryPostureMonitorConfiguration.bytes(forMegabytes: 800), configuration: config) == .reliefRecommended)
    #expect(MemoryPosturePolicy.classify(physicalFootprintBytes: MemoryPostureMonitorConfiguration.bytes(forMegabytes: 1_100), configuration: config) == .elevated)
    #expect(MemoryPosturePolicy.classify(physicalFootprintBytes: MemoryPostureMonitorConfiguration.bytes(forMegabytes: 1_400), configuration: config) == .critical)
}

@Test("Memory posture cadence waits through warmup and avoids status-refresh loops")
func memoryPostureCadenceGatesScheduledSampling() {
    let config = MemoryPostureMonitorConfiguration.conservativeDefault
    let launch = Date(timeIntervalSince1970: 1_000)

    #expect(MemoryPosturePolicy.shouldRunScheduledSample(
        now: launch.addingTimeInterval(config.warmupSeconds - 1),
        launchDate: launch,
        lastSampleAt: nil,
        inFlight: false,
        configuration: config
    ) == false)

    #expect(MemoryPosturePolicy.shouldRunScheduledSample(
        now: launch.addingTimeInterval(config.warmupSeconds),
        launchDate: launch,
        lastSampleAt: nil,
        inFlight: false,
        configuration: config
    ) == true)

    let firstSample = launch.addingTimeInterval(config.warmupSeconds)
    #expect(MemoryPosturePolicy.shouldRunScheduledSample(
        now: firstSample.addingTimeInterval(config.checkCadenceSeconds - 1),
        launchDate: launch,
        lastSampleAt: firstSample,
        inFlight: false,
        configuration: config
    ) == false)

    #expect(MemoryPosturePolicy.shouldRunScheduledSample(
        now: firstSample.addingTimeInterval(config.checkCadenceSeconds),
        launchDate: launch,
        lastSampleAt: firstSample,
        inFlight: false,
        configuration: config
    ) == true)

    #expect(MemoryPosturePolicy.shouldRunScheduledSample(
        now: firstSample.addingTimeInterval(config.checkCadenceSeconds),
        launchDate: launch,
        lastSampleAt: firstSample,
        inFlight: true,
        configuration: config
    ) == false)
}

@Test("Memory relief policy runs only for eligible bands or forced diagnostics")
func memoryReliefPolicyRequiresEligibleBandOrForce() {
    #expect(MemoryPosturePolicy.shouldApplyRelief(
        band: .normal,
        forced: false,
        dryRun: false,
        inFlight: false
    ) == false)
    #expect(MemoryPosturePolicy.shouldApplyRelief(
        band: .reliefRecommended,
        forced: false,
        dryRun: false,
        inFlight: false
    ) == true)
    #expect(MemoryPosturePolicy.shouldApplyRelief(
        band: .normal,
        forced: true,
        dryRun: false,
        inFlight: false
    ) == true)
    #expect(MemoryPosturePolicy.shouldApplyRelief(
        band: .critical,
        forced: false,
        dryRun: true,
        inFlight: false
    ) == false)
    #expect(MemoryPosturePolicy.shouldApplyRelief(
        band: .critical,
        forced: false,
        dryRun: false,
        inFlight: true
    ) == false)
}

@Test("Allocator relief summary records no-op failures without crashing callers")
func allocatorReliefOutcomeRecordsAttemptFailures() {
    let outcome = AllocatorPressureReliefOutcome(
        attempted: true,
        reclaimedBytes: nil,
        error: "allocator_unavailable"
    )

    #expect(outcome.attempted == true)
    #expect(outcome.reclaimedBytes == nil)
    #expect(outcome.error == "allocator_unavailable")
}
