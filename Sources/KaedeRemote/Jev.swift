import Foundation

public enum JevError: Error, Equatable {
    /// 401: the API key was rejected.
    case unauthorized
    /// 422: the request failed validation; `body` says why.
    case invalidRequest(body: String)
    /// 429: over the rate limit. Retry with exponential backoff.
    case rateLimited
    /// 529: Jev is overloaded. Retry with exponential backoff.
    case overloaded
    case http(status: Int, body: String)
    /// The answer named an option that was not offered.
    case unknownChoice(String)
    /// The answer's confidence was not between 0 and 1.
    case unexpectedConfidence(Double)
}

/// Reading Jev (TypeSafe) responses.
public enum JevResponse {
    /// Throws the error for a non-200 status.
    static func checkStatus(of data: Data, status: Int) throws {
        let body = String(decoding: data, as: UTF8.self)
        switch status {
        case 200: return
        case 401: throw JevError.unauthorized
        case 422: throw JevError.invalidRequest(body: body)
        case 429: throw JevError.rateLimited
        case 529: throw JevError.overloaded
        default: throw JevError.http(status: status, body: body)
        }
    }
}

/// The questions Kaede asks Jev, sharing one API key.
public struct Jev: Sendable {
    public let language: JevLanguageRequest
    public let spacing: JevSpacingRequest

    public init(apiKey: String) {
        language = JevLanguageRequest(apiKey: apiKey)
        spacing = JevSpacingRequest(apiKey: apiKey)
    }
}
