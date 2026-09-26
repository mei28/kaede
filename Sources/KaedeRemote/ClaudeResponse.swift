import Foundation

public enum ClaudeError: Error, Equatable {
    /// The API answered with a non-200 status; `body` is its error JSON.
    case http(status: Int, body: String)
    /// Safety classifiers declined the request, even after the server-side fallback.
    case refused
    /// The answer hit max_tokens before the JSON closed.
    case truncated
    /// The response was not the shape the request asked for.
    case malformed(String)
}

/// Reads the sentence out of a Messages API response to a `ClaudeRequest`.
public enum ClaudeResponse {
    public static func text(from data: Data, status: Int) throws -> String {
        guard status == 200 else {
            throw ClaudeError.http(status: status, body: String(decoding: data, as: UTF8.self))
        }
        let message = try JSONDecoder().decode(Message.self, from: data)
        switch message.stopReason {
        case "refusal": throw ClaudeError.refused
        case "max_tokens": throw ClaudeError.truncated
        default: break
        }
        // With output_config.format the answer is the text block; thinking blocks may precede it
        guard let json = message.content.first(where: { $0.type == "text" })?.text else {
            throw ClaudeError.malformed("no text block")
        }
        return try JSONDecoder().decode(Answer.self, from: Data(json.utf8)).text
    }

    private struct Message: Decodable {
        var stopReason: String?
        var content: [Block]

        enum CodingKeys: String, CodingKey {
            case stopReason = "stop_reason"
            case content
        }
    }

    private struct Block: Decodable {
        var type: String
        var text: String?
    }

    private struct Answer: Decodable {
        var text: String
    }
}
