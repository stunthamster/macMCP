enum MailboxesScript {
    static func list(accountName: String) -> String {
        let safeName = InputValidation.escapeForAppleScript(accountName)
        return """
        \(AppleScriptHelpers.escapeForJSON)

        tell application "Mail"
            set jsonResult to "["
            set acct to account "\(safeName)"
            set mboxes to every mailbox of acct
            set isFirst to true
            repeat with mb in mboxes
                if not isFirst then set jsonResult to jsonResult & ","
                set isFirst to false

                set mbName to my escapeForJSON(name of mb)
                set mbUnread to unread count of mb

                set jsonResult to jsonResult & "{\\"name\\": \\"" & mbName & "\\""
                set jsonResult to jsonResult & ", \\"unreadCount\\": " & mbUnread
                set jsonResult to jsonResult & ", \\"accountName\\": \\"" & my escapeForJSON(name of acct) & "\\""
                set jsonResult to jsonResult & "}"
            end repeat
            set jsonResult to jsonResult & "]"
            return jsonResult
        end tell
        """
    }
}
