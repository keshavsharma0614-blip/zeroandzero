import Foundation
import Testing
@testable import TradingKit

private func temporaryAgentSkillDirectory(_ label: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(label)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private func makeCustomAgentSkill(
    id: String = "skill-custom-test",
    title: String = "Custom Skill",
    now: Date = Date(timeIntervalSince1970: 1_800_000_000)
) -> AgentSkillRecord {
    AgentSkillRecord(
        skillId: id,
        title: title,
        summary: "Custom reusable method.",
        documentBody: "# Custom Skill\n\n## Boundaries\n\nThis skill does not authorize trades or bypass governance.",
        category: .custom,
        tags: ["custom", "method"],
        status: .active,
        updatedBy: "human owner",
        updateSource: .ownerUI,
        createdAt: now,
        updatedAt: now
    )
}

@Test("AgentSkillRecord saves and loads through v1 persistence")
func agentSkillRecordSavesAndLoads() async throws {
    let directory = try temporaryAgentSkillDirectory("agent-skill-roundtrip")
    defer { try? FileManager.default.removeItem(at: directory) }

    let now = Date(timeIntervalSince1970: 1_800_000_100)
    let store = AgentSkillStore(skillsDirectory: directory, now: { now })
    let skill = makeCustomAgentSkill(now: now)

    try await store.upsert(skill)

    let reloaded = AgentSkillStore(skillsDirectory: directory, now: { now.addingTimeInterval(60) })
    let loaded = try await reloaded.loadAll()

    #expect(loaded.count == 1)
    #expect(loaded.first?.skillId == "skill-custom-test")
    #expect(loaded.first?.title == "Custom Skill")
    #expect(loaded.first?.documentBody.contains("does not authorize trades") == true)
}

@Test("AgentSkillStore seeds the four default methodology skills once")
func agentSkillStoreSeedsDefaultSkillsOnce() async throws {
    let directory = try temporaryAgentSkillDirectory("agent-skill-seeds")
    defer { try? FileManager.default.removeItem(at: directory) }

    let now = Date(timeIntervalSince1970: 1_800_000_200)
    let store = AgentSkillStore(skillsDirectory: directory, now: { now })

    let firstSeed = try await store.seedMissingDefaultSkills()
    let secondSeed = try await store.seedMissingDefaultSkills()
    let skills = try await store.loadAll()

    #expect(firstSeed.count == 4)
    #expect(secondSeed.isEmpty)
    #expect(skills.count == 4)
    #expect(Set(skills.map(\.skillId)) == Set([
        AgentSkillSeed.disconfirmingEvidenceChecklistID,
        AgentSkillSeed.portfolioFitRiskLensID,
        AgentSkillSeed.sourceQualityCorroborationID,
        AgentSkillSeed.longShortCandidatePressureTestID
    ]))
}

@Test("Seeded agent skills are complete and carry governance boundary language")
func seededAgentSkillsAreCompleteAndBounded() {
    let skills = AgentSkillSeed.seededSkills(now: Date(timeIntervalSince1970: 1_800_000_300))

    #expect(skills.count == 4)
    for skill in skills {
        #expect(skill.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        #expect(skill.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        #expect(skill.documentBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        #expect(skill.seedIdentifier == skill.skillId)
        #expect(skill.updateSource == .systemSeed)
        #expect(skill.status == .active)
        #expect(skill.documentBody.localizedCaseInsensitiveContains("does not"))
        #expect(
            skill.documentBody.localizedCaseInsensitiveContains("authorize")
                || skill.documentBody.localizedCaseInsensitiveContains("approval")
                || skill.documentBody.localizedCaseInsensitiveContains("governance")
        )
    }
}

@Test("Seeded agent skill owner edits are not overwritten by reseed")
func seededAgentSkillOwnerEditIsNotOverwritten() async throws {
    let directory = try temporaryAgentSkillDirectory("agent-skill-owner-edit")
    defer { try? FileManager.default.removeItem(at: directory) }

    let now = Date(timeIntervalSince1970: 1_800_000_400)
    let store = AgentSkillStore(skillsDirectory: directory, now: { now })

    _ = try await store.seedMissingDefaultSkills()
    guard var skill = try await store.get(id: AgentSkillSeed.portfolioFitRiskLensID) else {
        Issue.record("Missing seeded Portfolio Fit skill")
        return
    }
    skill.summary = "Owner edited summary."
    skill.documentBody = "# Owner Edited Skill\n\nThe owner changed this method.\n\n## Boundaries\n\nStill does not authorize trades."
    skill.updateSource = .ownerUI
    skill.updatedBy = "human owner"
    try await store.upsert(skill)

    _ = try await store.seedMissingDefaultSkills()
    guard let loaded = try await store.get(id: AgentSkillSeed.portfolioFitRiskLensID) else {
        Issue.record("Missing reloaded Portfolio Fit skill")
        return
    }

    #expect(loaded.summary == "Owner edited summary.")
    #expect(loaded.documentBody.contains("The owner changed this method."))
    #expect(loaded.updateSource == .ownerUI)
}

@Test("Archived seeded agent skill is not recreated as an active duplicate")
func archivedSeededAgentSkillIsNotRecreated() async throws {
    let directory = try temporaryAgentSkillDirectory("agent-skill-archive")
    defer { try? FileManager.default.removeItem(at: directory) }

    let now = Date(timeIntervalSince1970: 1_800_000_500)
    let store = AgentSkillStore(skillsDirectory: directory, now: { now })

    _ = try await store.seedMissingDefaultSkills()
    _ = try await store.archive(id: AgentSkillSeed.disconfirmingEvidenceChecklistID)
    _ = try await store.seedMissingDefaultSkills()

    let matching = try await store.loadAll().filter { $0.skillId == AgentSkillSeed.disconfirmingEvidenceChecklistID }
    #expect(matching.count == 1)
    #expect(matching.first?.status == .archived)
    #expect(matching.first?.updateSource == .ownerUI)
}

@Test("AgentSkillStore skips corrupt and unknown schema files without failing global load")
func agentSkillStoreSkipsBadFiles() async throws {
    let directory = try temporaryAgentSkillDirectory("agent-skill-bad-files")
    defer { try? FileManager.default.removeItem(at: directory) }

    let now = Date(timeIntervalSince1970: 1_800_000_600)
    let validStore = AgentSkillStore(skillsDirectory: directory, now: { now })
    try await validStore.upsert(makeCustomAgentSkill(id: "skill-valid", now: now))

    try Data("not json".utf8).write(to: directory.appendingPathComponent("corrupt.json"))
    try Data(#"{"schemaVersion":999,"skill":{}}"#.utf8)
        .write(to: directory.appendingPathComponent("unknown.json"))

    let reloaded = AgentSkillStore(skillsDirectory: directory, now: { now })
    let skills = try await reloaded.loadAll()
    let diagnostics = await reloaded.drainLoadDiagnostics()

    #expect(skills.map(\.skillId) == ["skill-valid"])
    #expect(diagnostics.contains { $0.contains("invalid_document") })
    #expect(diagnostics.contains { $0.contains("unsupported_schema_version") })
}

@Test("AgentSkill category and status decoding remains stable")
func agentSkillCategoryAndStatusRawValuesAreStable() {
    #expect(AgentSkillCategory.researchMethod.rawValue == "research_method")
    #expect(AgentSkillCategory.portfolioConstructionMethod.rawValue == "portfolio_construction_method")
    #expect(AgentSkillCategory.sourceEvaluationMethod.rawValue == "source_evaluation_method")
    #expect(AgentSkillCategory.valuationOrCandidateFramework.rawValue == "valuation_or_candidate_framework")
    #expect(AgentSkillStatus.active.rawValue == "active")
    #expect(AgentSkillStatus.archived.rawValue == "archived")
    #expect(AgentSkillUpdateSource.ownerUI.rawValue == "owner_ui")
}

@Test("AgentSkill persistence schema has no secret fields")
func agentSkillPersistenceSchemaHasNoSecretFields() async throws {
    let directory = try temporaryAgentSkillDirectory("agent-skill-secret-scan")
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = AgentSkillStore(skillsDirectory: directory)
    try await store.upsert(makeCustomAgentSkill(id: "skill-schema-scan"))

    let file = try #require(FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first)
    let payload = try String(contentsOf: file, encoding: .utf8).lowercased()

    #expect(payload.contains("apikey") == false)
    #expect(payload.contains("api_key") == false)
    #expect(payload.contains("secret") == false)
    #expect(payload.contains("token") == false)
    #expect(payload.contains("password") == false)
}

@Test("Engine agent skill bootstrap path seeds defaults and exposes active skills")
func engineAgentSkillBootstrapSeedsDefaults() async throws {
    let directory = try temporaryAgentSkillDirectory("agent-skill-engine")
    defer { try? FileManager.default.removeItem(at: directory) }

    let skillStore = AgentSkillStore(skillsDirectory: directory)
    let engine = Engine(agentSkillStore: skillStore)

    let activeSkills = try await engine.listAgentSkills(includeArchived: false)

    #expect(activeSkills.count == 4)
    #expect(activeSkills.allSatisfy { $0.status == .active })
    #expect(Set(activeSkills.map(\.skillId)).contains(AgentSkillSeed.longShortCandidatePressureTestID))
}

@Test("Analyst synthesis validates skill usage against selected Agent Skill IDs")
func analystSynthesisRejectsUnknownSkillUsageIDs() throws {
    let validUsage = AgentSkillUsageSummary(
        skillId: AgentSkillSeed.disconfirmingEvidenceChecklistID,
        skillTitle: "Disconfirming Evidence Checklist",
        requirement: .required,
        usage: .applied,
        usageSummary: "Applied the disconfirming evidence checklist."
    )
    let validOutput = AnalystOpenAISynthesisOutput(
        findingTitle: "Finding",
        findingSummary: "Summary",
        findingThesis: "Thesis",
        findingConfidence: 0.7,
        memoTitle: "Memo",
        memoExecutiveSummary: "Executive summary",
        memoCurrentView: "Current view",
        memoEvidenceSummary: "Evidence summary",
        memoUncertaintySummary: "Uncertainty summary",
        memoRecommendedNextStep: "Next step",
        skillUsageSummaries: [validUsage]
    )

    let normalized = try validOutput.validated(allowedSkillIds: [AgentSkillSeed.disconfirmingEvidenceChecklistID])
    #expect(normalized.skillUsageSummaries.first?.skillId == AgentSkillSeed.disconfirmingEvidenceChecklistID)

    let invalidOutput = AnalystOpenAISynthesisOutput(
        findingTitle: "Finding",
        findingSummary: "Summary",
        findingThesis: "Thesis",
        findingConfidence: 0.7,
        memoTitle: "Memo",
        memoExecutiveSummary: "Executive summary",
        memoCurrentView: "Current view",
        memoEvidenceSummary: "Evidence summary",
        memoUncertaintySummary: "Uncertainty summary",
        memoRecommendedNextStep: "Next step",
        skillUsageSummaries: [
            AgentSkillUsageSummary(
                skillId: "skill-fabricated",
                skillTitle: "Fabricated Skill",
                requirement: .available,
                usage: .applied,
                usageSummary: "This must not become app-owned skill truth."
            )
        ]
    )

    #expect(throws: AnalystOpenAISynthesisError.malformedResponse(reason: "unknown_skill_usage_id")) {
        try invalidOutput.validated(allowedSkillIds: [AgentSkillSeed.disconfirmingEvidenceChecklistID])
    }
}
