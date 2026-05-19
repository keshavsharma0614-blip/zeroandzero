import Foundation

public func pmTaskingBriefHasContent(_ brief: PMTaskingBrief?) -> Bool {
    guard let brief else { return false }
    if nonEmptyPMTaskingValue(brief.taskObjective) != nil { return true }
    if nonEmptyPMTaskingValue(brief.whyNow) != nil { return true }
    if nonEmptyPMTaskingValue(brief.reviewLens) != nil { return true }
    if brief.expectedAnswerShape != nil { return true }
    if nonEmptyPMTaskingValue(brief.challengeInstruction) != nil { return true }
    if nonEmptyPMTaskingValue(brief.evidenceExpectation) != nil { return true }
    if nonEmptyPMTaskingValue(brief.disconfirmingEvidenceExpectation) != nil { return true }
    if brief.researchQuestions.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { return true }
    if brief.coverageRequired { return true }
    if brief.expectedOutputs.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { return true }
    if nonEmptyPMTaskingValue(brief.revisionReason) != nil { return true }
    if brief.selectedSkillReferences.isEmpty == false { return true }
    return false
}

public func makePMTaskingBriefBody(_ brief: PMTaskingBrief?) -> String {
    guard let brief, pmTaskingBriefHasContent(brief) else {
        return ""
    }

    var lines: [String] = []
    if let value = nonEmptyPMTaskingValue(brief.taskObjective) {
        lines.append("Objective: \(value)")
    }
    if let value = nonEmptyPMTaskingValue(brief.whyNow) {
        lines.append("Why now: \(value)")
    }
    if let value = nonEmptyPMTaskingValue(brief.reviewLens) {
        lines.append("Review lens: \(value)")
    }
    if let value = brief.expectedAnswerShape {
        lines.append("Expected answer shape: \(pmAnalystExpectedAnswerShapeTitle(value))")
    }
    if let value = nonEmptyPMTaskingValue(brief.challengeInstruction) {
        lines.append("Challenge instruction: \(value)")
    }
    if let value = nonEmptyPMTaskingValue(brief.evidenceExpectation) {
        lines.append("Evidence expectation: \(value)")
    }
    if let value = nonEmptyPMTaskingValue(brief.disconfirmingEvidenceExpectation) {
        lines.append("Disconfirming evidence: \(value)")
    }
    let researchQuestions = AnalystTaskQuestionChecklist.normalizedQuestions(brief.researchQuestions)
    if !researchQuestions.isEmpty {
        lines.append("Required question checklist:")
        lines.append(contentsOf: researchQuestions.enumerated().map { index, question in
            "\(index + 1). \(question)"
        })
    }
    if brief.coverageRequired {
        lines.append("Coverage required: answer every required question, or mark it partial/not found/blocked with a source gap.")
    }
    let expectedOutputs = brief.expectedOutputs
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    if !expectedOutputs.isEmpty {
        lines.append("Expected outputs: \(expectedOutputs.joined(separator: ", "))")
    }
    if let value = nonEmptyPMTaskingValue(brief.revisionReason) {
        lines.append("Revision reason: \(value)")
    }
    if brief.selectedSkillReferences.isEmpty == false {
        lines.append(
            "Selected Agent Skills: \(makePMTaskingSelectedSkillReferencesLine(brief.selectedSkillReferences))"
        )
    }
    return lines.joined(separator: "\n")
}

public func makePMTaskingSelectedSkillReferencesLine(
    _ references: [AgentSkillTaskReference]
) -> String {
    references
        .prefix(8)
        .map { reference in
            var value = "\(reference.skillTitle) [\(reference.skillId)] as \(reference.requirement.displayTitle.lowercased()) from \(reference.source.displayTitle)"
            if let rationale = nonEmptyPMTaskingValue(reference.rationale) {
                value += " - \(rationale)"
            }
            return value
        }
        .joined(separator: "; ")
}

public func pmAnalystExpectedAnswerShapeTitle(_ shape: PMAnalystExpectedAnswerShape) -> String {
    switch shape {
    case .memoOnly:
        return "Memo Only"
    case .evidenceBackedAnswer:
        return "Evidence-Backed Answer"
    case .riskView:
        return "Risk View"
    case .competingCaseComparison:
        return "Competing-Case Comparison"
    case .recommendationReadySynthesis:
        return "Recommendation-Ready Synthesis"
    case .escalationOnlyConclusion:
        return "Escalation-Only Conclusion"
    case .revisedTake:
        return "Revised Take"
    }
}

public func pmAnalystFollowUpActionTitle(_ actionType: PMAnalystFollowUpActionType) -> String {
    switch actionType {
    case .accept:
        return "Accept Current Output"
    case .requestRevision:
        return "Request Revision"
    case .requestStrongerEvidence:
        return "Request Stronger Evidence"
    case .rerouteToAnalyst:
        return "Reroute To Analyst"
    case .rerunWithRuntime:
        return "Rerun With Runtime"
    }
}

public struct PMAnalystFollowUpGuidance: Sendable, Equatable {
    public let managerialIntent: String
    public let useCase: String
    public let nextStepMeaning: String

    public init(
        managerialIntent: String,
        useCase: String,
        nextStepMeaning: String
    ) {
        self.managerialIntent = managerialIntent
        self.useCase = useCase
        self.nextStepMeaning = nextStepMeaning
    }
}

public func makePMAnalystFollowUpGuidance(
    _ actionType: PMAnalystFollowUpActionType
) -> PMAnalystFollowUpGuidance {
    switch actionType {
    case .accept:
        return PMAnalystFollowUpGuidance(
            managerialIntent: "The PM considers the current analyst output decision-useful as written.",
            useCase: "Use when the current memo or finding is strong enough to support PM judgment without another analyst cycle.",
            nextStepMeaning: "No new analyst task is created. The PM records acceptance and moves forward under the existing approval and trading guardrails."
        )
    case .requestRevision:
        return PMAnalystFollowUpGuidance(
            managerialIntent: "The PM wants the same line of work tightened so it responds more directly to the original question.",
            useCase: "Use when the analyst is directionally on task but the synthesis is incomplete, poorly structured, or not sharp enough for PM use.",
            nextStepMeaning: "The same analytical lane stays active, but the analyst is asked to deliver a clearer and more responsive answer."
        )
    case .requestStrongerEvidence:
        return PMAnalystFollowUpGuidance(
            managerialIntent: "The PM wants stronger proof before leaning on the current conclusion.",
            useCase: "Use when the current direction may be right but the evidence base is too thin, too one-sided, or too lightly sourced.",
            nextStepMeaning: "The analyst remains on the same question, but the next pass must deepen the evidence standard before PM escalation."
        )
    case .rerouteToAnalyst:
        return PMAnalystFollowUpGuidance(
            managerialIntent: "The PM believes a different specialist is the better fit for the question now.",
            useCase: "Use when the issue has shifted into another domain, needs a competing specialist view, or was routed to the wrong analyst in the first place.",
            nextStepMeaning: "A new delegation is issued to another charter while preserving lineage to the original work."
        )
    case .rerunWithRuntime:
        return PMAnalystFollowUpGuidance(
            managerialIntent: "The PM wants the same analyst to reattempt the task under a more suitable runtime or reasoning profile.",
            useCase: "Use when the framing is still broadly right but the PM wants a stronger runtime, a different reasoning mode, or a cleaner retry.",
            nextStepMeaning: "The same specialist remains responsible, but the new run is explicitly retried under revised runtime conditions."
        )
    }
}

public func makePMAnalystFollowUpBody(_ action: PMAnalystFollowUpAction) -> String {
    let guidance = makePMAnalystFollowUpGuidance(action.actionType)
    var lines: [String] = []
    lines.append("Action: \(pmAnalystFollowUpActionTitle(action.actionType))")
    lines.append("Managerial intent: \(guidance.managerialIntent)")
    lines.append("Use when: \(guidance.useCase)")
    let trimmedSummary = action.summary.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedSummary.isEmpty {
        lines.append("PM note: \(trimmedSummary)")
    }
    if let requestedCharterId = nonEmptyPMTaskingValue(action.requestedCharterId) {
        lines.append("Requested analyst: \(requestedCharterId)")
    }
    if let runtime = action.requestedRuntimePolicy {
        lines.append("Requested runtime: \(analystRequestedRuntimeText(runtime))")
    }
    let taskingBody = makePMTaskingBriefBody(action.taskingBrief)
    if !taskingBody.isEmpty {
        lines.append(taskingBody)
    }
    lines.append("Next step meaning: \(guidance.nextStepMeaning)")
    lines.append("Issued: \(DateCodec.formatISO8601(action.createdAt))")
    return lines.joined(separator: "\n")
}

public func makePMTaskDescription(
    baseDescription: String,
    brief: PMTaskingBrief?,
    action: PMAnalystFollowUpAction? = nil,
    sourceDelegationTitle: String? = nil
) -> String {
    var sections: [String] = []
    let trimmedBase = baseDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedBase.isEmpty {
        sections.append(trimmedBase)
    }
    if let action {
        let guidance = makePMAnalystFollowUpGuidance(action.actionType)
        if let sourceDelegationTitle = nonEmptyPMTaskingValue(sourceDelegationTitle) {
            sections.append("PM follow-up on \(sourceDelegationTitle): \(pmAnalystFollowUpActionTitle(action.actionType)). \(guidance.managerialIntent)")
        } else {
            sections.append("PM follow-up intent: \(guidance.managerialIntent)")
        }
    }
    let briefBody = makePMTaskingBriefBody(brief)
    if !briefBody.isEmpty {
        sections.append("PM tasking brief:\n\(briefBody)")
    }
    if let action {
        let trimmedSummary = action.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSummary.isEmpty {
            sections.append("PM follow-up note: \(trimmedSummary)")
        }
        sections.append("Requested next step meaning: \(makePMAnalystFollowUpGuidance(action.actionType).nextStepMeaning)")
    }
    return sections.joined(separator: "\n\n")
}

public func pmFollowUpWorkflowSummary(
    sourceDelegation: PMDelegationRecord,
    result: PMDelegationFollowUpResult
) -> String {
    if let decisionId = result.createdDecisionId {
        return "Accepted current analyst output for \(sourceDelegation.title). Decision recorded as \(decisionId)."
    }
    if let delegationId = result.createdDelegationId, let taskId = result.createdTaskId {
        if let latestAction = sourceDelegation.followUpActions.last {
            let guidance = makePMAnalystFollowUpGuidance(latestAction.actionType)
            return "Created analyst follow-up delegation \(delegationId) with task \(taskId). \(guidance.nextStepMeaning)"
        }
        return "Created analyst follow-up delegation \(delegationId) with task \(taskId)."
    }
    return "Recorded PM analyst follow-up for \(sourceDelegation.title)."
}

private func nonEmptyPMTaskingValue(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return trimmed
}
