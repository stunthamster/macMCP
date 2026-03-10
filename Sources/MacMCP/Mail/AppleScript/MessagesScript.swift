enum MessagesScript {
    static func list(accountName: String, mailboxName: String, limit: Int, offset: Int) -> String {
        let safeAccount = InputValidation.escapeForAppleScript(accountName)
        let safeMailbox = InputValidation.escapeForAppleScript(mailboxName)
        let startIdx = offset + 1
        let endIdx = offset + limit

        return """
        \(AppleScriptHelpers.escapeForJSON)

        tell application "Mail"
            set mb to mailbox "\(safeMailbox)" of account "\(safeAccount)"
            set msgCount to count of messages of mb
            set startIdx to \(startIdx)
            set endIdx to \(endIdx)
            if endIdx > msgCount then set endIdx to msgCount
            if startIdx > msgCount then
                return "[]"
            end if

            set jsonResult to "["
            set isFirst to true
            set msgs to messages startIdx thru endIdx of mb
            repeat with m in msgs
                if not isFirst then set jsonResult to jsonResult & ","
                set isFirst to false

                set subj to my escapeForJSON(subject of m)
                set sndr to my escapeForJSON(sender of m)
                set msgId to id of m
                set isRead to read status of m
                set isFlagged to flagged status of m

                -- Snippet: first 200 chars of body for triage
                set snippetText to ""
                try
                    set bodyText to content of m
                    if (count of bodyText) > 200 then
                        set snippetText to text 1 thru 200 of bodyText
                    else
                        set snippetText to bodyText
                    end if
                end try
                set snippetText to my escapeForJSON(snippetText)

                -- Date as ISO 8601 string
                set dateRecv to date received of m
                set dateStr to my escapeForJSON((dateRecv as «class isot» as string))

                set jsonResult to jsonResult & "{\\"id\\": " & msgId
                set jsonResult to jsonResult & ", \\"subject\\": \\"" & subj & "\\""
                set jsonResult to jsonResult & ", \\"sender\\": \\"" & sndr & "\\""
                set jsonResult to jsonResult & ", \\"dateReceived\\": \\"" & dateStr & "\\""
                set jsonResult to jsonResult & ", \\"isRead\\": " & isRead
                set jsonResult to jsonResult & ", \\"isFlagged\\": " & isFlagged
                set jsonResult to jsonResult & ", \\"snippet\\": \\"" & snippetText & "\\""
                set jsonResult to jsonResult & "}"
            end repeat
            set jsonResult to jsonResult & "]"
            return jsonResult
        end tell
        """
    }
}
