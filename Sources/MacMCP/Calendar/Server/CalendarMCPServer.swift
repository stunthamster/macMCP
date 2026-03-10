import MCP
import EventKit
import Foundation

final class CalendarMCPServer: @unchecked Sendable {
    private let server: Server
    private let store: CalendarEventKitStore
    private let rateLimiter: RateLimiter

    init() {
        self.server = Server(
            name: "macMCP-calendar",
            version: "0.1.0",
            capabilities: .init(tools: .init(listChanged: false))
        )
        self.store = CalendarEventKitStore()
        self.rateLimiter = RateLimiter()
    }

    func run() async {
        do {
            try await store.requestAccess()
        } catch {
            Self.logError("Failed to get Calendar access: \(error)")
        }

        let transport = StdioTransport()

        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: CalendarToolRegistry.allTools())
        }

        await server.withMethodHandler(CallTool.self) { [self] params in
            try await handleToolCall(params)
        }

        do {
            try await server.start(transport: transport)
            await server.waitUntilCompleted()
        } catch {
            Self.logError("Server error: \(error)")
        }
    }

    private func handleToolCall(_ params: CallTool.Parameters) async throws -> CallTool.Result {
        do {
            switch params.name {
            case "calendar_list_calendars":
                return try await handleListCalendars()
            case "calendar_get_events":
                return try await handleGetEvents(params.arguments)
            case "calendar_get_event":
                return try await handleGetEvent(params.arguments)
            case "calendar_search_events":
                return try await handleSearchEvents(params.arguments)
            case "calendar_create_event":
                return try await handleCreateEvent(params.arguments)
            case "calendar_update_event":
                return try await handleUpdateEvent(params.arguments)
            case "calendar_delete_event":
                return try await handleDeleteEvent(params.arguments)
            default:
                return CallTool.Result(
                    content: [.text("Unknown tool: \(params.name)")],
                    isError: true
                )
            }
        } catch let error as InputValidation.ValidationError {
            return CallTool.Result(
                content: [.text("Validation error: \(error.description)")],
                isError: true
            )
        } catch let error as EventKitError {
            return CallTool.Result(
                content: [.text("Error: \(error.description)")],
                isError: true
            )
        } catch let error as RateLimitError {
            return CallTool.Result(
                content: [.text("Error: \(error.description)")],
                isError: true
            )
        }
    }

    // MARK: - Logging

    private static func logError(_ message: String) {
        FileHandle.standardError.write(Data("[macMCP-calendar] \(message)\n".utf8))
    }

    private static func logAudit(_ tool: String, _ fields: [String: String]) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fieldStr = fields.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        FileHandle.standardError.write(Data("[macMCP \(timestamp)] CALENDAR \(tool): \(fieldStr)\n".utf8))
    }

    // MARK: - Read Tools

    private func handleListCalendars() async throws -> CallTool.Result {
        let calendars = await store.fetchCalendars()
        return CallTool.Result(content: [.text(CalendarFormatter.formatCalendars(calendars))])
    }

    private func handleGetEvents(_ args: [String: Value]?) async throws -> CallTool.Result {
        guard let startStr = args?["start_date"]?.stringValue,
              let endStr = args?["end_date"]?.stringValue else {
            return CallTool.Result(
                content: [.text("Error: start_date and end_date are required")],
                isError: true
            )
        }

        let (start, end) = try InputValidation.validateDateRange(startStr: startStr, endStr: endStr)
        let calendarID = try await resolveCalendarID(args)
        let limit = min(args?["limit"]?.intValue ?? 50, 200)

        let events = try await store.fetchEvents(start: start, end: end, calendarID: calendarID, limit: limit)
        return CallTool.Result(content: [.text(CalendarFormatter.formatEvents(events))])
    }

    private func handleGetEvent(_ args: [String: Value]?) async throws -> CallTool.Result {
        guard let eventID = args?["event_id"]?.stringValue else {
            return CallTool.Result(content: [.text("Error: event_id is required")], isError: true)
        }
        try InputValidation.validateCalendarID(eventID, parameter: "event_id")

        let detail = try await store.fetchEventDetail(id: eventID)
        return CallTool.Result(content: [.text(CalendarFormatter.formatEventDetail(detail))])
    }

    private func handleSearchEvents(_ args: [String: Value]?) async throws -> CallTool.Result {
        guard let query = args?["query"]?.stringValue,
              let startStr = args?["start_date"]?.stringValue,
              let endStr = args?["end_date"]?.stringValue else {
            return CallTool.Result(
                content: [.text("Error: query, start_date, and end_date are required")],
                isError: true
            )
        }
        try InputValidation.validateString(query, parameter: "query")
        let (start, end) = try InputValidation.validateDateRange(startStr: startStr, endStr: endStr)

        let calendarID = args?["calendar_id"]?.stringValue
        if let id = calendarID { try InputValidation.validateCalendarID(id, parameter: "calendar_id") }

        let events = try await store.searchEvents(query: query, start: start, end: end, calendarID: calendarID)
        return CallTool.Result(content: [.text(CalendarFormatter.formatEvents(events, context: "Search results for '\(query)'"))])
    }

    // MARK: - Write Tools

    private func handleCreateEvent(_ args: [String: Value]?) async throws -> CallTool.Result {
        guard let title = args?["title"]?.stringValue,
              let startStr = args?["start_date"]?.stringValue else {
            return CallTool.Result(
                content: [.text("Error: title and start_date are required")],
                isError: true
            )
        }
        try InputValidation.validateEventTitle(title)
        try await rateLimiter.checkCreate()

        let isAllDay = args?["is_all_day"]?.boolValue ?? false
        let startDate = try InputValidation.validateAndParseDate(startStr, parameter: "start_date")

        let endDate: Date
        if let endStr = args?["end_date"]?.stringValue {
            endDate = try InputValidation.validateAndParseDate(endStr, parameter: "end_date")
        } else if isAllDay {
            endDate = startDate
        } else {
            endDate = startDate.addingTimeInterval(3600) // default 1 hour
        }

        let calendarID = args?["calendar_id"]?.stringValue
        let calendarName = args?["calendar_name"]?.stringValue
        if let id = calendarID { try InputValidation.validateCalendarID(id, parameter: "calendar_id") }
        if let name = calendarName { try InputValidation.validateString(name, parameter: "calendar_name") }

        var location: String? = nil
        if let loc = args?["location"]?.stringValue {
            try InputValidation.validateString(loc, parameter: "location", maxLength: 500)
            location = loc
        }
        var notes: String? = nil
        if let n = args?["notes"]?.stringValue {
            try InputValidation.validateNotes(n)
            notes = n
        }
        let url = args?["url"]?.stringValue
        let alertMinutes = args?["alert_minutes"]?.intValue

        let availability: EKEventAvailability
        if let avail = args?["availability"]?.stringValue {
            let validated = try InputValidation.validateAvailability(avail)
            availability = parseAvailability(validated)
        } else {
            availability = .busy
        }

        let event = try await store.createEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            calendarID: calendarID,
            calendarName: calendarName,
            location: location,
            notes: notes,
            url: url,
            alertMinutes: alertMinutes,
            availability: availability
        )
        await rateLimiter.recordCreate()

        Self.logAudit("calendar_create_event", [
            "id": event.id,
            "title": String(title.prefix(80)),
            "calendar": event.calendarTitle,
            "start": event.startDate
        ])

        var output = "Created event: \(event.title)\n"
        output += "  ID: \(event.id)\n"
        output += "  Calendar: \(event.calendarTitle)\n"
        if event.isAllDay {
            output += "  All day: \(event.startDate)\n"
        } else {
            output += "  Start: \(event.startDate)\n"
            output += "  End: \(event.endDate)\n"
        }
        if let loc = event.location {
            output += "  Location: \(loc)\n"
        }
        return CallTool.Result(content: [.text(output)])
    }

    private func handleUpdateEvent(_ args: [String: Value]?) async throws -> CallTool.Result {
        guard let eventID = args?["event_id"]?.stringValue else {
            return CallTool.Result(content: [.text("Error: event_id is required")], isError: true)
        }
        try InputValidation.validateCalendarID(eventID, parameter: "event_id")

        var title: String? = nil
        if let t = args?["title"]?.stringValue {
            try InputValidation.validateEventTitle(t)
            title = t
        }
        var notes: String? = nil
        if let n = args?["notes"]?.stringValue {
            try InputValidation.validateNotes(n)
            notes = n
        }
        var startDate: Date? = nil
        if let s = args?["start_date"]?.stringValue {
            startDate = try InputValidation.validateAndParseDate(s, parameter: "start_date")
        }
        var endDate: Date? = nil
        if let e = args?["end_date"]?.stringValue {
            endDate = try InputValidation.validateAndParseDate(e, parameter: "end_date")
        }
        let isAllDay = args?["is_all_day"]?.boolValue
        let location = args?["location"]?.stringValue
        let url = args?["url"]?.stringValue
        let alertMinutes = args?["alert_minutes"]?.intValue

        let calendarID = args?["calendar_id"]?.stringValue
        let calendarName = args?["calendar_name"]?.stringValue
        if let id = calendarID { try InputValidation.validateCalendarID(id, parameter: "calendar_id") }
        if let name = calendarName { try InputValidation.validateString(name, parameter: "calendar_name") }

        let availability: EKEventAvailability?
        if let avail = args?["availability"]?.stringValue {
            let validated = try InputValidation.validateAvailability(avail)
            availability = parseAvailability(validated)
        } else {
            availability = nil
        }

        let spanStr = InputValidation.validateEventSpan(args?["update_span"]?.stringValue)
        let span: EKSpan = spanStr == "future" ? .futureEvents : .thisEvent

        let (event, updatedFields) = try await store.updateEvent(
            id: eventID,
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            location: location,
            notes: notes,
            url: url,
            alertMinutes: alertMinutes,
            calendarID: calendarID,
            calendarName: calendarName,
            availability: availability,
            travelTimeMinutes: nil,
            span: span
        )

        Self.logAudit("calendar_update_event", [
            "id": eventID,
            "fields": updatedFields.joined(separator: ","),
            "span": spanStr
        ])

        return CallTool.Result(content: [.text("Updated '\(event.title)': \(updatedFields.joined(separator: ", "))")])
    }

    private func handleDeleteEvent(_ args: [String: Value]?) async throws -> CallTool.Result {
        guard let eventID = args?["event_id"]?.stringValue else {
            return CallTool.Result(content: [.text("Error: event_id is required")], isError: true)
        }
        try InputValidation.validateCalendarID(eventID, parameter: "event_id")
        try await rateLimiter.checkDelete()

        let spanStr = InputValidation.validateEventSpan(args?["delete_span"]?.stringValue)
        let span: EKSpan = spanStr == "future" ? .futureEvents : .thisEvent

        let (title, calendarTitle) = try await store.deleteEvent(id: eventID, span: span)
        await rateLimiter.recordDelete()

        Self.logAudit("calendar_delete_event", [
            "id": eventID,
            "title": String(title.prefix(40)),
            "calendar": calendarTitle,
            "span": spanStr
        ])

        return CallTool.Result(content: [.text("Deleted event: \(title) (from \(calendarTitle))")])
    }

    // MARK: - Helpers

    private func resolveCalendarID(_ args: [String: Value]?) async throws -> String? {
        if let calendarID = args?["calendar_id"]?.stringValue {
            try InputValidation.validateCalendarID(calendarID, parameter: "calendar_id")
            return calendarID
        }
        if let calendarName = args?["calendar_name"]?.stringValue {
            try InputValidation.validateString(calendarName, parameter: "calendar_name")
            guard let id = await store.resolveCalendarIDByName(calendarName) else {
                throw EventKitError.calendarNotFound(id: calendarName)
            }
            return id
        }
        return nil
    }

    private func parseAvailability(_ value: String) -> EKEventAvailability {
        switch value {
        case "free": return .free
        case "tentative": return .tentative
        case "unavailable": return .unavailable
        default: return .busy
        }
    }
}
