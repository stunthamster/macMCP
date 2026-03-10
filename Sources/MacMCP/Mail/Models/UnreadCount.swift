import Foundation

struct UnreadCount: Codable, Sendable {
    let unreadCount: Int
    let accountName: String?
    let mailboxName: String?
    let breakdown: [UnreadBreakdown]?
}

struct UnreadBreakdown: Codable, Sendable {
    let account: String?
    let mailbox: String?
    let count: Int
}
