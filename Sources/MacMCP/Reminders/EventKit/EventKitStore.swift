@preconcurrency import EventKit
import Foundation

actor EventKitStore {
    private let store = EKEventStore()
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - Authorization

    func requestAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .fullAccess, .authorized:
            return
        case .restricted:
            throw EventKitError.accessRestricted
        case .denied:
            throw EventKitError.permissionDenied
        case .notDetermined, .writeOnly:
            let granted = try await store.requestFullAccessToReminders()
            if !granted {
                throw EventKitError.permissionDenied
            }
        @unknown default:
            let granted = try await store.requestFullAccessToReminders()
            if !granted {
                throw EventKitError.permissionDenied
            }
        }
    }

    // MARK: - Lists

    func resolveListIDByName(_ name: String) -> String? {
        let calendars = store.calendars(for: .reminder)
        return calendars.first(where: { $0.title.lowercased() == name.lowercased() })?.calendarIdentifier
    }

    func fetchLists() -> [ReminderList] {
        let calendars = store.calendars(for: .reminder)
        return calendars.map { cal in
            ReminderList(
                id: cal.calendarIdentifier,
                title: cal.title,
                color: cal.cgColor.flatMap { hexColor(from: $0) },
                isShared: isReadOnly(cal),
                reminderCount: 0, // populated below if needed
                incompleteCount: 0
            )
        }
    }

    func fetchListsWithCounts() async throws -> [ReminderList] {
        let calendars = store.calendars(for: .reminder)
        var results: [ReminderList] = []

        for cal in calendars {
            let predicate = store.predicateForReminders(in: [cal])
            let allReminders = try await fetchRemindersRaw(matching: predicate)
            let incomplete = allReminders.filter { !$0.isCompleted }

            results.append(ReminderList(
                id: cal.calendarIdentifier,
                title: cal.title,
                color: cal.cgColor.flatMap { hexColor(from: $0) },
                isShared: isReadOnly(cal),
                reminderCount: allReminders.count,
                incompleteCount: incomplete.count
            ))
        }
        return results
    }

    func createList(name: String) throws -> ReminderList {
        let calendar = EKCalendar(for: .reminder, eventStore: store)
        calendar.title = name

        // Use the default source for reminders
        guard let source = defaultReminderSource() else {
            throw EventKitError.saveFailed(underlying: NSError(domain: "macMCP", code: 1, userInfo: [NSLocalizedDescriptionKey: "No reminder source available"]))
        }
        calendar.source = source

        do {
            try store.saveCalendar(calendar, commit: true)
        } catch {
            throw EventKitError.saveFailed(underlying: error)
        }

        return ReminderList(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            color: nil,
            isShared: false,
            reminderCount: 0,
            incompleteCount: 0
        )
    }

    func deleteList(id: String) async throws -> (title: String, reminderCount: Int) {
        guard let calendar = store.calendar(withIdentifier: id) else {
            throw EventKitError.calendarNotFound(id: id)
        }
        guard !isReadOnly(calendar) else {
            throw EventKitError.readOnlyList(listName: calendar.title)
        }

        let title = calendar.title
        // Count reminders before deleting
        let predicate = store.predicateForReminders(in: [calendar])
        let reminders = try await fetchRemindersRaw(matching: predicate)
        let count = reminders.count

        do {
            try store.removeCalendar(calendar, commit: true)
        } catch {
            throw EventKitError.deleteFailed(underlying: error)
        }

        return (title: title, reminderCount: count)
    }

    // MARK: - Reminders

    func fetchReminders(listID: String?, includeCompleted: Bool, dueBefore: Date?, dueAfter: Date?, limit: Int) async throws -> [Reminder] {
        let calendars: [EKCalendar]?
        if let listID = listID {
            guard let cal = store.calendar(withIdentifier: listID) else {
                throw EventKitError.calendarNotFound(id: listID)
            }
            calendars = [cal]
        } else {
            calendars = nil
        }

        let reminders: [EKReminder]
        if includeCompleted {
            let predicate = store.predicateForReminders(in: calendars)
            reminders = try await fetchRemindersRaw(matching: predicate)
        } else {
            let predicate = store.predicateForIncompleteReminders(
                withDueDateStarting: dueAfter,
                ending: dueBefore,
                calendars: calendars
            )
            reminders = try await fetchRemindersRaw(matching: predicate)
        }

        // Apply date filters for the "all reminders" case
        var filtered = reminders
        if includeCompleted {
            if let after = dueAfter {
                filtered = filtered.filter { r in
                    guard let due = r.dueDateComponents?.date else { return false }
                    return due >= after
                }
            }
            if let before = dueBefore {
                filtered = filtered.filter { r in
                    guard let due = r.dueDateComponents?.date else { return false }
                    return due <= before
                }
            }
        }

        // Sort by due date (nil dates last), then by creation date
        filtered.sort { a, b in
            let aDate = a.dueDateComponents?.date
            let bDate = b.dueDateComponents?.date
            if let ad = aDate, let bd = bDate { return ad < bd }
            if aDate != nil { return true }
            if bDate != nil { return false }
            return (a.creationDate ?? .distantPast) > (b.creationDate ?? .distantPast)
        }

        return Array(filtered.prefix(limit)).map { mapReminder($0) }
    }

    func fetchReminderDetail(id: String) async throws -> ReminderDetail {
        guard let item = store.calendarItem(withIdentifier: id) as? EKReminder else {
            throw EventKitError.reminderNotFound(id: id)
        }

        let cal = item.calendar
        return ReminderDetail(
            id: item.calendarItemIdentifier,
            title: item.title ?? "",
            listID: cal?.calendarIdentifier ?? "",
            listTitle: cal?.title ?? "",
            isCompleted: item.isCompleted,
            completionDate: item.completionDate.map { dateFormatter.string(from: $0) },
            dueDate: item.dueDateComponents?.date.map { dateFormatter.string(from: $0) },
            remindDate: item.alarms?.first?.absoluteDate.map { dateFormatter.string(from: $0) },
            priority: item.priority,
            priorityLabel: priorityLabel(item.priority),
            isFlagged: false,
            notes: item.notes,
            url: item.url?.absoluteString,
            isSharedList: cal.map { isReadOnly($0) } ?? false,
            creationDate: item.creationDate.map { dateFormatter.string(from: $0) },
            lastModifiedDate: item.lastModifiedDate.map { dateFormatter.string(from: $0) }
        )
    }

    func createReminder(
        title: String,
        listID: String?,
        listName: String?,
        dueDate: Date?,
        remindDate: Date?,
        priority: Int,
        notes: String?,
        flagged: Bool,
        url: String?
    ) throws -> Reminder {
        let reminder = EKReminder(eventStore: store)
        reminder.title = title

        // Resolve list
        if let listID = listID {
            guard let cal = store.calendar(withIdentifier: listID) else {
                throw EventKitError.calendarNotFound(id: listID)
            }
            guard !isReadOnly(cal) else {
                throw EventKitError.readOnlyList(listName: cal.title)
            }
            reminder.calendar = cal
        } else if let listName = listName {
            let calendars = store.calendars(for: .reminder)
            guard let cal = calendars.first(where: { $0.title.lowercased() == listName.lowercased() }) else {
                throw EventKitError.calendarNotFound(id: listName)
            }
            guard !isReadOnly(cal) else {
                throw EventKitError.readOnlyList(listName: cal.title)
            }
            reminder.calendar = cal
        } else {
            reminder.calendar = store.defaultCalendarForNewReminders()
        }

        if let dueDate = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: dueDate
            )
        }
        if let remindDate = remindDate {
            reminder.addAlarm(EKAlarm(absoluteDate: remindDate))
        } else if let dueDate = dueDate {
            reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
        }
        reminder.priority = priority
        reminder.notes = notes
        // Note: isFlagged is not available in EventKit API
        if let urlString = url, let url = URL(string: urlString) {
            reminder.url = url
        }

        do {
            try store.save(reminder, commit: true)
        } catch {
            throw EventKitError.saveFailed(underlying: error)
        }

        return mapReminder(reminder)
    }

    func completeReminder(id: String, completed: Bool) throws -> Reminder {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else {
            throw EventKitError.reminderNotFound(id: id)
        }
        if let cal = reminder.calendar, isReadOnly(cal) {
            throw EventKitError.readOnlyList(listName: cal.title)
        }
        reminder.isCompleted = completed
        do {
            try store.save(reminder, commit: true)
        } catch {
            throw EventKitError.saveFailed(underlying: error)
        }
        return mapReminder(reminder)
    }

    func deleteReminder(id: String) throws -> (title: String, listTitle: String) {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else {
            throw EventKitError.reminderNotFound(id: id)
        }
        if let cal = reminder.calendar, isReadOnly(cal) {
            throw EventKitError.readOnlyList(listName: cal.title)
        }
        let title = reminder.title ?? ""
        let listTitle = reminder.calendar?.title ?? ""
        do {
            try store.remove(reminder, commit: true)
        } catch {
            throw EventKitError.deleteFailed(underlying: error)
        }
        return (title: title, listTitle: listTitle)
    }

    func updateReminder(
        id: String,
        title: String?,
        notes: String?,
        dueDate: Date?,
        clearDueDate: Bool,
        remindDate: Date?,
        clearRemindDate: Bool,
        priority: Int?,
        flagged: Bool?,
        listID: String?,
        listName: String?,
        url: String?,
        completed: Bool?
    ) throws -> (reminder: Reminder, updatedFields: [String]) {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else {
            throw EventKitError.reminderNotFound(id: id)
        }
        if let cal = reminder.calendar, isReadOnly(cal) {
            throw EventKitError.readOnlyList(listName: cal.title)
        }

        var updatedFields: [String] = []

        if let title = title {
            reminder.title = title
            updatedFields.append("title")
        }
        if let notes = notes {
            reminder.notes = notes.isEmpty ? nil : notes
            updatedFields.append("notes")
        }
        if clearDueDate {
            reminder.dueDateComponents = nil
            updatedFields.append("due_date")
        } else if let dueDate = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: dueDate
            )
            updatedFields.append("due_date")
        }
        if clearRemindDate {
            reminder.alarms?.forEach { reminder.removeAlarm($0) }
            updatedFields.append("remind_date")
        } else if let remindDate = remindDate {
            reminder.alarms?.forEach { reminder.removeAlarm($0) }
            reminder.addAlarm(EKAlarm(absoluteDate: remindDate))
            updatedFields.append("remind_date")
        }
        if let priority = priority {
            reminder.priority = priority
            updatedFields.append("priority")
        }
        // Note: isFlagged is not available in EventKit API
        _ = flagged
        if let listID = listID {
            guard let cal = store.calendar(withIdentifier: listID) else {
                throw EventKitError.calendarNotFound(id: listID)
            }
            reminder.calendar = cal
            updatedFields.append("list")
        } else if let listName = listName {
            let calendars = store.calendars(for: .reminder)
            guard let cal = calendars.first(where: { $0.title.lowercased() == listName.lowercased() }) else {
                throw EventKitError.calendarNotFound(id: listName)
            }
            reminder.calendar = cal
            updatedFields.append("list")
        }
        if let urlStr = url {
            reminder.url = urlStr.isEmpty ? nil : URL(string: urlStr)
            updatedFields.append("url")
        }
        if let completed = completed {
            reminder.isCompleted = completed
            updatedFields.append("completed")
        }

        do {
            try store.save(reminder, commit: true)
        } catch {
            throw EventKitError.saveFailed(underlying: error)
        }

        return (reminder: mapReminder(reminder), updatedFields: updatedFields)
    }

    func searchReminders(query: String, listID: String?, includeCompleted: Bool) async throws -> [Reminder] {
        let calendars: [EKCalendar]?
        if let listID = listID {
            guard let cal = store.calendar(withIdentifier: listID) else {
                throw EventKitError.calendarNotFound(id: listID)
            }
            calendars = [cal]
        } else {
            calendars = nil
        }

        let predicate = store.predicateForReminders(in: calendars)
        let allReminders = try await fetchRemindersRaw(matching: predicate)
        let queryLower = query.lowercased()

        let matched = allReminders.filter { r in
            if !includeCompleted && r.isCompleted { return false }
            let titleMatch = r.title?.lowercased().contains(queryLower) ?? false
            let notesMatch = r.notes?.lowercased().contains(queryLower) ?? false
            return titleMatch || notesMatch
        }

        return Array(matched.prefix(100)).map { mapReminder($0) }
    }

    // MARK: - Helpers

    /// Wrapper to safely pass non-Sendable EKReminder arrays across isolation boundaries.
    /// Safe because EventKitStore is an actor and serializes all access.
    private struct UncheckedReminders: @unchecked Sendable {
        let value: [EKReminder]
    }

    private func fetchRemindersRaw(matching predicate: NSPredicate) async throws -> [EKReminder] {
        let wrapped: UncheckedReminders = try await withCheckedThrowingContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    continuation.resume(returning: UncheckedReminders(value: reminders))
                } else {
                    continuation.resume(throwing: EventKitError.fetchFailed(
                        underlying: NSError(domain: "macMCP", code: 2, userInfo: [NSLocalizedDescriptionKey: "Fetch returned nil"])
                    ))
                }
            }
        }
        return wrapped.value
    }

    private func mapReminder(_ r: EKReminder) -> Reminder {
        Reminder(
            id: r.calendarItemIdentifier,
            title: r.title ?? "",
            listID: r.calendar?.calendarIdentifier ?? "",
            listTitle: r.calendar?.title ?? "",
            isCompleted: r.isCompleted,
            completionDate: r.completionDate.map { dateFormatter.string(from: $0) },
            dueDate: r.dueDateComponents?.date.map { dateFormatter.string(from: $0) },
            priority: r.priority,
            priorityLabel: priorityLabel(r.priority),
            isFlagged: false,
            hasNotes: r.notes != nil && !(r.notes?.isEmpty ?? true),
            creationDate: r.creationDate.map { dateFormatter.string(from: $0) }
        )
    }

    private func priorityLabel(_ priority: Int) -> String {
        switch priority {
        case 1...4: return "high"
        case 5: return "medium"
        case 6...9: return "low"
        default: return "none"
        }
    }

    private func isReadOnly(_ calendar: EKCalendar) -> Bool {
        !calendar.allowsContentModifications
    }

    private func defaultReminderSource() -> EKSource? {
        // Prefer iCloud, then local
        if let icloud = store.sources.first(where: { $0.sourceType == .calDAV }) {
            return icloud
        }
        return store.sources.first(where: { $0.sourceType == .local })
    }

    private func hexColor(from cgColor: CGColor) -> String? {
        guard let components = cgColor.components, components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
