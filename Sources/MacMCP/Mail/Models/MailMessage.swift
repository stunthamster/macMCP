import Foundation

struct MailMessage: Codable, Sendable {
    let id: Int
    let subject: String
    let sender: String
    let dateReceived: String
    let isRead: Bool
    let isFlagged: Bool
    let snippet: String?
}

struct MailMessageDetail: Codable, Sendable {
    let id: Int
    let subject: String
    let sender: String
    let toRecipients: [String]
    let ccRecipients: [String]
    let dateReceived: String
    let isRead: Bool
    let isFlagged: Bool
    let body: String
}
