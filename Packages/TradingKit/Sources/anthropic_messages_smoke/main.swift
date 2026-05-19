import Foundation
import TradingKit

@main
struct AnthropicMessagesSmoke {
    static func main() async {
        let provider = LLMProviderKind.anthropic
        let arguments = Array(CommandLine.arguments.dropFirst())
        let liveMode = arguments.contains("--live")
        let checkKeychain = liveMode || arguments.contains("--check-keychain")
        let model = arguments.first(where: { $0.hasPrefix("--") == false }) ?? "claude-sonnet-4-6"
        let checkedAt = ISO8601DateFormatter().string(from: Date())

        do {
            let settings = try LLMProviderSettingsStore().loadOrDefault()
            let profile = settings.profile(id: LLMCredentialProfile.anthropicDefaultProfileID)
                ?? settings.profiles(for: .anthropic).first
                ?? LLMCredentialProfile.defaultAnthropic(now: Date())
            emit("provider=\(provider.rawValue)")
            emit("model=\(model)")
            emit("profile_id=\(profile.profileId)")
            emit("keychain_service=\(profile.keychainService)")
            emit("keychain_account=\(profile.keychainAccount)")
            emit("credential_check_started=\(checkKeychain)")
            guard checkKeychain else {
                emit("credential_status=not_checked")
                emit("checked_at=\(checkedAt)")
                emit("live_call_attempted=false")
                emit("status_category=keychain_check_not_requested")
                return
            }

            let credentialTimeoutSeconds: TimeInterval = 10
            guard let resolution = await resolveCredential(
                profile: profile,
                timeoutSeconds: credentialTimeoutSeconds
            ) else {
                emit("credential_status=check_timeout")
                emit("checked_at=\(checkedAt)")
                emit("live_call_attempted=false")
                emit("status_category=credential_check_timeout")
                emit("credential_check_timeout_seconds=\(Int(credentialTimeoutSeconds))")
                return
            }

            emit("credential_status=\(resolution.status.rawValue)")
            emit("checked_at=\(checkedAt)")

            guard liveMode else {
                emit("live_call_attempted=false")
                emit("status_category=live_flag_not_set")
                return
            }

            guard let apiKey = resolution.apiKey else {
                emit("live_call_attempted=false")
                emit("status_category=missing_or_unavailable_credential")
                return
            }

            let request = PMConversationOpenAISynthesisRequest(
                runtimeIdentifier: model,
                reasoningMode: .standard,
                plannerMode: "owner_conversation_action_planning",
                sessionChannel: "smoke",
                ownerMessageBody: "Reply with one sentence confirming Anthropic Messages API structured output works for PM conversation smoke validation."
            )
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 30
            let httpClient = URLSessionAnthropicMessagesHTTPClient(
                session: URLSession(configuration: configuration)
            )
            let output = try await AnthropicMessagesPMSynthesisProvider(httpClient: httpClient)
                .synthesizeConversationReply(request: request, apiKey: apiKey)
            emit("live_call_attempted=true")
            emit("status_category=accepted")
            emit("structured_output_parse=true")
            emit("runtime_provenance=anthropic_messages[\(model)]")
            emit("first_text_received=\(!output.replyBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)")
        } catch let error as PMOpenAISynthesisError {
            emit("live_call_attempted=true")
            emit("status_category=provider_error")
            emit("structured_output_parse=false")
            emit("error_summary=\(error.boundedSummary)")
        } catch {
            emit("live_call_attempted=true")
            emit("status_category=internal_error")
            emit("structured_output_parse=false")
        }
    }
}

private func emit(_ line: String) {
    FileHandle.standardOutput.write(Data((line + "\n").utf8))
}

private func resolveCredential(
    profile: LLMCredentialProfile,
    timeoutSeconds: TimeInterval
) async -> LLMCredentialResolution? {
    await withCheckedContinuation { continuation in
        let box = CredentialResolutionContinuationBox(continuation)

        DispatchQueue.global(qos: .userInitiated).async {
            let keyReader = SystemKeyReader(authenticationUIPolicy: .failIfPromptRequired)
            let keychainProvider = KeychainCredentialsProvider(keyReader: keyReader)
            let resolver = LLMKeychainCredentialResolver(
                keychainProvider: keychainProvider,
                labelReader: { label, account in
                    SystemKeyReader.readKey(
                        label: label,
                        account: account,
                        authenticationUIPolicy: .failIfPromptRequired
                    )
                }
            )
            let resolution = resolver.resolve(profile: profile)
            box.resume(resolution)
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeoutSeconds) {
            box.resume(nil)
        }
    }
}

private final class CredentialResolutionContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false
    private let continuation: CheckedContinuation<LLMCredentialResolution?, Never>

    init(_ continuation: CheckedContinuation<LLMCredentialResolution?, Never>) {
        self.continuation = continuation
    }

    func resume(_ resolution: LLMCredentialResolution?) {
        lock.lock()
        defer { lock.unlock() }
        guard resumed == false else { return }
        resumed = true
        continuation.resume(returning: resolution)
    }
}
