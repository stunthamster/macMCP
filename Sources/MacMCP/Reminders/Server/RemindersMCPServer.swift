import MCP
import Foundation

final class RemindersMCPServer: @unchecked Sendable {
    private let server: Server
    private let store: EventKitStore
    private let rateLimiter: RateLimiter

    init() {
        self.server = Server(
            name: "macMCP-reminders",
            version: "0.1.0",
            capabilities: .init(tools: .init(listChanged: false))
        )
        self.store = EventKitStore()
        self.rateLimiter = RateLimiter()
    }

    func run() async {
        // Request EventKit access before accepting tool calls
        do {
            try await store.requestAccess()
        } catch {
            Self.logError("Failed to get Reminders access: \(error)")
            // Continue anyway — individual tool calls will fail with clear errors
        }

        let transport = StdioTransport()

        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: RemindersToolRegistry.allTools())
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
            case "reminders_list_lists":
                return try await handleListLists()
            case "reminders_get_reminders":
                return try await handleGetReminders(params.arguments)
            case "reminders_get_reminder":
                return try await handleGetReminder(params.arguments)
            case "reminders_create_reminder":
                return try await handleCreateReminder(params.arguments)
            case "reminders_complete_reminder":
                return try await handleCompleteReminder(params.arguments)
            case "reminders_delete_reminder":
                return try await handleDeleteReminder(params.arguments)
            case "reminders_update_reminder":
                return try await handleUpdateReminder(params.arguments)
            case "reminders_create_list":
                return try await handleCreateList(params.arguments)
            case "reminders_delete_list":
                return try await handleDeleteList(params.arguments)
            case "reminders_search":
                return try await handleSearch(params.arguments)
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
        FileHandle.standardError.write(Data("[macMCP-reminders] \(message)\n".utf8))
    }

    private static func logAudit(_ tool: String, _ fields: [String: String]) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fieldStr = fields.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        FileHandle.standardError.write(Data("[macMCP \(timestamp)] REMINDERS \(tool): \(fieldStr)\n".utf8))
    }

    // MARK: - Read Tools

    private func handleListLists() async throws -> CallTool.Result {
        let lists = try await store.fetchListsWithCounts()
        return CallTool.Result(content: [.text(ReminderFormatter.formatLists(lists))])
    }

    private func handleGetReminders(_ args: [String: Value]?) async throws -> CallTool.Result {
        let listID = try await resolveListID(args)
        let includeCompleted = args?["include_completed"]?.boolValue ?? false
        let limit = min(args?["limit"]?.intValue ?? 50, 200)

        var dueBefore: Date? = nil
        var dueAfter: Date? = nil
        if let before = args?["due_before"]?.stringValue {
            dueBefore = try InputValidation.validateAndParseDate(before, parameter: "due_before")
        }
        if let after = args?["due_after"]?.stringValue {
            dueAfter = try InputValidation.validateAndParseDate(after, parameter: "due_after")
        }

        let reminders = try await store.fetchReminders(
            listID: listID,
            includeCompleted: includeCompleted,
            dueBefore: dueBefore,
            dueAfter: dueAfter,
            limit: limit
        )
        return CallTool.Result(content: [.text(ReminderFormatter.formatReminders(reminders))])
    }

    private func handleGetReminder(_ args: [String: Value]?) async throws -> CallTool.Result {
        guard let reminderID = args?["reminder_id"]?.stringValue else {
            return CallTool.Result(content: [.text("Error: reminder_id is required")], isError: true)
        }
        try InputValidation.validateCalendarID(reminderID, parameter: "reminder_id")

        let detail = try await store.fetchReminderDetail(id: reminderID)
        return CallTool.Result(content: [.text(ReminderFormatter.formatReminderDetail(detail))])
    }

    // MARK: - Write Tools

    private func handleCreateReminder(_ args: [String: Value]?) async throws -> CallTool.Result {
        guard let title = args?["title"]?.stringValue else {
            return CallTool.Result(content: [.text("Error: title is required")], isError: true)
        }
        try InputValidation.validateReminderTitle(title)
        try await rateLimiter.checkCreate()

        let listID = args?["list_id"]?.stringValue
        let listName = args?["list_name"]?.stringValue
        if let id = listID { try InputValidation.validateCalendarID(id, parameter: "list_id") }
        if let name = listName { try InputValidation.validateString(name, parameter: "list_name") }

        var dueDate: Date? = nil
        if let dueDateStr = args?["due_date"]?.stringValue {
            dueDate = try InputValidation.validateAndParseDate(dueDateStr, parameter: "due_date")
        }
        var remindDate: Date? = nil
        if let remindStr = args?["remind_date"]?.stringValue {
            remindDate = try InputValidation.validateAndParseDate(remindStr, parameter: "remind_date")
        }

        let priority = parsePriority(args?["priority"]?.stringValue)
        var notes: String? = nil
        if let n = args?["notes"]?.stringValue {
            try InputValidation.validateNotes(n)
            notes = n
        }
        let flagged = args?["flagged"]?.boolValue ?? false
        let url = args?["url"]?.stringValue

        let reminder = try await store.createReminder(
            title: title,
            listID: listID,
            listName: listName,
            dueDate: dueDate,
            remindDate: remindDate,
            priority: priority,
            notes: notes,
            flagged: flagged,
            url: url
        )
        await rateLimiter.recordCreate()

        Self.logAudit("reminders_create_reminder", [
            "id": reminder.id,
            "title": String(title.prefix(80)),
            "list": reminder.listTitle,
            "due_date": dueDate.map { ISO8601DateFormatter().string(from: $0) } ?? "none"
        ])

        var output = "Created reminder: \(reminder.title)\n"
        output += "  ID: \(reminder.id)\n"
        output += "  List: \(reminder.listTitle)\n"
        if let due = reminder.dueDate {
            output += "  Due: \(due)\n"
        }
        return CallTool.Result(content: [.text(output)])
    }

    private func handleCompleteReminder(_ args: [String: Value]?) async throws -> CallTool.Result {
        guard let reminderID = args?["reminder_id"]?.stringValue else {
            return CallTool.Result(content: [.text("Error: reminder_id is required")], isError: true)
        }
        try InputValidation.validateCalendarID(reminderID, parameter: "reminder_id")

        let completed = args?["completed"]?.boolValue ?? true
        let reminder = try await store.completeReminder(id: reminderID, completed: completed)

        Self.logAudit("reminders_complete_reminder", [
            "id": reminderID,
            "completed": "\(completed)"
        ])

        let action = completed ? "Completed" : "Marked incomplete"
        return CallTool.Result(content: [.text("\(action): \(reminder.title)")])
    }

    private func handleDeleteReminder(_ args: [String: Value]?) async throws -> CallTool.Result {
        guard let reminderID = args?["reminder_id"]?.stringValue else {
            return CallTool.Result(content: [.text("Error: reminder_id is required")], isError: true)
        }
        try InputValidation.validateCalendarID(reminderID, parameter: "reminder_id")
        try await rateLimiter.checkDelete()

        let (title, listTitle) = try await store.deleteReminder(id: reminderID)
        await rateLimiter.recordDelete()

        Self.logAudit("reminders_delete_reminder", [
            "id": reminderID,
            "title": String(title.prefix(40)),
            "list": listTitle
        ])

        return CallTool.Result(content: [.text("Deleted reminder: \(title) (from \(listTitle))")])
    }

    private func handleUpdateReminder(_ args: [String: Value]?) async throws -> CallTool.Result {
        guard let reminderID = args?["reminder_id"]?.stringValue else {
            return CallTool.Result(content: [.text("Error: reminder_id is required")], isError: true)
        }
        try InputValidation.validateCalendarID(reminderID, parameter: "reminder_id")

        var title: String? = nil
        if let t = args?["title"]?.stringValue {
            try InputValidation.validateReminderTitle(t)
            title = t
        }
        var notes: String? = nil
        if let n = args?["notes"]?.stringValue {
            try InputValidation.validateNotes(n)
            notes = n
        }
        var dueDate: Date? = nil
        var clearDueDate = false
        if let dueDateStr = args?["due_date"]?.stringValue {
            if dueDateStr == "clear" {
                clearDueDate = true
            } else {
                dueDate = try InputValidation.validateAndParseDate(dueDateStr, parameter: "due_date")
            }
        }
        var remindDate: Date? = nil
        var clearRemindDate = false
        if let remindStr = args?["remind_date"]?.stringValue {
            if remindStr == "clear" {
                clearRemindDate = true
            } else {
                remindDate = try InputValidation.validateAndParseDate(remindStr, parameter: "remind_date")
            }
        }

        let priority: Int? = args?["priority"]?.stringValue.map { parsePriority($0) }
        let flagged = args?["flagged"]?.boolValue
        let listID = args?["list_id"]?.stringValue
        let listName = args?["list_name"]?.stringValue
        if let id = listID { try InputValidation.validateCalendarID(id, parameter: "list_id") }
        if let name = listName { try InputValidation.validateString(name, parameter: "list_name") }
        let url = args?["url"]?.stringValue

        let (reminder, updatedFields) = try await store.updateReminder(
            id: reminderID,
            title: title,
            notes: notes,
            dueDate: dueDate,
            clearDueDate: clearDueDate,
            remindDate: remindDate,
            clearRemindDate: clearRemindDate,
            priority: priority,
            flagged: flagged,
            listID: listID,
            listName: listName,
            url: url,
            completed: nil
        )

        Self.logAudit("reminders_update_reminder", [
            "id": reminderID,
            "fields": updatedFields.joined(separator: ",")
        ])

        return CallTool.Result(content: [.text("Updated '\(reminder.title)': \(updatedFields.joined(separator: ", "))")])
    }

    private func handleCreateList(_ args: [String: Value]?) async throws -> CallTool.Result {
        guard let name = args?["name"]?.stringValue else {
            return CallTool.Result(content: [.text("Error: name is required")], isError: true)
        }
        try InputValidation.validateReminderTitle(name, parameter: "name")
        try await rateLimiter.checkCreate()

        let list = try await store.createList(name: name)
        await rateLimiter.recordCreate()

        Self.logAudit("reminders_create_list", ["id": list.id, "name": name])

        return CallTool.Result(content: [.text("Created list: \(list.title)\n  ID: \(list.id)")])
    }

    private func handleDeleteList(_ args: [String: Value]?) async throws -> CallTool.Result {
        guard let listID = args?["list_id"]?.stringValue else {
            return CallTool.Result(content: [.text("Error: list_id is required")], isError: true)
        }
        try InputValidation.validateCalendarID(listID, parameter: "list_id")
        try await rateLimiter.checkDelete()

        let (title, reminderCount) = try await store.deleteList(id: listID)
        await rateLimiter.recordDelete()

        Self.logAudit("reminders_delete_list", [
            "id": listID,
            "title": title,
            "reminder_count": "\(reminderCount)"
        ])

        return CallTool.Result(content: [.text("Deleted list '\(title)' and its \(reminderCount) reminder(s).")])
    }

    private func handleSearch(_ args: [String: Value]?) async throws -> CallTool.Result {
        guard let query = args?["query"]?.stringValue else {
            return CallTool.Result(content: [.text("Error: query is required")], isError: true)
        }
        try InputValidation.validateString(query, parameter: "query")

        let listID = args?["list_id"]?.stringValue
        if let id = listID { try InputValidation.validateCalendarID(id, parameter: "list_id") }
        let includeCompleted = args?["include_completed"]?.boolValue ?? false

        let reminders = try await store.searchReminders(
            query: query,
            listID: listID,
            includeCompleted: includeCompleted
        )
        return CallTool.Result(content: [.text(ReminderFormatter.formatReminders(reminders, context: "Search results for '\(query)'"))])
    }

    // MARK: - Helpers

    private func resolveListID(_ args: [String: Value]?) async throws -> String? {
        if let listID = args?["list_id"]?.stringValue {
            try InputValidation.validateCalendarID(listID, parameter: "list_id")
            return listID
        }
        if let listName = args?["list_name"]?.stringValue {
            try InputValidation.validateString(listName, parameter: "list_name")
            guard let id = await store.resolveListIDByName(listName) else {
                throw EventKitError.calendarNotFound(id: listName)
            }
            return id
        }
        return nil
    }

    private func parsePriority(_ value: String?) -> Int {
        switch value?.lowercased() {
        case "high": return 1
        case "medium": return 5
        case "low": return 9
        default: return 0
        }
    }
}
