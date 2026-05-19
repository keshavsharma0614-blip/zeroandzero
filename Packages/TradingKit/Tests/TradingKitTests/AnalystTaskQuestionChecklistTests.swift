import Foundation
import Testing
@testable import TradingKit

@Test("Analyst question checklist preserves META multi-question ask without runtime instructions")
func analystQuestionChecklistPreservesMetaMultiQuestionAsk() {
    let text = """
    Please launch a fresh Technology Analyst task for META using the fixed analyst runtime. Answer explicitly: (1) next earnings report date/time and whether Meta has officially confirmed it; (2) next developer or Meta event/conference dates, including Meta Conversations 2026 and Meta Connect 2026 if announced; (3) credible public expectations or rumors about META 2026 technology/product releases and timing; (4) current/trailing P/E and forward P/E if available, with timestamp/source caveat; (5) latest reported cash/liquidity from filings, including cash, marketable securities, current assets/current liabilities, long-term debt, post-debt-offering pro forma liquidity, restricted cash, operating cash flow/free cash flow, 2026 capex guide, and commitments; (6) whether META is likely to make meaningful technology-platform progress in 2026. Use direct public web research by default unless expressly restricted; do not accept deterministic fallback; close with coverage for every question.
    """

    let questions = AnalystTaskQuestionChecklist.questions(taskDescription: text)

    #expect(questions.count == 6)
    let joined = questions.joined(separator: "\n")
    #expect(joined.contains("next earnings report date/time"))
    #expect(joined.contains("Meta Conversations 2026"))
    #expect(joined.contains("technology/product releases"))
    #expect(joined.contains("forward P/E"))
    #expect(joined.contains("post-debt-offering pro forma liquidity"))
    #expect(joined.contains("technology-platform progress in 2026"))
    #expect(questions.contains(where: { $0.localizedCaseInsensitiveContains("deterministic fallback") }) == false)
    #expect(questions.contains(where: { $0.localizedCaseInsensitiveContains("fixed analyst runtime") }) == false)
}

@Test("Analyst question checklist strips source and coverage instructions from trailing question text")
func analystQuestionChecklistStripsSourceAndCoverageInstructions() {
    let text = """
    Answer explicitly: (1) next earnings report date/time and whether Meta has officially confirmed it; (2) Meta Conversations 2026 date/location/livestream and whether Meta Connect 2026 has been announced; (3) credible public expectations or rumors about 2026 technology/product releases and timing; (4) trailing/current P/E and forward P/E if available with timestamp/source; (5) latest filing liquidity, including cash, marketable securities, current assets/current liabilities, long-term debt, post-debt-offering pro forma liquidity, restricted cash, operating cash flow/free cash flow, 2026 capex guide, and commitments; (6) whether META is likely to make meaningful technology-platform progress in 2026. Public web research is default unless the charter, selected skill, explicit owner instruction, or hard app governance restricts it; include question coverage.
    """

    let questions = AnalystTaskQuestionChecklist.questions(taskDescription: text)

    #expect(questions.count == 6)
    #expect(questions.last == "whether META is likely to make meaningful technology-platform progress in 2026")
    #expect(questions.contains(where: { $0.localizedCaseInsensitiveContains("Public web research") }) == false)
    #expect(questions.contains(where: { $0.localizedCaseInsensitiveContains("question coverage") }) == false)
}
