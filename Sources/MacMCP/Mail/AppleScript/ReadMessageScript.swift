enum ReadMessageScript {
    static let maxBodyLength = 10000

    static func read(accountName: String, mailboxName: String, messageId: Int) -> String {
        let safeAccount = InputValidation.escapeForAppleScript(accountName)
        let safeMailbox = InputValidation.escapeForAppleScript(mailboxName)

        return """
        \(AppleScriptHelpers.escapeForJSON)

        tell application "Mail"
            set mb to mailbox "\(safeMailbox)" of account "\(safeAccount)"
            set msg to (first message of mb whose id is \(messageId))

            set subj to my escapeForJSON(subject of msg)
            set sndr to my escapeForJSON(sender of msg)
            set msgId to id of msg
            set isRead to read status of msg
            set isFlagged to flagged status of msg

            -- Body with truncation
            set bodyText to content of msg
            if (count of bodyText) > \(maxBodyLength) then
                set bodyText to text 1 thru \(maxBodyLength) of bodyText
                set bodyText to bodyText & "\\n[TRUNCATED]"
            end if
            set bodyText to my escapeForJSON(bodyText)

            -- Recipients
            set toList to "["
            set toFirst to true
            repeat with r in to recipients of msg
                if not toFirst then set toList to toList & ","
                set toFirst to false
                set toList to toList & "\\"" & my escapeForJSON(address of r) & "\\""
            end repeat
            set toList to toList & "]"

            set ccList to "["
            set ccFirst to true
            repeat with r in cc recipients of msg
                if not ccFirst then set ccList to ccList & ","
                set ccFirst to false
                set ccList to ccList & "\\"" & my escapeForJSON(address of r) & "\\""
            end repeat
            set ccList to ccList & "]"

            -- Date as ISO 8601 string
            set dateRecv to date received of msg
            set dateStr to my escapeForJSON((dateRecv as «class isot» as string))

            set jsonResult to "{"
            set jsonResult to jsonResult & "\\"id\\": " & msgId
            set jsonResult to jsonResult & ", \\"subject\\": \\"" & subj & "\\""
            set jsonResult to jsonResult & ", \\"sender\\": \\"" & sndr & "\\""
            set jsonResult to jsonResult & ", \\"toRecipients\\": " & toList
            set jsonResult to jsonResult & ", \\"ccRecipients\\": " & ccList
            set jsonResult to jsonResult & ", \\"dateReceived\\": \\"" & dateStr & "\\""
            set jsonResult to jsonResult & ", \\"isRead\\": " & isRead
            set jsonResult to jsonResult & ", \\"isFlagged\\": " & isFlagged
            set jsonResult to jsonResult & ", \\"body\\": \\"" & bodyText & "\\""
            set jsonResult to jsonResult & "}"
            return jsonResult
        end tell
        """
    }
}
