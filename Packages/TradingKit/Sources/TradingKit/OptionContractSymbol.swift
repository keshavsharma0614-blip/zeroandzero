import Foundation

public struct ParsedOptionContractSymbol: Sendable, Equatable {
    public let underlyingSymbol: String
    public let expirationYYMMDD: String
    public let callPut: String
    public let strikePriceRaw: String

    public init(
        underlyingSymbol: String,
        expirationYYMMDD: String,
        callPut: String,
        strikePriceRaw: String
    ) {
        self.underlyingSymbol = underlyingSymbol
        self.expirationYYMMDD = expirationYYMMDD
        self.callPut = callPut
        self.strikePriceRaw = strikePriceRaw
    }
}

public enum OptionContractSymbol {
    public static func parse(_ raw: String) -> ParsedOptionContractSymbol? {
        let symbol = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let range = NSRange(location: 0, length: symbol.utf16.count)
        guard let match = regex.firstMatch(in: symbol, options: [], range: range),
              match.numberOfRanges == 5,
              let underlyingRange = Range(match.range(at: 1), in: symbol),
              let expirationRange = Range(match.range(at: 2), in: symbol),
              let callPutRange = Range(match.range(at: 3), in: symbol),
              let strikeRange = Range(match.range(at: 4), in: symbol)
        else {
            return nil
        }

        return ParsedOptionContractSymbol(
            underlyingSymbol: String(symbol[underlyingRange]),
            expirationYYMMDD: String(symbol[expirationRange]),
            callPut: String(symbol[callPutRange]),
            strikePriceRaw: String(symbol[strikeRange])
        )
    }

    private static let regex: NSRegularExpression = {
        // OCC format: ROOT(1-6) + YYMMDD + C/P + 8-digit strike.
        try! NSRegularExpression(pattern: "^([A-Z]{1,6})([0-9]{6})([CP])([0-9]{8})$")
    }()
}
