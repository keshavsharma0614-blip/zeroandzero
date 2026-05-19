import SwiftUI
import TradingKit

struct OwnerSurfaceSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.28), lineWidth: 1)
        )
    }
}

struct CommandCenterStrategyBriefSection: View {
    @EnvironmentObject private var appModel: AppModel
    let revisionCandidate: StrategyBriefConversationRevisionCandidatePresentation?

    @State private var editorState = StrategyBriefEditorPresentationState()
    @State private var feedback: String?
    @State private var feedbackIsError = false

    var body: some View {
        OwnerSurfaceSection(title: "Portfolio Strategy Brief") {
            VStack(alignment: .leading, spacing: 10) {
                if let brief = appModel.portfolioStrategyBrief {
                    let updateSourceLabel = brief.updateSource.rawValue.replacingOccurrences(of: "_", with: " ")
                    Text("Last updated by \(brief.updatedBy) via \(updateSourceLabel) on \(brief.updatedAt.formatted(date: .abbreviated, time: .standard))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let revisionSummary = brief.revisionSummary, revisionSummary.isEmpty == false {
                        Text("Latest revision note: \(revisionSummary)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                let effectiveTitle = editorState.briefTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if effectiveTitle.isEmpty == false {
                    Text(effectiveTitle)
                        .font(.headline)
                }

                if let revisionCandidate {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(revisionCandidate.senderLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(revisionCandidate.messageSummary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Button("Open Brief") {
                        editorState.presentFullDocument()
                    }
                    .ownerActionButton(prominent: true)

                    if let revisionCandidate {
                        Button("Use PM Reply As Revision Note") {
                            editorState.revisionSummary = revisionCandidate.revisionSuggestion
                            editorState.presentFullDocument()
                        }
                        .ownerActionButton()
                    }
                }

                if let feedback, feedback.isEmpty == false {
                    Text(feedback)
                        .font(.footnote)
                        .foregroundStyle(feedbackIsError ? .red : .green)
                }
            }
        }
        .task {
            if appModel.portfolioStrategyBrief == nil {
                _ = await appModel.refreshPortfolioStrategyBrief()
            }
            load(from: appModel.portfolioStrategyBrief)
        }
        .onChange(of: appModel.portfolioStrategyBrief?.updatedAt) { _ in
            load(from: appModel.portfolioStrategyBrief)
        }
        .sheet(
            isPresented: Binding(
                get: { editorState.isFullDocumentPresented },
                set: { isPresented in
                    if isPresented {
                        editorState.presentFullDocument()
                    } else {
                        editorState.dismissFullDocument()
                    }
                }
            )
        ) {
            StrategyBriefFullDocumentSheet(
                editorState: $editorState,
                feedback: $feedback,
                feedbackIsError: $feedbackIsError,
                onSave: save,
                onClose: {
                    editorState.dismissFullDocument()
                }
            )
        }
    }

    private func load(from brief: PortfolioStrategyBrief?) {
        editorState = StrategyBriefEditorPresentationState(
            brief: brief,
            isFullDocumentPresented: editorState.isFullDocumentPresented
        )
    }

    private func save() {
        let existing = appModel.portfolioStrategyBrief ?? PortfolioStrategyBrief.default(now: Date())
        let now = Date()
        let trimmedRevisionSummary = editorState.revisionSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let brief = PortfolioStrategyBrief(
            briefId: existing.briefId,
            title: editorState.briefTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            documentBody: editorState.briefBody.trimmingCharacters(in: .whitespacesAndNewlines),
            objectiveSummary: "",
            keyThemes: [],
            currentRiskPosture: "",
            materialDevelopments: [],
            nonMaterialDevelopments: [],
            reviewEscalationPosture: "",
            revisionSummary: trimmedRevisionSummary.isEmpty ? nil : trimmedRevisionSummary,
            sourceCommunicationMessageId: nil,
            updatedBy: "human owner",
            updateSource: .userEdited,
            createdAt: existing.createdAt,
            updatedAt: now
        )

        Task { @MainActor in
            feedback = await appModel.upsertPortfolioStrategyBrief(brief)
            feedbackIsError = feedback != nil
            if feedback == nil {
                feedback = "Saved portfolio strategy brief."
                feedbackIsError = false
                load(from: appModel.portfolioStrategyBrief)
            }
        }
    }

    private func applyConversationRevision() {
        guard let revisionCandidate else {
            feedback = "No recent PM reply is available for a strategy brief revision note."
            feedbackIsError = true
            return
        }

        let effectiveSummary = editorState.revisionSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? revisionCandidate.revisionSuggestion
            : editorState.revisionSummary

        Task { @MainActor in
            feedback = await appModel.revisePortfolioStrategyBriefFromConversation(
                messageId: revisionCandidate.messageId,
                title: editorState.briefTitle,
                documentBody: editorState.briefBody,
                revisionSummary: effectiveSummary
            )
            feedbackIsError = feedback != nil
            if feedback == nil {
                feedback = "Applied the PM revision note to the portfolio strategy brief."
                feedbackIsError = false
                load(from: appModel.portfolioStrategyBrief)
            }
        }
    }

}

struct StrategyBriefEditorPresentationState: Equatable {
    var briefTitle: String
    var briefBody: String
    var revisionSummary: String
    var isFullDocumentPresented: Bool

    init(
        briefTitle: String = "",
        briefBody: String = "",
        revisionSummary: String = "",
        isFullDocumentPresented: Bool = false
    ) {
        self.briefTitle = briefTitle
        self.briefBody = briefBody
        self.revisionSummary = revisionSummary
        self.isFullDocumentPresented = isFullDocumentPresented
    }

    init(brief: PortfolioStrategyBrief?, isFullDocumentPresented: Bool = false) {
        self.init(
            briefTitle: brief?.title ?? "",
            briefBody: brief?.primaryDocumentBody ?? "",
            revisionSummary: brief?.revisionSummary ?? "",
            isFullDocumentPresented: isFullDocumentPresented
        )
    }

    mutating func presentFullDocument() {
        isFullDocumentPresented = true
    }

    mutating func dismissFullDocument() {
        isFullDocumentPresented = false
    }
}

private struct StrategyBriefFullDocumentSheet: View {
    @Binding var editorState: StrategyBriefEditorPresentationState
    @Binding var feedback: String?
    @Binding var feedbackIsError: Bool

    let onSave: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(editorState.briefTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Portfolio Strategy Brief" : editorState.briefTitle)
                .font(.title2.weight(.semibold))
            Text("Full document view for reading and editing multi-page strategy briefs. This uses the same draft as the main Strategy Brief editor.")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField("Brief Title", text: $editorState.briefTitle)
            TextField("Revision Summary", text: $editorState.revisionSummary)

            TextEditor(text: $editorState.briefBody)
                .font(.system(.body, design: .default))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.24), lineWidth: 1)
                )

            if let feedback, feedback.isEmpty == false {
                Text(feedback)
                    .font(.footnote)
                    .foregroundStyle(feedbackIsError ? .red : .green)
            }

            HStack(spacing: 8) {
                Button("Save Owner Edit") {
                    onSave()
                }
                .ownerActionButton(prominent: true)

                Spacer()

                Button("Done") {
                    onClose()
                }
                .ownerActionButton()
            }
        }
        .padding(20)
        .frame(minWidth: 820, minHeight: 720)
    }
}

struct CommandCenterAnalystChartersSection: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var selectedCharterID: String?
    @State private var selectedSkillForAttachmentID = ""
    @State private var editorState = AnalystCharterEditorPresentationState()
    @State private var feedback: String?
    @State private var feedbackIsError = false

    private var visibleCharters: [AnalystCharter] {
        appModel.analystCharters.filter { charter in
            isLegacyDuplicateAnalystCharter(charter) == false && charter.benchRole != nil
        }
    }

    private var selectedCharter: AnalystCharter? {
        if let selectedCharterID,
           let charter = visibleCharters.first(where: { $0.charterId == selectedCharterID }) {
            return charter
        }
        return nil
    }

    private var activeSkills: [AgentSkillRecord] {
        appModel.agentSkills
            .filter { $0.status == .active }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private var skillsByID: [String: AgentSkillRecord] {
        Dictionary(uniqueKeysWithValues: appModel.agentSkills.map { ($0.skillId, $0) })
    }

    private var availableSkillsForAttachment: [AgentSkillRecord] {
        let attached = Set(editorState.skillReferences.map(\.skillId))
        return activeSkills.filter { attached.contains($0.skillId) == false }
    }

    var body: some View {
        OwnerSurfaceSection(
            title: "Analyst Charters",
            subtitle: "Each standing analyst now has a durable charter document parallel to the Portfolio Strategy Brief. Keep the main view compact, then open the full charter when you need long-form reading or editing."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if visibleCharters.isEmpty {
                    Text("No analyst charters are currently visible.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(makeOwnerFacingStandingAnalystBenchSections(charters: visibleCharters)) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.headline)

                            ForEach(section.charters) { charter in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(charter.title)
                                            .font(.callout.weight(.semibold))
                                        Spacer()
                                        if let benchRole = charter.benchRole {
                                            Text(benchRole.displayTitle)
                                                .font(.caption.weight(.semibold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.blue.opacity(0.12))
                                                .clipShape(Capsule())
                                        }
                                    }

                                    Text(charter.coverageScope)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)

                                    Text(charter.summary)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)

                                    HStack(spacing: 8) {
                                        Text("Family: \(charter.strategyFamily)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Button(selectedCharterID == charter.charterId ? "Viewing Charter" : "View Charter") {
                                            select(charter)
                                        }
                                        .ownerActionButton(prominent: selectedCharterID == charter.charterId)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedCharterID == charter.charterId ? Color.blue.opacity(0.08) : Color.secondary.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedCharterID == charter.charterId ? Color.blue.opacity(0.28) : Color.clear, lineWidth: 1)
                                )
                            }
                        }
                    }
                }

                if let feedback, feedback.isEmpty == false {
                    Text(feedback)
                        .font(.footnote)
                        .foregroundStyle(feedbackIsError ? .red : .green)
                }

                if let selectedCharter {
                    let updateSourceLabel = selectedCharter.updateSource.rawValue.replacingOccurrences(of: "_", with: " ")
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(editorState.charterTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? selectedCharter.title : editorState.charterTitle)
                                    .font(.headline)
                                Text(selectedCharter.coverageScope)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Text("Family: \(selectedCharter.strategyFamily)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Close") {
                                closeSelectedCharter()
                            }
                            .ownerActionButton()
                        }

                        Text("Last updated by \(selectedCharter.updatedBy) via \(updateSourceLabel) on \(selectedCharter.updatedAt.formatted(date: .abbreviated, time: .standard))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let revisionSummary = selectedCharter.revisionSummary,
                           revisionSummary.isEmpty == false {
                            Text("Latest revision note: \(revisionSummary)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        TextField("Charter Title", text: $editorState.charterTitle)
                        TextField("Revision Summary", text: $editorState.revisionSummary)
                        Toggle("Reputable Web Research Allowed", isOn: $editorState.reputableWebResearchAllowed)
                        TextField("Preferred Sources (comma-separated)", text: $editorState.preferredSources)
                        TextField("Restricted Sources (comma-separated)", text: $editorState.restrictedSources)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Attached Agent Skills")
                                .font(.subheadline.weight(.semibold))
                            Text("Selected skills are reusable methodology guidance for this analyst. They do not grant source access, approvals, proposals, execution, or trading authority.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            HStack(alignment: .center, spacing: 8) {
                                Text("\(editorState.skillReferences.count) attached")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.10))
                                    .clipShape(Capsule())
                                Text("\(availableSkillsForAttachment.count) available")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.10))
                                    .clipShape(Capsule())
                                Spacer()
                            }

                            HStack(spacing: 8) {
                                Picker("Attach Skill", selection: $selectedSkillForAttachmentID) {
                                    Text("Select skill").tag("")
                                    ForEach(availableSkillsForAttachment) { skill in
                                        Text(skill.title).tag(skill.skillId)
                                    }
                                }
                                .frame(maxWidth: 360)

                                Button("Attach Skill") {
                                    attachSelectedSkill()
                                }
                                .ownerActionButton(prominent: true)
                                .disabled(selectedSkillForAttachmentID.isEmpty)
                            }

                            if editorState.skillReferences.isEmpty {
                                Text("No skills attached to this charter yet.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach($editorState.skillReferences) { $reference in
                                    HStack(alignment: .top, spacing: 8) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(skillTitle(for: reference.skillId))
                                                .font(.callout.weight(.semibold))
                                            Text(reference.skillId)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            TextField("Optional rationale", text: $reference.rationale)
                                            .textFieldStyle(.roundedBorder)
                                        }
                                        Picker("Requirement", selection: $reference.requirement) {
                                            ForEach(AgentSkillReferenceRequirement.allCases) { requirement in
                                                Text(requirement.displayTitle).tag(requirement)
                                            }
                                        }
                                        .labelsHidden()
                                        .frame(width: 150)

                                        Button("Remove") {
                                            removeSkillReference(skillId: reference.skillId)
                                        }
                                        .ownerActionButton()
                                    }
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.secondary.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }

                        Text("The charter body below is the current durable operating document for this analyst. It remains separate from revision-note metadata and can be opened in a bounded full-document view for multi-page reading or editing.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack(alignment: .center, spacing: 8) {
                            Text("Current Charter Document")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button("Open Full Charter") {
                                editorState.presentFullDocument()
                            }
                            .ownerActionButton()
                        }

                        TextEditor(text: $editorState.charterBody)
                            .font(.system(.body, design: .default))
                            .frame(minHeight: 280, maxHeight: 360)
                            .padding(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.24), lineWidth: 1)
                            )

                        HStack(spacing: 8) {
                            Button("Save Owner Edit") {
                                save()
                            }
                            .ownerActionButton(prominent: true)
                        }
                    }
                }
            }
        }
        .task {
            if appModel.analystCharters.isEmpty {
                _ = await appModel.refreshAnalystCharters()
            }
            if appModel.agentSkills.isEmpty {
                _ = await appModel.refreshAgentSkills()
            }
            synchronizeSelectedCharter()
        }
        .onChange(of: appModel.analystCharters.map { "\($0.charterId)-\($0.updatedAt.timeIntervalSince1970)" }) { _ in
            synchronizeSelectedCharter()
        }
        .onChange(of: appModel.agentSkills.map { "\($0.skillId)-\($0.status.rawValue)-\($0.updatedAt.timeIntervalSince1970)" }) { _ in
            normalizeSelectedSkillForAttachment()
        }
        .sheet(
            isPresented: Binding(
                get: { editorState.isFullDocumentPresented },
                set: { isPresented in
                    if isPresented {
                        editorState.presentFullDocument()
                    } else {
                        editorState.dismissFullDocument()
                    }
                }
            )
        ) {
            AnalystCharterFullDocumentSheet(
                editorState: $editorState,
                feedback: $feedback,
                feedbackIsError: $feedbackIsError,
                onSave: save,
                onClose: {
                    editorState.dismissFullDocument()
                }
            )
        }
    }

    private func select(_ charter: AnalystCharter) {
        selectedCharterID = charter.charterId
        editorState = AnalystCharterEditorPresentationState(
            charter: charter,
            isFullDocumentPresented: editorState.isFullDocumentPresented
        )
        feedback = nil
        feedbackIsError = false
        normalizeSelectedSkillForAttachment()
    }

    private func save() {
        guard let selectedCharter else {
            feedback = "Select a charter before saving."
            feedbackIsError = true
            return
        }
        let trimmedTitle = editorState.charterTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = editorState.charterBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false, trimmedBody.isEmpty == false else {
            feedback = "Charter title and charter body are required."
            feedbackIsError = true
            return
        }

        var charter = selectedCharter
        charter.title = trimmedTitle
        charter.documentBody = trimmedBody
        let trimmedRevisionSummary = editorState.revisionSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        charter.revisionSummary = trimmedRevisionSummary.isEmpty ? nil : trimmedRevisionSummary
        charter.sourcePolicy = AnalystSourcePolicy(
            reputableWebResearchAllowed: editorState.reputableWebResearchAllowed,
            preferredSources: csvValues(editorState.preferredSources),
            restrictedSources: csvValues(editorState.restrictedSources),
            sourceCategories: charter.sourcePolicy.sourceCategories,
            guidanceNotes: charter.sourcePolicy.guidanceNotes
        )
        charter.skillReferences = editorState.makeSkillReferences(updatedBy: "human owner", now: Date())
        charter.updatedBy = "human owner"
        charter.updateSource = .userEdited
        charter.updatedAt = Date()

        Task { @MainActor in
            feedback = await appModel.upsertAnalystCharter(charter)
            feedbackIsError = feedback != nil
            if feedback == nil {
                feedback = "Saved analyst charter."
                feedbackIsError = false
                synchronizeSelectedCharter(preferredID: charter.charterId)
            }
        }
    }

    private func closeSelectedCharter() {
        selectedCharterID = nil
        editorState = AnalystCharterEditorPresentationState(
            charterTitle: "",
            charterBody: "",
            revisionSummary: "",
            reputableWebResearchAllowed: false,
            preferredSources: "",
            restrictedSources: "",
            isFullDocumentPresented: false
        )
        selectedSkillForAttachmentID = ""
        feedback = nil
        feedbackIsError = false
    }

    private func synchronizeSelectedCharter(preferredID: String? = nil) {
        let targetID = preferredID ?? selectedCharterID
        guard visibleCharters.isEmpty == false else {
            editorState = AnalystCharterEditorPresentationState(
                charterTitle: "",
                charterBody: "",
                revisionSummary: "",
                reputableWebResearchAllowed: false,
                preferredSources: "",
                restrictedSources: "",
                isFullDocumentPresented: editorState.isFullDocumentPresented
            )
            return
        }
        guard let targetID,
              let charter = visibleCharters.first(where: { $0.charterId == targetID }) else {
            selectedCharterID = nil
            editorState = AnalystCharterEditorPresentationState(
                charterTitle: "",
                charterBody: "",
                revisionSummary: "",
                reputableWebResearchAllowed: false,
                preferredSources: "",
                restrictedSources: "",
                isFullDocumentPresented: editorState.isFullDocumentPresented
            )
            return
        }

        selectedCharterID = charter.charterId
        editorState = AnalystCharterEditorPresentationState(
            charter: charter,
            isFullDocumentPresented: editorState.isFullDocumentPresented
        )
        normalizeSelectedSkillForAttachment()
    }

    private func attachSelectedSkill() {
        let skillId = selectedSkillForAttachmentID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard skillId.isEmpty == false,
              editorState.skillReferences.contains(where: { $0.skillId == skillId }) == false else {
            normalizeSelectedSkillForAttachment()
            return
        }
        let now = Date()
        editorState.skillReferences.append(
            AgentSkillReferenceEditorState(
                skillId: skillId,
                requirement: .recommended,
                rationale: "",
                createdAt: now,
                updatedAt: now
            )
        )
        normalizeSelectedSkillForAttachment()
    }

    private func removeSkillReference(skillId: String) {
        editorState.skillReferences.removeAll { $0.skillId == skillId }
        normalizeSelectedSkillForAttachment()
    }

    private func normalizeSelectedSkillForAttachment() {
        if selectedSkillForAttachmentID.isEmpty == false,
           availableSkillsForAttachment.contains(where: { $0.skillId == selectedSkillForAttachmentID }) {
            return
        }
        selectedSkillForAttachmentID = availableSkillsForAttachment.first?.skillId ?? ""
    }

    private func skillTitle(for skillId: String) -> String {
        if let skill = skillsByID[skillId] {
            let status = skill.status == .active ? "" : " (\(skill.status.displayTitle))"
            return "\(skill.title)\(status)"
        }
        return "\(skillId) (Missing)"
    }

    private func csvValues(_ text: String) -> [String] {
        text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }
}

struct AnalystCharterEditorPresentationState: Equatable {
    var charterTitle: String
    var charterBody: String
    var revisionSummary: String
    var reputableWebResearchAllowed: Bool
    var preferredSources: String
    var restrictedSources: String
    var skillReferences: [AgentSkillReferenceEditorState]
    var isFullDocumentPresented: Bool

    init(
        charterTitle: String = "",
        charterBody: String = "",
        revisionSummary: String = "",
        reputableWebResearchAllowed: Bool = false,
        preferredSources: String = "",
        restrictedSources: String = "",
        skillReferences: [AgentSkillReferenceEditorState] = [],
        isFullDocumentPresented: Bool = false
    ) {
        self.charterTitle = charterTitle
        self.charterBody = charterBody
        self.revisionSummary = revisionSummary
        self.reputableWebResearchAllowed = reputableWebResearchAllowed
        self.preferredSources = preferredSources
        self.restrictedSources = restrictedSources
        self.skillReferences = skillReferences
        self.isFullDocumentPresented = isFullDocumentPresented
    }

    init(charter: AnalystCharter?, isFullDocumentPresented: Bool = false) {
        self.init(
            charterTitle: charter?.title ?? "",
            charterBody: charter?.primaryDocumentBody ?? "",
            revisionSummary: charter?.revisionSummary ?? "",
            reputableWebResearchAllowed: charter?.sourcePolicy.reputableWebResearchAllowed ?? false,
            preferredSources: charter?.sourcePolicy.preferredSources.joined(separator: ", ") ?? "",
            restrictedSources: charter?.sourcePolicy.restrictedSources.joined(separator: ", ") ?? "",
            skillReferences: (charter?.skillReferences ?? []).map(AgentSkillReferenceEditorState.init(reference:)),
            isFullDocumentPresented: isFullDocumentPresented
        )
    }

    func makeSkillReferences(updatedBy: String, now: Date) -> [AgentSkillReference] {
        var seen = Set<String>()
        return skillReferences.compactMap { reference -> AgentSkillReference? in
            let skillId = reference.skillId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard skillId.isEmpty == false, seen.insert(skillId).inserted else {
                return nil
            }
            let rationale = reference.rationale.trimmingCharacters(in: .whitespacesAndNewlines)
            return AgentSkillReference(
                skillId: skillId,
                requirement: reference.requirement,
                rationale: rationale.isEmpty ? nil : rationale,
                updatedBy: updatedBy,
                createdAt: reference.createdAt,
                updatedAt: now
            )
        }
    }

    mutating func presentFullDocument() {
        isFullDocumentPresented = true
    }

    mutating func dismissFullDocument() {
        isFullDocumentPresented = false
    }
}

struct AgentSkillReferenceEditorState: Equatable, Identifiable {
    var id: String { skillId }

    var skillId: String
    var requirement: AgentSkillReferenceRequirement
    var rationale: String
    var createdAt: Date
    var updatedAt: Date

    init(
        skillId: String,
        requirement: AgentSkillReferenceRequirement,
        rationale: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.skillId = skillId
        self.requirement = requirement
        self.rationale = rationale
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(reference: AgentSkillReference) {
        self.init(
            skillId: reference.skillId,
            requirement: reference.requirement,
            rationale: reference.rationale ?? "",
            createdAt: reference.createdAt,
            updatedAt: reference.updatedAt
        )
    }
}

private struct AnalystCharterFullDocumentSheet: View {
    @Binding var editorState: AnalystCharterEditorPresentationState
    @Binding var feedback: String?
    @Binding var feedbackIsError: Bool

    let onSave: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(editorState.charterTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Analyst Charter" : editorState.charterTitle)
                .font(.title2.weight(.semibold))
            Text("Full document view for reading and editing long-form analyst charters. This uses the same draft as the compact Command Center charter editor.")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField("Charter Title", text: $editorState.charterTitle)
            TextField("Revision Summary", text: $editorState.revisionSummary)
            Toggle("Reputable Web Research Allowed", isOn: $editorState.reputableWebResearchAllowed)
            TextField("Preferred Sources (comma-separated)", text: $editorState.preferredSources)
            TextField("Restricted Sources (comma-separated)", text: $editorState.restrictedSources)

            TextEditor(text: $editorState.charterBody)
                .font(.system(.body, design: .default))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.24), lineWidth: 1)
                )

            if let feedback, feedback.isEmpty == false {
                Text(feedback)
                    .font(.footnote)
                    .foregroundStyle(feedbackIsError ? .red : .green)
            }

            HStack(spacing: 8) {
                Button("Save Owner Edit") {
                    onSave()
                }
                .ownerActionButton(prominent: true)

                Spacer()

                Button("Done") {
                    onClose()
                }
                .ownerActionButton()
            }
        }
        .padding(20)
        .frame(minWidth: 820, minHeight: 720)
    }
}

struct CommandCenterAgentSkillsLibrarySection: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var isAgentSkillsLibraryExpanded = false
    @State private var showArchivedSkills = false
    @State private var selectedSkillID: String?
    @State private var editorState = AgentSkillEditorPresentationState()
    @State private var feedback: String?
    @State private var feedbackIsError = false

    private var activeSkills: [AgentSkillRecord] {
        appModel.agentSkills
            .filter { $0.status == .active }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private var archivedSkills: [AgentSkillRecord] {
        appModel.agentSkills
            .filter { $0.status == .archived }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private var selectedSkill: AgentSkillRecord? {
        guard let selectedSkillID else {
            return nil
        }
        return appModel.agentSkills.first(where: { $0.skillId == selectedSkillID })
    }

    private var mostRecentlyUpdatedSkill: AgentSkillRecord? {
        appModel.agentSkills.max { lhs, rhs in
            lhs.updatedAt < rhs.updatedAt
        }
    }

    var body: some View {
        OwnerSurfaceSection(
            title: "Agent Skills Library",
            subtitle: "Reusable owner-editable methods for future analyst and PM tasking. Skills are methodology guidance only; they do not grant source access, approvals, or execution authority."
        ) {
            DisclosureGroup(isExpanded: $isAgentSkillsLibraryExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Button("Add Skill") {
                            addNewSkill()
                        }
                        .ownerActionButton(prominent: true)

                        Button("Refresh Skills") {
                            Task { @MainActor in
                                feedback = await appModel.refreshAgentSkills()
                                feedbackIsError = feedback != nil
                                if feedback == nil {
                                    feedback = "Refreshed Agent Skills Library."
                                }
                            }
                        }
                        .ownerActionButton()

                        Spacer()

                        if archivedSkills.isEmpty == false {
                            Toggle("Show archived", isOn: $showArchivedSkills)
                                .toggleStyle(.checkbox)
                                .font(.footnote)
                        }
                    }

                    skillsList(title: "Active Skills", skills: activeSkills, emptyText: "No active skills are currently available.")

                    if showArchivedSkills {
                        skillsList(title: "Archived Skills", skills: archivedSkills, emptyText: "No archived skills.")
                    }

                    if let feedback, feedback.isEmpty == false {
                        Text(feedback)
                            .font(.footnote)
                            .foregroundStyle(feedbackIsError ? .red : .green)
                    }
                }
                .padding(.top, 8)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text("Library Summary")
                            .font(.headline)
                        Text("\(activeSkills.count) active")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.12))
                            .clipShape(Capsule())
                        if archivedSkills.isEmpty == false {
                            Text("\(archivedSkills.count) archived")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    if let mostRecentlyUpdatedSkill {
                        Text("Recently updated: \(mostRecentlyUpdatedSkill.title) on \(mostRecentlyUpdatedSkill.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Seeded skills will appear here after the app-owned store initializes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task {
            if appModel.agentSkills.isEmpty {
                _ = await appModel.refreshAgentSkills()
            }
            synchronizeSelectedSkill()
        }
        .onChange(of: appModel.agentSkills.map { "\($0.skillId)-\($0.status.rawValue)-\($0.updatedAt.timeIntervalSince1970)" }) { _ in
            synchronizeSelectedSkill()
        }
        .sheet(
            isPresented: Binding(
                get: { editorState.isPresented },
                set: { isPresented in
                    if isPresented {
                        editorState.isPresented = true
                    } else {
                        editorState.dismiss()
                    }
                }
            )
        ) {
            AgentSkillEditorSheet(
                editorState: $editorState,
                feedback: $feedback,
                feedbackIsError: $feedbackIsError,
                onSave: save,
                onClose: {
                    editorState.dismiss()
                }
            )
        }
    }

    private func skillsList(title: String, skills: [AgentSkillRecord], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            if skills.isEmpty {
                Text(emptyText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(skills) { skill in
                    skillRow(skill)
                }
            }
        }
    }

    private func skillRow(_ skill: AgentSkillRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(skill.title)
                    .font(.callout.weight(.semibold))
                Spacer()
                Text(skill.category.displayTitle)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Capsule())
                Text(skill.status.displayTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(skill.status == .active ? .green : .secondary)
            }

            Text(skill.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if skill.tags.isEmpty == false {
                Text("Tags: \(skill.tags.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Button("Open Skill") {
                    select(skill)
                }
                .ownerActionButton(prominent: selectedSkillID == skill.skillId)

                if skill.status == .active {
                    Button("Archive") {
                        archive(skill)
                    }
                    .ownerActionButton()
                }

                Spacer()

                Text("Updated \(skill.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(selectedSkillID == skill.skillId ? Color.blue.opacity(0.08) : Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(selectedSkillID == skill.skillId ? Color.blue.opacity(0.28) : Color.clear, lineWidth: 1)
        )
    }

    private func select(_ skill: AgentSkillRecord) {
        selectedSkillID = skill.skillId
        editorState = AgentSkillEditorPresentationState(skill: skill, isPresented: true)
        feedback = nil
        feedbackIsError = false
    }

    private func addNewSkill() {
        let now = Date()
        let skill = AgentSkillRecord(
            skillId: "skill-custom-\(UUID().uuidString.lowercased())",
            title: "New Agent Skill",
            summary: "",
            documentBody: "# New Agent Skill\n\n## Purpose\n\n\n## Method\n\n\n## Boundaries\n\nThis skill is methodology guidance only. It does not authorize trades, grant source access, or bypass app governance.",
            category: .custom,
            tags: [],
            status: .active,
            updatedBy: "human owner",
            updateSource: .ownerUI,
            createdAt: now,
            updatedAt: now
        )
        selectedSkillID = skill.skillId
        editorState = AgentSkillEditorPresentationState(skill: skill, isPresented: true)
        feedback = nil
        feedbackIsError = false
    }

    private func save() {
        let trimmedTitle = editorState.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSummary = editorState.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDocumentBody = editorState.documentBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false, trimmedDocumentBody.isEmpty == false else {
            feedback = "Skill title and document body are required."
            feedbackIsError = true
            return
        }

        let now = Date()
        let base = selectedSkill ?? AgentSkillRecord(
            skillId: editorState.skillId,
            title: trimmedTitle,
            summary: trimmedSummary,
            documentBody: trimmedDocumentBody,
            category: editorState.category,
            tags: csvValues(editorState.tags),
            status: editorState.status,
            updatedBy: "human owner",
            updateSource: .ownerUI,
            createdAt: now,
            updatedAt: now
        )

        let revisionSummary = editorState.revisionSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let skill = base.ownerEdited(
            title: trimmedTitle,
            summary: trimmedSummary,
            documentBody: trimmedDocumentBody,
            category: editorState.category,
            tags: csvValues(editorState.tags),
            status: editorState.status,
            revisionSummary: revisionSummary.isEmpty ? nil : revisionSummary,
            updatedBy: "human owner",
            now: now
        )

        Task { @MainActor in
            feedback = await appModel.upsertAgentSkill(skill)
            feedbackIsError = feedback != nil
            if feedback == nil {
                feedback = "Saved agent skill."
                feedbackIsError = false
                selectedSkillID = skill.skillId
                synchronizeSelectedSkill(preferredID: skill.skillId)
                editorState.dismiss()
            }
        }
    }

    private func archive(_ skill: AgentSkillRecord) {
        Task { @MainActor in
            feedback = await appModel.archiveAgentSkill(skillId: skill.skillId)
            feedbackIsError = feedback != nil
            if feedback == nil {
                feedback = "Archived \(skill.title)."
                feedbackIsError = false
                synchronizeSelectedSkill()
            }
        }
    }

    private func synchronizeSelectedSkill(preferredID: String? = nil) {
        let targetID = preferredID ?? selectedSkillID
        guard let targetID,
              let skill = appModel.agentSkills.first(where: { $0.skillId == targetID }) else {
            selectedSkillID = nil
            return
        }
        selectedSkillID = skill.skillId
        if editorState.isPresented {
            editorState = AgentSkillEditorPresentationState(skill: skill, isPresented: true)
        }
    }

    private func csvValues(_ text: String) -> [String] {
        text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }
}

struct AgentSkillEditorPresentationState: Equatable {
    var skillId: String
    var title: String
    var summary: String
    var category: AgentSkillCategory
    var tags: String
    var documentBody: String
    var status: AgentSkillStatus
    var revisionSummary: String
    var isPresented: Bool

    init(
        skillId: String = "",
        title: String = "",
        summary: String = "",
        category: AgentSkillCategory = .custom,
        tags: String = "",
        documentBody: String = "",
        status: AgentSkillStatus = .active,
        revisionSummary: String = "",
        isPresented: Bool = false
    ) {
        self.skillId = skillId
        self.title = title
        self.summary = summary
        self.category = category
        self.tags = tags
        self.documentBody = documentBody
        self.status = status
        self.revisionSummary = revisionSummary
        self.isPresented = isPresented
    }

    init(skill: AgentSkillRecord?, isPresented: Bool = false) {
        self.init(
            skillId: skill?.skillId ?? "",
            title: skill?.title ?? "",
            summary: skill?.summary ?? "",
            category: skill?.category ?? .custom,
            tags: skill?.tags.joined(separator: ", ") ?? "",
            documentBody: skill?.documentBody ?? "",
            status: skill?.status ?? .active,
            revisionSummary: skill?.revisionSummary ?? "",
            isPresented: isPresented
        )
    }

    mutating func dismiss() {
        isPresented = false
    }
}

private struct AgentSkillEditorSheet: View {
    @Binding var editorState: AgentSkillEditorPresentationState
    @Binding var feedback: String?
    @Binding var feedbackIsError: Bool

    let onSave: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(editorState.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Agent Skill" : editorState.title)
                .font(.title2.weight(.semibold))
            Text("Skills are reusable methodology documents. They stay subordinate to app governance, source policy, Analyst Charters, PM mandate, approval gates, Live arming, kill switch, and LocalAuthentication protections.")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField("Skill Title", text: $editorState.title)
            TextField("Summary", text: $editorState.summary)
            Picker("Category", selection: $editorState.category) {
                ForEach(AgentSkillCategory.allCases) { category in
                    Text(category.displayTitle).tag(category)
                }
            }
            Picker("Status", selection: $editorState.status) {
                ForEach(AgentSkillStatus.allCases) { status in
                    Text(status.displayTitle).tag(status)
                }
            }
            TextField("Tags (comma-separated)", text: $editorState.tags)
            TextField("Revision Summary", text: $editorState.revisionSummary)

            TextEditor(text: $editorState.documentBody)
                .font(.system(.body, design: .default))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.24), lineWidth: 1)
                )

            if let feedback, feedback.isEmpty == false {
                Text(feedback)
                    .font(.footnote)
                    .foregroundStyle(feedbackIsError ? .red : .green)
            }

            HStack(spacing: 8) {
                Button("Save Skill") {
                    onSave()
                }
                .ownerActionButton(prominent: true)

                Spacer()

                Button("Cancel") {
                    onClose()
                }
                .ownerActionButton()
            }
        }
        .padding(20)
        .frame(minWidth: 820, minHeight: 720)
    }
}

struct CommandCenterAnalystStandingSchedulesSection: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var selectedCharterID: String?
    @State private var editorState = AnalystStandingScheduleEditorState()
    @State private var feedback: String?
    @State private var feedbackIsError = false

    private var presentations: [StandingAnalystReportSchedulePresentation] {
        makeStandingAnalystReportSchedulePresentations(
            charters: appModel.analystCharters,
            schedules: appModel.schedules
        )
    }

    private var selectedPresentation: StandingAnalystReportSchedulePresentation? {
        if let selectedCharterID,
           let presentation = presentations.first(where: { $0.charterId == selectedCharterID }) {
            return presentation
        }
        return nil
    }

    private var groupedPresentations: [(title: String, items: [StandingAnalystReportSchedulePresentation])] {
        let sector = presentations.filter { $0.benchRole == .sector }
        let overlay = presentations.filter { $0.benchRole == .overlay }
        var groups: [(title: String, items: [StandingAnalystReportSchedulePresentation])] = []
        if sector.isEmpty == false {
            groups.append(("Standing Bench — Sector Analysts", sector))
        }
        if overlay.isEmpty == false {
            groups.append(("Standing Bench — Overlay Analysts", overlay))
        }
        return groups
    }

    var body: some View {
        OwnerSurfaceSection(
            title: "Standing Analyst Reporting",
            subtitle: "Each standing analyst has a durable recurring report cadence. Weekly is the default, the schedule remains app-owned control-plane truth, and standing reports stay distinct from ad hoc PM tasking."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                schedulesList

                if let feedback, feedback.isEmpty == false {
                    Text(feedback)
                        .font(.footnote)
                        .foregroundStyle(feedbackIsError ? .red : .green)
                }

                selectedScheduleEditor
            }
        }
        .task {
            if appModel.analystCharters.isEmpty {
                _ = await appModel.refreshAnalystCharters()
            }
            if appModel.schedules.isEmpty {
                _ = await appModel.refreshSchedules()
            }
            synchronizeSelectedPresentation()
        }
        .onChange(of: appModel.schedules.map { "\($0.scheduleId)-\($0.intervalSec)-\($0.enabled)" }) { _ in
            synchronizeSelectedPresentation()
        }
        .onChange(of: appModel.analystCharters.map { "\($0.charterId)-\($0.updatedAt.timeIntervalSince1970)" }) { _ in
            synchronizeSelectedPresentation()
        }
    }

    @ViewBuilder
    private var schedulesList: some View {
        if presentations.isEmpty {
            Text("No standing analyst schedules are currently visible.")
                .foregroundStyle(.secondary)
        } else {
            ForEach(groupedPresentations, id: \.title) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.headline)

                    ForEach(section.items) { presentation in
                        scheduleRow(for: presentation)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var selectedScheduleEditor: some View {
        if let selectedPresentation {
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedPresentation.analystTitle)
                            .font(.headline)
                        Text(selectedPresentation.coverageScope)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Close") {
                        closeSelectedPresentation()
                    }
                    .ownerActionButton()
                }
                Text("Standing recurring reporting remains separate from ad hoc analyst tasks. Completed standing reports route into PM Inbox as distinct standing-report artifacts.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Toggle("Standing reporting enabled", isOn: $editorState.enabled)
                HStack(spacing: 10) {
                    Text("Cadence")
                        .font(.subheadline.weight(.semibold))
                    TextField("Interval", value: $editorState.intervalValue, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Picker("Unit", selection: $editorState.intervalUnit) {
                        ForEach(StandingAnalystReportIntervalUnit.allCases) { unit in
                            Text(unit.displayTitle).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                scheduleStatusGrid(for: selectedPresentation)

                HStack(spacing: 8) {
                    Button("Save Schedule") {
                        save()
                    }
                    .ownerActionButton(prominent: true)

                    Button("Run Now") {
                        runNow()
                    }
                    .ownerActionButton()
                    .disabled(selectedPresentation.scheduleId == nil)
                }
            }
        }
    }

    private func scheduleRow(
        for presentation: StandingAnalystReportSchedulePresentation
    ) -> some View {
        let isSelected = selectedCharterID == presentation.charterId
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(presentation.analystTitle)
                    .font(.callout.weight(.semibold))
                Spacer()
                Text(presentation.enabled ? "Enabled" : "Disabled")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((presentation.enabled ? Color.green : Color.secondary).opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(presentation.coverageScope)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack(spacing: 8) {
                Text("Cadence: \(standingAnalystReportCadenceSummary(intervalSec: presentation.intervalSec))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(isSelected ? "Configuring" : "Configure") {
                    select(presentation)
                }
                .ownerActionButton(prominent: isSelected)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.teal.opacity(0.08) : Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.teal.opacity(0.28) : Color.clear, lineWidth: 1)
        )
    }

    private func scheduleStatusGrid(
        for presentation: StandingAnalystReportSchedulePresentation
    ) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            GridRow {
                Text("Current cadence")
                    .foregroundStyle(.secondary)
                Text(editorState.cadenceSummary)
            }
            GridRow {
                Text("Next run")
                    .foregroundStyle(.secondary)
                Text(presentation.nextRunAt?.formatted(date: .abbreviated, time: .shortened) ?? "Scheduler will compute after save or restart")
            }
            GridRow {
                Text("Last run")
                    .foregroundStyle(.secondary)
                Text(presentation.lastRunAt?.formatted(date: .abbreviated, time: .shortened) ?? "Not yet run")
            }
            if let lastRunSummary = presentation.lastRunSummary,
               lastRunSummary.isEmpty == false {
                GridRow {
                    Text("Last summary")
                        .foregroundStyle(.secondary)
                    Text(lastRunSummary)
                }
            }
        }
        .font(.caption)
    }

    private func select(_ presentation: StandingAnalystReportSchedulePresentation) {
        selectedCharterID = presentation.charterId
        editorState = AnalystStandingScheduleEditorState(presentation: presentation)
        feedback = nil
        feedbackIsError = false
    }

    private func save() {
        guard let selectedPresentation,
              let scheduleID = selectedPresentation.scheduleId,
              let summary = appModel.schedules.first(where: { $0.scheduleId == scheduleID }) else {
            feedback = "Standing schedule data is still loading. Try again in a moment."
            feedbackIsError = true
            return
        }

        let intervalSec = editorState.intervalSec
        let schedule = ScheduledJob(
            scheduleId: summary.scheduleId,
            jobType: .standingAnalystReport,
            enabled: editorState.enabled,
            trigger: ScheduledJobTrigger(intervalSec: intervalSec),
            policy: ScheduledJobPolicy(
                runMode: summary.runMode,
                restartOnAppLaunch: summary.restartOnAppLaunch,
                maxRuntimeSec: summary.maxRuntimeSec,
                allowOverlap: summary.allowOverlap,
                startupBehavior: summary.startupBehavior
            ),
            params: summary.params
        )

        Task { @MainActor in
            feedback = await appModel.upsertSchedule(schedule)
            feedbackIsError = feedback != nil
            if feedback == nil {
                feedback = "Saved standing report schedule."
                feedbackIsError = false
                synchronizeSelectedPresentation(preferredCharterID: selectedPresentation.charterId)
            }
        }
    }

    private func runNow() {
        guard let selectedPresentation,
              let scheduleID = selectedPresentation.scheduleId else {
            feedback = "Save or load the standing schedule before running it now."
            feedbackIsError = true
            return
        }

        Task { @MainActor in
            let outcome = await appModel.runScheduleNow(id: scheduleID)
            let scheduleError = await appModel.refreshSchedules()
            let reportError = await appModel.refreshAnalystStandingReports()
            feedback = outcome.error ?? scheduleError ?? reportError
            feedbackIsError = feedback != nil
            synchronizeSelectedPresentation(preferredCharterID: selectedPresentation.charterId)

            guard feedback == nil else { return }
            if let summary = outcome.summary,
               let runningJobID = summary.runningJobId,
               runningJobID.isEmpty == false {
                feedback = "Standing report Run Now dispatched ✅ job \(String(runningJobID.prefix(8)))"
                feedbackIsError = false
            } else if let summary = outcome.summary,
                      let lastRunSummary = summary.lastRunSummary,
                      lastRunSummary.isEmpty == false {
                feedback = "Standing report Run Now: \(lastRunSummary)"
                feedbackIsError = summary.lastRunStatus == .failed || summary.lastRunStatus == .canceled
            } else {
                feedback = "Standing report Run Now dispatched."
                feedbackIsError = false
            }
        }
    }

    private func closeSelectedPresentation() {
        selectedCharterID = nil
        editorState = AnalystStandingScheduleEditorState()
        feedback = nil
        feedbackIsError = false
    }

    private func synchronizeSelectedPresentation(preferredCharterID: String? = nil) {
        let targetID = preferredCharterID ?? selectedCharterID
        guard presentations.isEmpty == false else {
            editorState = AnalystStandingScheduleEditorState()
            return
        }
        guard let targetID,
              let presentation = presentations.first(where: { $0.charterId == targetID }) else {
            selectedCharterID = nil
            editorState = AnalystStandingScheduleEditorState()
            return
        }
        selectedCharterID = presentation.charterId
        editorState = AnalystStandingScheduleEditorState(presentation: presentation)
    }
}

enum StandingAnalystReportIntervalUnit: String, CaseIterable, Identifiable {
    case hours
    case days
    case weeks

    var id: String { rawValue }

    var secondsMultiplier: Int {
        switch self {
        case .hours:
            return 3_600
        case .days:
            return 86_400
        case .weeks:
            return standingAnalystReportDefaultIntervalSec
        }
    }

    var displayTitle: String {
        switch self {
        case .hours:
            return "Hours"
        case .days:
            return "Days"
        case .weeks:
            return "Weeks"
        }
    }
}

struct AnalystStandingScheduleEditorState: Equatable {
    var enabled: Bool
    var intervalValue: Int
    var intervalUnit: StandingAnalystReportIntervalUnit

    init(
        enabled: Bool = true,
        intervalValue: Int = 1,
        intervalUnit: StandingAnalystReportIntervalUnit = .weeks
    ) {
        self.enabled = enabled
        self.intervalValue = max(1, intervalValue)
        self.intervalUnit = intervalUnit
    }

    init(presentation: StandingAnalystReportSchedulePresentation) {
        self.init(
            enabled: presentation.enabled,
            intervalValue: Self.intervalValue(for: presentation.intervalSec).value,
            intervalUnit: Self.intervalValue(for: presentation.intervalSec).unit
        )
    }

    var intervalSec: Int {
        max(1, intervalValue) * intervalUnit.secondsMultiplier
    }

    var cadenceSummary: String {
        standingAnalystReportCadenceSummary(intervalSec: intervalSec)
    }

    private static func intervalValue(for intervalSec: Int) -> (value: Int, unit: StandingAnalystReportIntervalUnit) {
        let normalized = max(1, intervalSec)
        if normalized % standingAnalystReportDefaultIntervalSec == 0 {
            return (max(1, normalized / standingAnalystReportDefaultIntervalSec), .weeks)
        }
        if normalized % 86_400 == 0 {
            return (max(1, normalized / 86_400), .days)
        }
        return (max(1, normalized / 3_600), .hours)
    }
}

struct SystemControlRSSFeedsSection: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var isExpanded = false
    @State private var editingRSSFeedID: String?
    @State private var rssName = ""
    @State private var rssURL = ""
    @State private var rssEnabled = true
    @State private var rssTags = ""
    @State private var feedback: String?

    var body: some View {
        OwnerSurfaceSection(
            title: "RSS Feeds",
            subtitle: "Feed configuration is operational, so it lives in System Control. Polling cadence stays tied to the `rss_poll` schedule in Automation."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text("Enabled: \(appModel.rssFeedSummary.enabledCount)")
                    Text("Disabled: \(appModel.rssFeedSummary.disabledCount)")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                if let lastPollStatus = appModel.rssFeedSummary.lastPollStatus,
                   lastPollStatus.isEmpty == false {
                    Text("Last poll: \(lastPollStatus)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(alignment: .leading, spacing: 12) {
                        if appModel.rssFeeds.isEmpty {
                            Text("No RSS feeds configured.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(appModel.rssFeeds) { feed in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(feed.name)
                                            .font(.headline)
                                        Spacer()
                                        Text(feed.enabled ? "Enabled" : "Disabled")
                                            .font(.caption)
                                            .foregroundStyle(feed.enabled ? .green : .secondary)
                                    }

                                    Text(feed.url)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)

                                    Text(feedSummaryText(feed))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    HStack(spacing: 8) {
                                        Button(feed.enabled ? "Disable" : "Enable") {
                                            Task { @MainActor in
                                                var updated = feed
                                                updated.enabled.toggle()
                                                feedback = await appModel.updateRSSFeed(updated)
                                            }
                                        }
                                        .ownerActionButton()

                                        Button("Edit") {
                                            loadEditor(from: feed)
                                        }
                                        .ownerActionButton()

                                        Button("Remove", role: .destructive) {
                                            Task { @MainActor in
                                                feedback = await appModel.removeRSSFeed(id: feed.id)
                                                if editingRSSFeedID == feed.id {
                                                    resetEditor()
                                                }
                                            }
                                        }
                                        .ownerActionButton()
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.secondary.opacity(0.06))
                                )
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(editingRSSFeedID == nil ? "Add Feed" : "Edit Feed")
                                .font(.headline)
                            TextField("Feed name", text: $rssName)
                            TextField("Feed URL", text: $rssURL)
                            HStack(spacing: 8) {
                                Toggle("Enabled", isOn: $rssEnabled)
                                    .ownerToggleTint(isOn: rssEnabled)
                                    .frame(maxWidth: 120, alignment: .leading)
                                TextField("Tags (comma-separated)", text: $rssTags)
                            }

                            HStack(spacing: 8) {
                                Button(editingRSSFeedID == nil ? "Add Feed" : "Save Feed") {
                                    save()
                                }
                                .ownerActionButton(prominent: true)

                                if editingRSSFeedID != nil {
                                    Button("Cancel Edit") {
                                        resetEditor()
                                    }
                                    .ownerActionButton()
                                }

                                Button("Reload Feeds") {
                                    Task { @MainActor in
                                        feedback = await appModel.refreshRSSFeeds()
                                    }
                                }
                                .ownerActionButton()
                            }
                        }
                    }
                    .padding(.top, 10)
                } label: {
                    Text(isExpanded ? "Hide RSS Feed Controls" : "Show RSS Feed Controls")
                        .font(.callout.weight(.semibold))
                }

                if let feedback, feedback.isEmpty == false {
                    Text(feedback)
                        .font(.footnote)
                        .foregroundStyle(
                            (feedback.hasPrefix("Saved") || feedback.hasPrefix("Added")) ? .green : .red
                        )
                }
            }
        }
        .task {
            if appModel.rssFeeds.isEmpty {
                _ = await appModel.refreshRSSFeeds()
            }
        }
    }

    private func save() {
        let trimmedName = rssName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = rssURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false, trimmedURL.isEmpty == false else {
            feedback = "Feed name and URL are required."
            return
        }

        let tags = rssTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        Task { @MainActor in
            if let editingRSSFeedID {
                let feed = RSSFeed(
                    id: editingRSSFeedID,
                    name: trimmedName,
                    url: trimmedURL,
                    enabled: rssEnabled,
                    pollIntervalSec: existingFeed.pollIntervalSec,
                    tags: tags
                )
                feedback = await appModel.updateRSSFeed(feed)
            } else {
                feedback = await appModel.addRSSFeed(
                    name: trimmedName,
                    url: trimmedURL,
                    pollIntervalSec: 300,
                    enabled: rssEnabled,
                    tags: tags
                )
            }

            if feedback == nil {
                feedback = editingRSSFeedID == nil ? "Added RSS feed." : "Saved RSS feed changes."
                resetEditor()
            }
        }
    }

    private func feedSummaryText(_ feed: RSSFeed) -> String {
        let tagsText = feed.tags.isEmpty ? "-" : feed.tags.joined(separator: ", ")
        return "Tags: \(tagsText)"
    }

    private func loadEditor(from feed: RSSFeed) {
        editingRSSFeedID = feed.id
        rssName = feed.name
        rssURL = feed.url
        rssEnabled = feed.enabled
        rssTags = feed.tags.joined(separator: ", ")
        feedback = nil
    }

    private func resetEditor() {
        editingRSSFeedID = nil
        rssName = ""
        rssURL = ""
        rssEnabled = true
        rssTags = ""
    }

    private var existingFeed: RSSFeed {
        if let editingRSSFeedID,
           let feed = appModel.rssFeeds.first(where: { $0.id == editingRSSFeedID }) {
            return feed
        }

        return RSSFeed(
            name: rssName.isEmpty ? "New Feed" : rssName,
            url: rssURL.isEmpty ? "https://example.com/feed.xml" : rssURL,
            enabled: rssEnabled,
            pollIntervalSec: 300,
            tags: rssTags
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
