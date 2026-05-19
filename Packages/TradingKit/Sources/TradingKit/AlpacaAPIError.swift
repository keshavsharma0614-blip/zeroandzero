import Foundation

public enum AlpacaAPIError: Error, LocalizedError, Sendable {
    case missingCredentials(environment: Environment)
    case localRateLimited(retryAfter: TimeInterval)
    case rateLimited(httpStatus: Int, alpacaMessage: String?, requestID: String?, retryAfter: TimeInterval?)
    case requestFailed(httpStatus: Int, alpacaMessage: String?, requestID: String?)
    case replaceRejected(httpStatus: Int, alpacaMessage: String?, requestID: String?)
    case decodingFailed(httpStatus: Int?, alpacaMessage: String?, requestID: String?)
    case transportFailure(message: String)

    public var httpStatus: Int? {
        switch self {
        case .rateLimited(let httpStatus, _, _, _):
            return httpStatus
        case .requestFailed(let httpStatus, _, _):
            return httpStatus
        case .replaceRejected(let httpStatus, _, _):
            return httpStatus
        case .decodingFailed(let httpStatus, _, _):
            return httpStatus
        default:
            return nil
        }
    }

    public var alpacaMessage: String? {
        switch self {
        case .rateLimited(_, let alpacaMessage, _, _):
            return alpacaMessage
        case .requestFailed(_, let alpacaMessage, _):
            return alpacaMessage
        case .replaceRejected(_, let alpacaMessage, _):
            return alpacaMessage
        case .decodingFailed(_, let alpacaMessage, _):
            return alpacaMessage
        default:
            return nil
        }
    }

    public var requestID: String? {
        switch self {
        case .rateLimited(_, _, let requestID, _):
            return requestID
        case .requestFailed(_, _, let requestID):
            return requestID
        case .replaceRejected(_, _, let requestID):
            return requestID
        case .decodingFailed(_, _, let requestID):
            return requestID
        default:
            return nil
        }
    }

    public var errorDescription: String? {
        switch self {
        case .missingCredentials(let environment):
            return "Missing Alpaca credentials for \(environment.rawValue) environment."
        case .localRateLimited(let retryAfter):
            return String(format: "Alpaca request locally rate limited; retry after %.2fs.", retryAfter)
        case .rateLimited(let httpStatus, let alpacaMessage, let requestID, let retryAfter):
            return Self.httpDescription(
                prefix: "Alpaca rate limited",
                httpStatus: httpStatus,
                alpacaMessage: alpacaMessage,
                requestID: requestID,
                retryAfter: retryAfter
            )
        case .requestFailed(let httpStatus, let alpacaMessage, let requestID):
            return Self.httpDescription(
                prefix: "Alpaca request failed",
                httpStatus: httpStatus,
                alpacaMessage: alpacaMessage,
                requestID: requestID
            )
        case .replaceRejected(let httpStatus, let alpacaMessage, let requestID):
            return Self.httpDescription(
                prefix: "Alpaca replace rejected",
                httpStatus: httpStatus,
                alpacaMessage: alpacaMessage,
                requestID: requestID
            )
        case .decodingFailed(let httpStatus, let alpacaMessage, let requestID):
            return Self.httpDescription(
                prefix: "Alpaca response decoding failed",
                httpStatus: httpStatus,
                alpacaMessage: alpacaMessage,
                requestID: requestID
            )
        case .transportFailure(let message):
            return "Alpaca transport failure: \(message)"
        }
    }

    private static func httpDescription(
        prefix: String,
        httpStatus: Int,
        alpacaMessage: String?,
        requestID: String?,
        retryAfter: TimeInterval? = nil
    ) -> String {
        var parts = ["\(prefix) status=\(httpStatus)"]
        if let alpacaMessage,
           alpacaMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            parts.append("message=\(alpacaMessage)")
        }
        if let requestID,
           requestID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            parts.append("request_id=\(requestID)")
        }
        if let retryAfter {
            parts.append(String(format: "retry_after=%.2fs", retryAfter))
        }
        return parts.joined(separator: " ")
    }

    private static func httpDescription(
        prefix: String,
        httpStatus: Int?,
        alpacaMessage: String?,
        requestID: String?
    ) -> String {
        guard let httpStatus else {
            var parts = [prefix]
            if let alpacaMessage,
               alpacaMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                parts.append("message=\(alpacaMessage)")
            }
            if let requestID,
               requestID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                parts.append("request_id=\(requestID)")
            }
            return parts.joined(separator: " ")
        }
        return httpDescription(
            prefix: prefix,
            httpStatus: httpStatus,
            alpacaMessage: alpacaMessage,
            requestID: requestID
        )
    }
}
