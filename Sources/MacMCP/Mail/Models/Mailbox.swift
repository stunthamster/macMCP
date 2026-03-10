import Foundation

struct Mailbox: Codable, Sendable {
    let name: String
    let unreadCount: Int
    let accountName: String
}
