import Foundation

extension InputValidation {
    /// Validate an EventKit calendar or reminder ID (opaque UUID-like string).
    static func validateCalendarID(_ value: String, parameter: String) throws {
        guard value.count >= 1 && value.count <= 200 else {
            throw ValidationError.tooLong(parameter: parameter, maxLength: 200)
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-:/=+"))
        for scalar in value.unicodeScalars {
            guard allowed.contains(scalar) else {
                throw ValidationError.containsControlCharacters(parameter: parameter)
            }
        }
    }

    /// Validate a reminder title.
    static func validateReminderTitle(_ value: String, parameter: String = "title") throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.containsControlCharacters(parameter: parameter)
        }
        try validateString(value, parameter: parameter, maxLength: 1000)
    }

    /// Validate reminder notes — allows newlines but rejects other control characters.
    static func validateNotes(_ value: String, parameter: String = "notes") throws {
        guard value.count <= 10_000 else {
            throw ValidationError.tooLong(parameter: parameter, maxLength: 10_000)
        }
        for scalar in value.unicodeScalars {
            // Allow newline (0x0A) and carriage return (0x0D)
            if scalar.value == 0x0A || scalar.value == 0x0D { continue }
            if scalar.value < 0x20 {
                throw ValidationError.containsControlCharacters(parameter: parameter)
            }
            if scalar.value == 0x7F {
                throw ValidationError.containsControlCharacters(parameter: parameter)
            }
            if scalar.value >= 0x80 && scalar.value <= 0x9F {
                throw ValidationError.containsControlCharacters(parameter: parameter)
            }
        }
    }

    /// Validate an ISO 8601 date string and return the parsed Date.
    static func validateAndParseDate(_ value: String, parameter: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) {
            return date
        }
        // Try date-only (e.g., "2026-03-15")
        let dateOnly = ISO8601DateFormatter()
        dateOnly.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        if let date = dateOnly.date(from: value) {
            return date
        }
        throw ValidationError.containsControlCharacters(parameter: parameter)
    }
}
