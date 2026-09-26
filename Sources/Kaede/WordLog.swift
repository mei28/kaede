import Foundation
import KaedeCore

/// Appends settled words to ~/Library/Logs/Kaede/words.jsonl, one JSON object per line.
///
/// Off unless the user runs `just words-log on`: the file holds what they typed. It stays on
/// this Mac; the system log never gets the text.
final class WordLog {
    static let defaultsKey = "logWords"
    let url: URL
    private let handle: FileHandle

    init() {
        let directory = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Logs/Kaede")
        url = directory.appending(path: "words.jsonl")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                FileManager.default.createFile(atPath: url.path(percentEncoded: false), contents: nil)
            }
            handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
        } catch {
            terminate("Could not open the word record at \(url.path(percentEncoded: false)): \(error)")
        }
    }

    func append(_ record: WordRecord) {
        var line: [String: String] = [
            "time": ISO8601DateFormatter().string(from: Date()),
            "typed": record.typed,
            "outcome": record.outcome,
        ]
        line["question"] = record.question
        line["answer"] = record.answer
        do {
            var data = try JSONSerialization.data(withJSONObject: line, options: [.sortedKeys, .withoutEscapingSlashes])
            data.append(0x0A)
            try handle.write(contentsOf: data)
        } catch {
            log.error("Writing the word record failed: \(error)")
        }
    }
}
