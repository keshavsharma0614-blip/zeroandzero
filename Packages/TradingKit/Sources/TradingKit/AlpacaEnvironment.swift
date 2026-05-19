import Foundation

public extension Environment {
    var tradingRESTBaseURL: URL {
        switch self {
        case .paper:
            return URL(string: "https://paper-api.alpaca.markets")!
        case .live:
            return URL(string: "https://api.alpaca.markets")!
        }
    }

    var marketDataRESTBaseURL: URL {
        URL(string: "https://data.alpaca.markets")!
    }
}
