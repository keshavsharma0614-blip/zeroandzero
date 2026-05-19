import Foundation
import Testing
@testable import TradingKit

@Test("Analyst finding presentation stays bounded and links to memo and evidence when present")
func analystFindingPresentationIncludesBoundedLinkedResearchContext() {
    let now = Date(timeIntervalSince1970: 1_744_900_000)
    let bundle = AnalystEvidenceBundle(
        bundleId: "bundle-1",
        analystId: "analyst-1",
        refs: [
            AnalystEvidenceRef(
                refId: "ref-1",
                sourceKind: .web,
                sourceIdentifier: "company-release",
                title: "Company release",
                observedAt: now,
                summary: "Management reiterated the rollout timeline."
            )
        ],
        summary: "Primary-source evidence supports the bounded thesis.",
        notes: "Coverage stayed focused on the launch update.",
        createdAt: now,
        updatedAt: now
    )
    let memo = AnalystMemo(
        memoId: "memo-1",
        analystId: "analyst-1",
        findingId: "finding-1",
        evidenceBundleId: "bundle-1",
        title: "Launch update memo",
        executiveSummary: "The launch remains on track.",
        currentView: "Constructive but bounded.",
        evidenceSummary: "Primary sources remain supportive.",
        uncertaintySummary: "Customer demand durability is still uncertain.",
        recommendedNextStep: "Keep this in PM review.",
        confidence: 0.68,
        createdAt: now,
        updatedAt: now
    )
    let finding = AnalystFinding(
        findingId: "finding-1",
        analystId: "analyst-1",
        title: "Launch timeline still credible",
        summary: "The rollout timeline still looks credible.",
        thesis: "Primary-source evidence suggests execution remains on track, though downstream demand evidence is still thin.",
        symbols: ["NVDA", "TSM"],
        tags: ["supply-chain", "timing"],
        status: .open,
        confidence: 0.68,
        timeHorizon: "1-2 quarters",
        evidenceBundleId: "bundle-1",
        createdAt: now,
        updatedAt: now
    )

    let presentation = makeAnalystFindingReadablePresentation(
        finding,
        linkedMemo: memo,
        linkedEvidenceBundle: bundle
    )

    #expect(presentation.title == "Launch timeline still credible")
    #expect(presentation.statusSummary == "Open")
    #expect(presentation.confidenceSummary == "68%")
    #expect(presentation.symbolsSummary == "NVDA, TSM")
    #expect(presentation.tagsSummary == "supply-chain, timing")
    #expect(presentation.linkedMemoSummary == "Memo memo-1")
    #expect(presentation.linkedEvidenceSummary == "Evidence bundle bundle-1 • 1 ref")
    #expect(presentation.boundaryNote.contains("not a PM decision") == true)
}

@Test("Analyst evidence bundle presentation stays compact and truthful")
func analystEvidenceBundlePresentationStaysCompactAndReadable() {
    let now = Date(timeIntervalSince1970: 1_744_900_500)
    let bundle = AnalystEvidenceBundle(
        bundleId: "bundle-2",
        analystId: "analyst-2",
        refs: [
            AnalystEvidenceRef(
                refId: "ref-1",
                sourceKind: .appNews,
                sourceIdentifier: "news-1",
                title: "App news item",
                observedAt: now,
                summary: "The earnings release included margin guidance."
            ),
            AnalystEvidenceRef(
                refId: "ref-2",
                sourceKind: .document,
                sourceIdentifier: "10-Q",
                title: "Quarterly filing",
                observedAt: now.addingTimeInterval(-3_600),
                summary: "The filing confirmed inventory normalization."
            )
        ],
        summary: "Two bounded evidence refs support the current finding.",
        notes: nil,
        createdAt: now,
        updatedAt: now
    )

    let presentation = makeAnalystEvidenceBundleReadablePresentation(bundle)

    #expect(presentation.summary == "Two bounded evidence refs support the current finding.")
    #expect(presentation.coverageSummary == "2 evidence refs")
    #expect(presentation.refs.count == 2)
    #expect(presentation.refs[0].sourceSummary == "App News • news-1")
    #expect(presentation.refs[1].sourceSummary == "Document • 10-Q")
    #expect(presentation.refs[0].observedAtSummary == DateCodec.formatISO8601(now))
    #expect(presentation.boundaryNote.contains("provenance anchors") == true)
}

@Test("Research trust presentation distinguishes app-news-only, corroborating, and materially additive coverage")
func analystResearchTrustPresentationClassifiesCoverageBoundedly() {
    let now = Date(timeIntervalSince1970: 1_744_901_000)
    let memo = AnalystMemo(
        memoId: "memo-coverage",
        analystId: "analyst-1",
        evidenceBundleId: "bundle-coverage",
        title: "Coverage memo",
        executiveSummary: "Coverage remains bounded.",
        currentView: "Use app-owned news first.",
        evidenceSummary: "This memo starts from app-owned news.",
        uncertaintySummary: "Coverage still has limits.",
        recommendedNextStep: "Keep review compact.",
        confidence: 0.61,
        createdAt: now,
        updatedAt: now
    )

    let appNewsOnlyBundle = AnalystEvidenceBundle(
        bundleId: "bundle-news-only",
        analystId: "analyst-1",
        refs: [
            AnalystEvidenceRef(
                refId: "ref-news-1",
                sourceKind: .appNews,
                sourceIdentifier: "news-1",
                title: "App news headline",
                observedAt: now,
                summary: "Baseline event."
            )
        ],
        summary: "App news only.",
        createdAt: now,
        updatedAt: now
    )

    let corroboratingBundle = AnalystEvidenceBundle(
        bundleId: "bundle-corroborating",
        analystId: "analyst-1",
        refs: [
            AnalystEvidenceRef(
                refId: "ref-news-2",
                sourceKind: .appNews,
                sourceIdentifier: "news-2",
                title: "App news headline",
                observedAt: now,
                summary: "Baseline event."
            ),
            AnalystEvidenceRef(
                refId: "ref-web-1",
                sourceKind: .web,
                sourceIdentifier: "preferred-source",
                title: "Primary confirmation",
                observedAt: now,
                summary: "Management reiterated guidance. Supplemental role: This source confirms the app-news baseline with stronger or more primary sourcing and adds only limited extra detail."
            )
        ],
        summary: "App news plus stronger confirmation.",
        createdAt: now,
        updatedAt: now
    )

    let additiveBundle = AnalystEvidenceBundle(
        bundleId: "bundle-additive",
        analystId: "analyst-1",
        refs: [
            AnalystEvidenceRef(
                refId: "ref-news-3",
                sourceKind: .appNews,
                sourceIdentifier: "news-3",
                title: "App news headline",
                observedAt: now,
                summary: "Baseline event."
            ),
            AnalystEvidenceRef(
                refId: "ref-web-2",
                sourceKind: .web,
                sourceIdentifier: "sector-journal",
                title: "Sector journal",
                observedAt: now,
                summary: "Power bottlenecks are extending deployment timelines. Supplemental role: This source adds incremental timing, background, or strategic/risk context beyond the app-news baseline."
            )
        ],
        summary: "App news plus additive context.",
        createdAt: now,
        updatedAt: now
    )

    let appNewsOnlyPresentation = makeAnalystResearchTrustReadablePresentation(
        memo: memo,
        linkedEvidenceBundle: appNewsOnlyBundle
    )
    let corroboratingPresentation = makeAnalystResearchTrustReadablePresentation(
        memo: memo,
        linkedEvidenceBundle: corroboratingBundle
    )
    let additivePresentation = makeAnalystResearchTrustReadablePresentation(
        memo: memo,
        linkedEvidenceBundle: additiveBundle
    )

    #expect(appNewsOnlyPresentation.coverageLabel == "App-News Baseline Only")
    #expect(appNewsOnlyPresentation.outsideResearchLabel == "No supplemental outside research recorded")
    #expect(corroboratingPresentation.coverageLabel == "App News + Corroborating Outside Research")
    #expect(corroboratingPresentation.outsideResearchLabel == "Stronger confirmation")
    #expect(additivePresentation.coverageLabel == "App News + Materially Additive Outside Research")
    #expect(additivePresentation.outsideResearchLabel == "Materially additive context")
}

@Test("Owner research trust summary stays compact and distinguishes corroborating vs materially additive support")
func ownerResearchTrustSummaryDistinguishesCoverageQuality() {
    let now = Date(timeIntervalSince1970: 1_744_901_050)
    let memo = AnalystMemo(
        memoId: "memo-owner-trust",
        analystId: "analyst-1",
        evidenceBundleId: "bundle-owner-trust",
        title: "Owner trust memo",
        executiveSummary: "Keep recommendation bounded.",
        currentView: "Use app news baseline with supplemental context.",
        evidenceSummary: "Supplemental evidence stayed additive.",
        uncertaintySummary: "Some timing uncertainty remains.",
        recommendedNextStep: "Proceed only with owner agreement.",
        confidence: 0.62,
        createdAt: now,
        updatedAt: now
    )
    let corroboratingBundle = AnalystEvidenceBundle(
        bundleId: "bundle-owner-trust-corroborating",
        analystId: "analyst-1",
        refs: [
            AnalystEvidenceRef(
                refId: "ref-news-1",
                sourceKind: .appNews,
                sourceIdentifier: "news-1",
                title: "App news baseline",
                observedAt: now,
                summary: "Baseline event context."
            ),
            AnalystEvidenceRef(
                refId: "ref-web-1",
                sourceKind: .web,
                sourceIdentifier: "issuer-site",
                title: "Issuer update",
                observedAt: now,
                summary: "Supplemental role: This source confirms the app-news baseline with stronger or more primary sourcing and adds only limited extra detail."
            )
        ],
        summary: "Corroborating outside support.",
        createdAt: now,
        updatedAt: now
    )
    let additiveBundle = AnalystEvidenceBundle(
        bundleId: "bundle-owner-trust-additive",
        analystId: "analyst-1",
        refs: [
            AnalystEvidenceRef(
                refId: "ref-news-2",
                sourceKind: .appNews,
                sourceIdentifier: "news-2",
                title: "App news baseline",
                observedAt: now,
                summary: "Baseline event context."
            ),
            AnalystEvidenceRef(
                refId: "ref-web-2",
                sourceKind: .web,
                sourceIdentifier: "industry-pub",
                title: "Industry publication",
                observedAt: now,
                summary: "Supplemental role: This source adds incremental timing, background, or strategic/risk context beyond the app-news baseline."
            )
        ],
        summary: "Materially additive outside support.",
        createdAt: now,
        updatedAt: now
    )

    let corroborating = makeOwnerResearchTrustSummaryPresentation(
        memo: memo,
        linkedEvidenceBundle: corroboratingBundle
    )
    let additive = makeOwnerResearchTrustSummaryPresentation(
        memo: memo,
        linkedEvidenceBundle: additiveBundle
    )

    #expect(corroborating.trustLabel == "Grounding: Outside research corroborated the baseline")
    #expect(corroborating.trustSummary.contains("corroborate or strengthen the baseline") == true)
    #expect(additive.trustLabel == "Grounding: Outside research materially improved the read")
    #expect(additive.trustSummary.contains("materially improved timing, context, or strategic/risk interpretation") == true)
    #expect(corroborating.boundaryNote.contains("PM Inbox") == true)
}

@Test("Research trust presentation surfaces disconfirming outside evidence distinctly")
func analystResearchTrustPresentationSurfacesDisconfirmingEvidence() {
    let now = Date(timeIntervalSince1970: 1_744_901_400)
    let memo = AnalystMemo(
        memoId: "memo-disconfirming",
        analystId: "analyst-1",
        evidenceBundleId: "bundle-disconfirming",
        title: "Disconfirming memo",
        executiveSummary: "A source challenged the baseline read.",
        currentView: "Treat outside evidence as qualifying.",
        evidenceSummary: "Outside evidence qualifies the baseline.",
        uncertaintySummary: "More work is still needed.",
        recommendedNextStep: "Review the contradiction before escalating.",
        confidence: 0.49,
        createdAt: now,
        updatedAt: now
    )
    let bundle = AnalystEvidenceBundle(
        bundleId: "bundle-disconfirming",
        analystId: "analyst-1",
        refs: [
            AnalystEvidenceRef(
                refId: "ref-news-1",
                sourceKind: .appNews,
                sourceIdentifier: "news-1",
                title: "App news baseline",
                observedAt: now,
                summary: "Baseline event."
            ),
            AnalystEvidenceRef(
                refId: "ref-web-1",
                sourceKind: .web,
                sourceIdentifier: "issuer-filing",
                title: "Issuer filing",
                observedAt: now,
                summary: "The filing challenges the earlier interpretation. Supplemental role: This source qualifies or challenges the app-news baseline and should be surfaced as disconfirming evidence rather than repetition."
            )
        ],
        summary: "Disconfirming outside evidence was recorded.",
        createdAt: now,
        updatedAt: now
    )

    let presentation = makeAnalystResearchTrustReadablePresentation(
        memo: memo,
        linkedEvidenceBundle: bundle
    )

    #expect(presentation.coverageLabel == "App News + Materially Additive Outside Research")
    #expect(presentation.outsideResearchLabel == "Disconfirming or qualifying")
    #expect(presentation.outsideResearchSummary?.contains("qualified or challenged") == true)
}

@Test("Research trust presentation surfaces open source gaps without false warnings when none exist")
func analystResearchTrustPresentationSurfacesRelevantSourceConstraintsCompactly() {
    let now = Date(timeIntervalSince1970: 1_744_901_800)
    let memo = AnalystMemo(
        memoId: "memo-gaps",
        analystId: "analyst-1",
        taskId: "task-1",
        title: "Gap memo",
        executiveSummary: "Coverage had one blocked source.",
        currentView: "Keep confidence bounded.",
        evidenceSummary: "App-owned news remained the baseline.",
        uncertaintySummary: "One restricted source could have improved completeness.",
        recommendedNextStep: "Review source-governance follow-up.",
        confidence: 0.57,
        createdAt: now,
        updatedAt: now
    )
    let openSuggestion = AnalystSourceAccessSuggestionRecord(
        suggestionId: "suggestion-open",
        analystId: "analyst-1",
        taskId: "task-1",
        memoId: "memo-gaps",
        requestedSource: "issuer investor relations page",
        requestedDomain: "investor.example.com",
        whyItMatters: "Would improve primary-source confirmation.",
        limitation: .restrictedByPolicy,
        recommendedNextStep: .allowByCharterUpdate,
        createdAt: now,
        updatedAt: now
    )

    let constrainedPresentation = makeAnalystResearchTrustReadablePresentation(
        memo: memo,
        relevantSourceSuggestions: [openSuggestion]
    )
    let unconstrainedPresentation = makeAnalystResearchTrustReadablePresentation(memo: memo)

    #expect(constrainedPresentation.sourceConstraintLabel == "Important sources are still missing or constrained")
    #expect(constrainedPresentation.sourceConstraintSummary?.contains("open source-gap item") == true)
    #expect(constrainedPresentation.sourceConstraintSummary?.contains("investor.example.com") == true)
    #expect(unconstrainedPresentation.sourceConstraintLabel == "No relevant source gaps recorded")
    #expect(unconstrainedPresentation.sourceConstraintSummary == nil)
    #expect(constrainedPresentation.boundaryNote.contains("untrusted evidence only") == true)
}

@Test("Owner research trust summary surfaces source constraints only when relevant")
func ownerResearchTrustSummarySurfacesOnlyRelevantSourceConstraints() {
    let now = Date(timeIntervalSince1970: 1_744_901_820)
    let memo = AnalystMemo(
        memoId: "memo-owner-gaps",
        analystId: "analyst-1",
        taskId: "task-owner-gaps",
        title: "Owner gap memo",
        executiveSummary: "Coverage was bounded.",
        currentView: "App news baseline remains primary.",
        evidenceSummary: "Outside context stayed supplemental.",
        uncertaintySummary: "One source remained blocked.",
        recommendedNextStep: "Review confidence bounds.",
        confidence: 0.55,
        createdAt: now,
        updatedAt: now
    )
    let openSuggestion = AnalystSourceAccessSuggestionRecord(
        suggestionId: "suggestion-owner-open",
        analystId: "analyst-1",
        taskId: "task-owner-gaps",
        memoId: "memo-owner-gaps",
        requestedSource: "issuer filing archive",
        requestedDomain: "filings.example.com",
        whyItMatters: "Would improve source completeness.",
        limitation: .restrictedByPolicy,
        recommendedNextStep: .allowByCharterUpdate,
        status: .open,
        createdAt: now,
        updatedAt: now
    )

    let constrained = makeOwnerResearchTrustSummaryPresentation(
        memo: memo,
        relevantSourceSuggestions: [openSuggestion]
    )
    let unconstrained = makeOwnerResearchTrustSummaryPresentation(memo: memo)

    #expect(constrained.sourceConstraintSummary?.contains("Important sources are still constrained") == true)
    #expect(constrained.sourceConstraintSummary?.contains("restricted") == true)
    #expect(unconstrained.sourceConstraintSummary == nil)
}

@Test("Source truth presentation prefers app-news and materially additive support over generic corroborating web references")
func sourceTruthPresentationPrefersMaterialSupport() {
    let now = Date(timeIntervalSince1970: 1_744_902_200)
    let memo = AnalystMemo(
        memoId: "memo-source-truth",
        analystId: "analyst-1",
        evidenceBundleId: "bundle-source-truth",
        title: "Source truth memo",
        executiveSummary: "The report stayed grounded in current evidence.",
        currentView: "App news stayed primary.",
        evidenceSummary: "App-owned news remained the baseline while one outside source added risk context.",
        uncertaintySummary: "Timing is still bounded.",
        recommendedNextStep: "Keep this in PM monitoring.",
        confidence: 0.6,
        createdAt: now,
        updatedAt: now
    )
    let bundle = AnalystEvidenceBundle(
        bundleId: "bundle-source-truth",
        analystId: "analyst-1",
        refs: [
            AnalystEvidenceRef(
                refId: "news-1",
                sourceKind: .appNews,
                sourceIdentifier: "news-1",
                title: "AI infrastructure capex stayed elevated",
                observedAt: now,
                summary: "Baseline event."
            ),
            AnalystEvidenceRef(
                refId: "web-1",
                sourceKind: .web,
                sourceIdentifier: "stanford-ai-index-report",
                title: "Stanford AI Index Report",
                observedAt: now,
                summary: "Supplemental role: This source mostly repeats the app-news fact pattern, so it should be compacted into corroboration rather than treated as a separate insight.",
                freshnessNote: "charter_preferred_source:stanford_ai_index_report"
            ),
            AnalystEvidenceRef(
                refId: "web-2",
                sourceKind: .web,
                sourceIdentifier: "industry-journal",
                title: "Semiconductor supply-chain journal",
                observedAt: now,
                summary: "Supplemental role: This source adds incremental timing, background, or strategic/risk context beyond the app-news baseline.",
                freshnessNote: "charter_preferred_public_source:industry-journal.example"
            )
        ],
        summary: "Source truth bundle.",
        createdAt: now,
        updatedAt: now
    )

    let presentation = makeAnalystSourceTruthPresentation(
        memo: memo,
        linkedEvidenceBundle: bundle
    )

    #expect(presentation?.primarySources.contains(where: { $0.contains("App-owned recent news") }) == true)
    #expect(presentation?.primarySources.contains(where: { $0.contains("Semiconductor supply-chain journal") }) == true)
    #expect(presentation?.primarySources.contains(where: { $0.contains("Stanford AI Index Report") }) == false)
}

@Test("Source truth presentation makes weak generic outside support explicit when it is all that was recorded")
func sourceTruthPresentationMakesWeakSupportExplicit() {
    let now = Date(timeIntervalSince1970: 1_744_902_260)
    let memo = AnalystMemo(
        memoId: "memo-weak-source-truth",
        analystId: "analyst-1",
        evidenceBundleId: "bundle-weak-source-truth",
        title: "Weak support memo",
        executiveSummary: "Support stayed thin.",
        currentView: "Outside references were generic.",
        evidenceSummary: "Support stayed thin.",
        uncertaintySummary: "Confidence is bounded.",
        recommendedNextStep: "Treat this as monitor-only.",
        confidence: 0.41,
        createdAt: now,
        updatedAt: now
    )
    let bundle = AnalystEvidenceBundle(
        bundleId: "bundle-weak-source-truth",
        analystId: "analyst-1",
        refs: [
            AnalystEvidenceRef(
                refId: "web-1",
                sourceKind: .web,
                sourceIdentifier: "macro-seminar",
                title: "Macro Seminar summaries",
                observedAt: now,
                summary: "Supplemental role: This source mostly repeats the app-news fact pattern, so it should be compacted into corroboration rather than treated as a separate insight.",
                freshnessNote: "charter_preferred_public_source:macro-seminar.example"
            )
        ],
        summary: "Weak support bundle.",
        createdAt: now,
        updatedAt: now
    )

    let presentation = makeAnalystSourceTruthPresentation(
        memo: memo,
        linkedEvidenceBundle: bundle
    )

    #expect(presentation?.primarySources.isEmpty == true)
    #expect(presentation?.weakSupportSummary?.contains("generic corroboration") == true)
    #expect(presentation?.weakSupportSummary?.contains("Macro Seminar summaries") == true)
}
