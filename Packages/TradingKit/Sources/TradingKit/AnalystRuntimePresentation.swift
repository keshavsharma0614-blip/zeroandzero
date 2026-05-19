import Foundation

public func analystRequestedRuntimeText(_ policy: AnalystRuntimePolicy?) -> String {
    guard let policy else {
        return "Worker fallback"
    }
    let reasoning = policy.reasoningMode?.rawValue ?? "standard"
    return "\(policy.runtimeIdentifier) (\(reasoning) reasoning)"
}

public func analystActualRuntimeText(_ provenance: AnalystRuntimeProvenance?) -> String {
    guard let provenance else {
        return "-"
    }
    let reasoningSuffix: String
    if let reasoning = provenance.actualReasoningMode?.rawValue {
        reasoningSuffix = " with \(reasoning) reasoning"
    } else {
        reasoningSuffix = ""
    }

    if provenance.actualRuntimeIdentifier.hasPrefix("deterministic_local["),
       provenance.actualRuntimeIdentifier.hasSuffix("]") {
        let start = provenance.actualRuntimeIdentifier.index(
            provenance.actualRuntimeIdentifier.startIndex,
            offsetBy: "deterministic_local[".count
        )
        let end = provenance.actualRuntimeIdentifier.index(before: provenance.actualRuntimeIdentifier.endIndex)
        let profile = String(provenance.actualRuntimeIdentifier[start..<end])
        return "Local synthesis profile \(profile)\(reasoningSuffix)"
    }

    if provenance.actualRuntimeIdentifier.hasPrefix("deterministic_local_fallback["),
       provenance.actualRuntimeIdentifier.hasSuffix("]") {
        let start = provenance.actualRuntimeIdentifier.index(
            provenance.actualRuntimeIdentifier.startIndex,
            offsetBy: "deterministic_local_fallback[".count
        )
        let end = provenance.actualRuntimeIdentifier.index(before: provenance.actualRuntimeIdentifier.endIndex)
        let profile = String(provenance.actualRuntimeIdentifier[start..<end])
        return "Local synthesis fallback profile \(profile)\(reasoningSuffix)"
    }

    if provenance.actualRuntimeIdentifier.hasPrefix("openai_responses["),
       provenance.actualRuntimeIdentifier.hasSuffix("]") {
        let start = provenance.actualRuntimeIdentifier.index(
            provenance.actualRuntimeIdentifier.startIndex,
            offsetBy: "openai_responses[".count
        )
        let end = provenance.actualRuntimeIdentifier.index(before: provenance.actualRuntimeIdentifier.endIndex)
        let model = String(provenance.actualRuntimeIdentifier[start..<end])
        return "OpenAI Responses model \(model)\(reasoningSuffix)"
    }

    if provenance.actualRuntimeIdentifier.hasPrefix("anthropic_messages["),
       provenance.actualRuntimeIdentifier.hasSuffix("]") {
        let start = provenance.actualRuntimeIdentifier.index(
            provenance.actualRuntimeIdentifier.startIndex,
            offsetBy: "anthropic_messages[".count
        )
        let end = provenance.actualRuntimeIdentifier.index(before: provenance.actualRuntimeIdentifier.endIndex)
        let model = String(provenance.actualRuntimeIdentifier[start..<end])
        return "Anthropic Messages model \(model)\(reasoningSuffix)"
    }

    if provenance.actualRuntimeIdentifier == "deterministic_local" {
        return "Local deterministic synthesis\(reasoningSuffix)"
    }

    if provenance.actualRuntimeIdentifier == "deterministic_local_fallback" {
        return "Local deterministic synthesis fallback\(reasoningSuffix)"
    }

    return "\(provenance.actualRuntimeIdentifier)\(reasoningSuffix)"
}

public func analystExecutionUsedRuntimeText(_ provenance: AnalystRuntimeProvenance?) -> String {
    guard let provenance else {
        return "-"
    }
    let actual = analystActualRuntimeText(provenance)
    guard let intended = provenance.intendedPolicy,
          analystRuntimeMatchesIntendedPolicy(provenance) == false else {
        return actual
    }
    return "\(actual) (fallback from \(analystRequestedRuntimeText(intended)))"
}

public func analystRuntimeComparisonText(_ provenance: AnalystRuntimeProvenance?) -> String {
    guard let provenance else {
        return "No runtime recorded."
    }
    let requested = analystRequestedRuntimeText(provenance.intendedPolicy)
    let actual = analystExecutionUsedRuntimeText(provenance)
    return "Requested \(requested). Executed with \(actual)."
}

private func analystRuntimeMatchesIntendedPolicy(_ provenance: AnalystRuntimeProvenance) -> Bool {
    guard let intended = provenance.intendedPolicy else {
        return true
    }

    if provenance.actualRuntimeIdentifier == intended.runtimeIdentifier,
       provenance.actualReasoningMode == intended.reasoningMode {
        return true
    }

    let deterministicWrapped = "deterministic_local[\(intended.runtimeIdentifier)]"
    if provenance.actualRuntimeIdentifier == deterministicWrapped,
       provenance.actualReasoningMode == intended.reasoningMode {
        return true
    }

    let openAIWrapped = "openai_responses[\(intended.runtimeIdentifier)]"
    if provenance.actualRuntimeIdentifier == openAIWrapped,
       provenance.actualReasoningMode == intended.reasoningMode {
        return true
    }

    let anthropicWrapped = "anthropic_messages[\(intended.runtimeIdentifier)]"
    if provenance.actualRuntimeIdentifier == anthropicWrapped,
       provenance.actualReasoningMode == intended.reasoningMode {
        return true
    }

    return provenance.actualRuntimeIdentifier == "deterministic_local"
        && intended.runtimeIdentifier.isEmpty
}
