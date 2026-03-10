@preconcurrency import EventKit
import Foundation

actor CalendarEventKitStore {
    private let store = EKEventStore()
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - Authorization

    func requestAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess, .authorized:
            return
        case .restricted:
            throw EventKitError.accessRestricted
        case .denied:
            throw EventKitError.permissionDenied
        case .notDetermined, .writeOnly:
            let granted = try await store.requestFullAccessToEvents()
            if !granted {
                throw EventKitError.permissionDenied
            }
        @unknown default:
            let granted = try await store.requestFullAccessToEvents()
            if !granted {
                throw EventKitError.permissionDenied
            }
        }
    }

    // MARK: - Calendars

    func resolveCalendarIDByName(_ name: String) -> String? {
        let calendars = store.calendars(for: .event)
        return calendars.first(where: { $0.title.lowercased() == name.lowercased() })?.calendarIdentifier
    }

    func fetchCalendars() -> [CalendarInfo] {
        let calendars = store.calendars(for: .event)
        return calendars.map { cal in
            CalendarInfo(
                id: cal.calendarIdentifier,
                title: cal.title,
                color: cal.cgColor.flatMap { hexColor(from: $0) },
                type: calendarTypeName(cal.type),
                sourceName: cal.source?.title ?? "Unknown",
                isReadOnly: !cal.allowsContentModifications,
                isSubscribed: cal.type == .subscription
            )
        }
    }

    // MARK: - Events

    func fetchEvents(start: Date, end: Date, calendarID: String?, limit: Int) throws -> [CalendarEvent] {
        let calendars: [EKCalendar]?
        if let calendarID = calendarID {
            guard let cal = store.calendar(withIdentifier: calendarID) else {
                throw EventKitError.calendarNotFound(id: calendarID)
            }
            calendars = [cal]
        } else {
            calendars = nil
        }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let events = store.events(matching: predicate)

        return Array(events.prefix(limit)).map { mapEvent($0) }
    }

    func fetchEventDetail(id: String) throws -> CalendarEventDetail {
        guard let event = store.calendarItem(withIdentifier: id) as? EKEvent else {
            throw EventKitError.eventNotFound(id: id)
        }
        return mapEventDetail(event)
    }

    func searchEvents(query: String, start: Date, end: Date, calendarID: String?) throws -> [CalendarEvent] {
        let calendars: [EKCalendar]?
        if let calendarID = calendarID {
            guard let cal = store.calendar(withIdentifier: calendarID) else {
                throw EventKitError.calendarNotFound(id: calendarID)
            }
            calendars = [cal]
        } else {
            calendars = nil
        }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let events = store.events(matching: predicate)
        let queryLower = query.lowercased()

        let matched = events.filter { event in
            let titleMatch = event.title?.lowercased().contains(queryLower) ?? false
            let notesMatch = event.notes?.lowercased().contains(queryLower) ?? false
            let locationMatch = event.location?.lowercased().contains(queryLower) ?? false
            return titleMatch || notesMatch || locationMatch
        }

        return Array(matched.prefix(100)).map { mapEvent($0) }
    }

    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        calendarID: String?,
        calendarName: String?,
        location: String?,
        notes: String?,
        url: String?,
        alertMinutes: Int?,
        availability: EKEventAvailability
    ) throws -> CalendarEvent {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.isAllDay = isAllDay

        // Resolve calendar
        if let calendarID = calendarID {
            guard let cal = store.calendar(withIdentifier: calendarID) else {
                throw EventKitError.calendarNotFound(id: calendarID)
            }
            guard cal.allowsContentModifications else {
                throw EventKitError.readOnlyCalendar(name: cal.title)
            }
            event.calendar = cal
        } else if let calendarName = calendarName {
            let calendars = store.calendars(for: .event)
            guard let cal = calendars.first(where: { $0.title.lowercased() == calendarName.lowercased() }) else {
                throw EventKitError.calendarNotFound(id: calendarName)
            }
            guard cal.allowsContentModifications else {
                throw EventKitError.readOnlyCalendar(name: cal.title)
            }
            event.calendar = cal
        } else {
            event.calendar = store.defaultCalendarForNewEvents
        }

        event.location = location
        event.notes = notes
        event.availability = availability

        if let urlString = url, let url = URL(string: urlString) {
            event.url = url
        }
        if let minutes = alertMinutes {
            event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-minutes * 60)))
        }

        do {
            try store.save(event, span: .thisEvent, commit: true)
        } catch {
            throw EventKitError.saveFailed(underlying: error)
        }

        return mapEvent(event)
    }

    func updateEvent(
        id: String,
        title: String?,
        startDate: Date?,
        endDate: Date?,
        isAllDay: Bool?,
        location: String?,
        notes: String?,
        url: String?,
        alertMinutes: Int?,
        calendarID: String?,
        calendarName: String?,
        availability: EKEventAvailability?,
        travelTimeMinutes: Int?,
        span: EKSpan
    ) throws -> (event: CalendarEvent, updatedFields: [String]) {
        guard let event = store.calendarItem(withIdentifier: id) as? EKEvent else {
            throw EventKitError.eventNotFound(id: id)
        }
        if let cal = event.calendar, !cal.allowsContentModifications {
            throw EventKitError.readOnlyCalendar(name: cal.title)
        }

        var updatedFields: [String] = []

        if let title = title {
            event.title = title
            updatedFields.append("title")
        }
        if let startDate = startDate {
            event.startDate = startDate
            updatedFields.append("start_date")
        }
        if let endDate = endDate {
            event.endDate = endDate
            updatedFields.append("end_date")
        }
        if let isAllDay = isAllDay {
            event.isAllDay = isAllDay
            updatedFields.append("is_all_day")
        }
        if let location = location {
            event.location = location.isEmpty ? nil : location
            updatedFields.append("location")
        }
        if let notes = notes {
            event.notes = notes.isEmpty ? nil : notes
            updatedFields.append("notes")
        }
        if let urlStr = url {
            event.url = urlStr.isEmpty ? nil : URL(string: urlStr)
            updatedFields.append("url")
        }
        if let minutes = alertMinutes {
            event.alarms?.forEach { event.removeAlarm($0) }
            if minutes >= 0 {
                event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-minutes * 60)))
            }
            updatedFields.append("alert")
        }
        if let calendarID = calendarID {
            guard let cal = store.calendar(withIdentifier: calendarID) else {
                throw EventKitError.calendarNotFound(id: calendarID)
            }
            event.calendar = cal
            updatedFields.append("calendar")
        } else if let calendarName = calendarName {
            let calendars = store.calendars(for: .event)
            guard let cal = calendars.first(where: { $0.title.lowercased() == calendarName.lowercased() }) else {
                throw EventKitError.calendarNotFound(id: calendarName)
            }
            event.calendar = cal
            updatedFields.append("calendar")
        }
        if let availability = availability {
            event.availability = availability
            updatedFields.append("availability")
        }
        _ = travelTimeMinutes // travel time not available in public EventKit API

        do {
            try store.save(event, span: span, commit: true)
        } catch {
            throw EventKitError.saveFailed(underlying: error)
        }

        return (event: mapEvent(event), updatedFields: updatedFields)
    }

    func deleteEvent(id: String, span: EKSpan) throws -> (title: String, calendarTitle: String) {
        guard let event = store.calendarItem(withIdentifier: id) as? EKEvent else {
            throw EventKitError.eventNotFound(id: id)
        }
        if let cal = event.calendar, !cal.allowsContentModifications {
            throw EventKitError.readOnlyCalendar(name: cal.title)
        }

        let title = event.title ?? ""
        let calendarTitle = event.calendar?.title ?? ""

        do {
            try store.remove(event, span: span, commit: true)
        } catch {
            throw EventKitError.deleteFailed(underlying: error)
        }

        return (title: title, calendarTitle: calendarTitle)
    }

    // MARK: - Helpers

    private func mapEvent(_ e: EKEvent) -> CalendarEvent {
        CalendarEvent(
            id: e.calendarItemIdentifier,
            title: e.title ?? "",
            calendarID: e.calendar?.calendarIdentifier ?? "",
            calendarTitle: e.calendar?.title ?? "",
            startDate: dateFormatter.string(from: e.startDate),
            endDate: dateFormatter.string(from: e.endDate),
            isAllDay: e.isAllDay,
            location: e.location,
            availability: availabilityName(e.availability),
            isRecurring: e.hasRecurrenceRules,
            hasNotes: e.notes != nil && !(e.notes?.isEmpty ?? true),
            hasAttendees: e.hasAttendees,
            hasAlerts: e.hasAlarms
        )
    }

    private func mapEventDetail(_ e: EKEvent) -> CalendarEventDetail {
        let organizerURL = e.organizer?.url.absoluteString
        let attendees: [EventAttendee] = (e.attendees ?? []).map { a in
            EventAttendee(
                name: a.name,
                email: a.url.absoluteString.replacingOccurrences(of: "mailto:", with: ""),
                status: participantStatusName(a.participantStatus),
                isOrganizer: a.url.absoluteString == organizerURL
            )
        }

        let alerts: [EventAlert] = (e.alarms ?? []).map { alarm in
            let minutes = Int(-alarm.relativeOffset / 60)
            return EventAlert(
                minutesBefore: minutes,
                description: formatAlertDescription(minutes)
            )
        }

        var recurrenceDesc: String? = nil
        if let rule = e.recurrenceRules?.first {
            recurrenceDesc = describeRecurrenceRule(rule)
        }

        return CalendarEventDetail(
            id: e.calendarItemIdentifier,
            title: e.title ?? "",
            calendarID: e.calendar?.calendarIdentifier ?? "",
            calendarTitle: e.calendar?.title ?? "",
            startDate: dateFormatter.string(from: e.startDate),
            endDate: dateFormatter.string(from: e.endDate),
            isAllDay: e.isAllDay,
            location: e.location,
            notes: e.notes,
            url: e.url?.absoluteString,
            availability: availabilityName(e.availability),
            isRecurring: e.hasRecurrenceRules,
            recurrenceDescription: recurrenceDesc,
            attendees: attendees,
            alerts: alerts,
            travelTimeMinutes: nil,
            isReadOnlyCalendar: e.calendar.map { !$0.allowsContentModifications } ?? false,
            creationDate: e.creationDate.map { dateFormatter.string(from: $0) },
            lastModifiedDate: e.lastModifiedDate.map { dateFormatter.string(from: $0) },
            organizer: e.organizer?.name,
            timeZone: e.timeZone?.identifier
        )
    }

    private func availabilityName(_ availability: EKEventAvailability) -> String {
        switch availability {
        case .busy: return "busy"
        case .free: return "free"
        case .tentative: return "tentative"
        case .unavailable: return "unavailable"
        case .notSupported: return "busy"
        @unknown default: return "busy"
        }
    }

    private func participantStatusName(_ status: EKParticipantStatus) -> String {
        switch status {
        case .accepted: return "accepted"
        case .declined: return "declined"
        case .tentative: return "tentative"
        case .pending: return "pending"
        case .delegated: return "delegated"
        case .completed: return "completed"
        case .inProcess: return "in-process"
        case .unknown: return "unknown"
        @unknown default: return "unknown"
        }
    }

    private func calendarTypeName(_ type: EKCalendarType) -> String {
        switch type {
        case .local: return "local"
        case .calDAV: return "calDAV"
        case .exchange: return "exchange"
        case .subscription: return "subscription"
        case .birthday: return "birthday"
        @unknown default: return "unknown"
        }
    }

    private func formatAlertDescription(_ minutes: Int) -> String {
        if minutes == 0 { return "At time of event" }
        if minutes < 60 { return "\(minutes) minutes before" }
        if minutes == 60 { return "1 hour before" }
        if minutes < 1440 {
            let hours = minutes / 60
            let remaining = minutes % 60
            if remaining == 0 { return "\(hours) hours before" }
            return "\(hours)h \(remaining)m before"
        }
        let days = minutes / 1440
        if days == 1 { return "1 day before" }
        return "\(days) days before"
    }

    private func describeRecurrenceRule(_ rule: EKRecurrenceRule) -> String {
        let interval = rule.interval
        let freq: String
        switch rule.frequency {
        case .daily: freq = interval == 1 ? "Daily" : "Every \(interval) days"
        case .weekly:
            let days = rule.daysOfTheWeek?.compactMap { dayName($0.dayOfTheWeek) } ?? []
            if interval == 1 && days.isEmpty { freq = "Weekly" }
            else if interval == 1 { freq = "Weekly on \(days.joined(separator: ", "))" }
            else { freq = "Every \(interval) weeks on \(days.joined(separator: ", "))" }
        case .monthly: freq = interval == 1 ? "Monthly" : "Every \(interval) months"
        case .yearly: freq = interval == 1 ? "Yearly" : "Every \(interval) years"
        @unknown default: freq = "Recurring"
        }

        if let end = rule.recurrenceEnd {
            if let endDate = end.endDate {
                let df = dateFormatter
                return "\(freq), until \(df.string(from: endDate))"
            } else if end.occurrenceCount > 0 {
                return "\(freq), \(end.occurrenceCount) times"
            }
        }
        return freq
    }

    private func dayName(_ day: EKWeekday) -> String {
        switch day {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        @unknown default: return "?"
        }
    }

    private func hexColor(from cgColor: CGColor) -> String? {
        guard let components = cgColor.components, components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
