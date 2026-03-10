import Foundation

enum EventKitError: Error, CustomStringConvertible {
    case permissionDenied
    case accessRestricted
    case calendarNotFound(id: String)
    case reminderNotFound(id: String)
    case saveFailed(underlying: Error)
    case deleteFailed(underlying: Error)
    case fetchFailed(underlying: Error)
    case readOnlyList(listName: String)
    case eventNotFound(id: String)
    case readOnlyCalendar(name: String)
    case invalidDateRange

    var description: String {
        switch self {
        case .permissionDenied:
            return "Access denied. Grant access in System Settings > Privacy & Security."
        case .accessRestricted:
            return "Access is restricted on this device."
        case .calendarNotFound:
            return "Calendar or list not found."
        case .reminderNotFound:
            return "Reminder not found."
        case .saveFailed(let underlying):
            return "Failed to save: \(underlying)"
        case .deleteFailed(let underlying):
            return "Failed to delete: \(underlying)"
        case .fetchFailed(let underlying):
            return "Failed to fetch data: \(underlying)"
        case .readOnlyList(let listName):
            return "Cannot modify '\(listName)' — it is a shared or read-only list."
        case .eventNotFound:
            return "Event not found."
        case .readOnlyCalendar(let name):
            return "Cannot modify '\(name)' — it is a read-only or subscribed calendar."
        case .invalidDateRange:
            return "Invalid date range: start_date must be before end_date, and range must not exceed 90 days."
        }
    }
}
