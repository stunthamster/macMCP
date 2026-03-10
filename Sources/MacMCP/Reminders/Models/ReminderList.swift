struct ReminderList: Sendable {
    let id: String
    let title: String
    let color: String?
    let isShared: Bool
    let reminderCount: Int
    let incompleteCount: Int
}
