import Foundation
import TradingKit

@main
struct FMPTier1ProbeMain {
    static func main() async {
        let client = FMPPrototypeClient()

        do {
            let summary = try await client.runDefaultValidation()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(summary)
            if let output = String(data: data, encoding: .utf8) {
                print(output)
            } else {
                fputs("Failed to render FMP probe summary.\n", stderr)
                Foundation.exit(1)
            }
        } catch FMPPrototypeError.missingAPIKey {
            fputs("Missing FMP API key in Keychain for service=fmp.api.key account=algo-trading.\n", stderr)
            Foundation.exit(2)
        } catch {
            fputs("FMP Tier 1 probe failed: \(error.localizedDescription)\n", stderr)
            Foundation.exit(1)
        }
    }
}
