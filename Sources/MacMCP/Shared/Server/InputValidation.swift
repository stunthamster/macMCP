import Foundation

enum InputValidation {
    enum ValidationError: Error, CustomStringConvertible {
        case containsControlCharacters(parameter: String)
        case tooLong(parameter: String, maxLength: Int)

        var description: String {
            switch self {
            case .containsControlCharacters(let param):
                return "'\(param)' contains invalid characters (control characters or newlines are not allowed)"
            case .tooLong(let param, let maxLength):
                return "'\(param)' exceeds maximum length of \(maxLength) characters"
            }
        }
    }

    /// Validate a string input, rejecting control characters that could enable AppleScript injection.
    static func validateString(_ value: String, parameter: String, maxLength: Int = 500) throws {
        guard value.count <= maxLength else {
            throw ValidationError.tooLong(parameter: parameter, maxLength: maxLength)
        }
        for scalar in value.unicodeScalars {
            if scalar.value < 0x20 {
                // Reject all C0 control characters (U+0000–U+001F)
                throw ValidationError.containsControlCharacters(parameter: parameter)
            }
            if scalar.value == 0x7F {
                // Reject DEL
                throw ValidationError.containsControlCharacters(parameter: parameter)
            }
            if scalar.value >= 0x80 && scalar.value <= 0x9F {
                // Reject C1 control characters
                throw ValidationError.containsControlCharacters(parameter: parameter)
            }
        }
    }

    /// Escape a string for safe embedding in an AppleScript string literal.
    /// Handles the two AppleScript escape sequences: \\ and \"
    static func escapeForAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Sanitize untrusted text (email subjects, senders, bodies, event titles, etc.)
    /// for safe embedding in MCP tool result output.
    ///
    /// Strips control characters, zero-width characters, and other problematic Unicode
    /// that can break JSON serialization when nested through multiple layers
    /// (MCP JSON-RPC → Claude API → client output).
    static func sanitizeOutputText(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)

        for scalar in text.unicodeScalars {
            let v = scalar.value
            switch v {
            // Allow newline and tab (needed for formatted output)
            case 0x0A, 0x09:
                result.unicodeScalars.append(scalar)
            // Strip all other C0 control characters (U+0000–U+001F)
            case 0x00...0x1F:
                continue
            // Strip DEL
            case 0x7F:
                continue
            // Strip C1 control characters (U+0080–U+009F)
            case 0x80...0x9F:
                continue
            // Replace line/paragraph separators with newline
            case 0x2028, 0x2029:
                result.append("\n")
            // Strip zero-width and invisible formatting characters
            case 0x200B, // zero-width space
                 0x200C, // zero-width non-joiner
                 0x200D, // zero-width joiner
                 0x034F, // combining grapheme joiner
                 0xFEFF, // BOM / zero-width no-break space
                 0xFFFC, // object replacement character
                 0xFFFD: // replacement character
                continue
            default:
                result.unicodeScalars.append(scalar)
            }
        }

        return result
    }
}
