import Foundation

enum AppleScriptError: Error, CustomStringConvertible {
    case permissionDenied
    case mailNotRunning
    case executionFailed(stderr: String)
    case timeout
    case invalidOutput(raw: String)
    case jsonDecodingFailed(raw: String, underlying: Error)

    var description: String {
        switch self {
        case .permissionDenied:
            return "Automation permission denied. Grant access in System Settings > Privacy & Security > Automation. Allow your terminal app to control Mail.app."
        case .mailNotRunning:
            return "Mail.app is not running and could not be launched."
        case .executionFailed(let stderr):
            return "AppleScript execution failed: \(stderr)"
        case .timeout:
            return "AppleScript execution timed out."
        case .invalidOutput:
            return "AppleScript returned unexpected output."
        case .jsonDecodingFailed(let raw, let underlying):
            return "JSON decode error: \(underlying). Raw prefix: \(raw.prefix(500))"
        }
    }
}
