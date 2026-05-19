import Foundation

public func pmRequestedRuntimeText(_ provenance: PMRuntimeProvenance?) -> String {
    guard let provenance else {
        return "No PM runtime recorded"
    }
    let reasoning = provenance.configuredReasoningMode?.rawValue ?? "standard"
    return "\(provenance.configuredRuntimeIdentifier) (\(reasoning) reasoning)"
}

public func pmActualRuntimeText(_ provenance: PMRuntimeProvenance?) -> String {
    guard let provenance else {
        return "-"
    }
    let reasoningSuffix: String
    if let reasoning = provenance.actualReasoningMode?.rawValue {
        reasoningSuffix = " with \(reasoning) reasoning"
    } else {
        reasoningSuffix = ""
    }

    if provenance.actualRuntimeIdentifier.hasPrefix("deterministic_local_fallback["),
       provenance.actualRuntimeIdentifier.hasSuffix("]") {
        let start = provenance.actualRuntimeIdentifier.index(
            provenance.actualRuntimeIdentifier.startIndex,
            offsetBy: "deterministic_local_fallback[".count
        )
        let end = provenance.actualRuntimeIdentifier.index(before: provenance.actualRuntimeIdentifier.endIndex)
        let profile = String(provenance.actualRuntimeIdentifier[start..<end])
        return "Local PM synthesis fallback profile \(profile)\(reasoningSuffix)"
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

    return "\(provenance.actualRuntimeIdentifier)\(reasoningSuffix)"
}

public func pmExecutionUsedRuntimeText(_ provenance: PMRuntimeProvenance?) -> String {
    guard let provenance else {
        return "-"
    }
    let actual = pmActualRuntimeText(provenance)
    if provenance.actualRuntimeIdentifier == "openai_responses[\(provenance.configuredRuntimeIdentifier)]",
       provenance.actualReasoningMode == provenance.configuredReasoningMode {
        return actual
    }
    return "\(actual) (fallback from \(pmRequestedRuntimeText(provenance)))"
}
