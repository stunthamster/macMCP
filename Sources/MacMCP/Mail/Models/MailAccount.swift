import Foundation

struct MailAccount: Codable, Sendable {
    let name: String
    let userName: String
    let enabled: Bool
    let emailAddresses: [String]
}
