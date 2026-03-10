struct CalendarEvent: Sendable {
    let id: String
    let title: String
    let calendarID: String
    let calendarTitle: String
    let startDate: String
    let endDate: String
    let isAllDay: Bool
    let location: String?
    let availability: String
    let isRecurring: Bool
    let hasNotes: Bool
    let hasAttendees: Bool
    let hasAlerts: Bool
}

struct CalendarEventDetail: Sendable {
    let id: String
    let title: String
    let calendarID: String
    let calendarTitle: String
    let startDate: String
    let endDate: String
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let url: String?
    let availability: String
    let isRecurring: Bool
    let recurrenceDescription: String?
    let attendees: [EventAttendee]
    let alerts: [EventAlert]
    let travelTimeMinutes: Int?
    let isReadOnlyCalendar: Bool
    let creationDate: String?
    let lastModifiedDate: String?
    let organizer: String?
    let timeZone: String?
}

struct EventAttendee: Sendable {
    let name: String?
    let email: String?
    let status: String
    let isOrganizer: Bool
}

struct EventAlert: Sendable {
    let minutesBefore: Int
    let description: String
}
