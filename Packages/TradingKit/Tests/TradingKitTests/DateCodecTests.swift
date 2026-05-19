import Foundation
import Testing
@testable import TradingKit

@Test("DateCodec parses ISO8601 variants and formats canonical output")
func dateCodecISO8601Variants() {
    let inputs = [
        "2026-03-02T12:34:56Z",
        "2026-03-02T12:34:56.123Z",
        "2026-03-02T12:34:56+00:00",
        "2026-03-02T12:34:56.123+00:00"
    ]

    for input in inputs {
        let parsed = DateCodec.parseISO8601(input)
        #expect(parsed != nil)
    }

    let reference = try! #require(DateCodec.parseISO8601("2026-03-02T12:34:56.123Z"))
    let canonical = DateCodec.formatISO8601(reference)
    #expect(canonical == "2026-03-02T12:34:56.123Z")

    let roundTrip = DateCodec.parseISO8601(canonical)
    #expect(roundTrip == reference)
}

@Test("DateCodec parses common RSS date formats")
func dateCodecRSSFormats() {
    let inputs = [
        "Tue, 02 Jan 2024 15:04:05 +0000",
        "Tue, 02 Jan 2024 15:04:05 GMT",
        "Tue, 2 Jan 2024 15:04:05 +0000",
        "02 Jan 2024 15:04:05 +0000",
        "2024-01-02T15:04:05Z"
    ]

    for input in inputs {
        #expect(DateCodec.parseRSSDate(input) != nil)
    }
}
