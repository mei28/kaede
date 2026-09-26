import Foundation
import os

/// Visible in Console.app under the subsystem com.mei28.kaede. Interpolated values are
/// redacted by default, so typed text never reaches the log.
let log = Logger(subsystem: "com.mei28.kaede", category: "kaede")

/// Logs a fixed message and exits with status 1.
func terminate(_ message: String) -> Never {
    log.error("\(message, privacy: .public)")
    FileHandle.standardError.write(Data("kaede: \(message)\n".utf8))
    exit(1)
}
