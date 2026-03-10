struct Reminder: Sendable {
    let id: String
    let title: String
    let listID: String
    let listTitle: String
    let isCompleted: Bool
    let completionDate: String?
    let dueDate: String?
    let priority: Int
    let priorityLabel: String
    let isFlagged: Bool
    let hasNotes: Bool
    let creationDate: String?
}

struct ReminderDetail: Sendable {
    let id: String
    let title: String
    let listID: String
    let listTitle: String
    let isCompleted: Bool
    let completionDate: String?
    let dueDate: String?
    let remindDate: String?
    let priority: Int
    let priorityLabel: String
    let isFlagged: Bool
    let notes: String?
    let url: String?
    let isSharedList: Bool
    let creationDate: String?
    let lastModifiedDate: String?
}
