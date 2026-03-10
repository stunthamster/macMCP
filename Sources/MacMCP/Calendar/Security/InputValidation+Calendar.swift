import Foundation

extension InputValidation {
    /// Validate an event title.
    static func validateEventTitle(_ value: String, parameter: String = "title") throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.containsControlCharacters(parameter: parameter)
        }
        try validateString(value, parameter: parameter, maxLength: 1000)
    }

    /// Validate an availability string.
    static func validateAvailability(_ value: String) throws -> String {
        let valid = ["busy", "free", "tentative", "unavailable"]
        let lower = value.lowercased()
        guard valid.contains(lower) else {
            throw ValidationError.containsControlCharacters(parameter: "availability")
        }
        return lower
    }

    /// Validate an event span parameter (for recurring event operations).
    static func validateEventSpan(_ value: String?) -> String {
        guard let v = value?.lowercased() else { return "this" }
        if ["this", "future", "all"].contains(v) { return v }
        return "this"
    }

    /// Validate a date range and return the parsed dates.
    static func validateDateRange(
        startStr: String, endStr: String, parameter: String = "date_range"
    ) throws -> (start: Date, end: Date) {
        let start = try validateAndParseDate(startStr, parameter: "start_date")
        let end = try validateAndParseDate(endStr, parameter: "end_date")
        guard start < end else {
            throw EventKitError.invalidDateRange
        }
        // Max 90 days
        let maxRange: TimeInterval = 90 * 24 * 60 * 60
        guard end.timeIntervalSince(start) <= maxRange else {
            throw EventKitError.invalidDateRange
        }
        return (start, end)
    }
}
