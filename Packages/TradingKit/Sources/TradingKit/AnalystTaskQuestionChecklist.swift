import Foundation

public enum AnalystTaskQuestionChecklist {
    public static let maxQuestionCount = 12

    public static func questions(
        taskTitle: String? = nil,
        taskDescription: String? = nil,
        taskingBrief: PMTaskingBrief? = nil
    ) -> [String] {
        let explicitQuestions = normalizedQuestions(
            (taskingBrief?.researchQuestions ?? []).flatMap(candidateQuestionFragments(from:))
        )
        if explicitQuestions.isEmpty == false {
            return explicitQuestions
        }

        var primaryCandidates: [String] = []
        if let taskDescription {
            primaryCandidates.append(contentsOf: candidateQuestionFragments(from: taskDescription))
        }
        let primary = normalizedQuestions(primaryCandidates)
        if primary.isEmpty == false {
            return primary
        }

        var candidates: [String] = []
        if let objective = taskingBrief?.taskObjective {
            candidates.append(contentsOf: candidateQuestionFragments(from: objective))
        }
        if let reviewLens = taskingBrief?.reviewLens {
            candidates.append(contentsOf: candidateQuestionFragments(from: reviewLens))
        }
        if let title = taskTitle {
            candidates.append(contentsOf: candidateQuestionFragments(from: title))
        }
        candidates.append(contentsOf: taskingBrief?.expectedOutputs ?? [])

        return normalizedQuestions(candidates)
    }

    public static func normalizedQuestions(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []
        for value in values {
            let question = normalizedQuestionText(value)
            guard question.isEmpty == false else { continue }
            let key = question.lowercased()
            guard seen.insert(key).inserted else { continue }
            normalized.append(question)
            if normalized.count >= maxQuestionCount {
                break
            }
        }
        return normalized
    }

    private static func candidateQuestionFragments(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return [] }

        let lowered = trimmed.lowercased()
        let focusPhrases = [
            "required questions:",
            "required coverage:",
            "research and answer explicitly:",
            "answer explicitly:",
            "answer these questions explicitly:",
            "answer:",
            "scope:"
        ]
        let focusRange = focusPhrases
            .compactMap { lowered.range(of: $0) }
            .min { $0.lowerBound < $1.lowerBound }
        let focused = focusRange.map { String(trimmed[$0.upperBound...]) } ?? trimmed

        let withQuestionSeparators = focused
            .replacingOccurrences(
                of: #"\s+\((\d{1,2})\)\s+"#,
                with: #"; ($1) "#,
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"^\((\d{1,2})\)\s+"#,
                with: #"($1) "#,
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?i)([,;]\s+(?:and\s+)?)(when|what|whether|which|how|why|are|is|does|do)\b"#,
                with: #"; $2"#,
                options: .regularExpression
            )
            .replacingOccurrences(of: "\n-", with: "; ")
            .replacingOccurrences(of: "\n*", with: "; ")
            .replacingOccurrences(of: "\n", with: "; ")
            .replacingOccurrences(of: "?", with: "?;")

        return withQuestionSeparators
            .split(separator: ";", omittingEmptySubsequences: true)
            .map(String.init)
    }

    private static func normalizedQuestionText(_ value: String) -> String {
        var text = value
            .replacingOccurrences(of: #"^\s*(?:[-*•]\s+|\(?\d+[.)]\s+)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        while text.lowercased().hasPrefix("and ") {
            text = String(text.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        while text.lowercased().hasPrefix("etc") {
            text = String(text.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let trailingInstructionMarkers = [
            ". Public web research",
            ". Direct public web research",
            ". Preserve explicit question coverage",
            ". Include question coverage",
            ". Question coverage",
            ". Label source",
            ". Use direct public web research",
            ". Use public web research",
            ". Do not accept deterministic fallback",
            ". Close with coverage",
            ". Use reputable secondary",
            ". Prioritize official"
        ]
        for marker in trailingInstructionMarkers {
            if let range = text.range(of: marker, options: [.caseInsensitive]) {
                text = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: ".;: "))

        guard text.count >= 8 else { return "" }
        let lower = text.lowercased()
        let genericOutputs: Set<String> = [
            "finding",
            "findings",
            "signal",
            "signals",
            "memo",
            "proposal",
            "report",
            "summary"
        ]
        guard genericOutputs.contains(lower) == false else { return "" }
        guard lower.hasPrefix("launch ") == false else { return "" }
        guard lower.hasPrefix("pm tasking brief") == false else { return "" }
        guard lower.hasPrefix("objective:") == false else { return "" }
        guard lower.hasPrefix("why now:") == false else { return "" }
        guard lower.hasPrefix("evidence expectation:") == false else { return "" }
        guard lower.hasPrefix("baseline status:") == false else { return "" }
        guard lower.hasPrefix("fresh ") == false || lower.contains("?") else { return "" }
        let instructionMarkers = [
            "fixed analyst runtime",
            "updated analyst runtime",
            "deterministic fallback",
            "public web research by default",
            "direct public web research",
            "source-tier",
            "source tier",
            "label source",
            "question coverage",
            "coverage checklist",
            "coverage required",
            "include coverage",
            "coverage for every question",
            "close with coverage",
            "use reputable secondary sources",
            "prioritize official"
        ]
        guard instructionMarkers.contains(where: { lower.contains($0) }) == false else { return "" }

        if text.count > 260 {
            text = String(text.prefix(257)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
        }
        return text
    }
}
